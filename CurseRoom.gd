extends Node2D

# ============================================================
# CurseRoom.gd  —  Norn's Bargain Altar
# ============================================================
# The curse room presents a deal:
#   Accept a permanent handicap this run in exchange for
#   a guaranteed rare+ rune item.
#
# ── FLOW ────────────────────────────────────────────────────
#   1. Player enters room. Enemies are here (extra count from
#      Room.gd — 4–6 enemies, harder than a normal room).
#   2. After room is cleared, the altar activates.
#   3. Player approaches the altar and presses E.
#   4. A choice UI appears: 3 curses shown side by side.
#      Player uses left/right arrows to browse, E to accept.
#   5. On acceptance: curse is applied to the player,
#      a rare+ rune pedestal spawns, the altar shatters.
#   6. If player leaves without accepting: altar stays.
#      They can come back or skip it entirely.
#
# ── CURSES ──────────────────────────────────────────────────
#   BLEEDING WOUND    -15 max HP (permanent this run)
#   SLOW STEP         -20 move speed
#   SHAKY HANDS       +0.15 fire rate (slower shooting)
#   HEAVY BURDEN      Item slots reduced to 3 (drop oldest)
#   MARKED FOR DEATH  Enemies deal +1 extra damage
#   CRACKED DEFENCE   i-frames reduced by 0.4s after hits
#   CURSED GOLD       All gold pickups worth half this run
#   WEAKENED FLESH    -8 base damage
#   FORSAKEN          Special ability cooldown +4s
#   HUNGRY RUNES      Item effects trigger at 75% chance
#
# ── REWARD ──────────────────────────────────────────────────
#   Always an uncommon or better rune.
#   Floor 3+: guaranteed rare or better.
#   Floor 5:  guaranteed legendary.
#
# SCENE TREE for CurseRoom.tscn:
#   CurseRoom  [Node2D]          ← this script
#   └── AltarDetector  [Area2D]  ← triggers UI when player nearby
#       └── CollisionShape2D     (CircleShape2D r=50)
# ============================================================

signal curse_accepted(curse: Dictionary)
signal curse_skipped()

# ── CURSE DEFINITIONS ────────────────────────────────────────
# Each curse is a Dictionary with an apply function name
const CURSES = [
	{
		"id":          "bleeding_wound",
		"name":        "Bleeding Wound",
		"description": "The Norns carve their toll. -15 max HP.",
		"flavour":     "Your blood feeds Yggdrasil.",
		"icon":        "♥",
		"apply":       "curse_bleeding_wound",
		"severity":    1,   # 1=mild, 2=moderate, 3=harsh
	},
	{
		"id":          "slow_step",
		"name":        "Slow Step",
		"description": "Your legs grow heavy. -20 move speed.",
		"flavour":     "The roots of the world drag at your heels.",
		"icon":        "⟳",
		"apply":       "curse_slow_step",
		"severity":    1,
	},
	{
		"id":          "shaky_hands",
		"name":        "Shaky Hands",
		"description": "Your aim wavers. Shoot 0.15s slower.",
		"flavour":     "Even the gods tremble before fate.",
		"icon":        "✦",
		"apply":       "curse_shaky_hands",
		"severity":    1,
	},
	{
		"id":          "heavy_burden",
		"name":        "Heavy Burden",
		"description": "One rune slot is sealed. Max 3 items.",
		"flavour":     "What you carry weighs more than you know.",
		"icon":        "▣",
		"apply":       "curse_heavy_burden",
		"severity":    2,
	},
	{
		"id":          "marked_for_death",
		"name":        "Marked for Death",
		"description": "Enemies deal +1 damage on every hit.",
		"flavour":     "The ravens have spoken your name.",
		"icon":        "☠",
		"apply":       "curse_marked_for_death",
		"severity":    2,
	},
	{
		"id":          "cracked_defence",
		"name":        "Cracked Defence",
		"description": "i-frames after hits reduced by 0.4s.",
		"flavour":     "Your guard has cracks the size of fjords.",
		"icon":        "⛨",
		"apply":       "curse_cracked_defence",
		"severity":    2,
	},
	{
		"id":          "cursed_gold",
		"name":        "Cursed Gold",
		"description": "All gold pickups worth half this run.",
		"flavour":     "Midas wept. You will too.",
		"icon":        "⚙",
		"apply":       "curse_cursed_gold",
		"severity":    1,
	},
	{
		"id":          "weakened_flesh",
		"name":        "Weakened Flesh",
		"description": "Your strikes lose edge. -8 base damage.",
		"flavour":     "Strength is borrowed. The Norns demand repayment.",
		"icon":        "⚔",
		"apply":       "curse_weakened_flesh",
		"severity":    2,
	},
	{
		"id":          "forsaken",
		"name":        "Forsaken",
		"description": "Special ability cooldown +4 seconds.",
		"flavour":     "The gods have turned their backs.",
		"icon":        "⊗",
		"apply":       "curse_forsaken",
		"severity":    2,
	},
	{
		"id":          "hungry_runes",
		"name":        "Hungry Runes",
		"description": "Item passive effects only trigger 75% of the time.",
		"flavour":     "Power demands sacrifice. Always.",
		"icon":        "◈",
		"apply":       "curse_hungry_runes",
		"severity":    3,
	},
]

