extends CharacterBody2D

# ============================================================
# EnemyBase.gd  —  Base class for ALL enemies
# ============================================================
# Every enemy (Draugr, Einherjar, Wight, etc.) extends this.
# It handles:
#   - Health + taking damage from bullets
#   - Hurtbox (Area2D that bullets detect)
#   - Death signal (so Room.gd knows to unlock doors)
#   - Knockback when hit
#   - Basic state machine: IDLE → CHASE → ATTACK → DEAD
#   - Visual feedback (flash red, death fade)
#
# To make a new enemy:
#   1. Create EnemyName.gd that extends "res://scripts/EnemyBase.gd"
#   2. Override _chase_behaviour() and _attack_behaviour()
#   3. Set the @export stats in the Inspector or in _ready()
# ============================================================

signal died()    # Emitted on death — Room.gd listens to this

# ── EXPORTED STATS ───────────────────────────────────────────
@export var enemy_name:   String = "Enemy"
@export var max_health:   int    = 30
@export var move_speed:   float  = 55.0
@export var damage:       int    = 1      # Hearts of damage (1 = half heart in Isaac)
@export var contact_damage_cooldown: float = 0.8  # Seconds between contact hits
@export var detection_range: float = 280.0  # Distance to start chasing player
@export var attack_range:    float = 20.0   # Distance to deal contact damage

# ── STATE MACHINE ────────────────────────────────────────────
# An enum defines named states. Cleaner than magic numbers.
enum State { IDLE, CHASE, ATTACK, HURT, DEAD }
var state: State = State.IDLE

# ── RUNTIME ──────────────────────────────────────────────────
var current_health:          int
var player_ref:              Node   = null   # cached reference to the player
var contact_damage_timer:    float  = 0.0    # cooldown between contact hits
var knockback_velocity:      Vector2 = Vector2.ZERO
var knockback_friction:      float   = 8.0   # how quickly knockback slows

# ── NODE REFERENCES ──────────────────────────────────────────
@onready var sprite:         Node2D  = $Sprite2D
@onready var hurtbox:        Area2D  = $Hurtbox     # Bullets hit this
@onready var detection_zone: Area2D  = $DetectionZone

# ════════════════════════════════════════════════════════════
# _ready()
# ════════════════════════════════════════════════════════════
func _ready():
	current_health = max_health
	add_to_group("enemies")
	
	# Connect the hurtbox so it responds to overlapping bullets
	# The BULLET adds itself to group "player_bullets" when spawned
	if hurtbox:
		hurtbox.add_to_group("enemy_hurtbox")
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	
	if detection_zone:
		detection_zone.body_entered.connect(_on_detection_body_entered)
		detection_zone.body_exited.connect(_on_detection_body_exited)

# ════════════════════════════════════════════════════════════
# _physics_process(delta)
# ════════════════════════════════════════════════════════════
func _physics_process(delta: float):
	if state == State.DEAD:
		return
	
	# Tick timers
	if contact_damage_timer > 0:
		contact_damage_timer -= delta
	
	# Apply knockback decay
	if knockback_velocity.length() > 0:
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, knockback_friction * delta)
		velocity = knockback_velocity
	else:
		# Normal AI behaviour based on current state
		match state:
			State.IDLE:   _idle_behaviour(delta)
			State.CHASE:  _chase_behaviour(delta)
			State.ATTACK: _attack_behaviour(delta)
			State.HURT:   pass   # Handled by timer in take_damage
	
	move_and_slide()
	
	# Check if we're touching the player for contact damage
	_check_contact_damage()

# ════════════════════════════════════════════════════════════
# STATE BEHAVIOURS — override these in subclasses
# ════════════════════════════════════════════════════════════
func _idle_behaviour(_delta: float):
	velocity = Vector2.ZERO
	# Look for the player if they're nearby
	if player_ref:
		state = State.CHASE

func _chase_behaviour(_delta: float):
	# Default: move straight toward the player
	if player_ref == null:
		state = State.IDLE
		return
	
	var to_player = player_ref.global_position - global_position
	
	# If out of range, go back to idle
	if to_player.length() > detection_range * 1.3:
		state    = State.IDLE
		velocity = Vector2.ZERO
		return
	
	velocity = to_player.normalized() * move_speed
	
	# Flip sprite to face movement direction
	if sprite and velocity.x != 0:
		sprite.scale.x = sign(velocity.x)

func _attack_behaviour(_delta: float):
	# Base class: enemies deal damage by contact, handled in _check_contact_damage
	# Override for ranged attacks (Einherjar fires projectiles, etc.)
	pass

# ════════════════════════════════════════════════════════════
# DAMAGE SYSTEM
# ════════════════════════════════════════════════════════════

# Called by Bullet.gd when a bullet hits this enemy
func take_damage(amount: int):
	if state == State.DEAD:
		return
	
	current_health -= amount
	
	_flash_hit()
	_apply_knockback_from_player()
	
	print("[", enemy_name, "] Hit for ", amount, "  HP:", current_health, "/", max_health)
	
	if current_health <= 0:
		_die()

func _apply_knockback_from_player():
	if player_ref:
		var push_dir = (global_position - player_ref.global_position).normalized()
		knockback_velocity = push_dir * 180.0   # knockback strength

func _flash_hit():
	if not sprite: return
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.RED,   0.06)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.06)

func _die():
	state = State.DEAD
	velocity = Vector2.ZERO
	
	# Disable hurtbox so bullets don't keep hitting a dead enemy
	if hurtbox:
		hurtbox.set_deferred("monitoring",  false)
		hurtbox.set_deferred("monitorable", false)
	
	emit_signal("died")   # Room.gd subtracts from enemies_alive count
	
	# Death fade animation then remove
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
		await tween.finished
	
	if has_node("/root/GameData"):
		GameData.track_kill()
	queue_free()

# ════════════════════════════════════════════════════════════
# CONTACT DAMAGE
# Called each physics frame — if the enemy is overlapping
# the player, deal damage (with cooldown so it's not instant death)
# ════════════════════════════════════════════════════════════
func _check_contact_damage():
	if contact_damage_timer > 0 or player_ref == null:
		return
	
	var dist = global_position.distance_to(player_ref.global_position)
	if dist <= attack_range + 16:   # +16 = rough player hitbox radius
		if player_ref.has_method("take_damage"):
			# "Marked for Death" curse adds extra damage on every hit
			var extra = player_ref.get_meta("curse_extra_damage", 0)
			if "last_hit_source" in player_ref:
				player_ref.last_hit_source = enemy_name
			player_ref.take_damage(damage + extra)
			contact_damage_timer = contact_damage_cooldown

# ════════════════════════════════════════════════════════════
# DETECTION ZONE SIGNALS
# When the player enters the DetectionZone Area2D, start chasing
# ════════════════════════════════════════════════════════════
func _on_detection_body_entered(body: Node2D):
	if body.is_in_group("player"):
		player_ref = body
		state      = State.CHASE

func _on_detection_body_exited(body: Node2D):
	if body.is_in_group("player"):
		# Keep chasing for a bit after leaving detection range
		# (handled by range check in _chase_behaviour)
		pass

# ════════════════════════════════════════════════════════════
# HURTBOX — picks up hits from Bullet Area2D nodes
# ════════════════════════════════════════════════════════════
func _on_hurtbox_area_entered(area: Area2D):
	# Bullets add themselves to "player_bullets" group
	if area.is_in_group("player_bullets"):
		if area.has_method("get") and area.get("damage") != null:
			take_damage(area.get("damage"))
