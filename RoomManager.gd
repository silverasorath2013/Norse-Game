extends Node2D

# ============================================================
# RoomManager.gd
# ============================================================
# This is the "director" of the dungeon floor.
# It sits above individual Room scenes and manages:
#   1. Which room is currently active
#   2. Room transition animations (camera slide, like Isaac)
#   3. Spawning/despawning rooms as the player moves
#   4. Communicating with the minimap
#   5. Tracking floor progression (did we beat the boss?)
#
# SCENE TREE STRUCTURE (how this fits in Godot):
#   Game.tscn
#   ├── RoomManager (this script)
#   │   ├── CurrentRoom (the active Room scene)
#   │   └── Camera2D (the camera that slides between rooms)
#   ├── Player (your hero)
#   ├── HUD (health bar, minimap, item slots)
#   └── Minimap
# ============================================================

# --- SIGNALS ---
signal floor_completed()              # Boss killed, ready to descend
signal minimap_updated(layout: Dictionary) # Tell the minimap to redraw

# --- REFERENCES ---
@onready var camera: Camera2D = $Camera2D
@onready var current_room_node: Node2D = $CurrentRoomContainer
@onready var transition_overlay: ColorRect = $TransitionOverlay  # Black screen for fade

# --- STATE ---
var floor_layout: FloorLayout = null     # The generated layout data
var current_room_pos: Vector2i           # Which grid cell the player is in
var active_room_scene: Node2D = null     # The currently visible Room scene
var is_transitioning: bool = false       # Are we mid-room-change?
var floor_number: int = 1

# Room scene to instantiate for each room
const ROOM_SCENE = preload("res://scenes/Room.tscn")

# Room dimensions in world pixels (matches Room.gd constants)
const ROOM_PIXEL_WIDTH  = 16 * 40   # 640 pixels
const ROOM_PIXEL_HEIGHT = 12 * 40   # 480 pixels

# ============================================================
# initialise_floor() — Call this from Game.gd to set up a new floor.
# ============================================================
func initialise_floor(floor_num: int):
	floor_number = floor_num
	
	# Use DungeonGenerator autoload to build the layout
	# (DungeonGenerator must be registered as an Autoload in Project Settings)
	floor_layout = DungeonGenerator.generate_floor(floor_num)
	
	# Start in the start room
	current_room_pos = floor_layout.start_room_pos
	
	# Load the starting room immediately (no transition)
	_load_room(current_room_pos, "none")
	
	# Tell the minimap about the layout
	emit_signal("minimap_updated", floor_layout.rooms)
	
	print("Floor ", floor_num, " initialised. Starting at grid pos: ", current_room_pos)

# ============================================================
# transition_to_room() — moves the player to an adjacent room.
# direction = "north", "south", "east", or "west"
# Called when the player walks through a door.
# ============================================================
func transition_to_room(direction: String):
	# Prevent double-transitions
	if is_transitioning:
		return
	
	var dir_vec = DungeonGenerator.DIRECTIONS[direction]
	var next_pos = current_room_pos + dir_vec
	
	# Verify there IS a room in that direction
	if not floor_layout.rooms.has(next_pos):
		push_warning("No room at " + str(next_pos) + " — door shouldn't be open!")
		return
	
	is_transitioning = true
	
	# Step 1: Fade out
	await _fade_screen(true, 0.15)
	
	# Step 2: Snap player to entry point of new room
	_reposition_player_for_entry(direction)
	
	# Step 3: Load new room
	_load_room(next_pos, direction)
	current_room_pos = next_pos
	
	# Step 4: Fade in
	await _fade_screen(false, 0.15)
	
	is_transitioning = false
	
	# Mark as visited and update minimap
	floor_layout.rooms[current_room_pos].visited = true
	emit_signal("minimap_updated", floor_layout.rooms)

