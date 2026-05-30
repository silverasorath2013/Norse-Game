extends "res://scripts/EnemyBase.gd"

# ============================================================
# NiflheimStalker.gd  —  The Mist Wraith  (Floor 2)
# ============================================================
# A ghostly figure that hides inside walls and ambushes.
# The most dangerous floor-2 enemy. Rare spawn (weight: 5).
#
# UNIQUE MECHANICS:
#   1. PHASE WALK: starts the room invisible inside a random
#      wall tile. Player can't see or target it.
#
#   2. STALK: while phased, it drifts toward the player through
#      walls. When within 60px of the player, it phases OUT
#      and attacks (surprise ambush).
#
#   3. SHADOW SLASH: on materialising, deals 2 contact damage
#      immediately (no cooldown — the ambush IS the attack).
#
#   4. TELEPORT: if the player stays away for 4s after
#      materialising, it phases back into walls and restarts.
#
#   5. FROST ECHO: leaves a brief decoy shimmer where it
#      dematerialised to confuse the player.
#
# STATES:
#   PHASED    → invisible inside wall, drifting toward player
#   EMERGING  → brief emerge animation (0.3s)
#   ATTACKING → visible, chases player for up to 5s
#   RETREATING → fading back into a wall
#
# STATS:
#   HP: 22   (fragile — if player can hit it)
#   Speed (phased): 35   Speed (attacking): 100
#   Damage: 2 (ambush hit), 1 (chase contact)
# ============================================================

enum StalkerState { PHASED, EMERGING, ATTACKING, RETREATING }

const PHASED_SPEED:    float = 35.0
const ATTACK_SPEED:    float = 100.0
const EMERGE_RANGE:    float = 60.0    # How close before emerging
const RETREAT_TIME:    float = 5.0     # Attacks for 5s before retreating
const EMERGE_DURATION: float = 0.30
const RETREAT_DURATION: float = 0.50
const AMBUSH_DAMAGE:   int   = 2

var stalker_state: StalkerState = StalkerState.PHASED
var state_timer:   float        = 0.0
var has_ambushed:  bool         = false   # Did we deal ambush damage yet?


func _ready():
	super()
	enemy_name     = "Niflheim Stalker"
	max_health     = 22
	current_health = max_health
	move_speed     = PHASED_SPEED
	damage         = 1
	contact_damage_cooldown = 1.0
	detection_range = 500.0   # Always "detects" — it's always hunting
	
	# Start phased — hide in nearest wall
	stalker_state = StalkerState.PHASED
	_enter_phased()


# ════════════════════════════════════════════════════════════
# _physics_process
# ════════════════════════════════════════════════════════════
func _physics_process(delta: float):
	state_timer -= delta
	
	match stalker_state:
		StalkerState.PHASED:     _handle_phased(delta)
		StalkerState.EMERGING:   _handle_emerging(delta)
		StalkerState.ATTACKING:  _handle_attacking(delta)
		StalkerState.RETREATING: _handle_retreating(delta)
	
	move_and_slide()
	
	if stalker_state == StalkerState.ATTACKING:
		_check_contact_damage()


# ════════════════════════════════════════════════════════════
# PHASED STATE — invisible, drifts through walls toward player
# ════════════════════════════════════════════════════════════
func _enter_phased():
	stalker_state = StalkerState.PHASED
	state_timer   = 999.0   # No timer — exits on range check
	has_ambushed  = false
	
	# Become invisible to player
	if sprite:
		sprite.visible = false
	
	# Disable hurtbox (can't be shot while phased)
	if hitbox:
		hitbox.set_deferred("monitorable", false)
		hitbox.set_deferred("monitoring",  false)
	
	# Move to a wall position near the edge
	# In production you'd raycast to find a wall; here we offset away from centre
	var room_cx = 16 * 40 / 2.0
	var room_cy = 12 * 40 / 2.0
	var to_wall  = (global_position - Vector2(room_cx, room_cy)).normalized()
	if to_wall.length() < 0.1: to_wall = Vector2.RIGHT
	global_position = Vector2(room_cx, room_cy) + to_wall * 220.0


