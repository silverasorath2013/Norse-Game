extends "res://scripts/EnemyBase.gd"

# ============================================================
# ValkyrieGuard.gd  —  Odin's Elite Warrior  (Floor 5)
# ============================================================
# The most skilled melee enemy in the game.
#
# MECHANICS:
#   PARRY: once every 6s, reflects the next player bullet back
#     at double speed and double damage. Visual telegraph:
#     sprite glows white for 0.6s before the parry window opens.
#   SWIFT STRIKE: dashes at 240 px/s, deals 2 damage on contact.
#     Unlike other charges, the ValkyrieGuard can steer
#     mid-dash (tracks the player) — very hard to dodge.
#   DIVINE JUDGEMENT: on killing the player, teleports to
#     the room centre and stands still (she has won — eerie).
#   SPEAR THROW: at range, throws a golden spear (high damage,
#     leaves a spear_stuck prop in the floor as an obstacle).
#
# STATS: HP 45, Speed 100, Damage 2, Parry CD 6s
# ============================================================

const PARRY_CD:     float = 6.0
const DASH_CD:      float = 3.5
const THROW_CD:     float = 5.0
const THROW_RANGE:  float = 220.0
const DASH_SPEED:   float = 240.0
const DASH_DURATION:float = 0.45
const PARRY_WINDOW: float = 0.8   # Seconds the parry is active

const STATE_PARRY_READY = 10
const STATE_PARRYING    = 11
const STATE_DASH        = 12
const STATE_THROW       = 13

var v_state:      int   = -1
var state_timer:  float = 0.0
var parry_cd:     float = PARRY_CD * randf_range(0.3, 0.6)
var dash_cd:      float = DASH_CD  * randf_range(0.3, 0.6)
var throw_cd:     float = THROW_CD * randf_range(0.4, 0.7)
var parry_active: bool  = false
var dash_dir:     Vector2 = Vector2.ZERO
const GOLD_COLOR = Color(1.0, 0.88, 0.3)


func _ready():
	super()
	enemy_name     = "Valkyrie Guard"
	max_health     = 45
	current_health = max_health
	move_speed     = 100.0
	damage         = 2
	contact_damage_cooldown = 0.8
	detection_range = 320.0
	if sprite: sprite.modulate = GOLD_COLOR


func _physics_process(delta: float):
	if parry_cd > 0: parry_cd -= delta
	if dash_cd  > 0: dash_cd  -= delta
	if throw_cd > 0: throw_cd -= delta

	match v_state:
		STATE_PARRY_READY: _do_parry_ready(delta)
		STATE_PARRYING:    _do_parrying(delta)
		STATE_DASH:        _do_dash(delta)
		STATE_THROW:       _do_throw(delta)
		_:                 super(delta)
	move_and_slide()


func _idle_behaviour(_d: float):
	velocity = Vector2.ZERO
	if player_ref: state = State.CHASE


func _chase_behaviour(_d: float):
	if player_ref == null: state = State.IDLE; return
	var to   = player_ref.global_position - global_position
	var dist = to.length()
	if dist > 450: state = State.IDLE; return

	velocity = to.normalized() * move_speed
	if sprite and velocity.x != 0: sprite.scale.x = sign(velocity.x)

	# Attack selection
	if parry_cd <= 0:          _enter_parry_telegraph()
	elif throw_cd <= 0 and dist > THROW_RANGE * 0.5: _enter_throw()
	elif dash_cd  <= 0:        _enter_dash(to.normalized())


# ── PARRY TELEGRAPH ──────────────────────────────────────────
func _enter_parry_telegraph():
	v_state     = STATE_PARRY_READY
	parry_cd    = PARRY_CD
	state_timer = 0.6   # 0.6s visible telegraph before window opens
	velocity    = Vector2.ZERO
	if sprite:
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color(2.0,2.0,1.0), 0.3)

func _do_parry_ready(delta: float):
	state_timer -= delta; velocity = Vector2.ZERO
	if state_timer <= 0:
		v_state     = STATE_PARRYING
		parry_active = true
		state_timer  = PARRY_WINDOW

func _do_parrying(delta: float):
	state_timer -= delta; velocity = Vector2.ZERO
	if state_timer <= 0:
		parry_active = false
		if sprite:
			var tw = create_tween()
			tw.tween_property(sprite, "modulate", GOLD_COLOR, 0.2)
		v_state = -1; state = State.CHASE; state_timer = 0.3


# ── PARRY INTERCEPT ──────────────────────────────────────────
func _on_hurtbox_area_entered(area: Area2D):
	if not area.is_in_group("player_bullets"): return
	if parry_active:
		parry_active = false
		print("[ValkyrieGuard] PARRY!")
		# Reflect bullet back
		var dmg = area.get("damage") if area.get("damage") != null else 10
		if player_ref:
			var reflect_dir = (player_ref.global_position - global_position).normalized()
			_fire(reflect_dir, 300.0, dmg * 2)   # Double speed, double damage
		area.queue_free()   # Destroy original bullet
		if sprite:
			var tw = create_tween()
			tw.tween_property(sprite, "modulate", Color(2.0,2.0,0.5), 0.06)
			tw.tween_property(sprite, "modulate", GOLD_COLOR,          0.15)
		v_state = -1; state = State.CHASE; state_timer = 0.4
		return
	take_damage(area.get("damage") if area.get("damage") != null else 10)


# ── DASH (tracking) ──────────────────────────────────────────
func _enter_dash(dir: Vector2):
	v_state    = STATE_DASH
	dash_cd    = DASH_CD
	dash_dir   = dir
	state_timer = DASH_DURATION

func _do_dash(delta: float):
	state_timer -= delta
	# Continuously re-aim toward player (tracking dash)
	if player_ref:
		var to = (player_ref.global_position - global_position).normalized()
		dash_dir = dash_dir.lerp(to, 0.12)   # Smooth steer
	velocity = dash_dir * DASH_SPEED
	if state_timer <= 0:
		v_state = -1; state = State.CHASE; state_timer = 0.2


# ── SPEAR THROW ──────────────────────────────────────────────
func _enter_throw():
	v_state    = STATE_THROW
	throw_cd   = THROW_CD
	state_timer = 0.7

func _do_throw(delta: float):
	state_timer -= delta; velocity = Vector2.ZERO
	if state_timer <= 0.35 and state_timer > 0.3 and player_ref:
		var dir = (player_ref.global_position - global_position).normalized()
		_fire(dir, 250.0, 14)   # High damage spear
	if state_timer <= 0: v_state = -1; state = State.CHASE; state_timer = 0.3


func _fire(dir: Vector2, spd: float, dmg: int):
	var path = "res://scenes/enemies/EnemyBullet.tscn"
	if not ResourceLoader.exists(path): return
	var b = load(path).instantiate()
	b.global_position = global_position
	b.direction=dir; b.speed=spd; b.damage=dmg
	if b.has_node("Sprite2D"):
		b.get_node("Sprite2D").modulate = GOLD_COLOR
	get_parent().add_child(b)
