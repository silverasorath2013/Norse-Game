extends "res://scripts/EnemyBase.gd"

# ============================================================
# CinderWolf.gd  —  Blazing Pack Runner  (Floor 3)
# ============================================================
# MECHANICS:
#   FIRE DASH: lunges at 260 px/s, entire body leaves a fire
#     trail of 4 lava patches along the dash path
#   SCORCH AURA: permanently marks nearby floor (spawns lava
#     patch under the wolf every 2s)
#   SPLIT ON DEATH: 50% chance to split into 2 Ember Pups
#     (same as CursedWolf but fire-themed, smaller, 15 HP)
#
# STATS: HP 38, Speed 80 (fastest floor-3 enemy), Damage 1
# ============================================================

const DASH_SPEED:    float = 260.0
const DASH_DURATION: float = 0.35
const DASH_CD:       float = 3.5
const SCORCH_CD:     float = 2.0
const CHARGE_RANGE:  float = 160.0

const STATE_WINDUP = 10
const STATE_DASH   = 11

var cinder_state:  int     = -1
var dash_cd:       float   = DASH_CD * randf_range(0.3, 0.6)
var scorch_timer:  float   = SCORCH_CD
var state_timer:   float   = 0.0
var dash_dir:      Vector2 = Vector2.ZERO
var is_pup:        bool    = false
const LAVA_PATH = "res://scenes/floor3/LavaPatch.tscn"
const FIRE_COLOR = Color(1.0, 0.45, 0.05)


func _ready():
	super()
	enemy_name   = "Cinder Wolf"
	max_health   = 38 if not is_pup else 16
	current_health = max_health
	move_speed   = 80.0 if not is_pup else 95.0
	damage       = 1
	contact_damage_cooldown = 0.75
	detection_range = 280.0
	if sprite:
		sprite.modulate = FIRE_COLOR
		if is_pup: sprite.scale *= 0.65


func _physics_process(delta: float):
	if dash_cd   > 0: dash_cd   -= delta
	if scorch_timer > 0: scorch_timer -= delta
	elif not is_pup:
		scorch_timer = SCORCH_CD
		_spawn_lava(global_position)

	match cinder_state:
		STATE_WINDUP: _do_windup(delta)
		STATE_DASH:   _do_dash(delta)
		_:            super(delta)
	move_and_slide()


func _chase_behaviour(_delta: float):
	if player_ref == null: state = State.IDLE; return
	var to = player_ref.global_position - global_position
	if to.length() > detection_range * 1.4: state = State.IDLE; return
	velocity = to.normalized() * move_speed
	if sprite and velocity.x != 0: sprite.scale.x = sign(velocity.x)
	if dash_cd <= 0 and to.length() < CHARGE_RANGE:
		_enter_windup(to.normalized())


func _idle_behaviour(_delta: float):
	velocity = Vector2.ZERO
	if player_ref: state = State.CHASE


func _enter_windup(dir: Vector2):
	cinder_state = STATE_WINDUP
	dash_cd      = DASH_CD
	dash_dir     = dir
	state_timer  = 0.4
	velocity     = Vector2.ZERO
	if sprite:
		var tw = create_tween()
		tw.tween_property(sprite, "scale",    Vector2(0.7, 1.4), 0.25)
		tw.tween_property(sprite, "modulate", Color(1.0, 0.7, 0.1), 0.25)

func _do_windup(delta: float):
	state_timer -= delta; velocity = Vector2.ZERO
	if state_timer <= 0: cinder_state = STATE_DASH; state_timer = DASH_DURATION

func _do_dash(delta: float):
	state_timer -= delta
	velocity = dash_dir * DASH_SPEED
	# Spawn lava trail every 0.08s during dash
	if int(state_timer * 12.5) % 1 == 0:
		_spawn_lava(global_position)
	if state_timer <= 0 or get_slide_collision_count() > 0:
		cinder_state = -1; state = State.CHASE
		if sprite:
			var tw = create_tween()
			tw.tween_property(sprite, "scale",    Vector2(1.0, 1.0), 0.15)
			tw.tween_property(sprite, "modulate", FIRE_COLOR, 0.15)


func _die():
	if not is_pup and randf() < 0.5:
		for i in range(2):
			if ResourceLoader.exists("res://scenes/enemies/CinderWolf.tscn"):
				var pup = load("res://scenes/enemies/CinderWolf.tscn").instantiate()
				pup.is_pup = true
				pup.global_position = global_position + Vector2(randf_range(-18,18), randf_range(-18,18))
				pup.add_to_group("enemies")
				get_parent().add_child(pup)
	# Ember burst
	for i in range(6):
		var a = (TAU/6.0)*i
		var path = "res://scenes/enemies/EnemyBullet.tscn"
		if not ResourceLoader.exists(path): break
		var b = load(path).instantiate()
		b.global_position = global_position
		b.direction = Vector2(cos(a), sin(a)); b.speed = 140.0; b.damage = 7
		if b.has_node("Sprite2D"): b.get_node("Sprite2D").modulate = FIRE_COLOR
		get_parent().add_child(b)
	super()

func _spawn_lava(pos: Vector2):
	if ResourceLoader.exists(LAVA_PATH):
		var p = load(LAVA_PATH).instantiate()
		p.global_position = pos; get_parent().add_child(p)
