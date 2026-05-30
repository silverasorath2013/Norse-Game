extends Node2D

# ============================================================
# VictoryScreen.gd
# ============================================================
# Shown when the player defeats the final boss and exits.
# Tonally different from the death screen — triumphant but
# still Norse-restrained. Gold and silver. No fireworks.
#
# ── WHAT IT SHOWS ───────────────────────────────────────────
#   PHASE 1: Fade in from white (not black — victory is bright)
#   PHASE 2: Title "SAGA COMPLETE" reveals letter by letter
#   PHASE 3: Hero portrait area + "The saga of [Name]" text
#   PHASE 4: Full stat table with per-stat Norse commentary
#   PHASE 5: Grade badge + score + "New Best?" indicator
#   PHASE 6: If a new hero was unlocked: unlock banner slides in
#   PHASE 7: Menu options
#
# ── UNIQUE FEATURE: UNLOCK BANNER ───────────────────────────
#   If the player unlocked a hero this run (first Jormungandr kill),
#   a gold banner slides in from the top showing:
#   "✦ ODIN UNLOCKED — Return to the hall to play as the Allfather"
# ============================================================

enum Phase { FADE_IN, TITLE, HERO_REVEAL, STATS_REVEAL, GRADE, UNLOCK_BANNER, MENU }
var phase:           Phase = Phase.FADE_IN
var phase_timer:     float = 0.0

# Animation vars
var bg_alpha:          float = 0.0
var title_chars:       int   = 0
var title_timer:       float = 0.0
var stats_revealed:    int   = 0
var stat_timer:        float = 0.0
var grade_scale:       float = 0.0
var banner_y_offset:   float = -80.0
var menu_alpha:        float = 0.0
var hero_reveal_alpha: float = 0.0

const TITLE_TEXT = "SAGA COMPLETE"
const CHAR_DELAY:   float = 0.08
const STAT_STAGGER: float = 0.18

# Run data cache
var hero_name:      String = "Unknown"
var run_grade:      String = "B"
var run_score:      int    = 0
var stat_lines:     Array  = []
var newly_unlocked: Array  = []   # Heroes unlocked this run
var is_new_best:    bool   = false
var floor_reached:  int    = 1

# Colours
const C_BG_TOP     = Color(0.06, 0.05, 0.10)
const C_BG_BOT     = Color(0.10, 0.08, 0.04)
const C_GOLD       = Color(0.90, 0.75, 0.20)
const C_GOLD_DIM   = Color(0.65, 0.52, 0.14)
const C_SILVER     = Color(0.78, 0.80, 0.84)
const C_TEXT       = Color(0.88, 0.86, 0.90)
const C_DIM        = Color(0.50, 0.48, 0.54)
const C_RUNE       = Color(0.60, 0.45, 0.85)

const GRADE_COLORS = {
	"S": Color(1.0,  0.88, 0.12),
	"A": Color(0.2,  0.85, 0.4),
	"B": Color(0.25, 0.55, 1.0),
	"C": Color(0.75, 0.75, 0.75),
	"D": Color(0.8,  0.5,  0.15),
}

# Norse commentary per stat range (flavour text shown next to stats)
const KILL_COMMENTS = [
	[0,  10,  "Timid"],
	[11, 30,  "Warrior"],
	[31, 60,  "Berserker"],
	[61, 999, "Slaughterer"],
]
const DAMAGE_COMMENTS = [
	[0,   50,  "Untouched"],
	[51,  150, "Scarred"],
	[151, 300, "Bloodied"],
	[301, 999, "Near Death"],
]


# ════════════════════════════════════════════════════════════
# _ready()
# ════════════════════════════════════════════════════════════
func _ready():
	get_tree().paused = false
	_cache_run_data()
	
	# Check which heroes were newly unlocked this run
	if has_node("/root/GameData"):
		var bosses = GameData.current_run.get("bosses_killed", [])
		if "Jormungandr_Floor1" in bosses:
			newly_unlocked.append("Odin")
		if "Fenrir_Floor2" in bosses:
			newly_unlocked.append("Loki")
	
	print("[VictoryScreen] Victory! Hero: ", hero_name,
		"  Grade: ", run_grade, "  Score: ", run_score)