# ============================================================
# _load_room() — unloads the old room, instantiates the new one.
# ============================================================
func _load_room(grid_pos: Vector2i, entry_direction: String):
	# Remove old room from scene
	if active_room_scene != null:
		active_room_scene.queue_free()
		active_room_scene = null
	
	# Instantiate a fresh Room scene
	var new_room = ROOM_SCENE.instantiate()
	current_room_node.add_child(new_room)
	active_room_scene = new_room
	
	# Pass the RoomData to the room so it builds itself
	var room_data = floor_layout.rooms[grid_pos]
	new_room.setup(room_data, floor_number)
	
	# Connect the room's signals to our handlers
	new_room.room_cleared.connect(_on_room_cleared)
	new_room.player_exited.connect(_on_player_exited_room)
	new_room.boss_defeated.connect(_on_boss_defeated)
	
	# Position the room at world origin (room is always centered in viewport)
	new_room.position = Vector2.ZERO

# ============================================================
# _reposition_player_for_entry() — places the player just
# inside the door they came through, on the correct side.
# ============================================================
func _reposition_player_for_entry(came_from_direction: String):
	# Find the player node (assumed to be in the "player" group)
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player = players[0]
	
	var tile_size = 40
	var cx = ROOM_PIXEL_WIDTH / 2
	var cy = ROOM_PIXEL_HEIGHT / 2
	
	# Place player just inside the door on the OPPOSITE wall from where they entered
	match came_from_direction:
		"north":   player.global_position = Vector2(cx, ROOM_PIXEL_HEIGHT - tile_size * 2)
		"south":   player.global_position = Vector2(cx, tile_size * 2)
		"east":    player.global_position = Vector2(tile_size * 2, cy)
		"west":    player.global_position = Vector2(ROOM_PIXEL_WIDTH - tile_size * 2, cy)
		"none":    player.global_position = Vector2(cx, cy)  # Floor start — centre

# ============================================================
# _fade_screen() — fades the transition overlay in or out.
# Uses Godot's Tween system for smooth animation.
# "await" pauses this function until the tween is done.
# ============================================================
func _fade_screen(fade_in: bool, duration: float):
	if transition_overlay == null:
		return
	
	# Create a Tween — Godot's animation interpolation system
	var tween = create_tween()
	var target_alpha = 1.0 if fade_in else 0.0
	
	# Animate the overlay's alpha (transparency) from current to target
	tween.tween_property(transition_overlay, "modulate:a", target_alpha, duration)
	
	# Wait for the tween to finish before continuing
	await tween.finished

# ============================================================
# Signal handlers — called when rooms emit their signals
# ============================================================

func _on_room_cleared(room_data):
	print("RoomManager: room cleared at ", room_data.grid_pos)
	# Could play a sound, flash the minimap icon, etc.

func _on_player_exited_room(direction: String):
	# Player stepped through a door — start the transition
	transition_to_room(direction)

func _on_boss_defeated():
	print("BOSS DEFEATED! Floor ", floor_number, " complete!")
	
	# Unlock the exit room (or spawn the stairs in the boss room)
	_spawn_exit()
	
	# Unlock the next hero if applicable
	_check_hero_unlocks()
	
	emit_signal("floor_completed")

func _spawn_exit():
	# Place the exit staircase in the boss room
	print("Exit spawned — descend to floor ", floor_number + 1)

func _check_hero_unlocks():
	if not has_node("/root/GameData"):
		return
	
	# Boss 1 kill → unlock all remaining heroes progressively
	var bosses_killed = GameData.current_run.get("bosses_killed", [])
	
	match floor_number:
		1: GameData.unlock_hero("Odin")
		2: GameData.unlock_hero("Loki")
		3: GameData.unlock_hero("Tyr")
		4: GameData.unlock_hero("Hel")

# ============================================================
# get_current_room_data() — getter for other scripts that need
# to know about the active room (e.g. the minimap, the HUD)
# ============================================================
func get_current_room_data() -> RoomData:
	if floor_layout and floor_layout.rooms.has(current_room_pos):
		return floor_layout.rooms[current_room_pos]
	return null
