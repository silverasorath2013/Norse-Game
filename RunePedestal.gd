extends Area2D

# ============================================================
# RunePedestal.gd
# ============================================================
# The physical item pickup in the world.
# Placed by Room.gd in treasure/curse/drop positions.
#
# SCENE TREE for RunePedestal.tscn:
#   RunePedestal  [Area2D]           ← this script
#   ├── CollisionShape2D             (CircleShape2D, radius 14)
#   ├── Sprite2D                     (pedestal base art)
#   ├── RuneSprite  [Sprite2D]       (the rune icon on top)
#   ├── GlowEffect  [Node2D]         (animated glow ring — optional)
#   └── InteractLabel  [Label]       (shows "E: Pick up [name]")
#
# HOW IT WORKS:
#   1. Room.gd calls setup(rune_data) after instantiating
#   2. The pedestal displays the rune's name and rarity colour
#   3. When the player walks into range, InteractLabel appears
#   4. When player presses "interact" (E key), try_pickup() fires
#   5. If inventory full, a "FULL" label flashes instead
#   6. On successful pickup, the pedestal plays a collect anim
#      and then queue_free()s itself
# ============================================================

signal picked_up(rune: Dictionary)   # Room.gd listens to remove pedestal from item list

var rune_data: Dictionary = {}
var player_in_range: bool = false
var player_ref: Node = null

# Visual state
var _bob_time: float = 0.0
var _glow_alpha: float = 0.0
var _collected: bool = false

@onready var rune_sprite:     Node2D = $RuneSprite
@onready var interact_label:  Label  = $InteractLabel
@onready var glow_effect:     Node2D = $GlowEffect

# Rarity glow colours (match RuneDatabase.RARITY_COLORS)
const RARITY_COLORS = {
	"common":    Color(0.75, 0.75, 0.75),
	"uncommon":  Color(0.2,  0.75, 0.35),
	"rare":      Color(0.25, 0.5,  1.0),
	"legendary": Color(0.85, 0.6,  0.1),
}


# ════════════════════════════════════════════════════════════
# setup()  —  called by Room.gd after instantiation
# ════════════════════════════════════════════════════════════
func setup(rune: Dictionary):
	rune_data = rune
	
	if rune.is_empty():
		push_warning("[RunePedestal] setup() called with empty rune!")
		queue_free()
		return
	
	# Tint the rune sprite to show rarity
	var rarity_color = RARITY_COLORS.get(rune.get("rarity", "common"), Color.WHITE)
	if rune_sprite:
		rune_sprite.modulate = rarity_color
	
	# Set glow colour
	if glow_effect:
		glow_effect.modulate = rarity_color
	
	# Hide interact label until player is in range
	if interact_label:
		interact_label.text = "E  " + rune.get("name", "???")
		interact_label.visible = false
	
	print("[RunePedestal] Ready: ", rune.get("name", "?"), " (", rune.get("rarity", "?"), ")")


# ════════════════════════════════════════════════════════════
# _ready()
# ════════════════════════════════════════════════════════════
func _ready():
	# Connect player detection
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Add to pedestal group so Room.gd can find all pedestals
	add_to_group("pedestals")


# ════════════════════════════════════════════════════════════
# _process()  —  bob animation + interact input
# ════════════════════════════════════════════════════════════
func _process(delta: float):
	if _collected: return
	
	# Gentle vertical bob on the rune sprite
	_bob_time += delta * 2.2
	if rune_sprite:
		rune_sprite.position.y = sin(_bob_time) * 3.0
	
	# Glow pulse
	_glow_alpha += delta * 1.5
	if glow_effect:
		glow_effect.modulate.a = 0.4 + sin(_glow_alpha) * 0.25
	
	# Check for interact input when player is in range
	if player_in_range and player_ref != null:
		if Input.is_action_just_pressed("interact"):
			_attempt_pickup()


# ════════════════════════════════════════════════════════════
# _attempt_pickup()
# Tries to add the rune to the player's inventory.
# ════════════════════════════════════════════════════════════
func _attempt_pickup():
	if rune_data.is_empty() or _collected:
		return
	
	# Get the ItemManager from the player
	var item_manager = player_ref.get_node_or_null("ItemManager")
	if item_manager == null:
		push_warning("[RunePedestal] Player has no ItemManager node!")
		return
	
	var success = item_manager.try_pick_up(rune_data)
	
	if success:
		_collected = true
		emit_signal("picked_up", rune_data)
		_play_collect_animation()
	else:
		# Inventory full — flash feedback
		_flash_full_message()


# ════════════════════════════════════════════════════════════
# _play_collect_animation()
# Quick flash-and-fade before queue_free()
# ════════════════════════════════════════════════════════════
func _play_collect_animation():
	if interact_label: interact_label.visible = false
	
	# Scale up, brighten, then fade out
	var tween = create_tween()
	tween.set_parallel(true)   # Run both tweens at the same time
	tween.tween_property(self, "scale",              Vector2(1.5, 1.5), 0.15)
	tween.tween_property(self, "modulate:a",          0.0,              0.3)
	tween.tween_property(self, "position:y",          position.y - 20,  0.3)
	await tween.finished
	queue_free()


# ════════════════════════════════════════════════════════════
# _flash_full_message()  —  "Inventory Full" feedback
# ════════════════════════════════════════════════════════════
func _flash_full_message():
	if interact_label:
		var original_text = interact_label.text
		interact_label.text = "Inventory Full!"
		interact_label.add_theme_color_override("font_color", Color.RED)
		
		await get_tree().create_timer(1.2).timeout
		
		interact_label.text = original_text
		interact_label.remove_theme_color_override("font_color")


# ════════════════════════════════════════════════════════════
# Detection
# ════════════════════════════════════════════════════════════
func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		player_ref     = body
		player_in_range = true
		if interact_label: interact_label.visible = true

func _on_body_exited(body: Node2D):
	if body.is_in_group("player"):
		player_in_range = false
		player_ref      = null
		if interact_label: interact_label.visible = false


# ════════════════════════════════════════════════════════════
# draw_rune_icon()
# Until you have pixel art, draw a coloured symbol in _draw()
# ════════════════════════════════════════════════════════════
func _draw():
	if rune_data.is_empty() or _collected: return
	
	var rarity = rune_data.get("rarity", "common")
	var color  = RARITY_COLORS.get(rarity, Color.WHITE)
	
	# Draw a small diamond shape as a placeholder rune icon
	# Diamonds are: 4 points — top, right, bottom, left
	var size = 8.0
	var pts  = PackedVector2Array([
		Vector2(0, -size),    # top
		Vector2(size, 0),     # right
		Vector2(0, size),     # bottom
		Vector2(-size, 0),    # left
	])
	draw_colored_polygon(pts, color)
	
	# Rarity border ring
	draw_polyline(PackedVector2Array([
		Vector2(0, -size), Vector2(size, 0),
		Vector2(0, size),  Vector2(-size, 0),
		Vector2(0, -size)
	]), color.lightened(0.3), 1.5)