# ════════════════════════════════════════════════════════════
# _cache_run_data()
# ════════════════════════════════════════════════════════════
func _cache_run_data():
	if not has_node("/root/GameData"): return
	
	var summary    = GameData.last_run_summary
	hero_name      = summary.get("hero_name", "Unknown")
	run_grade      = summary.get("grade",     "B")
	run_score      = summary.get("score",     0)
	floor_reached  = summary.get("floor",     1)
	
	if GameData.best_runs.size() > 0:
		is_new_best = (GameData.best_runs[0]["score"] == run_score)
	
	# Build stat lines with Norse commentary
	var kills  = summary.get("enemies_killed", 0)
	var damage = summary.get("damage_taken",   0)
	
	stat_lines = [
		{"label": "Floors Conquered",  "value": str(floor_reached),
		 "comment": "All realms traversed" if floor_reached >= 5 else str(floor_reached) + " of 5",
		 "color": C_GOLD},
		{"label": "Enemies Slain",     "value": str(kills),
		 "comment": _range_comment(kills, KILL_COMMENTS),
		 "color": C_TEXT},
		{"label": "Bosses Defeated",   "value": str(summary.get("bosses_killed", 0)),
		 "comment": "The mighty fall",
		 "color": C_GOLD},
		{"label": "Runes Mastered",    "value": str(summary.get("items",         0)),
		 "comment": "Power runs deep",
		 "color": C_RUNE},
		{"label": "Curses Borne",      "value": str(summary.get("curses",        0)),
		 "comment": "The price of power" if summary.get("curses", 0) > 0 else "Unblemished",
		 "color": C_DIM},
		{"label": "Damage Endured",    "value": str(damage),
		 "comment": _range_comment(damage, DAMAGE_COMMENTS),
		 "color": C_TEXT},
		{"label": "Gold Spent",        "value": str(summary.get("gold_spent", 0)) + "g",
		 "comment": "The merchant prospers",
		 "color": C_GOLD_DIM},
		{"label": "Time of Saga",      "value": summary.get("duration", "0:00"),
		 "comment": "Swift" if _is_fast_run(summary) else "Steadfast",
		 "color": C_DIM},
	]


func _range_comment(value: int, table: Array) -> String:
	for row in table:
		if value >= row[0] and value <= row[1]:
			return row[2]
	return ""

func _is_fast_run(summary: Dictionary) -> bool:
	# Under 20 minutes is considered fast
	var dur = summary.get("duration", "99:99")
	var parts = dur.split(":")
	if parts.size() >= 2:
		return int(parts[0]) < 20
	return false


# ════════════════════════════════════════════════════════════
# _process()
# ════════════════════════════════════════════════════════════
func _process(delta: float):
	phase_timer += delta
	
	match phase:
		Phase.FADE_IN:
			bg_alpha = move_toward(bg_alpha, 1.0, delta * 0.6)
			if phase_timer >= 2.0:
				phase = Phase.TITLE; phase_timer = 0.0
		
		Phase.TITLE:
			title_timer += delta
			if title_timer >= CHAR_DELAY:
				title_timer = 0.0
				if title_chars < TITLE_TEXT.length():
					title_chars += 1
			if title_chars >= TITLE_TEXT.length() and phase_timer >= 1.2:
				phase = Phase.HERO_REVEAL; phase_timer = 0.0
		
		Phase.HERO_REVEAL:
			hero_reveal_alpha = move_toward(hero_reveal_alpha, 1.0, delta * 1.2)
			if phase_timer >= 1.8:
				phase = Phase.STATS_REVEAL; phase_timer = 0.0
				stats_revealed = 0; stat_timer = STAT_STAGGER
		
		Phase.STATS_REVEAL:
			stat_timer -= delta
			if stat_timer <= 0 and stats_revealed < stat_lines.size():
				stats_revealed += 1; stat_timer = STAT_STAGGER
			if stats_revealed >= stat_lines.size() and phase_timer >= 0.8:
				phase = Phase.GRADE; phase_timer = 0.0
		
		Phase.GRADE:
			grade_scale = move_toward(grade_scale, 1.0, delta * 3.0)
			if phase_timer >= 0.8:
				phase = Phase.UNLOCK_BANNER; phase_timer = 0.0
		
		Phase.UNLOCK_BANNER:
			if newly_unlocked.size() > 0:
				banner_y_offset = move_toward(banner_y_offset, 8.0, delta * 200.0)
			if phase_timer >= (2.0 if newly_unlocked.size() > 0 else 0.1):
				phase = Phase.MENU; phase_timer = 0.0
		
		Phase.MENU:
			menu_alpha = move_toward(menu_alpha, 1.0, delta * 1.5)
	
	if phase == Phase.MENU and menu_alpha > 0.5:
		_handle_input()
	
	queue_redraw()


