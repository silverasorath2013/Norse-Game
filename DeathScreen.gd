extends Node2D

# ============================================================
# DeathScreen.gd
# ============================================================
# Shown when the hero's HP reaches 0.
# Hero.gd calls: get_tree().change_scene_to_file("res://scenes/DeathScreen.tscn")
#
# ── WHAT IT SHOWS ───────────────────────────────────────────
#   PHASE 1 (0–1.5s): Fade in from black. Silence.
#   PHASE 2 (1.5–3s): Tombstone rises from bottom with the
#     hero's name carved on it. Runes glow briefly.
#   PHASE 3 (3–5s): Run stats scroll up one by one with a
#     brief stagger between each line.
#   PHASE 4 (5s+): "Cause of death" line appears in red.
#     Grade badge slides in from the right.
#     Menu options fade in at the bottom.
#
# ── CONTROLS ────────────────────────────────────────────────
#   R / Enter     → Try Again (new run, same hero)
#   H             → Hero Select (back to character screen)
#   ESC           → Main Menu
#
# ── LAYOUT ──────────────────────────────────────────────────
#   All drawn in _draw() — no child nodes needed beyond
#   optional background music player.
# ============================================================

# ── ANIMATION PHASES ────────────────────────────────────────
enum Phase { FADE_IN, TOMBSTONE_RISE, STATS_REVEAL, FULL_DISPLAY }
var phase:          Phase = Phase.FADE_IN
var phase_timer:    float = 0.0
var bg_alpha:       float = 0.0   # Starts transparent, fades to 1

# Stats reveal — revealed one at a time
var stats_revealed: int   = 0
var stat_timer:     float = 0.0
const STAT_STAGGER: float = 0.22  # Seconds between each stat appearing

# Tombstone animation
var tombstone_y_offset: float = 120.0  # Starts below screen, rises to 0
const TOMBSTONE_RISE_SPEED: float = 90.0  # px/sec

# Grade badge
var grade_x_offset: float = 200.0  # Starts off right, slides to 0
const GRADE_SLIDE_SPEED: float = 350.0

# Menu fade
var menu_alpha: float = 0.0

# Cached run data (read once on _ready so it can't change mid-display)
var hero_name:      String = "Unknown Warrior"
var cause_of_death: String = "Unknown"
var floor_reached:  int    = 1
var run_grade:      String = "F"
var run_score:      int    = 0
var stat_lines:     Array  = []   # Array of {label, value, color} Dicts

# Best run highlight
var is_new_best:    bool   = false

# Colour palette
const C_BG         = Color(0.04, 0.03, 0.06)
const C_STONE      = Color(0.32, 0.28, 0.35)
const C_STONE_DARK = Color(0.18, 0.15, 0.22)
const C_TEXT       = Color(0.82, 0.80, 0.85)
const C_DIM        = Color(0.45, 0.43, 0.50)
const C_GOLD       = Color(0.88, 0.72, 0.18)
const C_RED        = Color(0.85, 0.18, 0.18)
const C_RUNE_GLOW  = Color(0.55, 0.30, 0.80)

# Grade colours
const GRADE_COLORS = {
	"S": Color(1.0,  0.85, 0.1),
	"A": Color(0.2,  0.85, 0.4),
	"B": Color(0.25, 0.55, 1.0),
	"C": Color(0.75, 0.75, 0.75),
	"D": Color(0.8,  0.5,  0.15),
	"F": Color(0.7,  0.18, 0.18),
}


# ════════════════════════════════════════════════════════════
# _ready()
# ════════════════════════════════════════════════════════════
func _ready():
	# Tell Godot the game is unpaused (it may have been paused on death)
	get_tree().paused = false
	
	# Read all run data immediately — GameData.end_run() was called by Hero._die()
	_cache_run_data()
	
	# Start fade-in
	phase       = Phase.FADE_IN
	phase_timer = 0.0
	bg_alpha    = 0.0
	
	print("[DeathScreen] Showing death for: ", hero_name,
		"  Floor: ", floor_reached, "  Grade: ", run_grade)


