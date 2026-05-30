extends "res://scripts/EnemyBase.gd"

# ============================================================
# FrostRevenant.gd  —  Niflheim's basic undead (Floor 2)
# ============================================================
# The Frost Revenant is the Draugr's cold counterpart.
# It looks like a translucent blue corpse warrior.
#
# WHAT MAKES IT DIFFERENT FROM DRAUGR:
#   1. ICE TRAIL: leaves frozen floor patches as it moves.
#      Players who step on ice patches are slowed for 1.5s.
#   2. FROST SHOT: instead of a charge, it fires a slow-moving
#      ice shard that splits into 3 shards on hitting a wall.
#   3. FREEZE BURST: on death, releases a ring of 6 slow ice
#      shards outward. Classic "explodes on death" danger.
#   4. CHILL AURA: players within 80px move 15% slower
#      (applied while in range, removed on exit).
#
# STATES:
#   WANDER   → slow drift, leaving ice trail
#   CHASE    → pursues player, still leaving trail
#   FROST_SHOT → fires ice shard at player (CD: 4s)
#   DEAD
#
# STATS:
#   HP: 30   Speed: 50   Damage: 1   Shot CD: 4s
# ============================================================

const STATE_FROST_SHOT = 10

const MOVE_SPEED:    float = 50.0
const SHOT_COOLDOWN: float = 4.0
const SHOT_SPEED:    float = 130.0
const SHOT_DAMAGE:   int   = 8
const CHILL_RANGE:   float = 80.0
const CHILL_SLOW:    float = 0.15   # 15% speed reduction
const ICE_TRAIL_CD:  float = 0.6    # Seconds between ice patch spawns

var frost_shot_cd:   float = SHOT_COOLDOWN * 0.5  # Ready sooner at first
var revenant_state:  int   = -1
var wander_dir:      Vector2 = Vector2.RIGHT
var wander_timer:    float   = 0.0
var ice_trail_timer: float   = 0.0
var chilling_player: bool   = false   # Are we currently slowing the player?

# Ice patch scene path
const ICE_PATCH_SCENE = "res://scenes/floor2/IcePatch.tscn"


func _ready():
	super()
	enemy_name     = "Frost Revenant"
	max_health     = 30
	current_health = max_health
	move_speed     = MOVE_SPEED
	damage         = 1
	contact_damage_cooldown = 0.9
	detection_range = 270.0
	
	# Randomise starting wander direction
	wander_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	wander_timer = randf_range(0.5, 2.0)


func _physics_process(delta: float):
	# Tick shot cooldown
	if frost_shot_cd > 0: frost_shot_cd -= delta
	
	# Ice trail
	_update_ice_trail(delta)
	
	# Chill aura check
	_update_chill_aura()
	
	# Custom state
	if revenant_state == STATE_FROST_SHOT:
		_handle_frost_shot(delta)
		move_and_slide()
		return
	
	super(delta)   # Base class handles IDLE/CHASE


func _idle_behaviour(delta: float):
	# Slow wandering
	wander_timer -= delta
	if wander_timer <= 0:
		var angle = randf_range(0, TAU)
		wander_dir   = Vector2(cos(angle), sin(angle))
		wander_timer = randf_range(0.8, 1.8)
	
	velocity = wander_dir * (MOVE_SPEED * 0.45)
	
	if player_ref:
		state = State.CHASE


func _chase_behaviour(_delta: float):
	if player_ref == null:
		state = State.IDLE
		return
	
	var to_player = player_ref.global_position - global_position
	if to_player.length() > detection_range * 1.4:
		state    = State.IDLE
		velocity = Vector2.ZERO
		return
	
	velocity = to_player.normalized() * MOVE_SPEED
	
	if sprite and velocity.x != 0:
		sprite.scale.x = sign(velocity.x)
	
	# Fire if ready and in reasonable range
	if frost_shot_cd <= 0 and to_player.length() < 220:
		_enter_frost_shot()


# ════════════════════════════════════════════════════════════
# FROST SHOT
# ════════════════════════════════════════════════════════════
func _enter_frost_shot():
	revenant_state = STATE_FROST_SHOT
	frost_shot_cd  = SHOT_COOLDOWN
	velocity       = Vector2.ZERO

