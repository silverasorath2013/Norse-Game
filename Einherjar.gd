extends "res://scripts/EnemyBase.gd"

# ============================================================
# Einherjar.gd  —  Ghost Warrior of Valhalla  (Ranged)
# ============================================================
# Appears from Floor 1. More dangerous than Draugr because it
# keeps its distance and shoots back at the player.
#
# BEHAVIOUR:
#   IDLE    → floats gently in place
#   STRAFE  → circles the player at medium range, keeping distance
#   SHOOT   → stops strafing briefly, fires a projectile, resumes
#   RETREAT → if player gets too close, backs away quickly
#
# WHAT MAKES IT INTERESTING:
#   It never charges at you — it circles and pokes from range.
#   You have to close the gap while dodging its shots.
#   It fires faster on higher floors (fire_rate scales up).
#
# STATS (Floor 1 base):
#   HP: 25   Strafe speed: 50   Projectile dmg: 8   Fire rate: 2.5s
# ============================================================

# ── EINHERJAR STATES ─────────────────────────────────────────
const STATE_STRAFE  = 10
const STATE_SHOOT   = 11
const STATE_RETREAT = 12

# ── POSITIONING CONSTANTS ────────────────────────────────────
const IDEAL_RANGE:     float = 180.0   # Target distance from player
const RETREAT_RANGE:   float = 90.0    # If player gets this close, retreat
const STRAFE_SPEED:    float = 52.0
const RETREAT_SPEED:   float = 100.0

# ── SHOOTING ─────────────────────────────────────────────────
const SHOOT_WINDUP:    float = 0.35   # Brief pause before firing
const BASE_FIRE_RATE:  float = 2.5    # Seconds between shots (floor 1)
const PROJECTILE_DMG:  int   = 8
const PROJECTILE_SPD:  float = 200.0

# ── RUNTIME VARS ─────────────────────────────────────────────
var einherjar_state:   int   = -1
var fire_timer:        float = 0.0    # Counts down to next shot
var shoot_windup:      float = 0.0
var strafe_sign:       float = 1.0    # +1 = clockwise, -1 = counter-clockwise
var floor_num:         int   = 1      # Injected by Room.gd at spawn


# ════════════════════════════════════════════════════════════
# _ready()
# ════════════════════════════════════════════════════════════
func _ready():
	super()
	enemy_name     = "Einherjar"
	max_health     = 25
	current_health = max_health
	move_speed     = STRAFE_SPEED
	damage         = 0    # No contact damage — ranged only
	detection_range = 320.0
	
	# Randomise clockwise vs counter-clockwise strafing
	strafe_sign  = 1.0 if randf() > 0.5 else -1.0
	
	# Stagger fire timers so multiple Einherjar don't all shoot at once
	fire_timer = randf_range(0.5, BASE_FIRE_RATE)


# ════════════════════════════════════════════════════════════
# _physics_process()  —  OVERRIDE to handle extra states
# ════════════════════════════════════════════════════════════
func _physics_process(delta: float):
	match einherjar_state:
		STATE_STRAFE:
			_handle_strafe(delta)
			move_and_slide()
			return
		STATE_SHOOT:
			_handle_shoot_windup(delta)
			move_and_slide()
			return
		STATE_RETREAT:
			_handle_retreat(delta)
			move_and_slide()
			return
	super(delta)


# ════════════════════════════════════════════════════════════
# _idle_behaviour()  —  gentle float, no wander
# ════════════════════════════════════════════════════════════
func _idle_behaviour(_delta: float):
	# Slow gentle bob in place — use a sine wave on y position
	# Time.get_ticks_msec() returns milliseconds since startup
	var bob = sin(Time.get_ticks_msec() * 0.002) * 0.3
	velocity = Vector2(0, bob)
	
	if player_ref:
		einherjar_state = STATE_STRAFE
		fire_timer = BASE_FIRE_RATE * 0.5   # Shoot sooner when entering combat