func _handle_phased(delta: float):
	if player_ref == null:
		player_ref = _find_player()
		if player_ref == null: return
	
	# Drift toward player slowly through walls
	var to_player = player_ref.global_position - global_position
	velocity      = to_player.normalized() * PHASED_SPEED
	
	# Emerge when close enough
	if to_player.length() < EMERGE_RANGE:
		_enter_emerging()


func _find_player() -> Node:
	var players = get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() else null


# ════════════════════════════════════════════════════════════
# EMERGING STATE — materialise with ambush damage
# ════════════════════════════════════════════════════════════
func _enter_emerging():
	stalker_state = StalkerState.EMERGING
	state_timer   = EMERGE_DURATION
	velocity      = Vector2.ZERO
	
	# Re-enable visibility + hurtbox
	if sprite:
		sprite.visible  = true
		sprite.modulate = Color(0.5, 0.7, 1.0, 0.0)
		var tween = create_tween()
		tween.tween_property(sprite, "modulate",
			Color(0.5, 0.7, 1.0, 1.0), EMERGE_DURATION)
	
	if hitbox:
		hitbox.set_deferred("monitorable", true)
		hitbox.set_deferred("monitoring",  true)
	
	# Spawn frost echo at old position (decoy shimmer)
	_spawn_frost_echo()


func _handle_emerging(_delta: float):
	velocity = Vector2.ZERO
	
	if state_timer > 0: return
	
	# Deal ambush damage immediately
	if player_ref and not has_ambushed:
		has_ambushed = true
		var dist = global_position.distance_to(player_ref.global_position)
		if dist < 50 and player_ref.has_method("take_damage"):
			if "last_hit_source" in player_ref:
				player_ref.last_hit_source = enemy_name
			player_ref.take_damage(AMBUSH_DAMAGE)
	
	_enter_attacking()


func _spawn_frost_echo():
	# A brief semi-transparent decoy at the emergence point
	# Placeholder: in production spawn a GPUParticles2D or
	# a Node2D that fades out over 1.5s
	print("[NiflheimStalker] Frost echo at ", global_position)


# ════════════════════════════════════════════════════════════
# ATTACKING STATE — visible, chases player
# ════════════════════════════════════════════════════════════
func _enter_attacking():
	stalker_state = StalkerState.ATTACKING
	state_timer   = RETREAT_TIME
	
	if sprite:
		sprite.modulate = Color(0.5, 0.7, 1.0, 1.0)


func _handle_attacking(_delta: float):
	if player_ref == null:
		_enter_retreating()
		return
	
	var to_player = player_ref.global_position - global_position
	velocity = to_player.normalized() * ATTACK_SPEED
	
	if sprite and velocity.x != 0:
		sprite.scale.x = sign(velocity.x)
	
	if state_timer <= 0:
		_enter_retreating()


# ════════════════════════════════════════════════════════════
# RETREATING STATE — fade back into a wall
# ════════════════════════════════════════════════════════════
func _enter_retreating():
	stalker_state = StalkerState.RETREATING
	state_timer   = RETREAT_DURATION
	velocity      = Vector2.ZERO
	
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, RETREAT_DURATION)
	
	if hitbox:
		hitbox.set_deferred("monitorable", false)
		hitbox.set_deferred("monitoring",  false)


func _handle_retreating(_delta: float):
	velocity = Vector2.ZERO
	if state_timer <= 0:
		_enter_phased()


# ════════════════════════════════════════════════════════════
# Override take_damage — only hittable when not phased
# ════════════════════════════════════════════════════════════
func take_damage(amount: int):
	if stalker_state == StalkerState.PHASED:
		return   # Immune while phased
	super(amount)


# ════════════════════════════════════════════════════════════
# Override _chase_behaviour (unused — handled above)
# ════════════════════════════════════════════════════════════
func _chase_behaviour(_delta: float):
	pass   # Stalker uses its own state machine entirely
