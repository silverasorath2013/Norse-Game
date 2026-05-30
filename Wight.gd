extends "res://scripts/EnemyBase.gd"

# ============================================================
# Wight.gd  —  Shadow Sprinter  (Floor 2+)
# ============================================================
# Fast, fragile. Only 20 HP but extremely quick.
# Its gimmick: it doesn't run TOWARD the player — it runs
# to the SIDE of the player trying to flank.
#
# BEHAVIOUR:
#   FLANK   → moves to a position 90° off the player's side
#   SPRINT  → when flanked, dashes directly at the player
#   DODGE   → when a bullet is nearby, sidesteps quickly
#   DEAD    → base class handles death
#
# WHAT MAKES IT INTERESTING:
#   It's hard to hit because it rarely approaches head-on.
#   Players learn to lead their shots to catch it.
#   Its dodge is reactive — it moves sideways when a bullet
#   gets within 60px, making it feel alive.
#
# STATS:
#   HP: 20   Flank speed: 95   Sprint speed: 180   Damage: 1
# ============================================================

const STATE_FLANK  = 10
const STATE_SPRINT = 11
const STATE_DODGE  = 12

const FLANK_SPEED:    float = 96.0
const SPRINT_SPEED:   float = 185.0
const DODGE_SPEED:    float = 220.0
const DODGE_DURATION: float = 0.25

# Distance from the player we aim to reach when flanking
const FLANK_DIST:     float = 100.0
# How far off-axis the flank target is (90° = perfect side)
const FLANK_ANGLE:    float = PI * 0.5   # 90 degrees

# Sprint range: how close the wight must be to its flank
# position before it switches to sprinting AT the player
const SPRINT_TRIGGER: float = 40.0

# Bullet detection range for reactive dodge
const DODGE_DETECT_RANGE: float = 65.0

var wight_state:       int     = -1
var flank_target:      Vector2 = Vector2.ZERO
var flank_side:        float   = 1.0    # +1 = right flank, -1 = left flank
var dodge_timer:       float   = 0.0
var dodge_velocity:    Vector2 = Vector2.ZERO
var recalc_timer:      float   = 0.0   # Recalculate flank target periodically


func _ready():
	super()
	enemy_name     = "Wight"
	max_health     = 20
	current_health = max_health
	move_speed     = FLANK_SPEED
	damage         = 1
	contact_damage_cooldown = 0.7
	detection_range = 300.0
	
	# Randomise which side this Wight flanks from
	flank_side = 1.0 if randf() > 0.5 else -1.0


func _physics_process(delta: float):
	# Reactive dodge check — runs every frame regardless of state
	if wight_state != STATE_DODGE and wight_state != -1:
		if _bullet_nearby():
			_begin_dodge()
	
	match wight_state:
		STATE_FLANK:  _handle_flank(delta)
		STATE_SPRINT: _handle_sprint(delta)
		STATE_DODGE:  _handle_dodge(delta)
		_: super(delta)
	
	move_and_slide()


# ════════════════════════════════════════════════════════════
# _idle_behaviour()  —  OVERRIDE
# ════════════════════════════════════════════════════════════
func _idle_behaviour(_delta: float):
	velocity = Vector2.ZERO
	if player_ref:
		wight_state = STATE_FLANK
		_recalculate_flank_target()


# ════════════════════════════════════════════════════════════
# _recalculate_flank_target()
# Compute the world position we want to reach — 90° off the
# player's side at FLANK_DIST away.
#
# HOW IT WORKS:
#   - Get the vector from player to us
#   - Rotate it 90° (left or right depending on flank_side)
#   - Normalise and scale to FLANK_DIST
#   - Add to player's position = our target
# ════════════════════════════════════════════════════════════
func _recalculate_flank_target():
	if player_ref == null:
		return
	
	# Vector from player toward us
	var from_player = (global_position - player_ref.global_position)
	if from_player.length() < 5:
		from_player = Vector2.RIGHT   # Fallback if directly on top of player
	
	# Rotate 90° to the side
	var side_dir    = from_player.normalized().rotated(FLANK_ANGLE * flank_side)
	flank_target    = player_ref.global_position + side_dir * FLANK_DIST


