extends CanvasLayer

# ============================================================
# BossHPBar.gd
# ============================================================
# The boss health bar shown at the bottom of the screen.
# Isaac-style: a long red bar with the boss name above it,
# split into segments per phase, with phase markers.
#
# SCENE TREE for BossHPBar.tscn:
#   BossHPBar  [CanvasLayer]     ← this script
#   (Everything drawn in _draw() — no child nodes needed)
#
# USAGE in BossRoom.gd / RoomManager:
#   var hpbar = load("res://scenes/BossHPBar.tscn").instantiate()
#   add_child(hpbar)
#   hpbar.connect_to_boss($Jormungandr)
# ============================================================

var boss_node:     Node   = null
var boss_name:     String = ""
var current_hp:    int    = 0
var max_hp:        int    = 1
var current_phase: int    = 1

# Animation state
var _visible_alpha: float = 0.0     # Fades in at start, out at death
var _shake_timer:   float = 0.0     # Shakes bar on damage
var _shake_offset:  float = 0.0
var _phase_flash:   float = 0.0     # Flashes white on phase change
var _last_hp:       int   = 0       # Detect HP changes for animations

# Layout constants
const BAR_WIDTH:   float = 360.0
const BAR_HEIGHT:  float = 14.0
const BAR_ORIGIN_Y: float = 0.0     # Set relative to screen bottom in _draw
const BAR_MARGIN:  float = 18.0     # From screen bottom

# Phase threshold positions on the bar (fractions of full width)
const PHASE_2_X: float = 0.66   # Phase 2 starts when HP drops below 66%
const PHASE_3_X: float = 0.33   # Phase 3 starts below 33%

# Colours
const COLOR_BAR_FULL   = Color(0.75, 0.1,  0.1)
const COLOR_BAR_EMPTY  = Color(0.18, 0.08, 0.08)
const COLOR_PHASE_MARK = Color(0.9,  0.75, 0.2)
const COLOR_BOSS_NAME  = Color(0.9,  0.85, 0.8)
const COLOR_BG_PANEL   = Color(0.06, 0.04, 0.04, 0.92)


# ════════════════════════════════════════════════════════════
# connect_to_boss()
# ════════════════════════════════════════════════════════════
func connect_to_boss(boss: Node):
	boss_node    = boss
	boss_name    = boss.enemy_name if "enemy_name" in boss else "???"
	max_hp       = boss.max_health if "max_health" in boss else 100
	current_hp   = max_hp
	_last_hp     = current_hp
	
	# Listen for phase changes
	if boss.has_signal("phase_changed"):
		boss.phase_changed.connect(_on_phase_changed)
	if boss.has_signal("boss_died"):
		boss.boss_died.connect(_on_boss_died)
	
	# Fade in
	_visible_alpha = 0.0
	var tween = create_tween()
	tween.tween_property(self, "_visible_alpha", 1.0, 0.8)
	
	print("[BossHPBar] Connected to: ", boss_name)


# ════════════════════════════════════════════════════════════
# _process()  —  poll HP and update animations
# ════════════════════════════════════════════════════════════
func _process(delta: float):
	if boss_node == null or not is_instance_valid(boss_node):
		return
	
	# Poll current HP from boss
	var new_hp = boss_node.current_health if "current_health" in boss_node else 0
	
	if new_hp != _last_hp:
		# HP changed — trigger damage shake
		if new_hp < _last_hp:
			_shake_timer = 0.25
		_last_hp = new_hp
	
	current_hp = new_hp
	
	# Tick shake animation
	if _shake_timer > 0:
		_shake_timer -= delta
		_shake_offset = sin(_shake_timer * 80.0) * 3.0
	else:
		_shake_offset = 0.0
	
	# Tick phase flash
	if _phase_flash > 0:
		_phase_flash -= delta
	
	queue_redraw()


