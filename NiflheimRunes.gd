extends Node

# ============================================================
# NiflheimRunes.gd
# ============================================================
# Called from RuneDatabase._ready() to register the 8 runes
# that are exclusive to or heavily weighted toward Floor 2.
#
# USAGE in RuneDatabase.gd _ready():
#   NiflheimRunes.register(self)   # pass the RuneDatabase node
#
# These runes use the same structure as all others in
# RuneDatabase. Floor weights make them rare on floor 1
# but common on floor 2, tapering off on floors 3+.
# ============================================================

# Call this from RuneDatabase._ready() after _register_all_runes()
static func register(db: Node):
	_add_niflheim_runes(db)
	print("[NiflheimRunes] 8 Niflheim runes registered.")


static func _add_niflheim_runes(db: Node):

	# ── COMMON ─────────────────────────────────────────────

	db._add({
		"id":          "frost_shard_rune",
		"name":        "Frost Shard",
		"description": "+4 damage. Your shots leave a brief chill on enemies.",
		"rarity":      "common",
		"tags":        ["damage", "cold", "projectile"],
		"stat_mods":   {"base_damage": 4},
		"on_pickup":   "enable_frost_shots",
		"on_kill":     "",
		"on_hit_dealt":"frost_chill_on_hit",
		"on_hit_taken":"",
		"on_room_clear":"",
		"floor_weight": {1:2, 2:12, 3:8, 4:5, 5:3},
	})

	db._add({
		"id":          "ymir_marrow",
		"name":        "Ymir's Marrow",
		"description": "+20 max HP. Your cold bones resist the first hit each room.",
		"rarity":      "common",
		"tags":        ["health", "defense", "cold"],
		"stat_mods":   {"max_health": 20},
		"on_pickup":   "heal_on_pickup",
		"on_kill":     "",
		"on_hit_dealt":"",
		"on_hit_taken":"ymir_absorb",
		"on_room_clear":"ymir_reset_shield",
		"floor_weight": {1:1, 2:11, 3:7, 4:5, 5:3},
	})

	db._add({
		"id":          "mist_veil",
		"name":        "Mist Veil",
		"description": "+0.25s i-frames. You flicker like mist after taking damage.",
		"rarity":      "common",
		"tags":        ["defense", "iframes", "cold"],
		"stat_mods":   {},
		"on_pickup":   "extend_iframes_quarter",
		"on_kill":     "",
		"on_hit_dealt":"",
		"on_hit_taken":"",
		"on_room_clear":"",
		"floor_weight": {1:1, 2:10, 3:7, 4:5, 5:3},
	})

	# ── UNCOMMON ───────────────────────────────────────────

	db._add({
		"id":          "blizzard_stride",
		"name":        "Blizzard Stride",
		"description": "Ice patches no longer slow you. Instead they boost speed by +10.",
		"rarity":      "uncommon",
		"tags":        ["speed", "cold", "utility"],
		"stat_mods":   {},
		"on_pickup":   "register_blizzard_stride",
		"on_kill":     "",
		"on_hit_dealt":"",
		"on_hit_taken":"",
		"on_room_clear":"",
		"floor_weight": {1:0, 2:9, 3:7, 4:5, 5:3},
	})

	db._add({
		"id":          "howling_wind",
		"name":        "Howling Wind",
		"description": "+30 projectile speed. Shots leave a brief wind trail that pushes enemies.",
		"rarity":      "uncommon",
		"tags":        ["projectile", "speed", "cold"],
		"stat_mods":   {"projectile_speed": 30.0},
		"on_pickup":   "",
		"on_kill":     "",
		"on_hit_dealt":"howling_wind_push",
		"on_hit_taken":"",
		"on_room_clear":"",
		"floor_weight": {1:1, 2:8, 3:7, 4:5, 5:4},
	})

	db._add({
		"id":          "frozen_heart",
		"name":        "Frozen Heart",
		"description": "On room clear: freeze all remaining ice patches, converting them to +3g each.",
		"rarity":      "uncommon",
		"tags":        ["cold", "gold", "on_room_clear"],
		"stat_mods":   {},
		"on_pickup":   "",
		"on_kill":     "",
		"on_hit_dealt":"",
		"on_hit_taken":"",
		"on_room_clear":"frozen_heart_convert",
		"floor_weight": {1:0, 2:8, 3:6, 4:4, 5:3},
	})

	# ── RARE ───────────────────────────────────────────────

	db._add({
		"id":          "jormungandrs_cold",
		"name":        "Jormungandr's Cold",
		"description": "Shots become ice: they pierce AND slow enemies hit for 1.5s. -5 base damage.",
		"rarity":      "rare",
		"tags":        ["projectile", "piercing", "cold", "serpent"],
		"stat_mods":   {"base_damage": -5},
		"on_pickup":   "enable_piercing",
		"on_kill":     "",
		"on_hit_dealt":"frost_chill_on_hit",
		"on_hit_taken":"",
		"on_room_clear":"",
		"floor_weight": {1:0, 2:5, 3:6, 4:6, 5:5},
	})

	# ── LEGENDARY ──────────────────────────────────────────

	db._add({
		"id":          "glacier_throne",
		"name":        "Glacier Throne",
		"description": "Standing still for 1.5s grants an ice shield (absorbs 1 hit). Refreshes each room.",
		"rarity":      "legendary",
		"tags":        ["defense", "cold", "utility"],
		"stat_mods":   {},
		"on_pickup":   "register_glacier_throne",
		"on_kill":     "",
		"on_hit_dealt":"",
		"on_hit_taken":"glacier_throne_absorb",
		"on_room_clear":"glacier_throne_refresh",
		"floor_weight": {1:0, 2:2, 3:3, 4:2, 5:2},
	})