# ── STATE ────────────────────────────────────────────────────
var floor_num:          int  = 1
var held_ids:           Array = []
var altar_active:       bool = false   # Altar is lit after room cleared
var showing_ui:         bool = false   # Curse selection UI visible
var curse_ui_index:     int  = 0       # Which curse is currently shown
var offered_curses:     Array = []     # The 3 curses presented this room
var curse_accepted_flag: bool = false
var player_near_altar:  Node = null

# Altar animation
var _altar_pulse:       float = 0.0
var _altar_shatter:     bool  = false
var _ui_slide:          float = 0.0   # 0=hidden, 1=fully shown

# Altar world position (centre of room, slightly up)
const ALTAR_POS: Vector2 = Vector2(16 * 40 * 0.5, 12 * 40 * 0.4)


# ════════════════════════════════════════════════════════════
# _ready()
# ════════════════════════════════════════════════════════════
func _ready():
	add_to_group("curse_room")
	
	# Spawn altar detector
	var detector = Area2D.new()
	detector.name = "AltarDetector"
	var shape_node = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 55.0
	shape_node.shape = circle
	detector.position = ALTAR_POS
	detector.collision_mask = 1   # Player layer
	detector.add_child(shape_node)
	detector.body_entered.connect(_on_altar_range_entered)
	detector.body_exited.connect(_on_altar_range_exited)
	add_child(detector)
	
	# Altar starts dark — activates after room clear
	altar_active = false


# ════════════════════════════════════════════════════════════
# setup()  —  called by Room.gd
# ════════════════════════════════════════════════════════════
func setup(f_num: int, h_ids: Array):
	floor_num = f_num
	held_ids  = h_ids
	
	# Pick 3 random curses to offer (avoid repetition)
	# On floor 1: only severity 1–2. Floor 3+: can offer severity 3.
	var pool = CURSES.filter(func(c): return c["severity"] <= (1 + floor_num / 2))
	pool.shuffle()
	offered_curses = pool.slice(0, 3)
	
	print("[CurseRoom] Ready on floor ", floor_num,
		". Curses offered: ", offered_curses.map(func(c): return c["name"]))


# ════════════════════════════════════════════════════════════
# activate_altar()  —  called by Room.gd when room is cleared
# ════════════════════════════════════════════════════════════
func activate_altar():
	altar_active = true
	print("[CurseRoom] Altar activated — the Norns await.")


# ════════════════════════════════════════════════════════════
# _process()
# ════════════════════════════════════════════════════════════
func _process(delta: float):
	_altar_pulse += delta
	
	# Animate UI slide in/out
	if showing_ui:
		_ui_slide = move_toward(_ui_slide, 1.0, delta * 5.0)
	else:
		_ui_slide = move_toward(_ui_slide, 0.0, delta * 6.0)
	
	# Handle curse selection input
	if showing_ui:
		if Input.is_action_just_pressed("shoot_left"):
			curse_ui_index = max(0, curse_ui_index - 1)
		if Input.is_action_just_pressed("shoot_right"):
			curse_ui_index = min(offered_curses.size() - 1, curse_ui_index + 1)
		if Input.is_action_just_pressed("interact"):
			_accept_curse(offered_curses[curse_ui_index])
		if Input.is_action_just_pressed("pause"):
			_close_ui()   # Escape to close without choosing
	
	# Open UI when player approaches active altar
	if player_near_altar != null and altar_active and not showing_ui \
	and not curse_accepted_flag:
		if Input.is_action_just_pressed("interact"):
			_open_ui()
	
	queue_redraw()


