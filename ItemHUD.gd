extends Control

# ============================================================
# ItemHUD.gd
# ============================================================
# Draws the 4 rune inventory slots in the bottom-left corner.
# Listens to ItemManager signals to update automatically.
#
# WHAT IT SHOWS:
#   [■] [■] [■] [■]    ← 4 item slots
#    Rune  name         ← name of hovered/last picked rune
#   ✦ SYNERGY NAME      ← synergy popup (fades after 3 seconds)
#
# HOW TO CONNECT:
#   In Game.gd _ready(), after connect_to_player():
#     $HUD/ItemHUD.connect_to_item_manager($Player/ItemManager)
# ============================================================

var item_manager: Node = null

# Layout
const SLOT_SIZE:    float = 34.0
const SLOT_GAP:     float = 6.0
const SLOTS_ORIGIN: Vector2 = Vector2(16, 0)   # y set relative to screen bottom in _draw

# Slot data cache (updated via signal)
var _slots: Array = []   # Array of rune Dicts (or empty Dict for empty slot)
var _hovered_slot: int = -1
var _last_picked_name: String = ""

# Synergy popup
var _synergy_text:  String = ""
var _synergy_alpha: float  = 0.0
var _synergy_timer: float  = 0.0

# Rarity colours
const RARITY_COLORS = {
	"common":    Color(0.75, 0.75, 0.75),
	"uncommon":  Color(0.2,  0.75, 0.35),
	"rare":      Color(0.25, 0.5,  1.0),
	"legendary": Color(0.85, 0.6,  0.1),
}
const COLOR_EMPTY    = Color(0.15, 0.15, 0.18, 0.9)
const COLOR_BG_PANEL = Color(0.08, 0.08, 0.1,  0.85)


# ════════════════════════════════════════════════════════════
# connect_to_item_manager()
# ════════════════════════════════════════════════════════════
func connect_to_item_manager(mgr: Node):
	item_manager = mgr
	
	# Initialise empty slots
	_slots = []
	for i in range(ItemManager.MAX_SLOTS):
		_slots.append({})
	
	# Connect signals
	if mgr.has_signal("inventory_changed"):
		mgr.inventory_changed.connect(_on_inventory_changed)
	if mgr.has_signal("synergy_activated"):
		mgr.synergy_activated.connect(_on_synergy_activated)
	if mgr.has_signal("rune_picked_up"):
		mgr.rune_picked_up.connect(_on_rune_picked_up)
	
	queue_redraw()


# ════════════════════════════════════════════════════════════
# _process()
# ════════════════════════════════════════════════════════════
func _process(delta: float):
	# Fade the synergy popup over time
	if _synergy_timer > 0:
		_synergy_timer -= delta
		_synergy_alpha  = clampf(_synergy_timer / 3.0, 0.0, 1.0)
		queue_redraw()
	
	# Mouse hover detection for tooltip
	var mouse  = get_local_mouse_position()
	var new_hover = _get_slot_at_mouse(mouse)
	if new_hover != _hovered_slot:
		_hovered_slot = new_hover
		queue_redraw()


# ════════════════════════════════════════════════════════════
# _draw()  —  all rendering happens here
# ════════════════════════════════════════════════════════════
func _draw():
	var font     = ThemeDB.fallback_font
	var vp_h     = get_viewport_rect().size.y
	var origin_y = vp_h - SLOT_SIZE - 20.0   # Anchor to bottom of screen
	var origin   = Vector2(SLOTS_ORIGIN.x, origin_y)
	
	# ── Background panel ────────────────────────────────────
	var panel_w = (SLOT_SIZE + SLOT_GAP) * 4 + 4
	var panel_h = SLOT_SIZE + 22.0
	draw_rect(Rect2(origin.x - 4, origin.y - 18, panel_w, panel_h + 8), COLOR_BG_PANEL)
	
	# ── "RUNES" label ───────────────────────────────────────
	draw_string(font, Vector2(origin.x, origin.y - 6),
		"RUNES", HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		Color(0.45, 0.45, 0.5))
	
	# ── Item slots ──────────────────────────────────────────
	for i in range(4):
		var sx = origin.x + i * (SLOT_SIZE + SLOT_GAP)
		var sy = origin.y
		var slot_rect = Rect2(sx, sy, SLOT_SIZE, SLOT_SIZE)
		
		# Background
		draw_rect(slot_rect, COLOR_EMPTY)
		
		# Slot number hint (small, bottom-right)
		draw_string(font, Vector2(sx + SLOT_SIZE - 10, sy + SLOT_SIZE - 2),
			str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color(0.3, 0.3, 0.35))
		
		if i < _slots.size() and not _slots[i].is_empty():
			var rune   = _slots[i]
			var rarity = rune.get("rarity", "common")
			var color  = RARITY_COLORS.get(rarity, Color.WHITE)
			
			# Filled slot background — tinted by rarity
			draw_rect(slot_rect, color * Color(0.15, 0.15, 0.15, 1.0))
			
			# Rarity border — thicker and brighter for higher rarity
			var border_w = 1.0 if rarity == "common" else (1.5 if rarity == "uncommon" else 2.0)
			draw_rect(slot_rect, color, false, border_w)
			
			# Legendary slots get an animated corner glow effect
			if rarity == "legendary":
				var pulse = 0.5 + sin(Time.get_ticks_msec() * 0.004) * 0.3
				draw_rect(Rect2(sx - 2, sy - 2, SLOT_SIZE + 4, SLOT_SIZE + 4),
					Color(color.r, color.g, color.b, pulse), false, 1.5)
			
			# Draw placeholder icon: a diamond shape inside the slot
			var cx   = sx + SLOT_SIZE / 2
			var cy   = sy + SLOT_SIZE / 2
			var half = SLOT_SIZE * 0.28
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx, cy - half),
				Vector2(cx + half, cy),
				Vector2(cx, cy + half),
				Vector2(cx - half, cy),
			]), color)
			
			# Hover highlight
			if i == _hovered_slot:
				draw_rect(slot_rect, Color(1, 1, 1, 0.12))
		
		else:
			# Empty slot — draw a faint inner border
			draw_rect(slot_rect, Color(0.3, 0.3, 0.35, 0.3), false, 0.5)
	
	# ── Tooltip for hovered slot ────────────────────────────
	if _hovered_slot >= 0 and _hovered_slot < _slots.size() \
	and not _slots[_hovered_slot].is_empty():
		_draw_tooltip(font, _slots[_hovered_slot], origin, origin_y)
	
	# ── Synergy popup ───────────────────────────────────────
	if _synergy_alpha > 0:
		_draw_synergy_popup(font, origin_y)
	
	# ── Last picked rune name (fades) ───────────────────────
	if _last_picked_name != "" and _synergy_timer <= 0:
		draw_string(font,
			Vector2(origin.x, origin.y - 20),
			_last_picked_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(0.8, 0.8, 0.9, minf(_synergy_alpha + 0.5, 1.0)))


