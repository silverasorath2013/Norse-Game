extends Node

# ============================================================
# RuneDatabase.gd  —  Autoload: register as "RuneDatabase"
# ============================================================
# The single source of truth for every item in the game.
# Every rune is a Dictionary with a fixed set of keys.
# Other scripts never hardcode item stats — they always ask
# RuneDatabase for the data by rune ID.
#
# RUNE STRUCTURE:
#   id          String  — unique snake_case identifier
#   name        String  — display name
#   description String  — one-line flavour/effect text
#   rarity      String  — "common" | "uncommon" | "rare" | "legendary"
#   tags        Array   — used for synergy detection (see SynergySystem)
#   stat_mods   Dict    — flat stat changes applied on pickup
#   on_pickup   String  — name of special function to call (or "")
#   on_kill     String  — fires every time the hero kills an enemy (or "")
#   on_hit_dealt String — fires when hero hits an enemy (or "")
#   on_hit_taken String — fires when hero takes damage (or "")
#   on_room_clear String — fires when a room is cleared (or "")
#   floor_weight Dict   — spawn weight per floor (higher = more common)
#                         e.g. {1:10, 2:8, 3:5} means common on floor 1,
#                              rarer on deeper floors
# ============================================================

# ── RARITY COLOURS (for HUD/UI tinting) ─────────────────────
const RARITY_COLORS = {
	"common":    Color(0.75, 0.75, 0.75),   # Silver-grey
	"uncommon":  Color(0.2,  0.75, 0.35),   # Green
	"rare":      Color(0.25, 0.5,  1.0),    # Blue
	"legendary": Color(0.85, 0.6,  0.1),    # Gold
}

# ── RARITY DROP WEIGHTS (used by ItemDropper) ────────────────
# Out of 100 total weight: common appears most, legendary rarely
const RARITY_WEIGHTS = {
	"common":    55,
	"uncommon":  28,
	"rare":      13,
	"legendary": 4,
}

# ════════════════════════════════════════════════════════════
# THE RUNE REGISTRY
# All 24 starting runes. More added as floors are built.
# ════════════════════════════════════════════════════════════
var runes: Dictionary = {}

func _ready():
	_register_all_runes()
	print("[RuneDatabase] Loaded ", runes.size(), " runes.")