func _input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		if phase.value < Phase.MENU.value:
			# Skip to full display
			phase             = Phase.MENU
			bg_alpha          = 1.0
			title_chars       = TITLE_TEXT.length()
			hero_reveal_alpha = 1.0
			stats_revealed    = stat_lines.size()
			grade_scale       = 1.0
			banner_y_offset   = 8.0 if newly_unlocked.size() > 0 else -80.0
			phase_timer       = 0.0


func _handle_input():
	if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_R):
		_new_run()
	elif Input.is_key_pressed(KEY_H):
		_hero_select()
	elif Input.is_action_just_pressed("pause"):
		_main_menu()


# ════════════════════════════════════════════════════════════
# _draw()
# ════════════════════════════════════════════════════════════
func _draw():
	var vp   = get_viewport_rect().size
	var font = ThemeDB.fallback_font
	var cx   = vp.x / 2.0
	
	# Gradient background (dark-to-dark-gold)
	draw_rect(Rect2(0, 0, vp.x, vp.y * 0.5),
		Color(C_BG_TOP.r, C_BG_TOP.g, C_BG_TOP.b, bg_alpha))
	draw_rect(Rect2(0, vp.y * 0.5, vp.x, vp.y * 0.5),
		Color(C_BG_BOT.r, C_BG_BOT.g, C_BG_BOT.b, bg_alpha))
	
	if bg_alpha < 0.05: return
	
	_draw_gold_border(vp, font)
	
	# ── TITLE ────────────────────────────────────────────────
	var title_shown = TITLE_TEXT.substr(0, title_chars)
	draw_string(font, Vector2(cx - 120, vp.y * 0.10),
		title_shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 28,
		Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, bg_alpha))
	
	# Blinking cursor while typing
	if title_chars < TITLE_TEXT.length():
		draw_string(font, Vector2(cx - 120 + title_chars * 16, vp.y * 0.10),
			"_", HORIZONTAL_ALIGNMENT_LEFT, -1, 28,
			Color(C_GOLD.r, C_GOLD.g, C_GOLD.b,
				bg_alpha * abs(sin(phase_timer * 6.0))))
	
	if phase == Phase.FADE_IN or (phase == Phase.TITLE and title_chars == 0):
		return
	
	# ── HERO NAME ────────────────────────────────────────────
	draw_string(font, Vector2(cx - 90, vp.y * 0.20),
		"The Saga of " + hero_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
		Color(C_SILVER.r, C_SILVER.g, C_SILVER.b, hero_reveal_alpha))
	
	# Decorative divider
	if hero_reveal_alpha > 0.1:
		draw_line(Vector2(cx - 130, vp.y * 0.24),
			Vector2(cx + 130, vp.y * 0.24),
			Color(C_GOLD_DIM.r, C_GOLD_DIM.g, C_GOLD_DIM.b, hero_reveal_alpha * 0.5),
			0.75)
	
	# ── STATS ────────────────────────────────────────────────
	_draw_victory_stats(cx, vp.y, font)
	
	# ── SCORE ────────────────────────────────────────────────
	if stats_revealed >= stat_lines.size():
		var sa = clampf(phase_timer * 2.0, 0.0, 1.0) if phase == Phase.GRADE else 1.0
		draw_string(font, Vector2(cx - 75, vp.y * 0.78),
			"FINAL SCORE  " + str(run_score),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 17,
			Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, sa))
		if is_new_best:
			draw_string(font, Vector2(cx + 80, vp.y * 0.78),
				"★ NEW BEST", HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
				Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, sa * 0.85))
	
	# ── GRADE ────────────────────────────────────────────────
	if grade_scale > 0.01:
		_draw_grade(vp, font)
	
	# ── UNLOCK BANNER ────────────────────────────────────────
	if newly_unlocked.size() > 0 and phase.value >= Phase.UNLOCK_BANNER.value:
		_draw_unlock_banner(vp, font)
	
	# ── MENU ─────────────────────────────────────────────────
	if phase == Phase.MENU:
		_draw_victory_menu(cx, vp.y, font)


func _draw_gold_border(vp: Rect2, font: Font):
	# Thin gold frame around the screen
	var a = bg_alpha * 0.4
	draw_rect(Rect2(8, 8, vp.x - 16, vp.y - 16),
		Color(C_GOLD_DIM.r, C_GOLD_DIM.g, C_GOLD_DIM.b, a), false, 0.75)
	# Corner rune glyphs
	var corners = [Vector2(14, 22), Vector2(vp.x - 26, 22),
		Vector2(14, vp.y - 10), Vector2(vp.x - 26, vp.y - 10)]
	for c in corners:
		draw_string(font, c, "ᚠ", HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(C_RUNE.r, C_RUNE.g, C_RUNE.b, a))


