extends Area2D

# ============================================================
# EnemyBullet.gd
# ============================================================
# Identical to Bullet.gd in movement, but it damages the PLAYER
# not enemies. It listens for the player's hitbox, not enemies'.
#
# SCENE TREE for EnemyBullet.tscn:
#   EnemyBullet  (Area2D)
#   ├── CollisionShape2D  (small circle)
#   ├── Sprite2D          (different colour from player bullets)
#   └── VisibleOnScreenNotifier2D
# ============================================================

var direction: Vector2 = Vector2.RIGHT
var speed:     float   = 200.0
var damage:    int     = 8
var lifetime:  float   = 3.0

var _age:      float   = 0.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready():
	rotation = direction.angle()
	add_to_group("enemy_bullets")
	
	# Connect to player's hitbox or body — watch for body_entered
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Visual: enemy bullets are a distinct colour so the player
	# can tell them apart from their own shots
	if sprite:
		sprite.modulate = Color(1.0, 0.4, 0.2)   # Orange-red for enemy bullets


func _process(delta: float):
	global_position += direction * speed * delta
	_age += delta
	if _age >= lifetime:
		queue_free()


func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
	elif body is TileMap or body.is_in_group("walls"):
		queue_free()   # Enemy bullets vanish on wall hit (no bouncing)


func _on_area_entered(area: Area2D):
	# Player shield/parry items can go in "player_shield" group
	if area.is_in_group("player_hitbox") or area.is_in_group("player_shield"):
		var target = area.get_parent()
		if target.has_method("take_damage"):
			target.take_damage(damage)
		queue_free()
