extends "res://scripts/EnemyBase.gd"

# ============================================================
# IceWolf.gd  —  Fenrir's Frozen Pack  (Floor 2)
# ============================================================
# Faster and more dangerous than the Cursed Wolf.
# Fights smarter when other wolves are present.
#
# UNIQUE MECHANICS:
#   1. PACK HOWL: If ≥2 other IceWolves are alive in the room,
#      every 8s one wolf howls — all wolves gain +20 speed
#      and +3 damage for 5 seconds. Visual: sprite turns bright
#      white, scale pulses. Audio: howl SFX.
#
#   2. FROST BITE: Contact damage applies a "Frost Bite" debuff
#      to the player. While bitten, player leaves frost trails
#      (cosmetic) and takes +1 damage from the next 3 hits
#      from any source. Stacks up to 3 times.
#
#   3. COORDINATED FLANK: IceWolves attempt to circle the player
#      from opposite sides. If two wolves detect each other
#      they automatically choose opposite flank angles.
#
# STATES:
#   STALK    → slow approach, coordinating flank angle
#   SPRINT   → fast charge at player
#   HOWL     → brief pause, buffing pack
#   LEAP     → short-range pounce (aerial, i-frames during leap)
#
# STATS:
#   HP: 40   Stalk: 55   Sprint: 170   Leap: 240   Damage: 1
# ============================================================

const STATE_STALK  = 10
const STATE_SPRINT = 11
const STATE_HOWL   = 12
const STATE_LEAP   = 13

const STALK_SPEED:    float = 55.0
const SPRINT_SPEED:   float = 170.0
const LEAP_SPEED:     float = 240.0
const LEAP_DURATION:  float = 0.30
const LEAP_RANGE:     float = 110.0   # Must be within this to leap
const SPRINT_TRIGGER: float = 60.0    # Distance to flank pos before sprinting
const HOWL_COOLDOWN:  float = 8.0
const HOWL_DURATION:  float = 5.0
const BUFF_SPEED:     int   = 20
const BUFF_DAMAGE:    int   = 3

var wolf_state:       int     = -1
var flank_angle:      float   = 0.0   # Our assigned flank angle
var flank_target:     Vector2 = Vector2.ZERO
var sprint_direction: Vector2 = Vector2.ZERO
var leap_timer:       float   = 0.0
var leap_direction:   Vector2 = Vector2.ZERO
var howl_timer:       float   = HOWL_COOLDOWN * randf_range(0.3, 0.7)
var howl_active:      bool    = false
var howl_buff_timer:  float   = 0.0
var is_buffed:        bool    = false
var recalc_timer:     float   = 0.0


func _ready():
	super()
	enemy_name     = "Ice Wolf"
	max_health     = 40
	current_health = max_health
	move_speed     = STALK_SPEED
	damage         = 1
	contact_damage_cooldown = 0.85
	detection_range = 300.0
	
	# Assign a flank angle — adjusted if another wolf is nearby
	flank_angle = randf_range(0, TAU)


func _physics_process(delta: float):
	# Pack howl timer
	_tick_howl(delta)
	if is_buffed:
		howl_buff_timer -= delta
		if howl_buff_timer <= 0:
			_remove_buff()
	
	match wolf_state:
		STATE_STALK:  _handle_stalk(delta)
		STATE_SPRINT: _handle_sprint(delta)
		STATE_HOWL:   _handle_howl(delta)
		STATE_LEAP:   _handle_leap(delta)
		_:            super(delta)
	
	move_and_slide()


# ════════════════════════════════════════════════════════════
# IDLE / DETECT
# ════════════════════════════════════════════════════════════
func _idle_behaviour(_delta: float):
	velocity = Vector2.ZERO
	if player_ref:
		wolf_state = STATE_STALK
		_coordinate_flank_angle()


# ════════════════════════════════════════════════════════════
# STALK — coordinate flank, approach from angle
# ════════════════════════════════════════════════════════════
func _handle_stalk(delta: float):
	if player_ref == null:
		wolf_state = -1; state = State.IDLE; return
	
	recalc_timer -= delta
	if recalc_timer <= 0:
		recalc_timer = 0.4
		_coordinate_flank_angle()
		_recalc_flank_target()
	
	var to_target = flank_target - global_position
	
	if to_target.length() < SPRINT_TRIGGER:
		# Flanked — sprint at player
		wolf_state        = STATE_SPRINT
		sprint_direction  = (player_ref.global_position - global_position).normalized()
		return
	
	velocity = to_target.normalized() * STALK_SPEED
	
	if sprite and velocity.x != 0:
		sprite.scale.x = sign(velocity.x)


func _coordinate_flank_angle():
	# Check for other IceWolves in the room
	var wolves = get_tree().get_nodes_in_group("enemies").filter(
		func(e): return e != self and e.get("wolf_state") != null
	)
	
	if wolves.is_empty():
		# Alone — use random flank side
		return
	
	# Find the closest other wolf's flank angle
	var closest_wolf  = wolves[0]
	var their_angle   = closest_wolf.get("flank_angle") if \
		closest_wolf.get("flank_angle") != null else 0.0
	
	# Take the opposite side (opposite = +PI)
	flank_angle = their_angle + PI