# ════════════════════════════════════════════════════════════
# _draw_tooltip()
# Small info card above the hovered slot
# ════════════════════════════════════════════════════════════
func _draw_tooltip(font: Font, rune: Dictionary, origin: Vector2, origin_y: float):
	var sx       = origin.x + _hovered_slot * (SLOT_SIZE + SLOT_GAP)
	var tooltip_y = origin_y - 52
	var bg_rect  = Rect2(sx - 2, tooltip_y, 160, 46)
	
	draw_rect(bg_rect, Color(0.08, 0.08, 0.1, 0.95))
	draw_rect(bg_rect, RARITY_COLORS.get(rune.get("rarity","common"), Color.GRAY),
		false, 0.75)
	
	# Name
	draw_string(font, Vector2(sx + 4, tooltip_y + 14),
		rune.get("name", "?"),
		HORIZONTAL_ALIGNMENT_LEFT, 152, 12,
		RARITY_COLORS.get(rune.get("rarity","common"), Color.WHITE))
	
	# Description
	draw_string(font, Vector2(sx + 4, tooltip_y + 30),
		rune.get("description", ""),
		HORIZONTAL_ALIGNMENT_LEFT, 152, 10,
		Color(0.65, 0.65, 0.7))


# ════════════════════════════════════════════════════════════
# _draw_synergy_popup()
# Flashes in the centre of the slots with gold text
# ════════════════════════════════════════════════════════════
func _draw_synergy_popup(font: Font, origin_y: float):
	var alpha  = _synergy_alpha
	var y_pos  = origin_y - 72 - (1.0 - alpha) * 10   # Rises as it fades
	
	# Background glow
	draw_rect(Rect2(SLOTS_ORIGIN.x - 4, y_pos - 16, 200, 24),
		Color(0.15, 0.12, 0.04, alpha * 0.85))
	
	# Synergy name
	draw_string(font,
		Vector2(SLOTS_ORIGIN.x, y_pos),
		"✦ " + _synergy_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		Color(0.9, 0.72, 0.15, alpha))


# ════════════════════════════════════════════════════════════
# Signal handlers
# ════════════════════════════════════════════════════════════

func _on_inventory_changed(new_inventory: Array):
	# Rebuild slot data from inventory array
	_slots = []
	for i in range(4):
		if i < new_inventory.size():
			_slots.append(new_inventory[i])
		else:
			_slots.append({})
	queue_redraw()

func _on_synergy_activated(synergy_name: String):
	_synergy_text  = synergy_name
	_synergy_alpha = 1.0
	_synergy_timer = 3.0   # Show for 3 seconds
	queue_redraw()

func _on_rune_picked_up(rune: Dictionary):
	_last_picked_name = rune.get("name", "")


# ════════════════════════════════════════════════════════════
# Input  —  number keys 1-4 drop items from slots
# ════════════════════════════════════════════════════════════
func _input(event: InputEvent):
	if item_manager == null: return
	
	# Hold ALT + number key to drop item from that slot
	if event is InputEventKey and event.pressed and event.alt_pressed:
		match event.keycode:
			KEY_1: _try_drop_slot(0)
			KEY_2: _try_drop_slot(1)
			KEY_3: _try_drop_slot(2)
			KEY_4: _try_drop_slot(3)

func _try_drop_slot(slot_idx: int):
	if slot_idx >= _slots.size() or _slots[slot_idx].is_empty():
		return
	var dropped = item_manager.drop_item(slot_idx)
	if not dropped.is_empty():
		print("[ItemHUD] Dropped: ", dropped.get("name","?"))


# ════════════════════════════════════════════════════════════
# _get_slot_at_mouse()  —  returns which slot index (0-3) the
# mouse is over, or -1 if none
# ════════════════════════════════════════════════════════════
func _get_slot_at_mouse(mouse_pos: Vector2) -> int:
	var vp_h     = get_viewport_rect().size.y
	var origin_y = vp_h - SLOT_SIZE - 20.0
	
	for i in range(4):
		var sx = SLOTS_ORIGIN.x + i * (SLOT_SIZE + SLOT_GAP)
		var slot_rect = Rect2(sx, origin_y, SLOT_SIZE, SLOT_SIZE)
		if slot_rect.has_point(mouse_pos):
			return i
	return -1