# ════════════════════════════════════════════════════════════
# _draw()
# ════════════════════════════════════════════════════════════
func _draw():
	if _visible_alpha <= 0.01: return
	
	var font       = ThemeDB.fallback_font
	var vp_size    = get_viewport().get_visible_rect().size
	var bar_x      = (vp_size.x - BAR_WIDTH) / 2 + _shake_offset
	var bar_y      = vp_size.y - BAR_MARGIN - BAR_HEIGHT
	
	var alpha      = _visible_alpha
	
	# ── Background panel ────────────────────────────────────
	var panel = Rect2(bar_x - 8, bar_y - 22, BAR_WIDTH + 16, BAR_HEIGHT + 30)
	draw_rect(panel, Color(COLOR_BG_PANEL.r, COLOR_BG_PANEL.g,
		COLOR_BG_PANEL.b, COLOR_BG_PANEL.a * alpha))
	
	# ── Boss name ───────────────────────────────────────────
	var name_color = COLOR_BOSS_NAME
	# Phase flash: name turns bright white briefly
	if _phase_flash > 0:
		name_color = name_color.lerp(Color.WHITE, _phase_flash)
	draw_string(font, Vector2(bar_x, bar_y - 6),
		boss_name.to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		Color(name_color.r, name_color.g, name_color.b, alpha))
	
	# Phase indicator: "PHASE 1" / "PHASE 2" / "PHASE 3"
	var phase_text  = "· PHASE " + str(current_phase) + " ·"
	var phase_color = Color(0.7, 0.7, 0.7, alpha * 0.7)
	draw_string(font, Vector2(bar_x + BAR_WIDTH - 60, bar_y - 6),
		phase_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, phase_color)
	
	# ── Empty bar background ────────────────────────────────
	var empty_rect = Rect2(bar_x, bar_y, BAR_WIDTH, BAR_HEIGHT)
	draw_rect(empty_rect,
		Color(COLOR_BAR_EMPTY.r, COLOR_BAR_EMPTY.g, COLOR_BAR_EMPTY.b, alpha))
	
	# ── Filled HP bar ───────────────────────────────────────
	var hp_fraction = clampf(float(current_hp) / float(max_hp), 0.0, 1.0)
	var fill_width  = BAR_WIDTH * hp_fraction
	
	# Colour shifts from red → dark red as HP drops
	var bar_color = COLOR_BAR_FULL.lerp(Color(0.4, 0.05, 0.05), 1.0 - hp_fraction)
	if _phase_flash > 0:
		bar_color = bar_color.lerp(Color.WHITE, _phase_flash * 0.6)
	
	if fill_width > 0:
		draw_rect(Rect2(bar_x, bar_y, fill_width, BAR_HEIGHT),
			Color(bar_color.r, bar_color.g, bar_color.b, alpha))
	
	# ── Phase marker lines ──────────────────────────────────
	# Vertical gold lines showing where phase transitions happen
	_draw_phase_marker(bar_x + BAR_WIDTH * PHASE_2_X, bar_y, alpha, current_hp > max_hp * PHASE_2_X)
	_draw_phase_marker(bar_x + BAR_WIDTH * PHASE_3_X, bar_y, alpha, current_hp > max_hp * PHASE_3_X)
	
	# ── Bar border ──────────────────────────────────────────
	draw_rect(empty_rect, Color(0.4, 0.3, 0.3, alpha), false, 1.0)
	
	# ── Skull icons for each phase (like Isaac's boss HP) ───
	for i in range(3):
		var skull_x = bar_x - 14 + i * -1   # Stack 3 skulls left of bar
		var skull_y = bar_y + BAR_HEIGHT / 2
		var skull_alpha = alpha if i < current_phase else alpha * 0.3
		draw_string(font, Vector2(bar_x - 22, bar_y + BAR_HEIGHT - 1),
			"☠" if current_phase >= i + 1 else "○",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(0.7, 0.1, 0.1, skull_alpha))
		break   # Just one skull indicator for now


func _draw_phase_marker(x: float, bar_y: float, alpha: float, is_active: bool):
	var color = Color(COLOR_PHASE_MARK.r, COLOR_PHASE_MARK.g,
		COLOR_PHASE_MARK.b, alpha * (0.9 if is_active else 0.4))
	draw_line(Vector2(x, bar_y - 2), Vector2(x, bar_y + BAR_HEIGHT + 2), color, 1.5)


# ════════════════════════════════════════════════════════════
# Signal handlers
# ════════════════════════════════════════════════════════════
func _on_phase_changed(new_phase: int):
	current_phase = new_phase
	_phase_flash  = 0.8   # 0.8 seconds of flash
	print("[BossHPBar] Phase ", new_phase, " — bar updated")

func _on_boss_died():
	# Fade out bar after boss dies
	var tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(self, "_visible_alpha", 0.0, 1.0)
	await tween.finished
	queue_free()
