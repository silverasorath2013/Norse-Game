extends Area2D

# ============================================================
# IcePatch.gd  —  Floor-2 Environmental Hazard
# ============================================================
# Spawned by FrostRevenants as they move.
# Also placed by DungeonGenerator as room obstacles on floor 2
# (replacing the "pit" hazard type for Niflheim).
#
# BEHAVIOUR:
#   - Player stepping on the patch is slowed by 25% for 1.5s.
#     Slows stack up to 3 patches simultaneously.
#   - Patch lasts 20 seconds then melts (alpha fades).
#   - Patch has 12 HP. Player bullets can break it (5 dmg/hit).
#     When destroyed: shatters into 4 small shards that deal
#     1 damage if the player is within 30px.
#   - "FIRE" tagged bullets (from future Muspelheim items)
#     instantly destroy it.
#   - Drawn in _draw() as a hexagonal ice crystal patch.
#
# SCENE TREE for IcePatch.tscn:
#   IcePatch  [Area2D]
#   └── CollisionShape2D  (RectangleShape2D 28×28)
#   Collision: Layer 9 (hazards), Mask: 1 (player) + 5 (bullets)
# ============================================================

const SLOW_AMOUNT:     float = 0.25   # 25% speed reduction per stack
const SLOW_DURATION:   float = 1.5    # Seconds of slow after leaving patch
const PATCH_LIFETIME:  float = 20.0   # Seconds before melting
const PATCH_HP:        int   = 12
const SHARD_RANGE:     float = 30.0   # Shatter radius

var current_hp:       int   = PATCH_HP
var lifetime:         float = PATCH_LIFETIME
var is_melting:       bool  = false
var players_on_patch: Array = []   # Track who's currently standing on it
var _shimmer:         float = 0.0

# Ice patch colour variants — each patch picks one on spawn
const ICE_COLORS = [
	Color(0.65, 0.82, 1.0, 0.72),
	Color(0.55, 0.75, 0.95, 0.68),
	Color(0.70, 0.88, 1.0, 0.65),
]
var patch_color: Color


func _ready():
	patch_color = ICE_COLORS[randi() % ICE_COLORS.size()]
	add_to_group("ice_patches")
	add_to_group("hazards")
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)


func _process(delta: float):
	_shimmer += delta
	lifetime -= delta
	
	# Start melting in last 4 seconds
	if lifetime < 4.0 and not is_melting:
		is_melting = true
	
	if lifetime <= 0:
		_melt()
		return
	
	queue_redraw()


func _draw():
	var alpha = patch_color.a
	if is_melting:
		alpha *= (lifetime / 4.0)   # Fade out
	
	# Shimmer: slightly vary the colour over time
	var shimmer_v = sin(_shimmer * 2.5) * 0.06
	var c = Color(patch_color.r + shimmer_v,
		patch_color.g + shimmer_v, patch_color.b, alpha)
	
	# Draw a hexagonal ice patch
	var size = 14.0
	var pts  = PackedVector2Array()
	for i in range(6):
		var a = (TAU / 6.0) * i - PI / 6.0
		pts.append(Vector2(cos(a), sin(a)) * size)
	draw_colored_polygon(pts, c)
	
	# Inner highlight
	var inner_pts = PackedVector2Array()
	for i in range(6):
		var a = (TAU / 6.0) * i - PI / 6.0
		inner_pts.append(Vector2(cos(a), sin(a)) * (size * 0.5))
	draw_colored_polygon(inner_pts,
		Color(1.0, 1.0, 1.0, alpha * 0.35))
	
	# HP crack lines (more cracks as HP drops)
	if current_hp < PATCH_HP:
		var crack_alpha = (1.0 - float(current_hp) / float(PATCH_HP)) * alpha
		draw_line(Vector2(-size * 0.3, -size * 0.2),
			Vector2(size * 0.4, size * 0.3),
			Color(0.85, 0.92, 1.0, crack_alpha), 1.0)
		if current_hp < PATCH_HP / 2:
			draw_line(Vector2(size * 0.2, -size * 0.4),
				Vector2(-size * 0.3, size * 0.1),
				Color(0.85, 0.92, 1.0, crack_alpha), 0.75)


# ════════════════════════════════════════════════════════════
# PLAYER DETECTION — apply/remove slow
# ════════════════════════════════════════════════════════════
func _on_body_entered(body: Node2D):
	if not body.is_in_group("player"): return
	if body in players_on_patch: return
	
	players_on_patch.append(body)
	_apply_slow(body)


func _on_body_exited(body: Node2D):
	if not body.is_in_group("player"): return
	players_on_patch.erase(body)
	_schedule_slow_removal(body)


func _apply_slow(player: Node):
	var stacks = player.get_meta("ice_slow_stacks", 0)
	player.set_meta("ice_slow_stacks", stacks + 1)
	if stacks == 0:
		# Apply first slow
		player.move_speed = max(40.0, player.move_speed * (1.0 - SLOW_AMOUNT))
		print("[IcePatch] Player slowed. Stacks: 1")


func _schedule_slow_removal(player: Node):
	# Remove slow after SLOW_DURATION seconds
	get_tree().create_timer(SLOW_DURATION).timeout.connect(
		func(): _remove_slow(player)
	)


func _remove_slow(player: Node):
	if not is_instance_valid(player): return
	var stacks = player.get_meta("ice_slow_stacks", 0)
	if stacks <= 0: return
	
	player.set_meta("ice_slow_stacks", stacks - 1)
	if stacks - 1 == 0:
		# Remove the speed penalty (reverse the multiplication)
		player.move_speed = min(
			player.move_speed / (1.0 - SLOW_AMOUNT),
			player.get("base_move_speed") if "base_move_speed" in player else 999.0
		)
		print("[IcePatch] Player slow removed")


# ════════════════════════════════════════════════════════════
# BULLET DAMAGE — players can shoot patches to clear them
# ════════════════════════════════════════════════════════════
func _on_area_entered(area: Area2D):
	if not area.is_in_group("player_bullets"): return
	
	var dmg = area.get("damage") if area.get("damage") != null else 5
	
	# Fire bullets instantly destroy ice
	if area.get_meta("is_fire_bullet", false):
		current_hp = 0
		_shatter()
		return
	
	current_hp -= dmg
	if current_hp <= 0:
		_shatter()


# ════════════════════════════════════════════════════════════
# DESTRUCTION
# ════════════════════════════════════════════════════════════
func _shatter():
	print("[IcePatch] Shattered!")
	
	# Remove slow from any players currently on the patch
	for player in players_on_patch:
		if is_instance_valid(player):
			_remove_slow(player)
	
	# Deal shard damage to nearby players
	for player in players_on_patch:
		if is_instance_valid(player):
			var dist = global_position.distance_to(player.global_position)
			if dist < SHARD_RANGE and player.has_method("take_damage"):
				player.take_damage(1)
	
	queue_free()


func _melt():
	# Gentle melt — remove slows, no shard damage
	for player in players_on_patch:
		if is_instance_valid(player):
			_remove_slow(player)
	queue_free()
