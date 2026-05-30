extends Node

# ============================================================
# FloorRunes_3_4_5.gd  —  Rune packs for Muspelheim, Helheim, Asgard
# ============================================================
# Call these from RuneDatabase._ready() after NiflheimRunes.register():
#   MuspelheimRunes.register(self)
#   HelheiRunes.register(self)
#   AsgardRunes.register(self)
#
# Each class follows the exact same pattern as NiflheimRunes.gd
# ============================================================


# ════════════════════════════════════════════════════════════
# MUSPELHEIM RUNES  (Floor 3)
# ════════════════════════════════════════════════════════════
class MuspelheimRunes:
	static func register(db: Node):
		# ── COMMON ───────────────────────────────────────────
		db._add({
			"id": "ember_brand",
			"name": "Ember Brand",
			"description": "+3 damage. Shots leave a 1-second burn on hit.",
			"rarity": "common",
			"tags": ["damage", "fire", "on_hit_dealt"],
			"stat_mods": {"base_damage": 3},
			"on_pickup": "",
			"on_kill": "",
			"on_hit_dealt": "ember_brand_burn",
			"on_hit_taken": "",
			"on_room_clear": "",
			"floor_weight": {1:0, 2:1, 3:12, 4:6, 5:3},
		})

		db._add({
			"id": "heat_ward",
			"name": "Heat Ward",
			"description": "Lava and burn damage reduced by 50%.",
			"rarity": "common",
			"tags": ["defense", "fire"],
			"stat_mods": {},
			"on_pickup": "register_heat_ward",
			"on_kill": "",
			"on_hit_dealt": "",
			"on_hit_taken": "",
			"on_room_clear": "",
			"floor_weight": {1:0, 2:1, 3:11, 4:6, 5:3},
		})

		# ── UNCOMMON ─────────────────────────────────────────
		db._add({
			"id": "surtr_blessing",
			"name": "Surtr's Blessing",
			"description": "On kill: 10% chance of a fire explosion (60px AoE, 15 damage).",
			"rarity": "uncommon",
			"tags": ["fire", "on_kill", "aoe"],
			"stat_mods": {},
			"on_pickup": "",
			"on_kill": "surtr_explosion",
			"on_hit_dealt": "",
			"on_hit_taken": "",
			"on_room_clear": "",
			"floor_weight": {1:0, 2:0, 3:9, 4:6, 5:3},
		})

		db._add({
			"id": "lava_heart",
			"name": "Lava Heart",
			"description": "Below 40% HP: immune to burn/lava + +8 damage.",
			"rarity": "uncommon",
			"tags": ["fire", "threshold", "damage", "defense"],
			"stat_mods": {},
			"on_pickup": "register_lava_heart",
			"on_kill": "",
			"on_hit_dealt": "",
			"on_hit_taken": "lava_heart_check",
			"on_room_clear": "",
			"floor_weight": {1:0, 2:0, 3:8, 4:5, 5:3},
		})

		# ── RARE ─────────────────────────────────────────────
		db._add({
			"id": "ragnarok_shard",
			"name": "Ragnarök Shard",
			"description": "Shots become fire: +8 damage, pierce, burn on hit. Jormungandr's Cold becomes fire instead.",
			"rarity": "rare",
			"tags": ["fire", "damage", "piercing", "projectile"],
			"stat_mods": {"base_damage": 8},
			"on_pickup": "enable_piercing",
			"on_kill": "",
			"on_hit_dealt": "ember_brand_burn",
			"on_hit_taken": "",
			"on_room_clear": "",
			"floor_weight": {1:0, 2:0, 3:5, 4:5, 5:4},
		})

		# ── LEGENDARY ────────────────────────────────────────
		db._add({
			"id": "giants_ember",
			"name": "Giant's Ember",
			"description": "On room clear: a fire ring erupts from the hero (12 bullets).",
			"rarity": "legendary",
			"tags": ["fire", "on_room_clear", "aoe"],
			"stat_mods": {},
			"on_pickup": "",
			"on_kill": "",
			"on_hit_dealt": "",
			"on_hit_taken": "",
			"on_room_clear": "giants_ember_burst",
			"floor_weight": {1:0, 2:0, 3:2, 4:2, 5:2},
		})

		print("[MuspelheimRunes] 6 runes registered.")