# ════════════════════════════════════════════════════════════
# _cache_run_data()
# Reads GameData once and builds the display arrays
# ════════════════════════════════════════════════════════════
func _cache_run_data():
	if not has_node("/root/GameData"):
		return
	
	var summary    = GameData.last_run_summary
	hero_name      = summary.get("hero_name",      "Unknown Warrior")
	cause_of_death = summary.get("cause_of_death", "the darkness")
	floor_reached  = summary.get("floor",          1)
	run_grade      = summary.get("grade",          "F")
	run_score      = summary.get("score",          0)
	
	# Check if this is a new best score
	if GameData.best_runs.size() > 0:
		is_new_best = (GameData.best_runs[0]["score"] == run_score)
	
	# Build the stat lines shown in the middle of the screen
	stat_lines = [
		{"label": "Floor Reached",   "value": str(floor_reached),
			"color": C_TEXT},
		{"label": "Enemies Slain",   "value": str(summary.get("enemies_killed", 0)),
			"color": C_TEXT},
		{"label": "Rooms Cleared",   "value": str(summary.get("rooms_cleared",  0)),
			"color": C_TEXT},
		{"label": "Bosses Felled",   "value": str(summary.get("bosses_killed",  0)),
			"color": C_GOLD if summary.get("bosses_killed", 0) > 0 else C_DIM},
		{"label": "Runes Held",      "value": str(summary.get("items",          0)),
			"color": C_RUNE_GLOW},
		{"label": "Curses Taken",    "value": str(summary.get("curses",         0)),
			"color": C_RED if summary.get("curses", 0) > 0 else C_DIM},
		{"label": "Damage Taken",    "value": str(summary.get("damage_taken",   0)),
			"color": C_TEXT},
		{"label": "Gold Spent",      "value": str(summary.get("gold_spent",     0)) + "g",
			"color": C_GOLD},
		{"label": "Run Time",        "value": summary.get("duration",           "0:00"),
			"color": C_DIM},
		{"label": "Total Deaths",    "value": str(GameData.current_run.get("deaths", 1)),
			"color": C_DIM},
	]


# ════════════════════════════════════════════════════════════
# _process()
# ════════════════════════════════════════════════════════════
func _process(delta: float):
	phase_timer += delta
	
	match phase:
		Phase.FADE_IN:
			bg_alpha = move_toward(bg_alpha, 1.0, delta * 0.8)
			if phase_timer >= 1.8:
				phase       = Phase.TOMBSTONE_RISE
				phase_timer = 0.0
		
		Phase.TOMBSTONE_RISE:
			tombstone_y_offset = move_toward(tombstone_y_offset, 0.0,
				TOMBSTONE_RISE_SPEED * delta)
			if phase_timer >= 1.6:
				phase       = Phase.STATS_REVEAL
				phase_timer = 0.0
				stats_revealed = 0
				stat_timer = STAT_STAGGER
		
		Phase.STATS_REVEAL:
			stat_timer -= delta
			if stat_timer <= 0 and stats_revealed < stat_lines.size():
				stats_revealed += 1
				stat_timer = STAT_STAGGER
			if stats_revealed >= stat_lines.size() and phase_timer >= 1.0:
				phase       = Phase.FULL_DISPLAY
				phase_timer = 0.0
		
		Phase.FULL_DISPLAY:
			grade_x_offset = move_toward(grade_x_offset, 0.0, GRADE_SLIDE_SPEED * delta)
			menu_alpha     = move_toward(menu_alpha, 1.0, delta * 1.5)
	
	# Handle menu input once fully displayed
	if phase == Phase.FULL_DISPLAY and menu_alpha > 0.5:
		_handle_input()
	
	queue_redraw()


# ════════════════════════════════════════════════════════════
# _input()  —  skip animation by pressing any key
# ════════════════════════════════════════════════════════════
func _input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		# Skip to full display on any key press before fully revealed
		if phase != Phase.FULL_DISPLAY:
			phase              = Phase.FULL_DISPLAY
			phase_timer        = 0.0
			stats_revealed     = stat_lines.size()
			tombstone_y_offset = 0.0
			bg_alpha           = 1.0


func _handle_input():
	if Input.is_action_just_pressed("ui_accept") or \
	Input.is_key_pressed(KEY_R):
		_try_again()
	elif Input.is_key_pressed(KEY_H):
		_hero_select()
	elif Input.is_action_just_pressed("pause"):
		_main_menu()