# ════════════════════════════════════════════════════════════
# _handle_flank()
# Move toward the flank target. Recalculate periodically
# since the player is moving.
# ════════════════════════════════════════════════════════════
func _handle_flank(delta: float):
	if player_ref == null:
		wight_state = -1
		state = State.IDLE
		return
	
	recalc_timer -= delta
	if recalc_timer <= 0:
		_recalculate_flank_target()
		recalc_timer = 0.3   # Recalculate every 0.3 seconds
	
	var to_target = flank_target - global_position
	var dist_to_target = to_target.length()
	
	if dist_to_target < SPRINT_TRIGGER:
		# Reached flank position — sprint at the player!
		wight_state = STATE_SPRINT
		return
	
	velocity = to_target.normalized() * FLANK_SPEED
	
	if sprite and velocity.x != 0:
		sprite.scale.x = sign(velocity.x)


# ════════════════════════════════════════════════════════════
# _handle_sprint()
# Flanked — now dash directly at the player
# ════════════════════════════════════════════════════════════
func _handle_sprint(_delta: float):
	if player_ref == null:
		wight_state = STATE_FLANK
		return
	
	var to_player = player_ref.global_position - global_position
	velocity = to_player.normalized() * SPRINT_SPEED
	
	if sprite and velocity.x != 0:
		sprite.scale.x = sign(velocity.x)
	
	# If we overshoot or lose the player, return to flanking
	if to_player.length() > FLANK_DIST * 2.5:
		wight_state = STATE_FLANK
		flank_side  = -flank_side   # Flip to the other flank
		_recalculate_flank_target()


# ════════════════════════════════════════════════════════════
# _bullet_nearby()
# Scans for player bullets within DODGE_DETECT_RANGE.
# Returns true if a bullet is close enough to dodge.
# ════════════════════════════════════════════════════════════
func _bullet_nearby() -> bool:
	var bullets = get_tree().get_nodes_in_group("player_bullets")
	for bullet in bullets:
		if global_position.distance_to(bullet.global_position) < DODGE_DETECT_RANGE:
			return true
	return false


# ════════════════════════════════════════════════════════════
# _begin_dodge()
# Sidestep perpendicular to the nearest bullet's travel direction
# ════════════════════════════════════════════════════════════
func _begin_dodge():
	var bullets = get_tree().get_nodes_in_group("player_bullets")
	if bullets.is_empty(): return
	
	# Find the closest bullet
	var closest     = bullets[0]
	var closest_dist = global_position.distance_to(closest.global_position)
	for b in bullets:
		var d = global_position.distance_to(b.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = b
	
	# Get bullet's travel direction and dodge perpendicular to it
	var bullet_dir  = closest.get("direction") if closest.get("direction") else Vector2.RIGHT
	# Two perpendicular options — pick the one away from the wall/further from player
	var perp1 = bullet_dir.rotated(PI * 0.5)
	var perp2 = bullet_dir.rotated(-PI * 0.5)
	
	# Choose direction that moves further from player (not into them)
	var from_player = global_position - (player_ref.global_position if player_ref else global_position)
	dodge_velocity  = perp1 if perp1.dot(from_player) > 0 else perp2
	
	wight_state  = STATE_DODGE
	dodge_timer  = DODGE_DURATION
	
	if sprite:
		sprite.modulate = Color(0.4, 0.6, 0.9)   # Flash blue for dodge


func _handle_dodge(delta: float):
	dodge_timer -= delta
	velocity     = dodge_velocity * DODGE_SPEED
	
	if dodge_timer <= 0:
		wight_state     = STATE_FLANK if player_ref else -1
		if sprite: sprite.modulate = Color.WHITE
		_recalculate_flank_target()


# ════════════════════════════════════════════════════════════
# _chase_behaviour()  —  OVERRIDE (Wight uses flank state)
# ════════════════════════════════════════════════════════════
func _chase_behaviour(_delta: float):
	wight_state = STATE_FLANK
	_recalculate_flank_target()
