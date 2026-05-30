extends Area2D

# ============================================================
# Gold.gd
# ============================================================
# A gold coin pickup. Adds to GameData.current_run["gold"].
# Used to buy items in shop rooms.
#
# SCENE TREE for Gold.tscn:
#   Gold  [Area2D]
#   ├── CollisionShape2D  (CircleShape2D, radius 8)
#   └── (drawn in _draw())
#
# GOLD AMOUNTS:
#   Set via meta: gold.set_meta("gold_amount", 5)
#   Default = 5g if not set
# ============================================================

var gold_amount: int    = 5
var _bob_time:   float  = 0.0
var _spin_time:  float  = 0.0
var _collected:  bool   = false

const COLOR_GOLD_OUTER = Color(0.9, 0.72, 0.1)
const COLOR_GOLD_INNER = Color(1.0, 0.88, 0.4)
const COLOR_GOLD_SHINE = Color(1.0, 0.96, 0.7)


func _ready():
	gold_amount = get_meta("gold_amount", 5)
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)


func _process(delta: float):
	if _collected: return
	_bob_time  += delta * 2.0
	_spin_time += delta * 3.5
	position.y += sin(_bob_time) * 0.35
	queue_redraw()


func _draw():
	if _collected: return
	
	# Outer coin circle
	draw_circle(Vector2.ZERO, 7.0, COLOR_GOLD_OUTER)
	# Inner face
	draw_circle(Vector2.ZERO, 5.5, COLOR_GOLD_INNER)
	# Shine highlight — moves with spin to look like a spinning coin
	var shine_x = cos(_spin_time) * 2.5
	draw_circle(Vector2(shine_x - 1.5, -2.0), 2.0, COLOR_GOLD_SHINE)
	
	# Amount label above coin for larger drops
	if gold_amount >= 10:
		var font = ThemeDB.fallback_font
		draw_string(font, Vector2(-6, -12),
			str(gold_amount) + "g",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			COLOR_GOLD_OUTER)


func _on_body_entered(body: Node2D):
	if _collected: return
	if not body.is_in_group("player"): return
	
	_collected = true
	
	# Add to the run's gold total in GameData
	if has_node("/root/GameData"):
		# "Cursed Gold" halves all gold pickups this run
		var actual = gold_amount
		if GameData.current_run.get("gold_curse", false):
			actual = max(1, int(gold_amount * 0.5))
		GameData.current_run["gold"] = GameData.current_run.get("gold", 0) + actual
		print("[Gold] +", actual, "g", " (cursed)" if actual != gold_amount else "", ". Total: ", GameData.current_run["gold"], "g")
	
	_play_collect_fx()


func _play_collect_fx():
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 14, 0.15)
	tween.tween_property(self, "modulate:a", 0.0,             0.2)
	await tween.finished
	queue_free()