func _register_all_runes():

	# ── COMMON RUNES ─────────────────────────────────────────

	_add({
		"id":          "wolf_fang",
		"name":        "Wolf Fang",
		"description": "+3 damage. Your shots feel heavier.",
		"rarity":      "common",
		"tags":        ["damage", "physical"],
		"stat_mods":   {"base_damage": 3},
		"on_pickup":   "",
		"on_kill":     "",
		"on_hit_dealt":"",
		"on_hit_taken":"",
		"on_room_clear":"",
		"floor_weight": {1:12, 2:10, 3:8, 4:6, 5:5},
	})

	_add({
		"id":          "draugr_marrow",
		"name":        "Draugr Marrow",
		"description": "+15 max HP. Smells of the grave.",
		"rarity":      "common",
		"tags":        ["health", "undead"],
		"stat_mods":   {"max_health": 15},
		"on_pickup":   "heal_on_pickup",  # Also heals 15 on pickup
		"on_kill":     "",
		"on_hit_dealt":"",
		"on_hit_taken":"",
		"on_room_clear":"",
		"floor_weight": {1:10, 2:10, 3:8, 4:8, 5:6},
	})

	_add({
		"id":          "rune_of_haste",
		"name":        "Rune of Haste",
		"description": "+15 move speed. Carved by Loki's own hand.",
		"rarity":      "common",
		"tags":        ["speed", "rune"],
		"stat_mods":   {"move_speed": 15.0},
		"on_pickup":   "",
		"on_kill":     "",
		"on_hit_dealt":"",
		"on_hit_taken":"",
		"on_room_clear":"",
		"floor_weight": {1:10, 2:9, 3:8, 4:7, 5:6},
	})

	_add({
		"id":          "shard_of_ice",
		"name":        "Shard of Niflheim",
		"description": "+0.06 fire rate. Shots slightly slower but more frequent.",
		"rarity":      "common",
		"tags":        ["fire_rate", "cold"],
		"stat_mods":   {"fire_rate": -0.06},   # Lower = faster shooting
		"on_pickup":   "",
		"on_kill":     "",
		"on_hit_dealt":"",
		"on_hit_taken":"",
		"on_room_clear":"",
		"floor_weight": {1:9, 2:9, 3:8, 4:7, 5:6},
	})

	_add({
		"id":          "ravens_eye",
		"name":        "Raven's Eye",
		"description": "+20 projectile speed. Shots zip across the room.",
		"rarity":      "common",
		"tags":        ["projectile", "speed"],
		"stat_mods":   {"projectile_speed": 20.0},
		"on_pickup":   "",
		"on_kill":     "",
		"on_hit_dealt":"",
		"on_hit_taken":"",
		"on_room_clear":"",
		"floor_weight": {1:8, 2:9, 3:9, 4:8, 5:7},
	})

	_add({
		"id":          "einherjar_shield",
		"name":        "Einherjar's Fragment",
		"description": "Gain 0.3s extra i-frames after taking damage.",
		"rarity":      "common",
		"tags":        ["defense", "iframes"],
		"stat_mods":   {},   # Applied via on_pickup special logic
		"on_pickup":   "extend_iframes",
		"on_kill":     "",
		"on_hit_dealt":"",
		"on_hit_taken":"",
		"on_room_clear":"",
		"floor_weight": {1:8, 2:8, 3:7, 4:7, 5:6},
	})

	# ── UNCOMMON RUNES ───────────────────────────────────────

	_add({
		"id":          "bloodied_axe",
		"name":        "Bloodied Axe",
		"description": "On kill: +1 damage this room. Resets each new room.",
		"rarity":      "uncommon",
		"tags":        ["damage", "on_kill", "stacking"],
		"stat_mods":   {},
		"on_pickup":   "",
		"on_kill":     "bloodied_axe_stack",
		"on_hit_dealt":"",
		"on_hit_taken":"",
		"on_room_clear":"bloodied_axe_reset",
		"floor_weight": {1:6, 2:8, 3:9, 4:9, 5:8},
	})

	_add({
		"id":          "valknut_charm",
		"name":        "Valknut Charm",
		"description": "On room clear: restore 5 HP.",
		"rarity":      "uncommon",
		"tags":        ["health", "on_room_clear"],
		"stat_mods":   {},
		"on_pickup":   "",
		"on_kill":     "",
		"on_hit_dealt":"",
		"on_hit_taken":"",
		"on_room_clear":"valknut_heal",
		"floor_weight": {1:5, 2:7, 3:8, 4:8, 5:7},
	})

	_add({
		"id":          "serpent_scale",
		"name":        "Serpent Scale",
		"description": "On hit taken: fire a ring of 6 shots. Once per 2 seconds.",
		"rarity":      "uncommon",
		"tags":        ["on_hit_taken", "retaliation", "serpent"],
		"stat_mods":   {},
		"on_pickup":   "",
		"on_kill":     "",
		"on_hit_dealt":"",
		"on_hit_taken":"serpent_retaliation",
		"on_room_clear":"",
		"floor_weight": {1:4, 2:6, 3:8, 4:8, 5:7},
	})

	_add({
		"id":          "odin_gallows",
		"name":        "Gallows Rope",
		"description": "+5 damage. -10 max HP. Sacrifice to gain power.",
		"rarity":      "uncommon",
		"tags":        ["damage", "health", "sacrifice"],
		"stat_mods":   {"base_damage": 5, "max_health": -10},
		"on_pickup":   "clamp_health",   # Make sure current HP doesn't exceed new max
		"on_kill":     "",
		"on_hit_dealt":"",
		"on_hit_taken":"",
		"on_room_clear":"",
		"floor_weight": {1:3, 2:6, 3:7, 4:8, 5:8},
	})

	_add({
		"id":          "mead_of_poetry",
		"name":        "Mead of Poetry",
		"description": "Every 10th shot is a triple spread burst.",
		"rarity":      "uncommon",
		"tags":        ["fire_rate", "spread", "rune"],
		"stat_mods":   {},
		"on_pickup":   "register_shot_counter",
		"on_kill":     "",
		"on_hit_dealt":"mead_shot_count",
		"on_hit_taken":"",
		"on_room_clear":"",
		"floor_weight": {1:3, 2:5, 3:7, 4:8, 5:8},
	})

	_add({
		"id":          "berserker_blood",
		"name":        "Berserker Blood",
		"description": "Below 30% HP: +8 damage and +20 speed.",
		"rarity":      "uncommon",
		"tags":        ["damage", "speed", "berserk", "threshold"],
		"stat_mods":   {},
		"on_pickup":   "register_berserk",
		"on_kill":     "",
		"on_hit_dealt":"",
		"on_hit_taken":"berserker_check",
		"on_room_clear":"",
		"floor_weight": {1:2, 2:5, 3:7, 4:8, 5:9},
	})

	# ── RARE RUNES ───────────────────────────────────────────

	_add({
		"id":          "bifrost_shard",
		"name":        "Bifrost Shard",
		"description": "Shots pierce through 2 enemies before stopping.",
		"rarity":      "rare",
		"tags":        ["projectile", "piercing", "bifrost"],
		"stat_mods":   {},
		"on_pickup":   "enable_piercing",
		"on_kill":     "",
		"on_hit_dealt":"",
		"on_hit_taken":"",
		"on_room_clear":"",
		"floor_weight": {1:1, 2:3, 3:5, 4:6, 5:7},
	})

	_add({
		"id":          "yggdrasil_root",
		"name":        "Yggdrasil Root",
		"description": "+25 max HP. Heal 1 HP per room cleared.",
		"rarity":      "rare",
		"tags":        ["health", "on_room_clear", "yggdrasil"],
		"stat_mods":   {"max_health": 25},
		"on_pickup":   "heal_on_pickup",
		"on_kill":     "",
		"on_hit_dealt":"",
		"on_hit_taken":"",
		"on_room_clear":"yggdrasil_tick",
		"floor_weight": {1:1, 2:2, 3:4, 4:6, 5:7},
	})

	_add({
		"id":          "fenrir_chain",
		"name":        "Fenrir's Chain",
		"description": "On kill: 15% chance to drop a gold coin.",
		"rarity":      "rare",
		"tags":        ["on_kill", "gold", "fenrir"],
		"stat_mods":   {},
		"on_pickup":   "",
		"on_kill":     "fenrir_gold_drop",
		"on_hit_dealt":"",
		"on_hit_taken":"",
		"on_room_clear":"",
		"floor_weight": {1:1, 2:2, 3:4, 4:6, 5:8},
	})

	_add({
		"id":          "gungir_tip",
		"name":        "Gungnir's Tip",
		"description": "+8 damage. Shots never miss — they curve slightly toward enemies.",
		"rarity":      "rare",
		"tags":        ["damage", "projectile", "homing"],
		"stat_mods":   {"base_damage": 8},
		"on_pickup":   "enable_homing",
		"on_kill":     "",
		"on_hit_dealt":"",
		"on_hit_taken":"",
		"on_room_clear":"",
		"floor_weight": {1:0, 2:2, 3:4, 4:6, 5:7},
	})

	_add({
		"id":          "norns_thread",
		"name":        "Norn's Thread",
		"description": "On room clear: reveal one adjacent room's type on minimap.",
		"rarity":      "rare",
		"tags":        ["utility", "minimap", "norn"],
		"stat_mods":   {},
		"on_pickup":   "",
		"on_kill":     "",
		"on_hit_dealt":"",
		"on_hit_taken":"",
		"on_room_clear":"norns_thread_reveal",
		"floor_weight": {1:0, 2:2, 3:4, 4:6, 5:7},
	})

	_add({
		"id":          "dead_mans_mead",
		"name":        "Dead Man's Mead",
		"description": "On kill: 8% chance to restore 1 HP.",
		"rarity":      "rare",
		"tags":        ["health", "on_kill", "lifesteal"],
		"stat_mods":   {},
		"on_pickup":   "",
		"on_kill":     "lifesteal_on_kill",
		"on_hit_dealt":"",
		"on_hit_taken":"",
		"on_room_clear":"",
		"floor_weight": {1:1, 2:2, 3:4, 4:5, 5:6},
	})

	# ── LEGENDARY RUNES ──────────────────────────────────────

	_add({
		"id":          "heart_of_ymir",
		"name":        "Heart of Ymir",
		"description": "+40 max HP. Also heals to full on pickup. Born of the first giant.",
		"rarity":      "legendary",
		"tags":        ["health", "yggdrasil", "giant"],
		"stat_mods":   {"max_health": 40},
		"on_pickup":   "full_heal",
		"on_kill":     "",
		"on_hit_dealt":"",
		"on_hit_taken":"",
		"on_room_clear":"",
		"floor_weight": {1:0, 2:0, 3:1, 4:2, 5:3},
	})

	_add({
		"id":          "ragnarok_ember",
		"name":        "Ragnarök Ember",
		"description": "+15 damage. On kill: a flame erupts at the enemy's position dealing 20 damage to nearby enemies.",
		"rarity":      "legendary",
		"tags":        ["damage", "on_kill", "fire", "aoe"],
		"stat_mods":   {"base_damage": 15},
		"on_pickup":   "",
		"on_kill":     "ragnarok_explosion",
		"on_hit_dealt":"",
		"on_hit_taken":"",
		"on_room_clear":"",
		"floor_weight": {1:0, 2:0, 3:1, 4:2, 5:3},
	})

	_add({
		"id":          "sleipnir_hoof",
		"name":        "Sleipnir's Hoof",
		"description": "+35 speed. Dodge roll gains a 2nd charge.",
		"rarity":      "legendary",
		"tags":        ["speed", "dodge", "sleipnir"],
		"stat_mods":   {"move_speed": 35.0},
		"on_pickup":   "double_dodge",
		"on_kill":     "",
		"on_hit_dealt":"",
		"on_hit_taken":"",
		"on_room_clear":"",
		"floor_weight": {1:0, 2:0, 3:1, 4:2, 5:3},
	})

	_add({
		"id":          "world_serpent_fang",
		"name":        "World Serpent's Fang",
		"description": "Shots bounce off walls once. On bounce: +5 damage.",
		"rarity":      "legendary",
		"tags":        ["projectile", "bouncing", "serpent"],
		"stat_mods":   {},
		"on_pickup":   "enable_bouncing",
		"on_kill":     "",
		"on_hit_dealt":"",
		"on_hit_taken":"",
		"on_room_clear":"",
		"floor_weight": {1:0, 2:0, 3:1, 4:2, 5:4},
	})

	_add({
		"id":          "huginn_muninn",
		"name":        "Huginn & Muninn",
		"description": "Two thought-ravens orbit you, each firing a shot every 2 seconds.",
		"rarity":      "legendary",
		"tags":        ["damage", "orbital", "raven"],
		"stat_mods":   {},
		"on_pickup":   "spawn_orbitals",
		"on_kill":     "",
		"on_hit_dealt":"",
		"on_hit_taken":"",
		"on_room_clear":"",
		"floor_weight": {1:0, 2:0, 3:1, 4:2, 5:3},
	})


