extends Area2D

# ============================================================
# Bullet.gd
# ============================================================
# Attached to a simple Area2D scene (no physics body needed —
# we move it manually and use area overlap for hit detection).
#
# SCENE TREE for Bullet.tscn:
#   Bullet  (Area2D)  ← this script lives here
#   ├── CollisionShape2D  (small circle, ~4px radius)
#   ├── Sprite2D          (your bullet pixel art)
#   └── VisibleOnScreenNotifier2D  (auto-frees if it leaves screen)
#
# HOW BULLETS WORK:
#   1. Hero spawns a Bullet and sets its .direction + .damage
#   2. Every frame, _process() moves it forward
#   3. _on_body_entered() fires when it overlaps a wall/enemy
#   4. It deals damage and destroys itself
# ============================================================

# ── DATA SET BY THE HERO ON SPAWN ────────────────────────────
var direction:   Vector2 = Vector2.RIGHT
var speed:       float   = 280.0
var damage:      int     = 10
var source_node: Node    = null   # Which hero fired this (for passive effects)

# ── BEHAVIOUR MODIFIERS (set by items/passives) ───────────────
var piercing:    bool  = false   # Pass through enemies without stopping
var bounces:     int   = 0       # How many walls it can bounce off
var lifetime:    float = 2.2     # Seconds before auto-destroy (prevents orphans)
var scale_over_time: bool = false # Grows as it travels (e.g. Odin's power shot)

# ── INTERNAL ─────────────────────────────────────────────────
var _age:        float = 0.0
var _hit_nodes:  Array = []     # Tracks already-hit enemies (for piercing)

@onready var sprite: Sprite2D = $Sprite2D


# ════════════════════════════════════════════════════════════
# _ready()
# Rotate the sprite to face the travel direction.
# This is why all bullet sprites should point RIGHT by default —
# we rotate them to match their actual direction.
# ════════════════════════════════════════════════════════════
func _ready():
	# atan2(y, x) gives the angle of a vector in radians
	rotation = direction.angle()
	
	# Connect hit signal — fires when this Area2D overlaps another
	# "body_entered" triggers for PhysicsBody2D nodes (walls, enemies with CharacterBody2D)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


# ════════════════════════════════════════════════════════════
# _process(delta)
# Move forward every frame. Using _process (not _physics_process)
# because bullets don't need physics collision resolution —
# they just move in a straight line and we detect hits via Area2D.
# ════════════════════════════════════════════════════════════
func _process(delta: float):
	# Move in our travel direction
	global_position += direction * speed * delta
	
	# Track age — destroy if too old (safety net)
	_age += delta
	if _age >= lifetime:
		_destroy()
		return
	
	# Optional: grow the bullet as it travels (for special abilities)
	if scale_over_time:
		var grow = 1.0 + (_age / lifetime) * 0.8   # grows up to 1.8x size
		scale = Vector2(grow, grow)


# ════════════════════════════════════════════════════════════
# _on_body_entered()
# Called when bullet overlaps a PhysicsBody2D.
# Enemies should be CharacterBody2D or StaticBody2D.
# Walls are TileMap / StaticBody2D.
# ════════════════════════════════════════════════════════════
func _on_body_entered(body: Node2D):
	# ── Hit an enemy ──────────────────────────────────────────
	if body.is_in_group("enemies"):
		# Skip if already hit this enemy (piercing bullets)
		if body in _hit_nodes:
			return
		
		_hit_nodes.append(body)
		
		# Deal damage — enemy must have a take_damage() method
		if body.has_method("take_damage"):
			body.call("take_damage", damage)
		if has_node("/root/GameData"):
			GameData.track_damage_dealt(damage)
		
		# Notify source hero for passive triggers (e.g. Thor's bounce counter)
		if source_node and source_node.has_method("_on_hit_landed"):
			source_node.call("_on_hit_landed", body.global_position)
		
		# Spawn a hit spark VFX at the contact point
		_spawn_hit_effect(global_position)
		
		# Piercing bullets keep going; normal bullets stop here
		if not piercing:
			_destroy()
	
	# ── Hit a wall ────────────────────────────────────────────
	elif body is TileMap or body.is_in_group("walls"):
		if bounces > 0:
			# Bounce: reflect direction off the wall
			bounces  -= 1
			direction = _reflect_off_wall(body)
			rotation  = direction.angle()   # Update visual rotation
		else:
			_spawn_hit_effect(global_position)
			_destroy()


# ════════════════════════════════════════════════════════════
# _on_area_entered()
# Some enemies use Area2D hurtboxes instead of physics bodies.
# This catches those cases.
# ════════════════════════════════════════════════════════════
func _on_area_entered(area: Area2D):
	if area.is_in_group("enemy_hurtbox"):
		var enemy = area.get_parent()
		if enemy in _hit_nodes: return
		_hit_nodes.append(enemy)
		
		if enemy.has_method("take_damage"):
			enemy.call("take_damage", damage)
		
		if source_node and source_node.has_method("_on_hit_landed"):
			source_node.call("_on_hit_landed", global_position)
		
		_spawn_hit_effect(global_position)
		if not piercing:
			_destroy()


# ════════════════════════════════════════════════════════════
# _reflect_off_wall()
# Simple bounce reflection — flips the axis with less velocity.
# We check which wall face was hit by looking at the bullet's
# position relative to the wall's normal.
# ════════════════════════════════════════════════════════════
func _reflect_off_wall(_wall_body) -> Vector2:
	# Simple approach: detect if we hit a horizontal or vertical surface
	# by checking which component of direction is bigger
	if abs(direction.x) > abs(direction.y):
		return Vector2(-direction.x, direction.y)   # Flip horizontal
	else:
		return Vector2(direction.x, -direction.y)   # Flip vertical


# ════════════════════════════════════════════════════════════
# _spawn_hit_effect()
# Creates a small flash at the hit point.
# Until you have a particle scene, this just logs it.
# Replace with: var fx = HIT_FX_SCENE.instantiate() etc.
# ════════════════════════════════════════════════════════════
func _spawn_hit_effect(pos: Vector2):
	# TODO: instantiate a CPUParticles2D or GPUParticles2D scene here
	# For now, a quick visual: flash the bullet white then delete
	if sprite:
		sprite.modulate = Color.WHITE * 2.0   # Overbright flash


# ════════════════════════════════════════════════════════════
# _destroy()
# Removes this bullet from the scene safely.
# queue_free() tells Godot "delete me at end of this frame"
# — safer than free() which deletes immediately mid-loop.
# ════════════════════════════════════════════════════════════
func _destroy():
	queue_free()
