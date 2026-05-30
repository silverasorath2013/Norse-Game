extends Node2D

# ============================================================
# BossRoom.gd
# ============================================================
# Controls the boss arena. Attached to the boss room scene.
# Handles:
#   - Sealing the entrance door permanently once player enters
#   - Spawning Jormungandr at the arena centre
#   - Spawning the BossHPBar UI
#   - Playing the boss music cue
#   - Handling the boss death → unlock → exit spawn sequence
#   - Brief camera zoom during the intro
#
# HOW ROOM.GD USES THIS:
#   In Room.gd _setup_room_type_content(), for RoomType.BOSS:
#     var boss_ctrl = load("res://scenes/BossRoom.tscn").instantiate()
#     add_child(boss_ctrl)
#     boss_ctrl.setup(floor_number)
# ============================================================

signal boss_arena_cleared()   # RoomManager listens to unlock exit

const JORMUNGANDR_SCENE = "res://scenes/boss/Jormungandr.tscn"
const BOSS_HP_BAR_SCENE = "res://scenes/boss/BossHPBar.tscn"

var floor_num: int = 1
var boss_node: Node = null
var arena_active: bool = false

# Arena dimensions (same as room tile dimensions)
const ROOM_PIXEL_W: float = 16 * 40.0
const ROOM_PIXEL_H: float = 12 * 40.0

# The spawn position — centre of the room, slightly upper half
var BOSS_SPAWN_POS: Vector2:
	get: return Vector2(ROOM_PIXEL_W / 2, ROOM_PIXEL_H * 0.38)


# ════════════════════════════════════════════════════════════
# setup()  —  called by Room.gd
# ════════════════════════════════════════════════════════════
func setup(f_num: int):
	floor_num = f_num
	
	# Detect when the player enters so we can seal the door behind them
	var detection = Area2D.new()
	detection.name = "ArenaDetector"
	var shape_node = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(ROOM_PIXEL_W - 80, ROOM_PIXEL_H - 80)
	shape_node.shape = shape
	detection.position = Vector2(ROOM_PIXEL_W / 2, ROOM_PIXEL_H / 2)
	detection.add_child(shape_node)
	detection.collision_mask = 1   # Player layer
	detection.body_entered.connect(_on_player_entered_arena)
	add_child(detection)
	
	print("[BossRoom] Floor ", floor_num, " boss arena ready.")


# ════════════════════════════════════════════════════════════
# _on_player_entered_arena()
# Player stepped into the boss room — begin the encounter
# ════════════════════════════════════════════════════════════
func _on_player_entered_arena(body: Node2D):
	if not body.is_in_group("player"): return
	if arena_active: return   # Already triggered
	
	arena_active = true
	print("[BossRoom] ARENA SEALED — boss fight begins!")
	
	# 1. Seal the entrance door (can't retreat)
	_seal_entrance()
	
	# 2. Brief pause before boss spawns (dramatic beat)
	await get_tree().create_timer(0.6).timeout
	
	# 3. Spawn Jormungandr
	_spawn_boss()
	
	# 4. Spawn the boss HP bar
	_spawn_hp_bar()
	
	# 5. Camera zoom in slightly — if you have a Camera2D
	_boss_camera_zoom()


# ════════════════════════════════════════════════════════════
# _seal_entrance()
# Closes the south door behind the player.
# Locks it so they can't leave until the boss is dead.
# ════════════════════════════════════════════════════════════
func _seal_entrance():
	# The Room node (parent) controls doors — call lock_doors()
	var room = get_parent()
	if room and room.has_method("lock_doors"):
		room.call("lock_doors")
	
	# Visual: draw a thick stone wall over the door gap
	# (In a full game: swap the door tile to a sealed stone tile)
	print("[BossRoom] Entrance sealed.")


# ════════════════════════════════════════════════════════════
# _spawn_boss()
# ════════════════════════════════════════════════════════════
func _spawn_boss():
	if not ResourceLoader.exists(JORMUNGANDR_SCENE):
		print("[BossRoom] Jormungandr.tscn not found — using placeholder!")
		_spawn_placeholder_boss()
		return
	
	boss_node = load(JORMUNGANDR_SCENE).instantiate()
	boss_node.global_position = BOSS_SPAWN_POS
	boss_node.add_to_group("enemies")
	boss_node.add_to_group("boss")
	
	# Connect boss signals
	boss_node.died.connect(_on_boss_died)
	boss_node.boss_died.connect(_on_boss_died_full)
	boss_node.phase_changed.connect(_on_phase_changed)
	
	get_parent().add_child(boss_node)
	print("[BossRoom] Jormungandr spawned at ", BOSS_SPAWN_POS)