# ════════════════════════════════════════════════════════════
# _draw()  —  all rendering
# ════════════════════════════════════════════════════════════
func _draw():
	var vp   = get_viewport_rect().size
	var font = ThemeDB.fallback_font
	var cx   = vp.x / 2
	
	# ── BACKGROUND ──────────────────────────────────────────
	draw_rect(Rect2(0, 0, vp.x, vp.y),
		Color(C_BG.r, C_BG.g, C_BG.b, bg_alpha))
	
	if bg_alpha < 0.1: return
	
	# ── BACKGROUND RUNE PATTERN (subtle) ────────────────────
	_draw_bg_runes(vp, font)
	
	# ── TOMBSTONE ───────────────────────────────────────────
	_draw_tombstone(cx, vp.y * 0.38 + tombstone_y_offset, font)
	
	if phase == Phase.FADE_IN: return
	
	# ── "YOU HAVE FALLEN" HEADER ────────────────────────────
	var header_alpha = clampf((phase_timer if phase == Phase.TOMBSTONE_RISE
		else 1.0), 0.0, 1.0)
	draw_string(font, Vector2(cx - 110, vp.y * 0.12),
		"— YOU HAVE FALLEN —",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
		Color(C_RED.r, C_RED.g, C_RED.b, header_alpha * bg_alpha))
	
	# Sub-header: cause of death
	draw_string(font, Vector2(cx - 90, vp.y * 0.12 + 22),
		"Slain by " + cause_of_death,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		Color(C_DIM.r, C_DIM.g, C_DIM.b, header_alpha * bg_alpha))
	
	if phase == Phase.TOMBSTONE_RISE: return
	
	# ── STAT LINES ──────────────────────────────────────────
	_draw_stats(cx, vp.y, font)
	
	# ── GRADE BADGE ─────────────────────────────────────────
	if phase == Phase.FULL_DISPLAY:
		_draw_grade_badge(vp, font)
	
	# ── SCORE ───────────────────────────────────────────────
	if stats_revealed >= stat_lines.size():
		var score_alpha = clampf(phase_timer * 2.0, 0.0, 1.0) \
			if phase == Phase.FULL_DISPLAY else 1.0
		draw_string(font, Vector2(cx - 60, vp.y * 0.62),
			"SCORE  " + str(run_score),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
			Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, score_alpha))
		
		if is_new_best:
			draw_string(font, Vector2(cx + 40, vp.y * 0.62),
				"★ NEW BEST",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
				Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, score_alpha * 0.9))
	
	# ── MENU OPTIONS ────────────────────────────────────────
	if phase == Phase.FULL_DISPLAY:
		_draw_menu(cx, vp.y, font)