# ════════════════════════════════════════════════════════════
# _handle_strafe()
# The Einherjar orbits the player at IDEAL_RANGE.
#
# HOW ORBITING WORKS:
#   1. Get the vector FROM player TO us (the "outward" vector)
#   2. Rotate that vector 90° to get a tangent (strafing direction)
#   3. Also push toward/away from ideal range
#   4. Combine these two forces into a final velocity
# ════════════════════════════════════════════════════════════
func _handle_strafe(delta: float):
	if player_ref == null:
		einherjar_state = -1
		state = State.IDLE
		return
	
	var to_player  = player_ref.global_position - global_position
	var dist       = to_player.length()
	
	# ── RETREAT if player got too close ──────────────────────
	if dist < RETREAT_RANGE:
		einherjar_state = STATE_RETREAT
		return
	
	# ── ORBIT CALCULATION ────────────────────────────────────
	# outward = direction away from player (we stay on the outside)
	var outward  = -to_player.normalized()
	
	# tangent = 90° rotation of outward = strafe direction
	# Vector2.rotated(angle) rotates the vector by that angle (radians)
	# PI/2 = 90 degrees. strafe_sign flips between CW and CCW.
	var tangent  = outward.rotated(PI * 0.5 * strafe_sign)
	
	# Range correction: push in/out to maintain ideal distance
	var range_error = dist - IDEAL_RANGE        # positive = too far, negative = too close
	var range_force = to_player.normalized() * (range_error * 0.02)
	
	velocity = (tangent * STRAFE_SPEED) + range_force
	
	# Flip sprite to face movement direction
	if sprite and velocity.x != 0:
		sprite.scale.x = sign(velocity.x)
	
	# ── FIRE TIMER ───────────────────────────────────────────
	fire_timer -= delta
	if fire_timer <= 0:
		einherjar_state = STATE_SHOOT
		shoot_windup    = SHOOT_WINDUP
		velocity        = Vector2.ZERO


# ════════════════════════════════════════════════════════════
# _handle_shoot_windup()
# Brief pause before firing — stops moving, aims at player,
# then fires a projectile.
# ════════════════════════════════════════════════════════════
func _handle_shoot_windup(delta: float):
	velocity     = Vector2.ZERO
	shoot_windup -= delta
	
	# Slowly rotate to face the player during windup (visual feedback)
	if sprite and player_ref:
		var to_player = player_ref.global_position - global_position
		sprite.scale.x = 1.0 if to_player.x > 0 else -1.0
		# Pulse the sprite slightly to telegraph the shot
		var pulse = 1.0 + sin(shoot_windup * 20.0) * 0.05
		sprite.scale.y = pulse
	
	if shoot_windup <= 0:
		_fire_at_player()


# ════════════════════════════════════════════════════════════
# _fire_at_player()
# Spawns a projectile aimed at the player's current position.
# The projectile uses Bullet.gd but is marked as an ENEMY bullet.
# ════════════════════════════════════════════════════════════
func _fire_at_player():
	if player_ref == null:
		einherjar_state = STATE_STRAFE
		return
	
	var to_player = (player_ref.global_position - global_position).normalized()
	
	if ResourceLoader.exists("res://scenes/EnemyBullet.tscn"):
		var bullet           = load("res://scenes/EnemyBullet.tscn").instantiate()
		bullet.global_position = global_position
		bullet.direction     = to_player
		bullet.speed         = PROJECTILE_SPD
		bullet.damage        = PROJECTILE_DMG
		# Scale fire rate with floor number — faster on deeper floors
		var scaled_rate      = max(1.2, BASE_FIRE_RATE - (floor_num * 0.25))
		fire_timer           = scaled_rate
		get_parent().add_child(bullet)
	else:
		print("[Einherjar] Fire! dir:", to_player, " dmg:", PROJECTILE_DMG)
		fire_timer = BASE_FIRE_RATE
	
	# Resume strafing
	einherjar_state = STATE_STRAFE
	
	if sprite:
		sprite.scale.y = 1.0   # Reset pulse scale


# ════════════════════════════════════════════════════════════
# _handle_retreat()
# Player got too close — back away quickly
# ════════════════════════════════════════════════════════════
func _handle_retreat(delta: float):
	if player_ref == null:
		einherjar_state = STATE_STRAFE
		return
	
	var away = (global_position - player_ref.global_position).normalized()
	velocity = away * RETREAT_SPEED
	
	var dist = global_position.distance_to(player_ref.global_position)
	if dist >= IDEAL_RANGE * 0.85:
		einherjar_state = STATE_STRAFE   # Back to comfortable range — resume orbit
	
	if sprite and velocity.x != 0:
		sprite.scale.x = sign(velocity.x)


# ════════════════════════════════════════════════════════════
# _chase_behaviour()  —  OVERRIDE (not used — we use STATE_STRAFE)
# ════════════════════════════════════════════════════════════
func _chase_behaviour(_delta: float):
	einherjar_state = STATE_STRAFE