# ════════════════════════════════════════════════════════════
# PUBLIC API
# ════════════════════════════════════════════════════════════

# _add() — internal helper to register a rune
func _add(data: Dictionary):
	runes[data["id"]] = data

# get_rune(id) — fetch a rune dictionary by its ID
func get_rune(rune_id: String) -> Dictionary:
	return runes.get(rune_id, {})

# get_all_rune_ids() — returns all rune IDs as an Array
func get_all_rune_ids() -> Array:
	return runes.keys()

# get_runes_by_rarity(rarity) — returns all runes of a given rarity
func get_runes_by_rarity(rarity: String) -> Array:
	var result = []
	for id in runes:
		if runes[id]["rarity"] == rarity:
			result.append(runes[id])
	return result

# get_runes_by_tag(tag) — useful for synergy checks
func get_runes_by_tag(tag: String) -> Array:
	var result = []
	for id in runes:
		if tag in runes[id]["tags"]:
			result.append(runes[id])
	return result

# roll_random_rune(floor_num, exclude_ids) — picks a rune using
# weighted random selection appropriate for the current floor.
# exclude_ids prevents duplicates of what the player already has.
func roll_random_rune(floor_num: int = 1, exclude_ids: Array = []) -> Dictionary:
	# Step 1: Roll rarity using RARITY_WEIGHTS
	var rarity = _roll_rarity(floor_num)
	
	# Step 2: Get all runes of that rarity not already held
	var pool = []
	for id in runes:
		var r = runes[id]
		if r["rarity"] == rarity and id not in exclude_ids:
			# Check floor_weight — if weight is 0 on this floor, skip
			var weight = r["floor_weight"].get(floor_num, 0)
			if weight > 0:
				pool.append(r)
	
	# Fallback: if pool is empty (rare + deep floor exclusions), grab any common
	if pool.is_empty():
		pool = get_runes_by_rarity("common")
	
	if pool.is_empty():
		return {}
	
	# Step 3: Weighted pick within the pool
	return _weighted_pick(pool, floor_num)