func _draw_bg_runes(vp: Rect2, font: Font):
	# Scattered rune symbols — very faint
	var runes = ["ᚠ","ᚢ","ᚦ","ᚨ","ᚱ","ᚲ","ᚷ","ᚹ","ᚺ","ᚾ","ᛁ","ᛃ","ᛇ","ᛈ","ᛉ","ᛊ"]
	var alpha  = bg_alpha * 0.06
	for i in range(20):
		var rx = (i * 137) % int(vp.x)  # Pseudo-random scatter
		var ry = (i * 97 + 50) % int(vp.y)
		draw_string(font, Vector2(rx, ry),
			runes[i % runes.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
			Color(C_RUNE_GLOW.r, C_RUNE_GLOW.g, C_RUNE_GLOW.b, alpha))


func _draw_tombstone(cx: float, ty: float, font: Font):
	# Stone base
	var base_w = 90.0
	var base_h = 110.0
	draw_rect(Rect2(cx - base_w / 2, ty - base_h * 0.6, base_w, base_h),
		C_STONE_DARK)
	draw_rect(Rect2(cx - base_w / 2, ty - base_h * 0.6, base_w, base_h),
		C_STONE, false, 1.5)
	
	# Arch top
	draw_arc(Vector2(cx, ty - base_h * 0.6), base_w / 2,
		PI, TAU, 16, C_STONE_DARK, base_w / 2)
	draw_arc(Vector2(cx, ty - base_h * 0.6), base_w / 2,
		PI, TAU, 16, C_STONE, 1.5)
	
	# Hero name carved into stone
	draw_string(font, Vector2(cx - 36, ty - base_h * 0.15),
		hero_name.to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		Color(C_DIM.r, C_DIM.g, C_DIM.b, 0.9))
	
	# Cross / rune symbol etched on stone
	var cross_cx = cx
	var cross_cy = ty - base_h * 0.45
	draw_line(Vector2(cross_cx, cross_cy - 14),
		Vector2(cross_cx, cross_cy + 14), C_DIM, 2.0)
	draw_line(Vector2(cross_cx - 10, cross_cy - 4),
		Vector2(cross_cx + 10, cross_cy - 4), C_DIM, 2.0)
	
	# "R.I.P." text
	draw_string(font, Vector2(cx - 14, ty - base_h * 0.72),
		"R.I.P.", HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		Color(C_STONE.r, C_STONE.g, C_STONE.b, 0.7))
	
	# Ground line
	draw_line(Vector2(cx - base_w * 0.8, ty + base_h * 0.42),
		Vector2(cx + base_w * 0.8, ty + base_h * 0.42),
		C_STONE_DARK, 3.0)


func _draw_stats(cx: float, vp_h: float, font: Font):
	var stat_start_y = vp_h * 0.50
	var col_spacing  = 210.0
	var row_h        = 17.0
	var items_per_col = 5
	
	for i in range(stats_revealed):
		var s    = stat_lines[i]
		var col  = i / items_per_col
		var row  = i % items_per_col
		var sx   = cx - col_spacing * 0.5 + col * col_spacing
		var sy   = stat_start_y + row * row_h
		
		# Animated: new lines slide in from slightly below
		var freshness = clampf((stats_revealed - i) / 3.0, 0.0, 1.0)
		var slide_y   = sy + (1.0 - freshness) * 8.0
		
		# Label (dim)
		draw_string(font, Vector2(sx - 90, slide_y),
			s["label"] + ":",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(C_DIM.r, C_DIM.g, C_DIM.b, freshness))
		
		# Value (bright)
		draw_string(font, Vector2(sx + 20, slide_y),
			str(s["value"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(s["color"].r, s["color"].g, s["color"].b, freshness))


func _draw_grade_badge(vp: Rect2, font: Font):
	var gx     = vp.x * 0.78 + grade_x_offset
	var gy     = vp.y * 0.28
	var color  = GRADE_COLORS.get(run_grade, C_DIM)
	var size   = 52.0
	
	# Outer hexagon badge shape (approximate with rect + corners)
	draw_rect(Rect2(gx - size * 0.5, gy - size * 0.5, size, size),
		Color(color.r * 0.15, color.g * 0.15, color.b * 0.15, 0.9))
	draw_rect(Rect2(gx - size * 0.5, gy - size * 0.5, size, size),
		Color(color.r, color.g, color.b, 0.9), false, 2.0)
	
	# Grade letter
	draw_string(font, Vector2(gx - 14, gy + 18),
		run_grade, HORIZONTAL_ALIGNMENT_LEFT, -1, 42,
		Color(color.r, color.g, color.b, 1.0))
	
	# "GRADE" label below
	draw_string(font, Vector2(gx - 18, gy + size * 0.5 + 14),
		"— GRADE —",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		Color(C_DIM.r, C_DIM.g, C_DIM.b, 0.8))


func _draw_menu(cx: float, vp_h: float, font: Font):
	var my = vp_h * 0.88
	var a  = menu_alpha
	
	# Separator line
	draw_line(Vector2(cx - 160, my - 12), Vector2(cx + 160, my - 12),
		Color(C_DIM.r, C_DIM.g, C_DIM.b, a * 0.4), 0.5)
	
	var options = [
		{"key": "[R]",   "label": "Try Again",   "col": -150.0},
		{"key": "[H]",   "label": "Hero Select", "col": -20.0},
		{"key": "[ESC]", "label": "Main Menu",   "col": 100.0},
	]
	
	for opt in options:
		var ox = cx + opt["col"]
		draw_string(font, Vector2(ox, my),
			opt["key"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, a))
		draw_string(font, Vector2(ox + 36, my),
			opt["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(C_TEXT.r, C_TEXT.g, C_TEXT.b, a))


# ════════════════════════════════════════════════════════════
# NAVIGATION
# ════════════════════════════════════════════════════════════

func _try_again():
	if has_node("/root/GameData"):
		GameData.start_run()   # Reset run stats for next attempt
	get_tree().change_scene_to_file("res://scenes/CharacterSelect.tscn")

func _hero_select():
	if has_node("/root/GameData"):
		GameData.start_run()
	get_tree().change_scene_to_file("res://scenes/CharacterSelect.tscn")

func _main_menu():
	if has_node("/root/GameData"):
		GameData.start_run()
	get_tree().change_scene_to_file("res://scenes/HomeScreen.tscn")