# ════════════════════════════════════════════════════════════
# _draw()  —  altar + choice UI
# ════════════════════════════════════════════════════════════
func _draw():
	_draw_altar()
	if _ui_slide > 0.01:
		_draw_curse_ui()

func _draw_altar():
	var font  = ThemeDB.fallback_font
	var pulse = sin(_altar_pulse * 2.2)
	
	if _altar_shatter:
		# Draw broken altar pieces scattered
		for i in range(6):
			var angle  = (TAU / 6.0) * i + _altar_pulse * 0.5
			var dist   = 20.0 + _altar_pulse * 15.0
			var frag_x = ALTAR_POS.x + cos(angle) * dist
			var frag_y = ALTAR_POS.y + sin(angle) * dist
			draw_rect(Rect2(frag_x - 4, frag_y - 4, 8, 8),
				Color(0.35, 0.25, 0.4, max(0.0, 1.0 - _altar_pulse * 0.3)))
		return
	
	# Base stone plinth
	draw_rect(Rect2(ALTAR_POS.x - 22, ALTAR_POS.y + 10, 44, 18),
		Color(0.22, 0.18, 0.28))
	draw_rect(Rect2(ALTAR_POS.x - 22, ALTAR_POS.y + 10, 44, 18),
		Color(0.35, 0.28, 0.45), false, 1.0)
	
	# Altar stone top
	draw_rect(Rect2(ALTAR_POS.x - 18, ALTAR_POS.y - 4, 36, 16),
		Color(0.28, 0.22, 0.38))
	
	if not altar_active:
		# Dark — room not cleared yet
		draw_circle(ALTAR_POS + Vector2(0, 2), 8, Color(0.15, 0.1, 0.2))
		draw_string(font, ALTAR_POS + Vector2(-20, -14),
			"[Clear room first]", HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color(0.4, 0.35, 0.5))
		return
	
	# Active altar — glowing purple crystal on top
	var glow_alpha  = 0.55 + pulse * 0.3
	var glow_radius = 10.0 + pulse * 2.0
	
	# Outer glow
	draw_circle(ALTAR_POS + Vector2(0, -2), glow_radius + 4,
		Color(0.6, 0.2, 0.8, glow_alpha * 0.4))
	# Crystal core
	var crystal_pts = PackedVector2Array([
		ALTAR_POS + Vector2(0, -14),   # top point
		ALTAR_POS + Vector2(7, -4),    # right
		ALTAR_POS + Vector2(4, 4),     # lower-right
		ALTAR_POS + Vector2(-4, 4),    # lower-left
		ALTAR_POS + Vector2(-7, -4),   # left
	])
	draw_colored_polygon(crystal_pts, Color(0.65, 0.25, 0.85, 0.9))
	draw_polyline(PackedVector2Array([
		ALTAR_POS + Vector2(0, -14), ALTAR_POS + Vector2(7, -4),
		ALTAR_POS + Vector2(4, 4), ALTAR_POS + Vector2(-4, 4),
		ALTAR_POS + Vector2(-7, -4), ALTAR_POS + Vector2(0, -14),
	]), Color(0.85, 0.6, 1.0, 0.9), 1.2)
	
	# "Norn's Bargain" label + prompt
	draw_string(font, ALTAR_POS + Vector2(-38, -28),
		"Norn's Bargain", HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		Color(0.75, 0.5, 0.9, 0.9))
	
	if player_near_altar != null and not curse_accepted_flag:
		draw_string(font, ALTAR_POS + Vector2(-22, 28),
			"[E] Bargain", HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			Color(0.7, 0.7, 0.75, 0.85 + pulse * 0.1))
	elif curse_accepted_flag:
		draw_string(font, ALTAR_POS + Vector2(-22, 28),
			"Bargain struck.", HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			Color(0.5, 0.5, 0.55))