# _roll_rarity() — returns a rarity string based on weighted chance
func _roll_rarity(floor_num: int) -> String:
	# On deeper floors, slightly bump up rare/legendary odds
	var weights = RARITY_WEIGHTS.duplicate()
	var bonus = floor_num - 1   # 0 on floor 1, 4 on floor 5
	weights["rare"]      = weights["rare"]      + bonus * 1
	weights["legendary"] = weights["legendary"] + bonus * 1
	weights["common"]    = max(20, weights["common"] - bonus * 2)
	
	# Weighted random roll
	var total = 0
	for w in weights.values(): total += w
	var roll = randi() % total
	
	var cumulative = 0
	for rarity in weights:
		cumulative += weights[rarity]
		if roll < cumulative:
			return rarity
	return "common"   # Fallback

# _weighted_pick() — picks from pool weighted by floor_weight
func _weighted_pick(pool: Array, floor_num: int) -> Dictionary:
	var total_weight = 0
	for r in pool:
		total_weight += r["floor_weight"].get(floor_num, 1)
	
	var roll = randi() % max(total_weight, 1)
	var cumulative = 0
	for r in pool:
		cumulative += r["floor_weight"].get(floor_num, 1)
		if roll < cumulative:
			return r
	
	return pool[pool.size() - 1]   # Fallback: last item
