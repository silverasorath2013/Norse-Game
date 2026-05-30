extends "res://scripts/EnemyBase.gd"

# ============================================================
# Draugr.gd  —  Shambling Undead Warrior
# ============================================================
# The most common enemy. Floor 1 staple.
#
# BEHAVIOUR OVERVIEW:
#   IDLE    → wanders slowly in a random direction, changes
#             direction every 1–2 seconds
#   CHASE   → moves directly toward the player at medium speed
#   CHARGE  → after locking on for 1.2s, lunges at high speed
#             in a straight line (can't steer mid-charge)
#   STUNNED → brief recovery after charge hits a wall
#
# WHAT MAKES IT INTERESTING:
#   The charge is telegraphed — the Draugr stops and "winds up"
#   visually (sprite shrinks/darkens) before launching.
#   A skilled player can dodge through it (i-frames) or bait it
#   into a rock obstacle.
#
# STATS:
#   HP: 35   Speed: 60 (chase) / 220 (charge)   Damage: 1
# ============================================================

# ── DRAUGR-SPECIFIC STATES ───────────────────────────────────
# We EXTEND the base State enum with our own states.
# GDScript doesn't allow extending enums directly, so we use
# integer constants instead.
const STATE_WINDUP  = 10   # Winding up before charge
const STATE_CHARGE  = 11   # Mid-charge, locked direction
const STATE_STUNNED = 12   # Hit a wall, briefly stunned

# ── DRAUGR STATS ─────────────────────────────────────────────
const CHASE_SPEED:   float = 62.0
const CHARGE_SPEED:  float = 230.0
const WINDUP_TIME:   float = 1.1    # Seconds of telegraph before charging
const CHARGE_TIME:   float = 0.55   # How long the charge lasts
const STUN_TIME:     float = 0.7    # Stun after hitting a wall
const CHARGE_RANGE:  float = 180.0  # Must be within this range to charge
const CHARGE_COOLDOWN: float = 3.5  # Seconds between charges

# ── WANDER BEHAVIOUR VARS ────────────────────────────────────
var wander_direction:    Vector2 = Vector2.RIGHT
var wander_timer:        float   = 0.0
const WANDER_CHANGE_TIME: float  = 1.5

# ── CHARGE BEHAVIOUR VARS ────────────────────────────────────
var windup_timer:        float   = 0.0
var charge_timer:        float   = 0.0
var stun_timer:          float   = 0.0
var charge_direction:    Vector2 = Vector2.ZERO
var charge_cooldown:     float   = 0.0
var draugr_state:        int     = -1   # -1 = use base State enum


# ════════════════════════════════════════════════════════════
# _ready()
# ════════════════════════════════════════════════════════════
func _ready():
	super()   # Always call super() first — it runs EnemyBase._ready()
	
	enemy_name   = "Draugr"
	max_health   = 35
	current_health = max_health
	move_speed   = CHASE_SPEED
	damage       = 1
	contact_damage_cooldown = 0.85
	detection_range = 260.0
	attack_range    = 18.0
	
	# Give each Draugr a slightly randomised first wander direction
	# randf_range(a, b) returns a random float between a and b
	wander_direction = Vector2(randf_range(-1,1), randf_range(-1,1)).normalized()
	wander_timer     = randf_range(0.5, WANDER_CHANGE_TIME)


# ════════════════════════════════════════════════════════════
# _physics_process()
# We override this to handle our extra states (windup/charge/stun)
# BEFORE handing off to the base class.
# ════════════════════════════════════════════════════════════
func _physics_process(delta: float):
	# Handle our custom states first
	match draugr_state:
		STATE_WINDUP:
			_handle_windup(delta)
			move_and_slide()
			return   # Skip base class logic this frame
		STATE_CHARGE:
			_handle_charge(delta)
			move_and_slide()
			return
		STATE_STUNNED:
			_handle_stun(delta)
			move_and_slide()
			return
	
	# Tick charge cooldown
	if charge_cooldown > 0:
		charge_cooldown -= delta
	
	# All other states → base class handles them
	super(delta)


# ════════════════════════════════════════════════════════════
# _idle_behaviour()  —  OVERRIDE
# The Draugr wanders randomly when it can't see the player
# ════════════════════════════════════════════════════════════
func _idle_behaviour(delta: float):
	wander_timer -= delta
	
	if wander_timer <= 0:
		# Pick a new random direction and reset timer
		var angle          = randf_range(0, TAU)   # TAU = full circle in radians
		wander_direction   = Vector2(cos(angle), sin(angle))
		wander_timer       = randf_range(0.8, WANDER_CHANGE_TIME)
	
	velocity = wander_direction * (move_speed * 0.4)   # Slow wander
	
	# Flip sprite
	if sprite and velocity.x != 0:
		sprite.scale.x = sign(velocity.x)
	
	# Transition to chase if player detected
	if player_ref:
		state = State.CHASE