func _draw_curse_ui():
	var font       = ThemeDB.fallback_font
	var vp         = get_viewport_rect().size
	var ui_alpha   = _ui_slide
	var card_w     = 140.0
	var card_h     = 160.0
	var card_gap   = 14.0
	var total_w    = card_w * 3 + card_gap * 2
	var start_x    = (vp.x - total_w) / 2.0
	# Slide up from below
	var base_y     = vp.y * 0.25 + (1.0 - _ui_slide) * 80.0
	
	# ── Dark overlay ──────────────────────────────────────────
	draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0, 0, 0, 0.55 * ui_alpha))
	
	# ── Header ────────────────────────────────────────────────
	draw_string(font, Vector2(vp.x * 0.5 - 90, base_y - 28),
		"The Norns offer their price.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
		Color(0.75, 0.5, 0.9, ui_alpha))
	draw_string(font, Vector2(vp.x * 0.5 - 80, base_y - 12),
		"← → to choose · E to accept · ESC to refuse",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		Color(0.55, 0.55, 0.6, ui_alpha))
	
	# ── Curse cards ───────────────────────────────────────────
	for i in range(offered_curses.size()):
		var curse   = offered_curses[i]
		var cx      = start_x + i * (card_w + card_gap)
		var is_sel  = (i == curse_ui_index)
		var card_rect = Rect2(cx, base_y, card_w, card_h)
		
		# Card background
		var bg_color = Color(0.18, 0.12, 0.22, 0.95 * ui_alpha)
		if is_sel: bg_color = Color(0.28, 0.18, 0.38, 0.98 * ui_alpha)
		draw_rect(card_rect, bg_color)
		
		# Card border — thicker and brighter when selected
		var border_color = Color(0.65, 0.3, 0.85, ui_alpha)
		var border_w     = 2.0 if is_sel else 0.75
		draw_rect(card_rect, Color(border_color.r, border_color.g,
			border_color.b, border_color.a), false, border_w)
		
		# Severity dots (1–3 skulls)
		var sev = curse.get("severity", 1)
		for s in range(3):
			var dot_color = Color(0.7, 0.1, 0.1, ui_alpha) if s < sev \
				else Color(0.25, 0.2, 0.3, ui_alpha)
			draw_circle(Vector2(cx + 12 + s * 14, base_y + 12), 4.0, dot_color)
		
		# Icon (large centred)
		draw_string(font, Vector2(cx + card_w * 0.5 - 8, base_y + 42),
			curse.get("icon", "?"), HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
			Color(0.8, 0.55, 1.0, ui_alpha))
		
		# Curse name
		draw_string(font, Vector2(cx + 8, base_y + 66),
			curse.get("name", "?"), HORIZONTAL_ALIGNMENT_LEFT, card_w - 16, 12,
			Color(0.9, 0.8, 1.0, ui_alpha))
		
		# Description (word-wrapped manually at ~18 chars)
		var desc = curse.get("description", "")
		_draw_wrapped_text(font, desc, cx + 8, base_y + 82,
			card_w - 16, 9, Color(0.65, 0.6, 0.75, ui_alpha))
		
		# Flavour text (italic style via colour)
		draw_string(font, Vector2(cx + 8, base_y + card_h - 18),
			curse.get("flavour", ""), HORIZONTAL_ALIGNMENT_LEFT,
			card_w - 16, 8, Color(0.45, 0.4, 0.55, ui_alpha * 0.8))
		
		# "ACCEPT" button on selected card
		if is_sel:
			var btn_rect = Rect2(cx + 14, base_y + card_h + 8, card_w - 28, 20)
			draw_rect(btn_rect, Color(0.5, 0.2, 0.7, ui_alpha))
			draw_string(font, Vector2(cx + 30, base_y + card_h + 21),
				"ACCEPT CURSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
				Color(1.0, 1.0, 1.0, ui_alpha))


