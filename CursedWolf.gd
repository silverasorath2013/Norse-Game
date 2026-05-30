extends "res://scripts/EnemyBase.gd"

# ============================================================
# CursedWolf.gd  —  Fenrir's Cursed Pack  (Floor 1+)
# ============================================================
# Mid-tier threat. Slow and predictable until it locks on,
# then FAST. Has two mechanics the player must respect:
#
# 1. LOCK-ON LUNGE: When the player stands still for 0.6s
#    within range, the wolf locks on and dashes hard.
#    The wolf visually lowers its head (sprite tilt) to telegraph.
#
# 2. DEATH SPLIT: When killed, 50% chance to split into
#    two Wolf Pups (weaker, smaller, same AI).
#    This creates a "do I shoot it?" risk/reward moment.
#
# STATES:
#   PROWL   → slow, weaving approach. Non-threatening.
#   LOCK_ON → player stood still, wolf is timing its lunge
#   LUNGE   → full-speed dash at lock-on position
#   HOWL    → area-of-effect intimidation (stops nearby enemies
#             dealing contact damage briefly — placeholder)
#
# STATS:
#   HP: 45   Prowl speed: 45   Lunge speed: 200   Damage: 1
# ============================================================

const STATE_PROWL   = 10
const STATE_LOCK_ON = 11
const STATE_LUNGE   = 12

const PROWL_SPEED:      float = 46.0
const LUNGE_SPEED:      float = 205.0
const LOCK_ON_TIME:     float = 0.6    # How long player must be still
const LUNGE_TIME:       float = 0.4
const LOCK_ON_RANGE:    float = 200.0
const LUNGE_COOLDOWN:   float = 2.8
const STILL_THRESHOLD:  float = 18.0  # Player velocity below this = "standing still"

# Weave pattern — the wolf doesn't run straight
const WEAVE_FREQUENCY:  float = 2.5   # How fast it weaves (oscillation speed)
const WEAVE_AMPLITUDE:  float = 40.0  # How far it weaves side to side

var wolf_state:        int     = -1
var lock_on_timer:     float   = 0.0
var lunge_timer:       float   = 0.0
var lunge_direction:   Vector2 = Vector2.ZERO
var lunge_cooldown:    float   = 0.0
var weave_time:        float   = 0.0   # Accumulates for sin() weave calculation
var is_pup:            bool    = false  # True if this was spawned from a death split


func _ready():
	super()
	enemy_name     = "Cursed Wolf"
	max_health     = 45
	current_health = max_health
	move_speed     = PROWL_SPEED
	damage         = 1
	contact_damage_cooldown = 0.9
	detection_range = 290.0
	
	if is_pup:
		# Wolf pups are weaker and smaller
		max_health    = 15
		current_health = max_health
		enemy_name    = "Wolf Pup"
		if sprite:
			sprite.scale = Vector2(0.6, 0.6)


func _physics_process(delta: float):
	if lunge_cooldown > 0:
		lunge_cooldown -= delta
	
	match wolf_state:
		STATE_PROWL:   _handle_prowl(delta)
		STATE_LOCK_ON: _handle_lock_on(delta)
		STATE_LUNGE:   _handle_lunge(delta)
		_:             super(delta)
	
	move_and_slide()


# ════════════════════════════════════════════════════════════
# _idle_behaviour()  —  OVERRIDE
# ════════════════════════════════════════════════════════════
func _idle_behaviour(_delta: float):
	velocity = Vector2.ZERO
	if player_ref:
		wolf_state = STATE_PROWL
		weave_time = randf_range(0, TAU)   # Randomise weave phase


# ════════════════════════════════════════════════════════════
# _handle_prowl()
# Slow, weaving approach. The wolf oscillates side-to-side
# as it walks toward the player, making it harder to hit.
#
# WEAVE MATHS:
#   - "forward" = direction toward player
#   - "sideways" = perpendicular (rotate 90°)
#   - velocity = forward * prowl_speed + sideways * sin(time) * amplitude
# ════════════════════════════════════════════════════════════
func _handle_prowl(delta: float):
	if player_ref == null:
		wolf_state = -1
		state = State.IDLE
		return
	
	weave_time += delta * WEAVE_FREQUENCY
	
	var to_player = player_ref.global_position - global_position
	var dist      = to_player.length()
	
	if dist > detection_range * 1.5:
		wolf_state = -1
		state = State.IDLE
		velocity = Vector2.ZERO
		return
	
	var forward   = to_player.normalized()
	var sideways  = forward.rotated(PI * 0.5)
	var weave     = sin(weave_time) * WEAVE_AMPLITUDE
	
	velocity = forward * PROWL_SPEED + sideways * weave
	
	if sprite and velocity.x != 0:
		sprite.scale.x = sign(velocity.x) * (0.6 if is_pup else 1.0)
	
	# Check if we should enter lock-on
	if dist <= LOCK_ON_RANGE and lunge_cooldown <= 0:
		# Is the player standing still?
		var player_vel = player_ref.get("velocity") if player_ref.get("velocity") != null else Vector2.ZERO
		if player_vel.length() < STILL_THRESHOLD:
			wolf_state    = STATE_LOCK_ON
			lock_on_timer = LOCK_ON_TIME
			_telegraph_lock_on()


