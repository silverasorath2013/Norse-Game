extends Node2D

# ============================================================
# Game.gd
# ============================================================
# This is the ROOT scene of the actual game.
# Think of it as the "stage manager" — it doesn't do much
# itself but connects all the other systems together:
#
#   DungeonGenerator  →  RoomManager  →  Room
#                                    ↘  Minimap
#   GameData (Autoload)               ↘  HUD
#   Player                            ↘  Camera
#
# SCENE TREE:
#   Game.tscn
#   ├── RoomManager         (Room.gd — manages all rooms)
#   ├── Player              (Hero.gd — the player character)  
#   ├── HUD                 (CanvasLayer — drawn over everything)
#   │   ├── HealthBar
#   │   ├── Minimap         (Minimap.gd)
#   │   ├── ItemSlots       (4 rune slots)
#   │   └── GoldCounter
#   └── TransitionOverlay   (black ColorRect for fades)
# ============================================================

# --- REFERENCES ---
@onready var room_manager: Node2D = $RoomManager
@onready var minimap: Control = $HUD/Minimap
@onready var hud_health_bar: TextureProgressBar = $HUD/HealthBar
@onready var hud_gold_label: Label = $HUD/GoldCounter
@onready var player: CharacterBody2D = $Player

# Current floor number
var current_floor: int = 1
const MAX_FLOORS:   int = 5

# ============================================================
# _ready() — runs when the Game scene loads.
# This is where we kick everything off.
# ============================================================
func _ready():
	# Safety check — make sure GameData autoload exists
	if not has_node("/root/GameData"):
		push_error("GameData autoload not registered! Go to Project > Project Settings > Autoload")
		return
	
	# Set the player's hero based on what was chosen in character select
	_configure_player_from_selection()
	
	# Generate and load floor 1
	_start_floor(1)
	
	# Connect room manager signals to our handler functions
	room_manager.floor_completed.connect(_on_floor_completed)
	room_manager.minimap_updated.connect(_on_minimap_updated)
	
	print("Game started! Good luck, ", GameData.chosen_hero.get("name", "warrior"), "!")

# ============================================================
# _process() — runs every frame. Used for HUD updates.
# ============================================================
func _process(_delta: float):
	_update_hud()

# ============================================================
# _configure_player_from_selection() — reads the chosen hero
# from GameData and applies their stats to the Player node.
# ============================================================
func _configure_player_from_selection():
	if GameData.chosen_hero.is_empty():
		push_warning("No hero chosen — defaulting to Thor stats")
		return
	
	var hero = GameData.chosen_hero
	
	# Apply stats — these properties must exist on your Hero.gd script
	if player.has_method("setup_from_data"):
		player.call("setup_from_data", hero)
	else:
		# Directly set properties (Hero.gd has these as @export vars)
		player.hero_name = hero.get("name", "Unknown")
		player.max_health = hero.get("health", 100)
		player.current_health = player.max_health
	
	print("Player configured as: ", hero.get("name", "?"))

# ============================================================
# _start_floor() — generates a new floor and tells RoomManager to load it.
# ============================================================
func _start_floor(floor_num: int):
	current_floor = floor_num
	GameData.current_run["floor"] = floor_num
	
	print("=== ENTERING FLOOR ", floor_num, " ===")
	
	# RoomManager handles the generation and room loading
	room_manager.initialise_floor(floor_num)

# ============================================================
# _update_hud() — refreshes health bar and gold display
# Called every frame from _process()
# ============================================================
func _update_hud():
	if player == null:
		return
	
	# Update health bar
	if hud_health_bar:
		hud_health_bar.max_value = player.max_health
		hud_health_bar.value = player.current_health
	
	# Update gold
	if hud_gold_label:
		hud_gold_label.text = str(GameData.current_run.get("gold", 0)) + "g"

# ============================================================
# Signal handlers
# ============================================================

func _on_floor_completed():
	print("Floor ", current_floor, " complete!")
	if current_floor >= MAX_FLOORS:
		_trigger_victory()
		return
	await get_tree().create_timer(2.0).timeout
	_start_floor(current_floor + 1)

func _trigger_victory():
	print("[Game] All floors cleared — VICTORY!")
	if has_node("/root/GameData"):
		GameData.end_run(true, "")
	get_tree().change_scene_to_file("res://scenes/VictoryScreen.tscn")

func _on_minimap_updated(rooms: Dictionary):
	if minimap and minimap.has_method("update_minimap"):
		minimap.update_minimap(rooms, room_manager.current_room_pos)

# ============================================================
# pause_game() / resume_game() — for the pause menu
# ============================================================
func pause_game():
	get_tree().paused = true
	# Show pause menu UI

func resume_game():
	get_tree().paused = false
