extends Area2D

# ============================================================
# Heart.gd
# ============================================================
# A heart pickup the player walks over to heal.
# Spawned by ItemDropper.spawn_heart() after room clears,
# or placed in special rooms.
#
# SCENE TREE for Heart.tscn:
#   Heart  [Area2D]             ← this script
#   ├── CollisionShape2D        (CircleShape2D, radius 10)
#   └── (no Sprite2D needed — drawn in _draw())
#
# HEAL AMOUNTS:
#   Full heart  = 20 HP  (is_half_heart = false)
#   Half heart  = 10 HP  (is_half_heart = true, set via meta)
# ============================================================

var is_half_heart: bool = false
var _bob_time: float    = 0.0
var _collected: bool    = false

const FULL_HEAL:  int = 20
const HALF_HEAL:  int = 10

# Colours
const COLOR_HEART_FULL = Color(0.9, 0.15, 0.2)
const COLOR_HEART_HALF = Color(0.75, 0.35, 0.35)


func _ready():
	# Read the half-heart flag set by ItemDropper
	is_half_heart = get_meta("is_half_heart", false)
	
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)


func _process(delta: float):
	if _collected: return
	_bob_time += delta * 2.5
	position.y += sin(_bob_time) * 0.4   # Gentle float
	queue_redraw()


func _draw():
	if _collected: return
	var color = COLOR_HEART_HALF if is_half_heart else COLOR_HEART_FULL
	var s     = 8.0   # Half-size of heart
	
	# Draw a pixel-style heart using rectangles
	# Top-left lobe
	draw_rect(Rect2(-s * 0.9, -s * 0.6, s * 0.8, s * 0.7), color)
	# Top-right lobe
	draw_rect(Rect2(s * 0.1,  -s * 0.6, s * 0.8, s * 0.7), color)
	# Body
	draw_rect(Rect2(-s,        -s * 0.1, s * 2,   s * 0.8), color)
	# Bottom point
	draw_rect(Rect2(-s * 0.6,  s * 0.65, s * 1.2, s * 0.4), color)
	draw_rect(Rect2(-s * 0.2,  s * 1.0,  s * 0.4, s * 0.25), color)
	
	# For half heart: grey out the right side
	if is_half_heart:
		draw_rect(Rect2(0, -s * 0.7, s, s * 1.8), Color(0.15, 0.12, 0.12, 0.65))


func _on_body_entered(body: Node2D):
	if _collected: return
	if not body.is_in_group("player"): return
	
	# Only pick up if the player is missing HP
	var current = body.get("current_health") if "current_health" in body else 0
	var maximum  = body.get("max_health")    if "max_health"    in body else 1
	if current >= maximum:
		return   # Already full — don't consume the heart
	
	_collected = true
	var heal_amount = HALF_HEAL if is_half_heart else FULL_HEAL
	
	if body.has_method("heal"):
		body.heal(heal_amount)
	
	# Notify ItemManager in case any items proc on heal
	var mgr = body.get_node_or_null("ItemManager")
	if mgr and mgr.has_method("notify_heal"):
		mgr.notify_heal(heal_amount)
	
	_play_collect_fx()


func _play_collect_fx():
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale",      Vector2(1.6, 1.6), 0.12)
	tween.tween_property(self, "modulate:a", 0.0,              0.18)
	await tween.finished
	queue_free()