# ════════════════════════════════════════════════════════════
# _telegraph_lock_on()
# Visual: the wolf crouches low (sprite squashes down)
# and the head tilts forward — player has 0.6s to move
# ════════════════════════════════════════════════════════════
func _telegraph_lock_on():
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "scale",
			Vector2(1.3 if not is_pup else 0.78, 0.65 if not is_pup else 0.39),
			LOCK_ON_TIME * 0.8)
		tween.tween_property(sprite, "modulate",
			Color(0.8, 0.3, 0.15), LOCK_ON_TIME * 0.8)


func _handle_lock_on(delta: float):
	velocity       = Vector2.ZERO
	lock_on_timer -= delta
	
	# If player MOVES during the lock-on window, abort and return to prowl
	if player_ref:
		var player_vel = player_ref.get("velocity") if player_ref.get("velocity") != null else Vector2.ZERO
		if player_vel.length() >= STILL_THRESHOLD:
			wolf_state = STATE_PROWL
			if sprite:
				var tween = create_tween()
				tween.tween_property(sprite, "scale",    Vector2(1.0 if not is_pup else 0.6, 1.0 if not is_pup else 0.6), 0.15)
				tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
			return
	
	if lock_on_timer <= 0:
		_begin_lunge()


# ════════════════════════════════════════════════════════════
# _begin_lunge()
# Lock in the target position and launch
# ════════════════════════════════════════════════════════════
func _begin_lunge():
	wolf_state      = STATE_LUNGE
	lunge_timer     = LUNGE_TIME
	
	if player_ref:
		lunge_direction = (player_ref.global_position - global_position).normalized()
	
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "scale",
			Vector2(0.7 if not is_pup else 0.42, 1.4 if not is_pup else 0.84), 0.06)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.08)


func _handle_lunge(delta: float):
	lunge_timer -= delta
	velocity     = lunge_direction * LUNGE_SPEED
	
	if lunge_timer <= 0 or get_slide_collision_count() > 0:
		wolf_state     = STATE_PROWL
		lunge_cooldown = LUNGE_COOLDOWN
		if sprite:
			var tween = create_tween()
			tween.tween_property(sprite, "scale",
				Vector2(1.0 if not is_pup else 0.6, 1.0 if not is_pup else 0.6), 0.2)


# ════════════════════════════════════════════════════════════
# _die()  —  OVERRIDE
# 50% chance to split into two Wolf Pups on death.
# Pups are just CursedWolf with is_pup = true.
# ════════════════════════════════════════════════════════════
func _die():
	# Pups don't split again (prevent infinite recursion)
	if not is_pup and randf() < 0.5:
		_spawn_pups()
	
	super()   # Run the normal death fade/removal

func _spawn_pups():
	print("[CursedWolf] Death split — spawning 2 Wolf Pups!")
	
	for i in range(2):
		if ResourceLoader.exists("res://scenes/enemies/CursedWolf.tscn"):
			var pup      = load("res://scenes/enemies/CursedWolf.tscn").instantiate()
			pup.is_pup   = true
			# Offset spawn positions slightly so they don't stack exactly
			var offset   = Vector2(randf_range(-20, 20), randf_range(-20, 20))
			pup.global_position = global_position + offset
			pup.add_to_group("enemies")
			get_parent().add_child(pup)
		else:
			# Placeholder until scene is made
			print("[CursedWolf] Pup ", i+1, " spawned at ", global_position)


# ════════════════════════════════════════════════════════════
# _chase_behaviour()  —  OVERRIDE (uses prowl state)
# ════════════════════════════════════════════════════════════
func _chase_behaviour(_delta: float):
	wolf_state = STATE_PROWL