# ════════════════════════════════════════════════════════════
# HELHEIM RUNES  (Floor 4)
# ════════════════════════════════════════════════════════════
class HelheiRunes:
	static func register(db: Node):
		# ── COMMON ───────────────────────────────────────────
		db._add({
			"id": "souls_weight",
			"name": "Soul's Weight",
			"description": "On kill: restore 2 HP (lifesteal every kill).",
			"rarity": "common",
			"tags": ["health", "on_kill", "lifesteal"],
			"stat_mods": {},
			"on_pickup": "",
			"on_kill": "souls_weight_heal",
			"on_hit_dealt": "",
			"on_hit_taken": "",
			"on_room_clear": "",
			"floor_weight": {1:0, 2:1, 3:2, 4:12, 5:6},
		})

		db._add({
			"id": "shadow_cloak",
			"name": "Shadow Cloak",
			"description": "+0.5s i-frames. After taking damage, you flicker with shadow for 0.3s (untargetable by enemies).",
			"rarity": "common",
			"tags": ["defense", "iframes", "shadow"],
			"stat_mods": {},
			"on_pickup": "extend_iframes_half",
			"on_kill": "",
			"on_hit_dealt": "",
			"on_hit_taken": "",
			"on_room_clear": "",
			"floor_weight": {1:0, 2:1, 3:2, 4:11, 5:5},
		})

		# ── UNCOMMON ─────────────────────────────────────────
		db._add({
			"id": "void_mantle",
			"name": "Void Mantle",
			"description": "10% chance to become incorporeal on hit — that damage is ignored.",
			"rarity": "uncommon",
			"tags": ["defense", "shadow", "dodge"],
			"stat_mods": {},
			"on_pickup": "register_void_mantle",
			"on_kill": "",
			"on_hit_dealt": "",
			"on_hit_taken": "void_mantle_dodge",
			"on_room_clear": "",
			"floor_weight": {1:0, 2:0, 3:1, 4:9, 5:5},
		})

		db._add({
			"id": "hels_bargain",
			"name": "Hel's Bargain",
			"description": "-20 max HP. On room clear: fully restore HP.",
			"rarity": "uncommon",
			"tags": ["health", "sacrifice", "on_room_clear"],
			"stat_mods": {"max_health": -20},
			"on_pickup": "clamp_health",
			"on_kill": "",
			"on_hit_dealt": "",
			"on_hit_taken": "",
			"on_room_clear": "hels_bargain_heal",
			"floor_weight": {1:0, 2:0, 3:1, 4:8, 5:4},
		})

		# ── RARE ─────────────────────────────────────────────
		db._add({
			"id": "nidhogg_fang",
			"name": "Nidhogg's Fang",
			"description": "Shots become soul bolts: restore 3 HP on each enemy hit.",
			"rarity": "rare",
			"tags": ["health", "lifesteal", "projectile", "shadow"],
			"stat_mods": {},
			"on_pickup": "register_nidhogg_fang",
			"on_kill": "",
			"on_hit_dealt": "nidhogg_fang_heal",
			"on_hit_taken": "",
			"on_room_clear": "",
			"floor_weight": {1:0, 2:0, 3:1, 4:5, 5:4},
		})

		# ── LEGENDARY ────────────────────────────────────────
		db._add({
			"id": "realm_walker",
			"name": "Realm Walker",
			"description": "Special ability becomes: teleport to cursor position (replaces hero's original special for this run).",
			"rarity": "legendary",
			"tags": ["shadow", "utility", "speed"],
			"stat_mods": {},
			"on_pickup": "override_special_teleport",
			"on_kill": "",
			"on_hit_dealt": "",
			"on_hit_taken": "",
			"on_room_clear": "",
			"floor_weight": {1:0, 2:0, 3:0, 4:2, 5:2},
		})

		print("[HelheiRunes] 6 runes registered.")


# ════════════════════════════════════════════════════════════
# ASGARD RUNES  (Floor 5)
# ════════════════════════════════════════════════════════════
class AsgardRunes:
	static func register(db: Node):
		# ── COMMON ───────────────────────────────────────────
		db._add({
			"id": "divine_light",
			"name": "Divine Light",
			"description": "+5 damage. Your shots glow gold and reveal enemy weak points.",
			"rarity": "common",
			"tags": ["damage", "divine"],
			"stat_mods": {"base_damage": 5},
			"on_pickup": "enable_divine_shots",
			"on_kill": "",
			"on_hit_dealt": "",
			"on_hit_taken": "",
			"on_room_clear": "",
			"floor_weight": {1:0, 2:0, 3:0, 4:1, 5:12},
		})

		# ── UNCOMMON ─────────────────────────────────────────
		db._add({
			"id": "runic_mastery",
			"name": "Runic Mastery",
			"description": "All passive rune procs trigger twice (doubles all on_kill, on_hit, on_room_clear effects).",
			"rarity": "uncommon",
			"tags": ["divine", "utility"],
			"stat_mods": {},
			"on_pickup": "register_runic_mastery",
			"on_kill": "",
			"on_hit_dealt": "",
			"on_hit_taken": "",
			"on_room_clear": "",
			"floor_weight": {1:0, 2:0, 3:0, 4:1, 5:9},
		})

		db._add({
			"id": "valkyrie_grace",
			"name": "Valkyrie's Grace",
			"description": "On room clear: spawn a heart pickup at the room centre.",
			"rarity": "uncommon",
			"tags": ["health", "divine", "on_room_clear"],
			"stat_mods": {},
			"on_pickup": "",
			"on_kill": "",
			"on_hit_dealt": "",
			"on_hit_taken": "",
			"on_room_clear": "valkyrie_grace_heart",
			"floor_weight": {1:0, 2:0, 3:1, 4:2, 5:9},
		})

		# ── RARE ─────────────────────────────────────────────
		db._add({
			"id": "gungnir_mastery",
			"name": "Gungnir's Mastery",
			"description": "Shots pierce ALL enemies and curve toward the nearest target.",
			"rarity": "rare",
			"tags": ["damage", "projectile", "piercing", "homing", "divine"],
			"stat_mods": {},
			"on_pickup": "enable_piercing",
			"on_kill": "",
			"on_hit_dealt": "",
			"on_hit_taken": "",
			"on_room_clear": "",
			"floor_weight": {1:0, 2:0, 3:0, 4:1, 5:6},
		})

		# ── LEGENDARY ────────────────────────────────────────
		db._add({
			"id": "allfather_eye",
			"name": "Allfather's Eye",
			"description": "Reveals entire dungeon map. +15 damage. +20 move speed. You see all.",
			"rarity": "legendary",
			"tags": ["divine", "damage", "speed", "minimap"],
			"stat_mods": {"base_damage": 15, "move_speed": 20.0},
			"on_pickup": "allfather_reveal_all",
			"on_kill": "",
			"on_hit_dealt": "",
			"on_hit_taken": "",
			"on_room_clear": "",
			"floor_weight": {1:0, 2:0, 3:0, 4:0, 5:3},
		})

		print("[AsgardRunes] 5 runes registered.")
