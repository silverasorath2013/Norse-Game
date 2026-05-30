extends "res://scripts/EnemyBase.gd"

# ============================================================
# RuneGolem.gd  —  Divine Stone Construct  (Floor 5)
# ============================================================
# A slow, massive golem covered in protective runes.
# Three rune shields (glowing panels) must be destroyed before
# the golem takes damage. Each shield has 25 HP.
# When a shield breaks: the golem RAGES briefly (+25 speed, 5s).
# When all 3 break: takes double damage permanently.
#
# ATTACKS:
#   RUNE SLAM: area-of-effect punch, slow wind-up
#   RUNE BEAM: fires a continuous laser beam for 1.5s
#   GOLEM CHARGE: slow charge that destroys all cover/rocks
#
# STATS: HP 80 (tankiest regular enemy), Speed 40
# ============================================================

const STATE_SLAM   = 10
const STATE_BEAM   = 11
const STATE_CHARGE = 12

var golem_state:    int   = -1
var state_timer:    float = 0.0
var shields_left:   int   = 3
var rage_timer:     float = 0.0
var cd_slam:        float = 5.0
var cd_beam:        float = 6.0
var cd_charge:      float = 8.0
const GOLD_COLOR = Color(1.0, 0.85, 0.2)


func _ready():
	super()
	enemy_name     = "Rune Golem"
	max_health     = 80
	current_health = max_health
	move_speed     = 40.0
	damage         = 2
	contact_damage_cooldown = 1.2
	detection_range = 280.0
	if sprite: sprite.modulate = Color(0.85, 0.75, 0.35)


func _physics_process(delta: float):
	if cd_slam  > 0: cd_slam  -= delta
	if cd_beam  > 0: cd_beam  -= delta
	if cd_charge > 0: cd_charge -= delta
	if rage_timer > 0:
		rage_timer -= delta
		if rage_timer <= 0: move_speed = 40.0

	match golem_state:
		STATE_SLAM:   _do_slam(delta)
		STATE_BEAM:   _do_beam(delta)
		STATE_CHARGE: _do_charge(delta)
		_:            super(delta)
	move_and_slide()


func _idle_behaviour(_d: float):
	velocity = Vector2.ZERO
	if player_ref: state = State.CHASE


func _chase_behaviour(_d: float):
	if player_ref == null: state = State.IDLE; return
	var to = player_ref.global_position - global_position
	if to.length() > 400: state = State.IDLE; return
	velocity = to.normalized() * move_speed
	if cd_slam   <= 0 and to.length() < 90:  golem_state = STATE_SLAM;   state_timer = 1.2
	elif cd_beam <= 0:                         golem_state = STATE_BEAM;   state_timer = 2.0
	elif cd_charge <= 0:                       golem_state = STATE_CHARGE; state_timer = 0.6


func _do_slam(delta: float):
	state_timer -= delta; velocity = Vector2.ZERO
	if state_timer <= 0:
		cd_slam = 5.5
		if player_ref and global_position.distance_to(player_ref.global_position) < 95:
			if "last_hit_source" in player_ref: player_ref.last_hit_source = "Golem Slam"
			player_ref.take_damage(3)
		# AoE lava/void ring
		for i in range(8):
			var a = (TAU/8.0)*i
			_fire(Vector2(cos(a),sin(a)), 130.0, 10)
		golem_state = -1; state = State.CHASE; state_timer = 0.4


func _do_beam(delta: float):
	state_timer -= delta; velocity = Vector2.ZERO
	# Fire repeatedly while beam is active
	if int(state_timer * 10) % 3 == 0 and player_ref:
		var base = (player_ref.global_position - global_position).normalized()
		_fire(base, 230.0, 6)
	if state_timer <= 0:
		cd_beam = 7.0; golem_state = -1; state = State.CHASE; state_timer = 0.4


func _do_charge(delta: float):
	state_timer -= delta
	if state_timer > 0.3:
		velocity = Vector2.ZERO
	else:
		if player_ref:
			velocity = (player_ref.global_position - global_position).normalized() * 200.0
	if state_timer <= 0 or get_slide_collision_count() > 0:
		cd_charge = 9.0; golem_state = -1; state = State.CHASE; state_timer = 0.4


# Shields must be broken first
func take_damage(amount: int):
	if shields_left > 0:
		# Damage a shield instead
		shields_left -= 1
		print("[RuneGolem] Shield broken! Remaining: ", shields_left)
		_rage_burst()
		return
	var actual = amount * 2 if shields_left == 0 else amount
	super(actual)

func _rage_burst():
	move_speed = 65.0; rage_timer = 5.0
	if sprite:
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color(2.0, 1.0, 0.3), 0.1)
		tw.tween_property(sprite, "modulate", Color(0.85, 0.75, 0.35), 0.5)
	for i in range(6):
		var a = (TAU/6.0)*i
		_fire(Vector2(cos(a),sin(a)), 160.0, 8)

func _fire(dir: Vector2, spd: float, dmg: int):
	var path = "res://scenes/enemies/EnemyBullet.tscn"
	if not ResourceLoader.exists(path): return
	var b = load(path).instantiate()
	b.global_position = global_position
	b.direction=dir; b.speed=spd; b.damage=dmg
	if b.has_node("Sprite2D"):
		b.get_node("Sprite2D").modulate=GOLD_COLOR
	get_parent().add_child(b)