func _draw_victory_stats(cx: float, vp_h: float, font: Font):
	var start_y  = vp_h * 0.28
	var row_h    = 19.0
	var col_w    = 240.0
	var per_col  = 4
	
	for i in range(stats_revealed):
		var s       = stat_lines[i]
		var col     = i / per_col
		var row     = i % per_col
		var sx      = cx - col_w * 0.5 + col * col_w
		var sy      = start_y + row * row_h
		var fresh   = clampf(float(stats_revealed - i) / 3.0, 0.0, 1.0)
		var slide_y = sy + (1.0 - fresh) * 6.0
		
		# Label
		draw_string(font, Vector2(sx - 100, slide_y),
			s["label"] + ":",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(C_DIM.r, C_DIM.g, C_DIM.b, fresh))
		
		# Value (bold-ish with larger size)
		draw_string(font, Vector2(sx + 14, slide_y),
			str(s["value"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(s["color"].r, s["color"].g, s["color"].b, fresh))
		
		# Norse commentary (right-aligned in italic via smaller size)
		if s.get("comment", "") != "":
			draw_string(font, Vector2(sx + 62, slide_y),
				"· " + s["comment"],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
				Color(C_DIM.r, C_DIM.g, C_DIM.b, fresh * 0.7))


func _draw_grade(vp: Rect2, font: Font):
	var gx     = vp.x * 0.82
	var gy     = vp.y * 0.55
	var color  = GRADE_COLORS.get(run_grade, C_DIM)
	var s      = grade_scale
	var size   = 55.0 * s
	
	draw_rect(Rect2(gx - size * 0.5, gy - size * 0.5, size, size),
		Color(color.r * 0.12, color.g * 0.12, color.b * 0.12, 0.92 * s))
	draw_rect(Rect2(gx - size * 0.5, gy - size * 0.5, size, size),
		Color(color.r, color.g, color.b, 0.9 * s), false, 2.0)
	draw_string(font, Vector2(gx - 15 * s, gy + 18 * s),
		run_grade, HORIZONTAL_ALIGNMENT_LEFT, -1, int(42 * s),
		Color(color.r, color.g, color.b, s))
	draw_string(font, Vector2(gx - 20 * s, gy + size * 0.5 + 14 * s),
		"— GRADE —", HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		Color(C_DIM.r, C_DIM.g, C_DIM.b, 0.8 * s))


func _draw_unlock_banner(vp: Rect2, font: Font):
	var bw  = 340.0
	var bh  = 30.0
	var bx  = vp.x * 0.5 - bw * 0.5
	var by  = banner_y_offset
	var a   = clampf((by - (-80)) / 88.0, 0.0, 1.0)
	
	draw_rect(Rect2(bx, by, bw, bh), Color(0.12, 0.10, 0.04, 0.95 * a))
	draw_rect(Rect2(bx, by, bw, bh),
		Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.85 * a), false, 1.5)
	
	var hero = newly_unlocked[0] if newly_unlocked.size() > 0 else "?"
	draw_string(font, Vector2(bx + 14, by + 20),
		"✦ " + hero.to_upper() + " UNLOCKED — Available on next run",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, a))


func _draw_victory_menu(cx: float, vp_h: float, font: Font):
	var my = vp_h * 0.90
	var a  = menu_alpha
	
	draw_line(Vector2(cx - 170, my - 12), Vector2(cx + 170, my - 12),
		Color(C_GOLD_DIM.r, C_GOLD_DIM.g, C_GOLD_DIM.b, a * 0.35), 0.5)
	
	var opts = [
		{"key":"[R]","label":"New Run",    "col":-150.0},
		{"key":"[H]","label":"Hero Select","col":-20.0},
		{"key":"[ESC]","label":"Main Menu","col":100.0},
	]
	for opt in opts:
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

func _new_run():
	if has_node("/root/GameData"):
		GameData.start_run()
	get_tree().change_scene_to_file("res://scenes/CharacterSelect.tscn")

func _hero_select():
	if has_node("/root/GameData"):
		GameData.start_run()
	get_tree().change_scene_to_file("res://scenes/CharacterSelect.tscn")

func _main_menu():
	if has_node("/root/GameData"):
		GameData.start_run()
	get_tree().change_scene_to_file("res://scenes/HomeScreen.tscn")
