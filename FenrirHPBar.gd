extends "res://scripts/boss/BossHPBar.gd"

# ============================================================
# FenrirHPBar.gd  —  Extends BossHPBar for Fenrir's chain UI
# ============================================================
# Adds a row of chain icons below the HP bar.
# 4 chain links: filled = intact, hollow = broken.
# Breaking a chain shows a brief shatter animation.
# ============================================================

var chains_intact:    int   = 4
var chain_flash:      Array = [0.0, 0.0, 0.0, 0.0]  # Per-chain flash timers

const CHAIN_COLOR_FULL    = Color(0.65, 0.80, 1.0)
const CHAIN_COLOR_BROKEN  = Color(0.25, 0.30, 0.40)
const CHAIN_COLOR_FLASH   = Color(1.0,  0.92, 0.5)


func connect_to_boss(boss: Node):
	super(boss)   # Call parent BossHPBar setup
	
	if boss.has_signal("chain_broken"):
		boss.chain_broken.connect(_on_chain_broken)


func _on_chain_broken(remaining: int):
	var broken_index = chains_intact - 1   # Which chain just broke
	chains_intact    = remaining
	
	if broken_index >= 0 and broken_index < chain_flash.size():
		chain_flash[broken_index] = 0.6   # Flash for 0.6s


func _process(delta: float):
	super(delta)   # Let parent handle HP polling
	
	# Tick chain flash timers
	for i in range(chain_flash.size()):
		if chain_flash[i] > 0:
			chain_flash[i] -= delta


func _draw():
	super()   # Draw the normal HP bar first
	
	if _visible_alpha <= 0.01: return
	
	var font      = ThemeDB.fallback_font
	var vp_size   = get_viewport().get_visible_rect().size
	var bar_x     = (vp_size.x - BAR_WIDTH) / 2
	var chain_y   = vp_size.y - BAR_MARGIN - BAR_HEIGHT - 22
	var alpha     = _visible_alpha
	
	# "CHAINS" label
	draw_string(font, Vector2(bar_x, chain_y + 12),
		"CHAINS:", HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		Color(0.55, 0.65, 0.80, alpha * 0.8))
	
	# 4 chain link icons
	var icon_size  = 14.0
	var icon_gap   = 6.0
	var icon_start = bar_x + 55.0
	
	for i in range(4):
		var ix     = icon_start + i * (icon_size + icon_gap)
		var iy     = chain_y + 3
		var intact = i < chains_intact
		var flash  = chain_flash[i] > 0
		
		var color: Color
		if flash:
			color = CHAIN_COLOR_FLASH.lerp(
				CHAIN_COLOR_BROKEN, 1.0 - chain_flash[i] / 0.6)
		elif intact:
			color = CHAIN_COLOR_FULL
		else:
			color = CHAIN_COLOR_BROKEN
		
		color.a = alpha
		
		# Draw a chain link shape: two overlapping rounded rects
		# Simplified as two rectangles
		draw_rect(Rect2(ix, iy + 1, icon_size, icon_size * 0.45),
			color if intact else Color(color.r, color.g, color.b, alpha * 0.3))
		draw_rect(Rect2(ix, iy + icon_size * 0.55, icon_size, icon_size * 0.45),
			color if intact else Color(color.r, color.g, color.b, alpha * 0.3))
		
		# Connecting bar in middle
		draw_rect(Rect2(ix + icon_size * 0.3, iy + icon_size * 0.38,
			icon_size * 0.4, icon_size * 0.25), color)
		
		# Border
		draw_rect(Rect2(ix, iy, icon_size, icon_size),
			Color(color.r * 0.6, color.g * 0.6, color.b * 0.6, alpha * 0.8),
			false, 1.0)
		
		# "Shatter" effect on break
		if flash and chain_flash[i] > 0.4:
			var scatter = (0.6 - chain_flash[i]) * 40.0
			draw_rect(Rect2(ix - scatter, iy - scatter * 0.5, 4, 4),
				Color(CHAIN_COLOR_FLASH.r, CHAIN_COLOR_FLASH.g,
					CHAIN_COLOR_FLASH.b, alpha * chain_flash[i]))
			draw_rect(Rect2(ix + icon_size + scatter * 0.5, iy + scatter * 0.3, 3, 3),
				Color(CHAIN_COLOR_FLASH.r, CHAIN_COLOR_FLASH.g,
					CHAIN_COLOR_FLASH.b, alpha * chain_flash[i]))
	
	# "AIM FOR PAWS" hint on first chain break
	if chains_intact == 3 and _visible_alpha > 0.9:
		draw_string(font,
			Vector2(icon_start + 4 * (icon_size + icon_gap) + 8, chain_y + 12),
			"Aim for the paws!",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color(0.65, 0.80, 1.0, alpha * 0.7))
