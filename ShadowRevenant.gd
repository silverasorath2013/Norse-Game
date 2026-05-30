extends Node

# ============================================================
# HELHEIM  —  Floor 4  "The Realm of the Dead"
# ============================================================
# Dark, oppressive, soul-draining. Rooms are more claustrophobic.
# Enemies steal HP rather than dealing straight damage.
# The hazard is "shadow pools" that reduce max HP temporarily.
#
# Add to FloorTheme.gd:
# static func helheim() -> FloorTheme: ...
#
# ENEMIES:
#   ShadowRevenant   — drains HP into a shield, transfers it back as damage
#   SoulEater        — ranged; steals HP on bullet hit (lifesteal for enemies)
#   VoidHound        — creates shadow clones that confuse targeting
#
# BOSS: Nidhogg, the Root Gnawer
#   The great serpent that gnaws at Yggdrasil's roots.
#   Unlike Jormungandr, Nidhogg is slow and methodical — its
#   danger is the arena: roots erupt from the floor, roots
#   grow back after being destroyed, and Nidhogg can HIDE in
#   the root network.
# ============================================================


# ════════════════════════════════════════════════════════════
# THEME
# ════════════════════════════════════════════════════════════
# Add to FloorTheme.gd static methods — copy this block:
#
# static func helheim() -> FloorTheme:
#     var t               = FloorTheme.new()
#     t.floor_number      = 4
#     t.realm_name        = "Helheim"
#     t.realm_subtitle    = "The realm of the dishonoured dead"
#     t.color_floor       = Color(0.08, 0.08, 0.12)   # Near-black void
#     t.color_floor_alt   = Color(0.06, 0.06, 0.10)
#     t.color_floor_crack = Color(0.15, 0.05, 0.18)   # Purple crack
#     t.color_wall        = Color(0.06, 0.05, 0.10)
#     t.color_wall_dark   = Color(0.04, 0.03, 0.07)
#     t.color_door        = Color(0.18, 0.10, 0.25)
#     t.color_rock        = Color(0.12, 0.08, 0.18)
#     t.color_pillar      = Color(0.16, 0.10, 0.22)
#     t.color_pit         = Color(0.0, 0.0, 0.04)     # Absolute black
#     t.ambient_particle_color = Color(0.55, 0.15, 0.70, 0.40)
#     t.ambient_particle_type  = "ash"
#     t.ambient_particle_count = 14
#     t.bg_darkness       = 0.95
#     t.torch_color       = Color(0.55, 0.20, 0.80)
#     t.music_path        = "res://audio/music/floor4_helheim.ogg"
#     t.enemy_pool = {
#         "res://scenes/enemies/ShadowRevenant.tscn": 10,
#         "res://scenes/enemies/SoulEater.tscn":       7,
#         "res://scenes/enemies/VoidHound.tscn":       5,
#         "res://scenes/enemies/NiflheimStalker.tscn": 2,
#     }
#     t.boss_scene_path   = "res://scenes/boss/Nidhogg.tscn"
#     t.boss_name         = "Nidhogg, the Root Gnawer"
#     t.hazard_type       = "shadow"
#     t.hazard_damage     = 0   # Shadow doesn't damage; reduces max HP temporarily
#     return t


# ════════════════════════════════════════════════════════════
# ENEMY 1: ShadowRevenant
# ════════════════════════════════════════════════════════════
# Absorbs hits (up to 20 stored), converts them to a SOUL SHIELD.
# When it dies or the shield is full: fires ALL stored damage
# back at the player as a single condensed soul bolt.
# STATS: HP 28, Speed 55, Damage 1


# ════════════════════════════════════════════════════════════
# ENEMY 2: SoulEater
# ════════════════════════════════════════════════════════════
# Ranged ghost. Fires "soul bolts" — on hit the enemy HEALS
# for the amount dealt (5 HP per bolt). Forces player to close
# the gap rather than shoot from range.
# Has a "soul link" aura — if two SoulEaters are alive and
# within 150px of each other, one absorbs damage for the other
# (share a HP pool effectively).
# STATS: HP 32, Speed 45 (slow), Damage 8 per bolt, Heal 5 per hit


# ════════════════════════════════════════════════════════════
# ENEMY 3: VoidHound
# ════════════════════════════════════════════════════════════
# Creates 2 shadow decoys that mirror its movement.
# Decoys deal no damage but block bullets (12 HP each).
# The real VoidHound is identified by slightly different shade.
# On death: decoys all explode into 4 void shards.
# STATS: HP 30, Speed 88 (very fast), Damage 1

# Full implementations below:


extends "res://scripts/EnemyBase.gd"
# ── ShadowRevenant ───────────────────────────────────────────
class_name ShadowRevenant

const MAX_STORED:   int   = 20
const BOLT_SPEED:   float = 220.0
var stored_damage:  int   = 0

func _ready():
	super()
	enemy_name = "Shadow Revenant"
	max_health = 28; current_health = 28
	move_speed = 55.0; damage = 1
	contact_damage_cooldown = 0.9
	if sprite: sprite.modulate = Color(0.35, 0.15, 0.55)

func _idle_behaviour(_d): velocity=Vector2.ZERO; if player_ref: state=State.CHASE
func _chase_behaviour(_d):
	if player_ref==null: state=State.IDLE; return
	var to=player_ref.global_position-global_position
	if to.length()>300: state=State.IDLE; return
	velocity=to.normalized()*move_speed

func take_damage(amount:int):
	stored_damage=min(stored_damage+amount, MAX_STORED)
	super(amount)
	if stored_damage>=MAX_STORED: _fire_soul_bolt()

func _fire_soul_bolt():
	if player_ref==null: return
	var path="res://scenes/enemies/EnemyBullet.tscn"
	if not ResourceLoader.exists(path): return
	var b=load(path).instantiate()
	b.global_position=global_position
	b.direction=(player_ref.global_position-global_position).normalized()
	b.speed=BOLT_SPEED; b.damage=stored_damage
	if b.has_node("Sprite2D"): b.get_node("Sprite2D").modulate=Color(0.6,0.2,0.9)
	get_parent().add_child(b)
	stored_damage=0; print("[ShadowRevenant] SOUL BOLT — ", b.damage, " dmg!")

func _die():
	if stored_damage>0: _fire_soul_bolt()
	super()
