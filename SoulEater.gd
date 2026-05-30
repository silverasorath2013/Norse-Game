extends "res://scripts/EnemyBase.gd"

# ============================================================
# SoulEater.gd  —  Helheim Ranged Drainer  (Floor 4)
# ============================================================
# MECHANICS:
#   SOUL BOLT: fires a slow purple bolt — on hitting the player,
#     heals THIS enemy for 5 HP (lifesteal for enemies).
#     Forces player to close the gap rather than shoot from afar.
#   SOUL LINK: if two SoulEaters are within 150px, they share
#     a HP pool — damage dealt to one is split equally.
#     Visual: a thin purple line between them.
#   DRAIN AURA: player within 90px loses 1 HP every 3s.
# STATS: HP 32, Speed 42, Bolt damage 8, Bolt heal 5
# ============================================================

const BOLT_CD:      float = 3.2
const BOLT_RANGE:   float = 210.0
const RETREAT_DIST: float = 85.0
const LINK_RANGE:   float = 150.0
const DRAIN_RANGE:  float = 90.0
const DRAIN_CD:     float = 3.0
const BOLT_HEAL:    int   = 5

var bolt_cd:    float = BOLT_CD * randf_range(0.3, 0.7)
var drain_cd:   float = DRAIN_CD
var linked_partner: Node = null
const SOUL_COLOR = Color(0.6, 0.2, 0.9)


func _ready():
	super()
	enemy_name     = "Soul Eater"
	max_health     = 32
	current_health = max_health
	move_speed     = 42.0
	damage         = 0   # No contact damage — ranged only
	detection_range = 320.0
	if sprite: sprite.modulate = SOUL_COLOR


func _physics_process(delta: float):
	if bolt_cd  > 0: bolt_cd  -= delta
	if drain_cd > 0: drain_cd -= delta
	_update_link()
	_check_drain(delta)
	super(delta)


func _idle_behaviour(_d: float):
	velocity = Vector2.ZERO
	if player_ref: state = State.CHASE


func _chase_behaviour(_delta: float):
	if player_ref == null: state = State.IDLE; return
	var to   = player_ref.global_position - global_position
	var dist = to.length()
	if dist > detection_range * 1.5: state = State.IDLE; return

	# Maintain distance — retreat if too close
	if dist < RETREAT_DIST:
		velocity = -to.normalized() * move_speed
	else:
		velocity = to.normalized() * (move_speed * 0.3)  # Drift slowly

	if sprite and velocity.x != 0: sprite.scale.x = sign(velocity.x)

	# Fire when in range and off cooldown
	if bolt_cd <= 0 and dist < BOLT_RANGE:
		_fire_soul_bolt()


func _fire_soul_bolt():
	bolt_cd = BOLT_CD
	if player_ref == null: return

	var path = "res://scenes/enemies/EnemyBullet.tscn"
	if not ResourceLoader.exists(path):
		print("[SoulEater] BOLT → player"); return

	var b                = load(path).instantiate()
	b.global_position    = global_position
	b.direction          = (player_ref.global_position - global_position).normalized()
	b.speed              = 140.0
	b.damage             = 8
	b.set_meta("heals_source", self)   # Bullet.gd checks this and calls _on_bolt_hit
	if b.has_node("Sprite2D"):
		b.get_node("Sprite2D").modulate = SOUL_COLOR
	get_parent().add_child(b)


func _on_bolt_hit():
	# Called by Bullet.gd when a soul bolt connects with the player
	current_health = min(current_health + BOLT_HEAL, max_health)
	print("[SoulEater] Healed ", BOLT_HEAL, " HP from bolt. Now: ", current_health)


func _update_link():
	# Find nearest other SoulEater within LINK_RANGE
	var others = get_tree().get_nodes_in_group("enemies").filter(
		func(e): return e != self and e.get("bolt_cd") != null  # crude type check
	)
	linked_partner = null
	for o in others:
		if global_position.distance_to(o.global_position) < LINK_RANGE:
			linked_partner = o
			break


func _check_drain(_delta: float):
	if player_ref == null or drain_cd > 0: return
	if global_position.distance_to(player_ref.global_position) < DRAIN_RANGE:
		drain_cd = DRAIN_CD
		if player_ref.has_method("take_damage"):
			if "last_hit_source" in player_ref:
				player_ref.last_hit_source = "Soul Drain"
			player_ref.take_damage(1)


# Soul Link: split incoming damage with partner
func take_damage(amount: int):
	if linked_partner != null and is_instance_valid(linked_partner):
		var split = max(1, amount / 2)
		super(split)
		linked_partner.take_damage_direct(split)
	else:
		super(amount)

func take_damage_direct(amount: int):
	# Bypasses link check (prevents infinite recursion)
	super(amount)