# ════════════════════════════════════════════════════════════
# _chase_behaviour()  —  OVERRIDE
# Moves toward the player. When close enough and off cooldown,
# begins the charge windup.
# ════════════════════════════════════════════════════════════
func _chase_behaviour(_delta: float):
	if player_ref == null:
		state = State.IDLE
		return
	
	var to_player = player_ref.global_position - global_position
	var dist      = to_player.length()
	
	if dist > detection_range * 1.4:
		state    = State.IDLE
		velocity = Vector2.ZERO
		return
	
	velocity = to_player.normalized() * CHASE_SPEED
	
	if sprite and velocity.x != 0:
		sprite.scale.x = sign(velocity.x)
	
	# Begin windup if in charge range and cooldown is ready
	if dist <= CHARGE_RANGE and charge_cooldown <= 0:
		_begin_windup()


# ════════════════════════════════════════════════════════════
# _begin_windup()
# Stops movement and starts the charge telegraph.
# The sprite shrinks slightly to look like it's coiling back.
# ════════════════════════════════════════════════════════════
func _begin_windup():
	draugr_state = STATE_WINDUP
	windup_timer = WINDUP_TIME
	velocity     = Vector2.ZERO
	
	# Lock in the charge direction NOW — we aim at the player's
	# current position, not where they'll be.
	# This is fair: if the player moves during the windup, they can dodge.
	if player_ref:
		charge_direction = (player_ref.global_position - global_position).normalized()
	
	# Visual telegraph: shrink the sprite and tint dark
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(0.7, 0.7), WINDUP_TIME * 0.6)
		tween.tween_property(sprite, "modulate", Color(0.3, 0.3, 0.4), WINDUP_TIME * 0.6)


# ════════════════════════════════════════════════════════════
# _handle_windup()  —  called every frame during windup
# ════════════════════════════════════════════════════════════
func _handle_windup(delta: float):
	windup_timer -= delta
	velocity      = Vector2.ZERO
	
	if windup_timer <= 0:
		_begin_charge()


# ════════════════════════════════════════════════════════════
# _begin_charge()
# Launches the Draugr at high speed in the locked direction.
# Sprite scales up ("lunges forward") and turns bright.
# ════════════════════════════════════════════════════════════
func _begin_charge():
	draugr_state = STATE_CHARGE
	charge_timer = CHARGE_TIME
	velocity     = charge_direction * CHARGE_SPEED
	
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "scale",    Vector2(1.3, 0.8), 0.08)  # Squash & stretch
		tween.tween_property(sprite, "modulate", Color(0.8, 0.3, 0.3), 0.08)


# ════════════════════════════════════════════════════════════
# _handle_charge()  —  called every frame during charge
# The Draugr can't steer. If it hits a wall, it gets stunned.
# ════════════════════════════════════════════════════════════
func _handle_charge(delta: float):
	charge_timer -= delta
	velocity      = charge_direction * CHARGE_SPEED
	
	# Check if we just hit a wall (move_and_slide sets this)
	# get_slide_collision_count() returns how many collisions happened
	if get_slide_collision_count() > 0:
		_begin_stun()
		return
	
	if charge_timer <= 0:
		# Charge finished without hitting anything — return to chase
		_end_charge()


# ════════════════════════════════════════════════════════════
# _begin_stun()  —  charge hit a wall
# ════════════════════════════════════════════════════════════
func _begin_stun():
	draugr_state = STATE_STUNNED
	stun_timer   = STUN_TIME
	velocity     = Vector2.ZERO
	charge_cooldown = CHARGE_COOLDOWN
	
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "scale",    Vector2(1.0, 1.0), 0.2)
		tween.tween_property(sprite, "modulate", Color.WHITE,       0.2)
		# Shake in place: nudge position left and right
		tween.tween_property(sprite, "position:x",  4.0, 0.06)
		tween.tween_property(sprite, "position:x", -4.0, 0.06)
		tween.tween_property(sprite, "position:x",  0.0, 0.06)


func _handle_stun(delta: float):
	stun_timer -= delta
	velocity    = Vector2.ZERO
	if stun_timer <= 0:
		_end_charge()


func _end_charge():
	draugr_state = -1   # Return to base state machine
	charge_cooldown = CHARGE_COOLDOWN
	state = State.CHASE if player_ref else State.IDLE
	
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "scale",    Vector2(1.0, 1.0), 0.15)
		tween.tween_property(sprite, "modulate", Color.WHITE,       0.15)


# ════════════════════════════════════════════════════════════
# take_damage()  —  OVERRIDE
# A charging Draugr takes DOUBLE damage — it's vulnerable
# mid-charge (reward for timing a counter-shot)
# ════════════════════════════════════════════════════════════
func take_damage(amount: int):
	var actual = amount * 2 if draugr_state == STATE_CHARGE else amount
	super(actual)
	
	# Getting hit interrupts a charge
	if draugr_state == STATE_CHARGE:
		_begin_stun()