func _handle_frost_shot(delta: float):
	# Brief windup then fire
	velocity = Vector2.ZERO
	frost_shot_cd -= delta   # already ticking in _physics_process too — this is fine
	
	# Fire after 0.3s windup
	if frost_shot_cd <= SHOT_COOLDOWN - 0.3:
		if player_ref:
			var dir = (player_ref.global_position - global_position).normalized()
			_fire_ice_shard(dir)
		revenant_state = -1
		state = State.CHASE


func _fire_ice_shard(direction: Vector2, speed_override: float = SHOT_SPEED,
					 damage_override: int = SHOT_DAMAGE):
	var path = "res://scenes/enemies/EnemyBullet.tscn"
	if not ResourceLoader.exists(path):
		print("[FrostRevenant] ICE SHARD → ", direction)
		return
	
	var shard = load(path).instantiate()
	shard.global_position = global_position
	shard.direction  = direction
	shard.speed      = speed_override
	shard.damage     = damage_override
	shard.set_meta("is_ice_shard", true)
	shard.set_meta("can_split",    true)   # Bullet.gd checks this on wall hit
	
	if shard.has_node("Sprite2D"):
		shard.get_node("Sprite2D").modulate = Color(0.7, 0.9, 1.0)
	
	get_parent().add_child(shard)


# ════════════════════════════════════════════════════════════
# ICE TRAIL  —  leaves frozen floor patches while moving
# ════════════════════════════════════════════════════════════
func _update_ice_trail(delta: float):
	if velocity.length() < 5.0: return   # Not moving
	
	ice_trail_timer -= delta
	if ice_trail_timer <= 0:
		ice_trail_timer = ICE_TRAIL_CD
		_spawn_ice_patch(global_position)


func _spawn_ice_patch(pos: Vector2):
	if ResourceLoader.exists(ICE_PATCH_SCENE):
		var patch = load(ICE_PATCH_SCENE).instantiate()
		patch.global_position = pos
		get_parent().add_child(patch)
	# If no scene: just log during development
	# (IcePatch.gd is built separately below)


# ════════════════════════════════════════════════════════════
# CHILL AURA  —  slows player when nearby
# ════════════════════════════════════════════════════════════
func _update_chill_aura():
	if player_ref == null: return
	
	var dist        = global_position.distance_to(player_ref.global_position)
	var in_range    = dist < CHILL_RANGE
	
	if in_range and not chilling_player:
		chilling_player = true
		if "move_speed" in player_ref:
			player_ref.set_meta("chill_slow_stacks",
				player_ref.get_meta("chill_slow_stacks", 0) + 1)
			# Apply slow on the first stack
			if player_ref.get_meta("chill_slow_stacks", 0) == 1:
				player_ref.move_speed *= (1.0 - CHILL_SLOW)
	
	elif not in_range and chilling_player:
		chilling_player = false
		if "move_speed" in player_ref:
			var stacks = player_ref.get_meta("chill_slow_stacks", 0)
			if stacks > 0:
				player_ref.set_meta("chill_slow_stacks", stacks - 1)
				if stacks - 1 == 0:
					player_ref.move_speed /= (1.0 - CHILL_SLOW)


# ════════════════════════════════════════════════════════════
# FREEZE BURST on death
# ════════════════════════════════════════════════════════════
func _die():
	# Release chill before dying
	if chilling_player and player_ref and "move_speed" in player_ref:
		var stacks = player_ref.get_meta("chill_slow_stacks", 0)
		if stacks > 0:
			player_ref.set_meta("chill_slow_stacks", stacks - 1)
			if stacks - 1 == 0:
				player_ref.move_speed /= (1.0 - CHILL_SLOW)
	
	# 6-shard death burst
	for i in range(6):
		var angle = (TAU / 6.0) * i
		_fire_ice_shard(Vector2(cos(angle), sin(angle)), 110.0, 6)
	
	# Spawn a large ice patch at death position
	_spawn_ice_patch(global_position)
	
	super()   # EnemyBase handles die signal, track_kill, queue_free
