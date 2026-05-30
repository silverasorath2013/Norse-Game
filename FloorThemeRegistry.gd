extends Node

# ============================================================
# FloorThemeRegistry.gd  —  Autoload: "FloorThemeRegistry"
# ============================================================
# Single point of access for floor themes.
# Any script can call:
#   var theme = FloorThemeRegistry.get_theme(floor_num)
#
# Also handles theme-specific room drawing additions:
#   - Ice patch hazard overlay for Niflheim
#   - Ambient particle spawning
#   - Realm transition banner (shown briefly on floor entry)
# ============================================================

var _themes: Dictionary = {}
var _current_theme: FloorTheme = null


func _ready():
	# Pre-build all themes on startup
	_themes[1] = FloorTheme.midgard()
	_themes[2] = FloorTheme.niflheim()
	# Floors 3-5 can be added here as we build them
	print("[FloorThemeRegistry] ", _themes.size(), " themes loaded.")


# ════════════════════════════════════════════════════════════
# get_theme()  —  returns the FloorTheme for a given floor
# Falls back to Midgard if the floor isn't defined yet
# ════════════════════════════════════════════════════════════
func get_theme(floor_num: int) -> FloorTheme:
	if _themes.has(floor_num):
		return _themes[floor_num]
	# Fallback: return the highest defined theme
	var max_defined = _themes.keys().max()
	return _themes[max_defined]


# ════════════════════════════════════════════════════════════
# set_active_theme()  —  call when entering a new floor
# Broadcasts theme to Room.gd via group call
# ════════════════════════════════════════════════════════════
func set_active_theme(floor_num: int):
	_current_theme = get_theme(floor_num)
	print("[FloorThemeRegistry] Active theme: ", _current_theme.realm_name)


func get_active_theme() -> FloorTheme:
	return _current_theme


# ════════════════════════════════════════════════════════════
# roll_enemy_from_pool()  —  weighted random enemy pick
# Used by Room.gd instead of the old hardcoded enemy list
# ════════════════════════════════════════════════════════════
func roll_enemy_from_pool(floor_num: int) -> String:
	var theme = get_theme(floor_num)
	var pool  = theme.enemy_pool
	
	if pool.is_empty():
		return "res://scenes/enemies/Draugr.tscn"
	
	# Weighted pick
	var total = 0
	for w in pool.values(): total += w
	var roll = randi() % max(1, total)
	var cumulative = 0
	for path in pool:
		cumulative += pool[path]
		if roll < cumulative:
			return path
	
	return pool.keys()[0]  # Fallback


# ════════════════════════════════════════════════════════════
# get_floor_tilecolor()  —  returns a colour dict for Room.gd
# to use when drawing tile placeholders (no art yet)
# ════════════════════════════════════════════════════════════
func get_floor_tilecolor(floor_num: int, tile_type: String) -> Color:
	var t = get_theme(floor_num)
	match tile_type:
		"floor":        return t.color_floor
		"floor_alt":    return t.color_floor_alt
		"floor_crack":  return t.color_floor_crack
		"wall":         return t.color_wall
		"wall_dark":    return t.color_wall_dark
		"door":         return t.color_door
		"rock":         return t.color_rock
		"pillar":       return t.color_pillar
		"pit":          return t.color_pit
	return Color.MAGENTA   # Should never reach this


# ════════════════════════════════════════════════════════════
# show_realm_banner()  —  brief overlay when entering a floor
# Displays "Entering Niflheim — The realm of ice and mist"
# ════════════════════════════════════════════════════════════
func show_realm_banner(floor_num: int, parent_node: Node):
	var theme = get_theme(floor_num)
	
	# Create a CanvasLayer banner that fades in and out
	var canvas = CanvasLayer.new()
	canvas.layer = 15
	parent_node.add_child(canvas)
	
	var banner_node = Node2D.new()
	canvas.add_child(banner_node)
	
	# We'll use a script to draw the banner
	var script = GDScript.new()
	script.source_code = _build_banner_script(theme)
	banner_node.set_script(script)
	
	# Auto-remove after 3 seconds
	await parent_node.get_tree().create_timer(3.5).timeout
	canvas.queue_free()


func _build_banner_script(theme: FloorTheme) -> String:
	return """extends Node2D
var alpha = 0.0
var timer = 0.0
func _process(delta):
	timer += delta
	if timer < 0.8: alpha = timer / 0.8
	elif timer < 2.5: alpha = 1.0
	else: alpha = max(0.0, 1.0 - (timer - 2.5) / 0.8)
	queue_redraw()
func _draw():
	var vp = get_viewport_rect()
	var font = ThemeDB.fallback_font
	draw_rect(Rect2(0, vp.size.y*0.42, vp.size.x, 42), Color(0,0,0,alpha*0.75))
	draw_string(font, Vector2(vp.size.x/2-80, vp.size.y*0.42+18),
		\"""" + theme.realm_name.to_upper() + """\", HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
		Color(""" + str(theme.color_floor.r) + """,""" + str(theme.color_floor.g) + """,""" + str(theme.color_floor.b) + """,alpha))
	draw_string(font, Vector2(vp.size.x/2-100, vp.size.y*0.42+34),
		\"""" + theme.realm_subtitle + """\", HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		Color(0.7,0.7,0.75,alpha*0.8))
"""