func _draw_wrapped_text(font: Font, text: String, x: float, y: float,
						max_w: float, size: int, color: Color):
	# Split text into lines that fit within max_w (approximation)
	var words       = text.split(" ")
	var line        = ""
	var line_y      = y
	var approx_char_w = size * 0.6   # Rough character width
	
	for word in words:
		var test = line + (" " if line != "" else "") + word
		if test.length() * approx_char_w > max_w and line != "":
			draw_string(font, Vector2(x, line_y), line,
				HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
			line   = word
			line_y += size + 3
		else:
			line = test
	
	if line != "":
		draw_string(font, Vector2(x, line_y), line,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


# ════════════════════════════════════════════════════════════
# UI OPEN / CLOSE
# ════════════════════════════════════════════════════════════
func _open_ui():
	showing_ui     = true
	curse_ui_index = 0
	get_tree().paused = false   # Ensure not paused
	print("[CurseRoom] Bargain UI opened.")

func _close_ui():
	showing_ui = false
	emit_signal("curse_skipped")
	print("[CurseRoom] Bargain refused.")


# ════════════════════════════════════════════════════════════
# ACCEPT CURSE
# ════════════════════════════════════════════════════════════
func _accept_curse(curse: Dictionary):
	showing_ui          = false
	curse_accepted_flag = true
	
	print("[CurseRoom] Accepted: ", curse["name"])
	
	# Apply the curse to the player
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_apply_curse_to_player(curse, players[0])
	
	# Record in GameData
	if has_node("/root/GameData"):
		var curses_taken = GameData.current_run.get("curses", [])
		curses_taken.append(curse["id"])
		GameData.current_run["curses"] = curses_taken
	
	# Spawn the reward item
	await get_tree().create_timer(0.5).timeout
	_spawn_curse_reward()
	
	# Shatter the altar visually
	_shatter_altar()
	
	emit_signal("curse_accepted", curse)


func _apply_curse_to_player(curse: Dictionary, player: Node):
	match curse["id"]:
		"bleeding_wound":
			player.max_health    = max(1, player.max_health - 15)
			player.current_health = min(player.current_health, player.max_health)
			player.emit_signal("health_changed", player.current_health, player.max_health)
		"slow_step":
			player.move_speed    = max(40.0, player.move_speed - 20.0)
		"shaky_hands":
			player.fire_rate    += 0.15
		"heavy_burden":
			var mgr = player.get_node_or_null("ItemManager")
			if mgr:
				# Seal one slot — drop the last item if over limit
				mgr.set_meta("max_slots_override", 3)
				while mgr.get_inventory_size() > 3:
					mgr.drop_item(mgr.get_inventory_size() - 1)
		"marked_for_death":
			player.set_meta("curse_extra_damage", 1)
		"cracked_defence":
			var bonus = player.get_meta("iframe_bonus", 0.0)
			player.set_meta("iframe_bonus", bonus - 0.4)
		"cursed_gold":
			if has_node("/root/GameData"):
				GameData.current_run["gold_curse"] = true
		"weakened_flesh":
			player.base_damage = max(1, player.base_damage - 8)
		"forsaken":
			player.special_cooldown_max += 4.0
		"hungry_runes":
			player.set_meta("rune_proc_chance", 0.75)
	
	print("[CurseRoom] Curse '", curse["name"], "' applied to player.")


func _spawn_curse_reward():
	# Roll a guaranteed uncommon+ item (rare+ on floors 3+, legendary on floor 5)
	var min_rarity = "uncommon"
	if floor_num >= 5: min_rarity = "legendary"
	elif floor_num >= 3: min_rarity = "rare"
	
	var rune = {}
	var attempts = 0
	while attempts < 6:
		rune = RuneDatabase.roll_random_rune(floor_num, held_ids)
		var rarity = rune.get("rarity", "common")
		if min_rarity == "legendary" and rarity == "legendary": break
		if min_rarity == "rare" and rarity in ["rare","legendary"]: break
		if min_rarity == "uncommon" and rarity in ["uncommon","rare","legendary"]: break
		attempts += 1
	
	if rune.is_empty():
		rune = RuneDatabase.get_rune("yggdrasil_root")   # Fallback
	
	var reward_pos = ALTAR_POS + Vector2(0, 60)
	if has_node("/root/ItemDropper"):
		ItemDropper._spawn_pedestal(get_parent(), reward_pos, rune)
	print("[CurseRoom] Reward spawned: ", rune.get("name","?"), " (", rune.get("rarity","?"), ")")


func _shatter_altar():
	_altar_shatter = true
	_altar_pulse   = 0.0   # Reset so we track shatter time from here
	print("[CurseRoom] Altar shatters!")


# ════════════════════════════════════════════════════════════
# DETECTION
# ════════════════════════════════════════════════════════════
func _on_altar_range_entered(body: Node2D):
	if body.is_in_group("player"):
		player_near_altar = body

func _on_altar_range_exited(body: Node2D):
	if body.is_in_group("player"):
		player_near_altar = null
		if showing_ui:
			_close_ui()
