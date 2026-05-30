extends Node

# ============================================================
# FloorTheme_Additions.gd  —  READ AND COPY, DON'T ATTACH
# ============================================================
# Add these static methods to FloorTheme.gd
# Then register them in FloorThemeRegistry._ready()
# ============================================================

# ── ADD TO FloorTheme.gd ─────────────────────────────────────

# static func muspelheim() -> FloorTheme:
#   var t = FloorTheme.new()
#   t.floor_number = 3; t.realm_name = "Muspelheim"
#   t.realm_subtitle = "The realm of fire and ruin"
#   t.color_floor = Color(0.28, 0.14, 0.06)
#   t.color_floor_alt = Color(0.32, 0.12, 0.04)
#   t.color_floor_crack = Color(0.40, 0.18, 0.02)
#   t.color_wall = Color(0.22, 0.10, 0.04)
#   t.color_wall_dark = Color(0.14, 0.06, 0.02)
#   t.color_door = Color(0.50, 0.22, 0.06)
#   t.color_rock = Color(0.38, 0.16, 0.04)
#   t.color_pillar = Color(0.42, 0.20, 0.06)
#   t.color_pit = Color(0.65, 0.18, 0.02)
#   t.ambient_particle_color = Color(1.0, 0.55, 0.10, 0.45)
#   t.ambient_particle_type = "ember"
#   t.ambient_particle_count = 20
#   t.bg_darkness = 0.78; t.torch_color = Color(1.0, 0.50, 0.10)
#   t.music_path = "res://audio/music/floor3_muspelheim.ogg"
#   t.enemy_pool = {
#     "res://scenes/enemies/SurtrSpawn.tscn": 10,
#     "res://scenes/enemies/LavaStalker.tscn": 8,
#     "res://scenes/enemies/CinderWolf.tscn": 6,
#     "res://scenes/enemies/FrostRevenant.tscn": 2,
#   }
#   t.boss_scene_path = "res://scenes/boss/Surtr.tscn"
#   t.boss_name = "Surtr, Lord of Flames"
#   t.hazard_type = "lava"; t.hazard_damage = 2
#   return t

# static func helheim() -> FloorTheme:
#   var t = FloorTheme.new()
#   t.floor_number = 4; t.realm_name = "Helheim"
#   t.realm_subtitle = "The realm of the dishonoured dead"
#   t.color_floor = Color(0.08, 0.08, 0.12)
#   t.color_floor_alt = Color(0.06, 0.06, 0.10)
#   t.color_floor_crack = Color(0.15, 0.05, 0.18)
#   t.color_wall = Color(0.06, 0.05, 0.10)
#   t.color_wall_dark = Color(0.04, 0.03, 0.07)
#   t.color_door = Color(0.18, 0.10, 0.25)
#   t.color_rock = Color(0.12, 0.08, 0.18)
#   t.color_pillar = Color(0.16, 0.10, 0.22)
#   t.color_pit = Color(0.0, 0.0, 0.04)
#   t.ambient_particle_color = Color(0.55, 0.15, 0.70, 0.40)
#   t.ambient_particle_type = "ash"
#   t.ambient_particle_count = 14
#   t.bg_darkness = 0.95; t.torch_color = Color(0.55, 0.20, 0.80)
#   t.music_path = "res://audio/music/floor4_helheim.ogg"
#   t.enemy_pool = {
#     "res://scenes/enemies/ShadowRevenant.tscn": 10,
#     "res://scenes/enemies/SoulEater.tscn": 7,
#     "res://scenes/enemies/VoidHound.tscn": 5,
#     "res://scenes/enemies/NiflheimStalker.tscn": 2,
#   }
#   t.boss_scene_path = "res://scenes/boss/Nidhogg.tscn"
#   t.boss_name = "Nidhogg, the Root Gnawer"
#   t.hazard_type = "shadow"; t.hazard_damage = 0
#   return t

# static func asgard() -> FloorTheme:
#   var t = FloorTheme.new()
#   t.floor_number = 5; t.realm_name = "Asgard"
#   t.realm_subtitle = "The golden halls of the gods"
#   t.color_floor = Color(0.72, 0.62, 0.28)
#   t.color_floor_alt = Color(0.65, 0.56, 0.24)
#   t.color_floor_crack = Color(0.80, 0.70, 0.32)
#   t.color_wall = Color(0.55, 0.46, 0.20)
#   t.color_wall_dark = Color(0.38, 0.32, 0.14)
#   t.color_door = Color(0.82, 0.70, 0.30)
#   t.color_rock = Color(0.60, 0.52, 0.22)
#   t.color_pillar = Color(0.75, 0.65, 0.28)
#   t.color_pit = Color(0.88, 0.78, 0.35)
#   t.ambient_particle_color = Color(1.0, 0.90, 0.40, 0.50)
#   t.ambient_particle_type = "divine"
#   t.ambient_particle_count = 16
#   t.bg_darkness = 0.55; t.torch_color = Color(1.0, 0.92, 0.55)
#   t.music_path = "res://audio/music/floor5_asgard.ogg"
#   t.enemy_pool = {
#     "res://scenes/enemies/GoldenEinherjar.tscn": 9,
#     "res://scenes/enemies/RuneGolem.tscn": 7,
#     "res://scenes/enemies/ValkyrieGuard.tscn": 6,
#   }
#   t.boss_scene_path = "res://scenes/boss/OdinFinal.tscn"
#   t.boss_name = "Odin, the Allfather"
#   t.hazard_type = "divine"; t.hazard_damage = 3
#   return t


# ── ADD TO FloorThemeRegistry._ready() ───────────────────────
#
#   _themes[3] = FloorTheme.muspelheim()
#   _themes[4] = FloorTheme.helheim()
#   _themes[5] = FloorTheme.asgard()


# ── NEW RUNES PER FLOOR (add to RuneDatabase via per-floor files) ──────────

# MUSPELHEIM RUNES (floor_weight peak at floor 3):
#   "ember_brand"     — common   — +3 dmg; shots leave 1s burn on hit
#   "surtr_blessing"  — uncommon — on kill: 8% chance a fire explosion (AoE 60px, 15 dmg)
#   "lava_heart"      — uncommon — below 40% HP: immunity to burn/lava hazards + +8 dmg
#   "ragnarok_shard"  — rare     — shots become fire: +8 dmg, pierce + burn
#   "giants_ember"    — legendary — on room clear: fire ring erupts (12 bullets from hero)

# HELHEIM RUNES (floor_weight peak at floor 4):
#   "souls_weight"    — common   — on kill: +2 current HP (lifesteal on every kill)
#   "void_mantle"     — uncommon — 10% chance to become incorporeal on hit (dodge)
#   "hels_bargain"    — uncommon — -20 max HP; on room clear: fully heal
#   "nidhogg_fang"    — rare     — shots become soul bolts: heal 3 HP on hit
#   "realm_walker"    — legendary — teleport to cursor on special use (replaces hero special)

# ASGARD RUNES (floor_weight peak at floor 5):
#   "divine_light"    — common   — +5 dmg; torch light radius doubled (visual)
#   "runic_mastery"   — uncommon — all rune procs trigger twice (doubles passive effects)
#   "valkyrie_grace"  — uncommon — on room clear: gain a full-heal heart pickup
#   "gungnir_tip_v2"  — rare     — shots pierce all enemies + homes to nearest target
#   "allfather_eye"   — legendary — reveals entire dungeon + +15 dmg + +20 speed