func _recalc_flank_target():
	if player_ref == null: return
	var flank_dist = 95.0
	flank_target = player_ref.global_position + \
		Vector2(cos(flank_angle), sin(flank_angle)) * flank_dist


# ════════════════════════════════════════════════════════════
# SPRINT — dash at player
# ════════════════════════════════════════════════════════════
func _handle_sprint(_delta: float):
	if player_ref == null:
		wolf_state = STATE_STALK; return
	
	velocity = sprint_direction * SPRINT_SPEED
	
	var dist = global_position.distance_to(player_ref.global_position)
	
	# Leap when very close
	if dist < LEAP_RANGE:
		_enter_leap()
		return
	
	# Overshot or lost player
	if dist > detection_range * 1.5:
		wolf_state = STATE_STALK


# ════════════════════════════════════════════════════════════
# LEAP — short aerial pounce
# ════════════════════════════════════════════════════════════
func _enter_leap():
	wolf_state      = STATE_LEAP
	leap_timer      = LEAP_DURATION
	if player_ref:
		leap_direction = (player_ref.global_position - global_position).normalized()
	
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(0.75, 1.5), 0.08)
		tween.tween_property(sprite, "modulate", Color(0.75, 0.9, 1.0), 0.08)


func _handle_leap(delta: float):
	leap_timer -= delta
	velocity    = leap_direction * LEAP_SPEED
	
	if leap_timer <= 0 or get_slide_collision_count() > 0:
		wolf_state = STATE_STALK
		if sprite:
			var tween = create_tween()
			tween.tween_property(sprite, "scale",    Vector2(1.0, 1.0), 0.15)
			tween.tween_property(sprite, "modulate", Color(0.7, 0.85, 1.0), 0.15)


# ════════════════════════════════════════════════════════════
# PACK HOWL
# ════════════════════════════════════════════════════════════
func _tick_howl(delta: float):
	if howl_active: return
	howl_timer -= delta
	if howl_timer > 0: return
	
	# Only howl if 2+ other wolves alive
	var other_wolves = get_tree().get_nodes_in_group("enemies").filter(
		func(e): return e != self and e.get("wolf_state") != null
	)
	if other_wolves.size() < 2:
		howl_timer = HOWL_COOLDOWN
		return
	
	_start_howl()


func _start_howl():
	howl_active = true
	wolf_state  = STATE_HOWL
	velocity    = Vector2.ZERO
	
	print("[IceWolf] PACK HOWL!")
	
	# Buff all wolves in room
	var wolves = get_tree().get_nodes_in_group("enemies").filter(
		func(e): return e.get("wolf_state") != null
	)
	for w in wolves:
		if w.has_method("_apply_buff"):
			w._apply_buff()


func _handle_howl(delta: float):
	velocity = Vector2.ZERO
	# Flash white
	if sprite:
		sprite.modulate = Color(1.0, 1.0, 1.0, 0.7 + sin(delta * 20.0) * 0.3)
	
	if not howl_active:
		wolf_state = STATE_STALK
		if sprite: sprite.modulate = Color(0.7, 0.85, 1.0)


func _apply_buff():
	if is_buffed: return
	is_buffed       = true
	howl_buff_timer = HOWL_DURATION
	move_speed     += BUFF_SPEED
	damage         += BUFF_DAMAGE
	if sprite: sprite.modulate = Color(0.9, 0.95, 1.0)
	
	# End the howl state after 0.6s
	await get_tree().create_timer(0.6).timeout
	howl_active = false
	howl_timer  = HOWL_COOLDOWN


func _remove_buff():
	is_buffed   = false
	move_speed  = max(STALK_SPEED, move_speed - BUFF_SPEED)
	damage      = max(1, damage - BUFF_DAMAGE)
	if sprite: sprite.modulate = Color(0.7, 0.85, 1.0)


# ════════════════════════════════════════════════════════════
# FROST BITE contact damage override
# ════════════════════════════════════════════════════════════
func _deal_contact(amount: int):
	if player_ref == null or contact_damage_timer > 0: return
	
	# Apply Frost Bite debuff
	var stacks = player_ref.get_meta("frost_bite_stacks", 0)
	if stacks < 3:
		player_ref.set_meta("frost_bite_stacks", stacks + 1)
		print("[IceWolf] Frost Bite applied! Stacks: ", stacks + 1)
	
	if player_ref.has_method("take_damage"):
		var extra = player_ref.get_meta("curse_extra_damage", 0)
		if "last_hit_source" in player_ref:
			player_ref.last_hit_source = enemy_name
		player_ref.take_damage(amount + extra)
		contact_damage_timer = contact_damage_cooldown


# ════════════════════════════════════════════════════════════
# _chase_behaviour override
# ════════════════════════════════════════════════════════════
func _chase_behaviour(_delta: float):
	wolf_state = STATE_STALK
