extends "res://scripts/EnemyBase.gd"

# ============================================================
# LavaStalker.gd  —  Subterranean Fire Predator  (Floor 3)
# ============================================================
# MECHANICS:
#   LAVA DIVE: submerges into any lava patch in the room,
#     travels underground (immune), resurfaces under the player
#   FIRE SPIT: ranged 3-shot spread from distance
#   LAVA TRAIL: leaves a lava patch every 1.2s while moving
#   HEAT SHIELD: takes -3 damage from all hits (min 1)
#
# STATES: STALK → SPIT → DIVING → SUBMERGED → RESURFACE
# STATS: HP 45, Speed 58, Damage 1, Fire resistance
# ============================================================

const STATE_SPIT      = 10
const STATE_DIVING    = 11
const STATE_SUBMERGED = 12
const STATE_RESURFACE = 13

const SPIT_RANGE:    float = 200.0
const SPIT_CD:       float = 4.5
const DIVE_CD:       float = 8.0
const SUBMERGE_TIME: float = 1.2
const HEAT_RESIST:   int   = 3

var stalker_state:  int     = -1
var spit_cd:        float   = SPIT_CD * 0.5
var dive_cd:        float   = DIVE_CD
var state_timer:    float   = 0.0
var submerge_target:Vector2 = Vector2.ZERO
var trail_timer:    float   = 1.2
const FIRE_COLOR = Color(1.0, 0.45, 0.05)
const LAVA_PATCH_SCENE = "res://scenes/floor3/LavaPatch.tscn"


func _ready():
	super()
	enemy_name   = "Lava Stalker"
	max_health   = 45
	current_health = max_health
	move_speed   = 58.0
	damage       = 1
	contact_damage_cooldown = 0.9
	detection_range = 300.0
	if sprite: sprite.modulate = Color(0.9, 0.35, 0.05)


func _physics_process(delta: float):
	if spit_cd  > 0: spit_cd  -= delta
	if dive_cd  > 0: dive_cd  -= delta
	trail_timer -= delta
	if trail_timer <= 0:
		trail_timer = 1.2
		if velocity.length() > 5: _spawn_lava(global_position)

	match stalker_state:
		STATE_SPIT:      _do_spit(delta)
		STATE_DIVING:    _do_diving(delta)
		STATE_SUBMERGED: _do_submerged(delta)
		STATE_RESURFACE: _do_resurface(delta)
		_:               super(delta)
	move_and_slide()


func _chase_behaviour(_delta: float):
	if player_ref == null: state = State.IDLE; return
	var to = player_ref.global_position - global_position
	if to.length() > detection_range * 1.4: state = State.IDLE; return
	velocity = to.normalized() * move_speed
	if sprite and velocity.x != 0: sprite.scale.x = sign(velocity.x)
	if spit_cd <= 0 and to.length() < SPIT_RANGE: stalker_state = STATE_SPIT
	elif dive_cd <= 0: _start_dive()


func _idle_behaviour(_delta: float):
	velocity = Vector2.ZERO
	if player_ref: state = State.CHASE


# ── SPIT ─────────────────────────────────────────────────────
func _do_spit(delta: float):
	state_timer -= delta
	velocity = Vector2.ZERO
	if state_timer <= 0:
		spit_cd     = SPIT_CD
		stalker_state = -1
		state       = State.CHASE
		return
	if state_timer <= -0.05:   # Fire mid-windup
		return
	if state_timer <= 0.3 and state_timer > 0.25 and player_ref:
		var base = (player_ref.global_position - global_position).normalized()
		for a in [-0.3, 0.0, 0.3]:
			_fire(base.rotated(a), 175.0, 11, FIRE_COLOR)
		state_timer = -0.1   # Flag fired

func _start_spit():
	stalker_state = STATE_SPIT
	state_timer   = 0.7
	velocity      = Vector2.ZERO


# ── DIVE ─────────────────────────────────────────────────────
func _start_dive():
	stalker_state = STATE_DIVING
	state_timer   = 0.4
	velocity      = Vector2.ZERO
	dive_cd       = DIVE_CD
	if player_ref: submerge_target = player_ref.global_position
	if sprite:
		var tw = create_tween()
		tw.tween_property(sprite, "scale:y", 0.0, 0.3)

func _do_diving(delta: float):
	state_timer -= delta
	velocity = Vector2.ZERO
	if state_timer <= 0: stalker_state = STATE_SUBMERGED; state_timer = SUBMERGE_TIME
	if hitbox: hitbox.set_deferred("monitorable", false)

func _do_submerged(delta: float):
	state_timer -= delta
	velocity = Vector2.ZERO
	if player_ref: submerge_target = player_ref.global_position
	if state_timer <= 0:
		global_position = submerge_target
		stalker_state   = STATE_RESURFACE
		state_timer     = 0.35

func _do_resurface(delta: float):
	state_timer -= delta
	velocity = Vector2.ZERO
	if sprite:
		sprite.scale.y = lerpf(sprite.scale.y, 1.0, 0.3)
	if state_timer <= 0:
		if hitbox: hitbox.set_deferred("monitorable", true)
		# Burst on resurface
		for i in range(6):
			var a = (TAU/6.0)*i
			_fire(Vector2(cos(a), sin(a)), 140.0, 10, FIRE_COLOR)
		_spawn_lava(global_position)
		stalker_state = -1; state = State.CHASE
		if sprite:
			var tw = create_tween()
			tw.tween_property(sprite, "scale:y", 1.0, 0.15)


# ── DAMAGE OVERRIDE (heat shield) ────────────────────────────
func take_damage(amount: int):
	super(max(1, amount - HEAT_RESIST))


func _fire(dir: Vector2, spd: float, dmg: int, col: Color):
	var path = "res://scenes/enemies/EnemyBullet.tscn"
	if not ResourceLoader.exists(path): return
	var b = load(path).instantiate()
	b.global_position = global_position
	b.direction = dir; b.speed = spd; b.damage = dmg
	if b.has_node("Sprite2D"): b.get_node("Sprite2D").modulate = col
	get_parent().add_child(b)

func _spawn_lava(pos: Vector2):
	if ResourceLoader.exists(LAVA_PATCH_SCENE):
		var p = load(LAVA_PATCH_SCENE).instantiate()
		p.global_position = pos; get_parent().add_child(p)