func _spawn_placeholder_boss():
	# A large coloured rectangle until the scene is built
	var rect       = ColorRect.new()
	rect.size      = Vector2(60, 60)
	rect.position  = BOSS_SPAWN_POS - Vector2(30, 30)
	rect.color     = Color(0.2, 0.6, 0.15)
	rect.name      = "BossPlaceholder"
	get_parent().add_child(rect)
	print("[BossRoom] Placeholder boss spawned.")


# ════════════════════════════════════════════════════════════
# _spawn_hp_bar()
# ════════════════════════════════════════════════════════════
func _spawn_hp_bar():
	if boss_node == null: return
	
	var hp_bar: Node
	if ResourceLoader.exists(BOSS_HP_BAR_SCENE):
		hp_bar = load(BOSS_HP_BAR_SCENE).instantiate()
	else:
		# Fallback: create a minimal CanvasLayer with BossHPBar.gd
		hp_bar = CanvasLayer.new()
		hp_bar.set_script(load("res://scripts/boss/BossHPBar.gd"))
	
	hp_bar.name = "BossHPBar"
	add_child(hp_bar)
	
	if hp_bar.has_method("connect_to_boss"):
		hp_bar.connect_to_boss(boss_node)


# ════════════════════════════════════════════════════════════
# _boss_camera_zoom()
# Zoom the camera in slightly for the intro
# ════════════════════════════════════════════════════════════
func _boss_camera_zoom():
	var cameras = get_tree().get_nodes_in_group("camera")
	if cameras.is_empty(): return
	var cam = cameras[0]
	
	var tween = create_tween()
	tween.tween_property(cam, "zoom", Vector2(1.15, 1.15), 0.8)
	await get_tree().create_timer(3.0).timeout
	
	var tween2 = create_tween()
	tween2.tween_property(cam, "zoom", Vector2(1.0, 1.0), 0.6)


# ════════════════════════════════════════════════════════════
# Signal handlers
# ════════════════════════════════════════════════════════════
func _on_phase_changed(new_phase: int):
	print("[BossRoom] Phase ", new_phase, " — arena shakes!")
	# Shake the camera
	_shake_camera(new_phase == 3)   # Bigger shake for phase 3

func _on_boss_died():
	# This is the EnemyBase 'died' signal — Room.gd handles door unlock
	pass

func _on_boss_died_full():
	print("[BossRoom] Jormungandr is dead. Victory!")
	
	# 1. Unlock the arena door
	var room = get_parent()
	if room and room.has_method("unlock_doors"):
		room.call("unlock_doors")
	
	# 2. Record the boss kill in GameData
	if has_node("/root/GameData"):
		var bosses = GameData.current_run.get("bosses_killed", [])
		bosses.append("Jormungandr_Floor" + str(floor_num))
		GameData.current_run["bosses_killed"] = bosses
	
	# 3. Unlock Odin (first boss kill reward)
	if has_node("/root/GameData"):
		GameData.unlock_hero("Odin")
		print("[BossRoom] Odin UNLOCKED!")
	
	# 4. Spawn the exit staircase after a brief delay
	await get_tree().create_timer(2.0).timeout
	_spawn_exit()
	
	# 5. Restore camera zoom
	var cameras = get_tree().get_nodes_in_group("camera")
	if not cameras.is_empty():
		var tween = create_tween()
		tween.tween_property(cameras[0], "zoom", Vector2(1.0, 1.0), 0.5)
	
	emit_signal("boss_arena_cleared")

func _shake_camera(strong: bool = false):
	var cameras = get_tree().get_nodes_in_group("camera")
	if cameras.is_empty(): return
	var cam = cameras[0]
	var intensity = 8.0 if strong else 4.0
	
	var tween = create_tween()
	for i in range(8):
		var ox = randf_range(-intensity, intensity)
		var oy = randf_range(-intensity, intensity)
		tween.tween_property(cam, "offset", Vector2(ox, oy), 0.06)
	tween.tween_property(cam, "offset", Vector2.ZERO, 0.08)


# ════════════════════════════════════════════════════════════
# _spawn_exit()
# Spawns a staircase / portal in the centre of the boss room
# ════════════════════════════════════════════════════════════
func _spawn_exit():
	print("[BossRoom] Exit portal opening...")
	
	if ResourceLoader.exists("res://scenes/Exit.tscn"):
		var exit = load("res://scenes/Exit.tscn").instantiate()
		exit.global_position = BOSS_SPAWN_POS + Vector2(0, 30)
		get_parent().add_child(exit)
	else:
		# Placeholder: a glowing rectangle
		var exit_marker = ColorRect.new()
		exit_marker.size     = Vector2(32, 32)
		exit_marker.position = BOSS_SPAWN_POS + Vector2(-16, 14)
		exit_marker.color    = Color(0.2, 0.85, 0.6)
		exit_marker.name     = "ExitPortal"
		get_parent().add_child(exit_marker)
		print("[BossRoom] Exit placeholder placed at ",
			BOSS_SPAWN_POS + Vector2(0, 30))
