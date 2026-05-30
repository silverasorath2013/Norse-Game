extends Resource

# ============================================================
# FloorTheme.gd  —  Data resource describing a floor's look
# ============================================================
# Each floor of the dungeon has a theme that controls:
#   - Background / wall / floor tile colours (drawn in Room.gd)
#   - Ambient particle colour (ice crystals, embers, dust)
#   - Minimap accent colour
#   - Music track path
#   - Enemy pool (which enemy types can spawn here)
#   - Boss scene path
#   - Any floor-unique environmental hazard type
#
# Room.gd reads the current theme from FloorThemeRegistry
# and uses it when calling _build_tilemap() and _draw_ambient().
#
# USAGE in Room.gd _setup():
#   var theme = FloorThemeRegistry.get_theme(floor_num)
#   _apply_theme(theme)
# ============================================================

class_name FloorTheme

var floor_number:    int    = 1
var realm_name:      String = "Midgard"
var realm_subtitle:  String = "The mortal world"

# ── TILE COLOURS ────────────────────────────────────────────
# These are used in Room._draw() to tint the TileMap
# or to set placeholder ColorRect colours during development
var color_floor:       Color = Color(0.22, 0.20, 0.18)
var color_floor_alt:   Color = Color(0.19, 0.17, 0.15)
var color_floor_crack: Color = Color(0.16, 0.14, 0.12)
var color_wall:        Color = Color(0.18, 0.16, 0.22)
var color_wall_dark:   Color = Color(0.12, 0.10, 0.15)
var color_door:        Color = Color(0.30, 0.25, 0.35)
var color_rock:        Color = Color(0.28, 0.25, 0.30)
var color_pillar:      Color = Color(0.32, 0.28, 0.36)
var color_pit:         Color = Color(0.08, 0.06, 0.10)

# ── AMBIENT ─────────────────────────────────────────────────
var ambient_particle_color: Color  = Color(0.6, 0.4, 0.8, 0.4)
var ambient_particle_count: int    = 12
var ambient_particle_type:  String = "dust"  # "dust"|"ice"|"ember"|"ash"

# ── LIGHTING ────────────────────────────────────────────────
var bg_darkness:     float = 0.85   # 0=bright  1=pitch black vignette
var torch_color:     Color = Color(1.0, 0.7, 0.3)

# ── AUDIO ────────────────────────────────────────────────────
var music_path:      String = "res://audio/music/floor1_midgard.ogg"
var ambience_path:   String = "res://audio/ambience/dungeon_echo.ogg"

# ── ENEMIES ─────────────────────────────────────────────────
# Weighted pool: {"scene_path": weight}
# Room._spawn_enemies() picks from this per floor
var enemy_pool:      Dictionary = {
	"res://scenes/enemies/Draugr.tscn":    10,
	"res://scenes/enemies/CursedWolf.tscn": 6,
	"res://scenes/enemies/Einherjar.tscn":  4,
	"res://scenes/enemies/Wight.tscn":      3,
}

# ── BOSS ─────────────────────────────────────────────────────
var boss_scene_path: String = "res://scenes/boss/Jormungandr.tscn"
var boss_name:       String = "Jormungandr"

# ── HAZARD TYPE ─────────────────────────────────────────────
var hazard_type:     String = "pit"   # "pit"|"ice"|"lava"|"shadow"
var hazard_damage:   int    = 1


# ════════════════════════════════════════════════════════════
# STATIC FACTORY METHODS  —  create pre-configured themes
# ════════════════════════════════════════════════════════════

static func midgard() -> FloorTheme:
	var t               = FloorTheme.new()
	t.floor_number      = 1
	t.realm_name        = "Midgard"
	t.realm_subtitle    = "The mortal dungeon"
	# Stone grey-brown
	t.color_floor       = Color(0.22, 0.20, 0.18)
	t.color_floor_alt   = Color(0.19, 0.17, 0.15)
	t.color_floor_crack = Color(0.16, 0.14, 0.12)
	t.color_wall        = Color(0.20, 0.18, 0.24)
	t.color_wall_dark   = Color(0.13, 0.11, 0.16)
	t.color_door        = Color(0.32, 0.26, 0.38)
	t.color_rock        = Color(0.30, 0.27, 0.32)
	t.color_pillar      = Color(0.34, 0.30, 0.38)
	t.color_pit         = Color(0.08, 0.06, 0.10)
	t.ambient_particle_color = Color(0.55, 0.35, 0.70, 0.35)
	t.ambient_particle_type  = "dust"
	t.ambient_particle_count = 10
	t.bg_darkness       = 0.82
	t.torch_color       = Color(1.0, 0.68, 0.28)
	t.music_path        = "res://audio/music/floor1_midgard.ogg"
	t.enemy_pool = {
		"res://scenes/enemies/Draugr.tscn":     10,
		"res://scenes/enemies/CursedWolf.tscn":  6,
		"res://scenes/enemies/Einherjar.tscn":   4,
		"res://scenes/enemies/Wight.tscn":       3,
	}
	t.boss_scene_path   = "res://scenes/boss/Jormungandr.tscn"
	t.boss_name         = "Jormungandr, the World Serpent"
	t.hazard_type       = "pit"
	return t

static func niflheim() -> FloorTheme:
	var t               = FloorTheme.new()
	t.floor_number      = 2
	t.realm_name        = "Niflheim"
	t.realm_subtitle    = "The realm of ice and mist"
	# Ice: cold blue-whites, deep navy shadows
	t.color_floor       = Color(0.55, 0.68, 0.80)   # Pale ice blue
	t.color_floor_alt   = Color(0.48, 0.62, 0.76)   # Slightly darker ice
	t.color_floor_crack = Color(0.38, 0.52, 0.68)   # Deep crack blue
	t.color_wall        = Color(0.22, 0.30, 0.48)   # Dark ice wall
	t.color_wall_dark   = Color(0.14, 0.20, 0.34)   # Shadow navy
	t.color_door        = Color(0.35, 0.50, 0.70)   # Frost door
	t.color_rock        = Color(0.40, 0.55, 0.72)   # Ice boulder
	t.color_pillar      = Color(0.50, 0.65, 0.82)   # Ice pillar (translucent look)
	t.color_pit         = Color(0.04, 0.08, 0.18)   # Black abyss
	t.ambient_particle_color = Color(0.70, 0.88, 1.0, 0.50)
	t.ambient_particle_type  = "ice"                # Drifting ice crystals
	t.ambient_particle_count = 18
	t.bg_darkness       = 0.90                      # Darker — misty and cold
	t.torch_color       = Color(0.55, 0.80, 1.0)    # Blue-white cold light
	t.music_path        = "res://audio/music/floor2_niflheim.ogg"
	t.ambience_path     = "res://audio/ambience/blizzard_wind.ogg"
	t.enemy_pool = {
		"res://scenes/enemies/FrostRevenant.tscn":  10,
		"res://scenes/enemies/IceWolf.tscn":         8,
		"res://scenes/enemies/NiflheimStalker.tscn": 5,
		"res://scenes/enemies/Draugr.tscn":          3,  # Carried over, rarer
	}
	t.boss_scene_path   = "res://scenes/boss/Fenrir.tscn"
	t.boss_name         = "Fenrir, the Unchained"
	t.hazard_type       = "ice"   # Ice patches slow + can slide player
	t.hazard_damage     = 0       # Ice doesn't hurt, it slows
	return t
