extends Node

# ============================================================
# DungeonGenerator.gd
# ============================================================
# This script generates a full floor layout, Isaac-style.
# 
# HOW ISAAC-STYLE GENERATION WORKS:
# 1. Start at a center "origin" room on a grid
# 2. Do a "random walk" — branch out in 4 directions (N/S/E/W)
# 3. Keep placing rooms until we hit our target room count
# 4. Tag special rooms: Boss, Shop, Treasure, Secret
# 5. Each room stores which doors it has (N/S/E/W)
#
# The result is a grid-map of rooms you can visualise like a minimap.
# ============================================================

# --- ROOM TYPES ---
# In GDScript, "enum" creates a named set of integer constants.
# RoomType.NORMAL == 0, RoomType.BOSS == 1, etc.
enum RoomType {
	NORMAL,      # Standard enemy room
	START,       # Where the player spawns
	BOSS,        # End-of-floor boss
	TREASURE,    # Guaranteed item room (Isaac's "item room")
	SHOP,        # Buy items with gold
	SECRET,      # Hidden room — no doors, accessed by bombing a wall
	CURSE,       # Norn's Bargain room (our custom mechanic)
	MINIBOSS,    # Mid-floor challenge room
	EXIT         # Staircase down to next floor (appears after boss dies)
}

# --- DIRECTION VECTORS ---
# We use Vector2i (integer Vector2) for grid positions.
# These are the 4 cardinal directions on our room grid.
const DIRECTIONS = {
	"north": Vector2i(0, -1),
	"south": Vector2i(0,  1),
	"east":  Vector2i(1,  0),
	"west":  Vector2i(-1, 0)
}

# Opposite of each direction — used to set matching doors
const OPPOSITE = {
	"north": "south",
	"south": "north",
	"east":  "west",
	"west":  "east"
}

# --- FLOOR SETTINGS ---
# How many rooms per floor, by floor number.
# Floor 1 = simpler, floor 5 = sprawling.
const ROOMS_PER_FLOOR = {
	1: 8,
	2: 10,
	3: 12,
	4: 14,
	5: 16
}

# The grid is 10x10. Rooms are placed on this grid.
# Grid position (5,5) = center = starting room.
const GRID_SIZE = 10
const GRID_CENTER = Vector2i(5, 5)

# ============================================================
# RoomData — a lightweight class to represent one room's data.
# In GDScript, inner classes are defined with "class" inside a script.
# ============================================================
class RoomData:
	var grid_pos: Vector2i         # Position on the 10x10 layout grid
	var room_type: int             # One of the RoomType enum values
	var doors: Dictionary          # {"north": true, "south": false, ...}
	var cleared: bool = false      # Has the player killed all enemies?
	var visited: bool = false      # Has the player entered this room?
	var enemy_count: int = 0       # How many enemies spawn here
	var layout_seed: int = 0       # Random seed for tile layout inside this room
	var special_tile_data: Array = [] # Obstacles, pits, decoration positions
	
	func _init(pos: Vector2i, type: int):
		grid_pos = pos
		room_type = type
		doors = {"north": false, "south": false, "east": false, "west": false}
	
	# Helper — returns a list of open door directions as strings
	func get_open_doors() -> Array:
		var open = []
		for dir in doors:
			if doors[dir]:
				open.append(dir)
		return open

# ============================================================
# THE MAIN GENERATOR CLASS
# ============================================================
class FloorLayout:
	var rooms: Dictionary = {}      # Key: Vector2i grid pos, Value: RoomData
	var floor_number: int = 1
	var start_room_pos: Vector2i
	var boss_room_pos: Vector2i
	var rng: RandomNumberGenerator  # Godot's built-in RNG class
	
	func _init(floor_num: int, seed_value: int = 0):
		floor_number = floor_num
		rng = RandomNumberGenerator.new()
		# If seed is 0, use a random seed (different every run)
		# If a seed is provided, the floor will always look the same — useful for testing!
		if seed_value == 0:
			rng.randomize()
		else:
			rng.seed = seed_value
	
	# ----------------------------------------------------------
	# generate() — the main entry point. Call this to build a floor.
	# Returns the completed FloorLayout (self).
	# ----------------------------------------------------------
	func generate() -> FloorLayout:
		var target_rooms = ROOMS_PER_FLOOR.get(floor_number, 10)
		
		# Step 1: Place the starting room at the grid center
		start_room_pos = GRID_CENTER
		_place_room(GRID_CENTER, RoomType.START)
		
		# Step 2: Random walk to fill the floor with normal rooms
		_random_walk(target_rooms - 1)  # -1 because START already placed
		
		# Step 3: Tag special rooms (boss, shop, treasure, secret)
		_assign_special_rooms()
		
		# Step 4: Connect rooms with doors
		_open_doors()
		
		# Step 5: Populate rooms (enemy counts, obstacle seeds)
		_populate_rooms()
		
		print("Floor ", floor_number, " generated: ", rooms.size(), " rooms")
		return self
	
	# ----------------------------------------------------------
	# _place_room() — adds a RoomData entry to our rooms dictionary
	# ----------------------------------------------------------
	func _place_room(pos: Vector2i, type: int = RoomType.NORMAL):
		if not rooms.has(pos):
			var room = RoomData.new(pos, type)
			room.layout_seed = rng.randi()  # Each room gets a unique random seed
			rooms[pos] = room
	
	# ----------------------------------------------------------
	# _random_walk() — the core layout algorithm.
	# Starts from placed rooms and branches outward randomly.
	# ----------------------------------------------------------
	func _random_walk(count: int):
		var attempts = 0
		var max_attempts = count * 20  # Safety limit so we don't loop forever
		
		while rooms.size() < count + 1 and attempts < max_attempts:
			attempts += 1
			
			# Pick a random already-placed room to branch from
			var existing_positions = rooms.keys()
			var branch_from: Vector2i = existing_positions[rng.randi() % existing_positions.size()]
			
			# Try a random direction from that room
			var dir_names = DIRECTIONS.keys()
			var dir_name: String = dir_names[rng.randi() % dir_names.size()]
			var dir_vec: Vector2i = DIRECTIONS[dir_name]
			var new_pos: Vector2i = branch_from + dir_vec
			
			# Validate the new position:
			# 1. Must be within the 10x10 grid
			# 2. Must not already be occupied
			# 3. Must not create a room that touches 3+ existing rooms
			#    (This prevents the map from clumping up)
			if _is_valid_room_position(new_pos):
				_place_room(new_pos, RoomType.NORMAL)
	
	# ----------------------------------------------------------
	# _is_valid_room_position() — checks if we CAN place a room at pos
	# ----------------------------------------------------------
	func _is_valid_room_position(pos: Vector2i) -> bool:
		# Must be within grid bounds
		if pos.x < 0 or pos.x >= GRID_SIZE or pos.y < 0 or pos.y >= GRID_SIZE:
			return false
		
		# Must not already exist
		if rooms.has(pos):
			return false
		
		# Count how many existing rooms are adjacent to this position
		# Isaac's algorithm avoids rooms touching more than 1 existing room
		# (except the one they're branching from) to keep things spread out
		var adjacent_count = 0
		for dir_vec in DIRECTIONS.values():
			if rooms.has(pos + dir_vec):
				adjacent_count += 1
		
		# Allow position only if it touches exactly 1 existing room
		# (The one we're branching FROM)
		return adjacent_count == 1
	
	# ----------------------------------------------------------
	# _assign_special_rooms() — labels certain rooms as boss/shop/etc.
	# ----------------------------------------------------------
	func _assign_special_rooms():
		# The BOSS room is the room farthest from the start
		boss_room_pos = _find_farthest_room()
		rooms[boss_room_pos].room_type = RoomType.BOSS
		
		# Collect all NORMAL rooms (excludes start and boss)
		var normal_rooms: Array = []
		for pos in rooms:
			if rooms[pos].room_type == RoomType.NORMAL:
				normal_rooms.append(pos)
		
		# Shuffle the list randomly
		normal_rooms.shuffle()
		
		# Assign special rooms in order (if we have enough normal rooms)
		var special_idx = 0
		
		if special_idx < normal_rooms.size():
			rooms[normal_rooms[special_idx]].room_type = RoomType.TREASURE
			special_idx += 1
		
		if special_idx < normal_rooms.size():
			rooms[normal_rooms[special_idx]].room_type = RoomType.SHOP
			special_idx += 1
		
		if special_idx < normal_rooms.size():
			rooms[normal_rooms[special_idx]].room_type = RoomType.MINIBOSS
			special_idx += 1
		
		# Curse room: only on floor 2+
		if floor_number >= 2 and special_idx < normal_rooms.size():
			rooms[normal_rooms[special_idx]].room_type = RoomType.CURSE
			special_idx += 1
		
		# Secret room: placed adjacent to many rooms but NOT in the main list
		# It's discovered separately — see _place_secret_room()
		_place_secret_room()
	
	# ----------------------------------------------------------
	# _find_farthest_room() — returns the grid position of the room
	# that is farthest (in steps) from the start room.
	# This becomes the boss room.
	# Uses BFS (Breadth-First Search) — a classic algorithm for
	# measuring distances on a grid.
	# ----------------------------------------------------------
	func _find_farthest_room() -> Vector2i:
		# BFS: we explore outward from start, level by level
		var visited_bfs: Dictionary = {}
		var queue: Array = [start_room_pos]
		var distances: Dictionary = {start_room_pos: 0}
		visited_bfs[start_room_pos] = true
		
		var farthest_pos = start_room_pos
		var max_dist = 0
		
		while not queue.is_empty():
			var current: Vector2i = queue.pop_front()
			
			for dir_vec in DIRECTIONS.values():
				var neighbor = current + dir_vec
				if rooms.has(neighbor) and not visited_bfs.has(neighbor):
					visited_bfs[neighbor] = true
					distances[neighbor] = distances[current] + 1
					queue.append(neighbor)
					
					# Track the farthest room we've seen
					if distances[neighbor] > max_dist:
						max_dist = distances[neighbor]
						farthest_pos = neighbor
		
		return farthest_pos
	
	# ----------------------------------------------------------
	# _place_secret_room() — finds a grid cell adjacent to 3+ rooms
	# that isn't already occupied. That becomes the secret room.
	# ----------------------------------------------------------
	func _place_secret_room():
		var best_pos: Vector2i = Vector2i(-1, -1)
		var best_neighbor_count = 0
		
		# Check every empty cell on the grid
		for x in range(GRID_SIZE):
			for y in range(GRID_SIZE):
				var pos = Vector2i(x, y)
				if rooms.has(pos):
					continue  # Skip occupied cells
				
				# Count how many rooms surround this empty cell
				var neighbor_count = 0
				for dir_vec in DIRECTIONS.values():
					if rooms.has(pos + dir_vec):
						neighbor_count += 1
				
				# Secret rooms are hidden in spots touching 3+ rooms
				if neighbor_count >= 3 and neighbor_count > best_neighbor_count:
					best_neighbor_count = neighbor_count
					best_pos = pos
		
		# If we found a valid secret room position, place it
		if best_pos != Vector2i(-1, -1):
			_place_room(best_pos, RoomType.SECRET)
			print("Secret room placed at: ", best_pos)
	
	# ----------------------------------------------------------
	# _open_doors() — for each room, check all 4 neighbors.
	# If a neighbor room exists, open a door between them.
	# SECRET rooms don't get automatic doors (you bomb the wall).
	# ----------------------------------------------------------
	func _open_doors():
		for pos in rooms:
			var room: RoomData = rooms[pos]
			
			# Secret rooms have no regular doors
			if room.room_type == RoomType.SECRET:
				continue
			
			for dir_name in DIRECTIONS:
				var dir_vec: Vector2i = DIRECTIONS[dir_name]
				var neighbor_pos = pos + dir_vec
				
				if rooms.has(neighbor_pos):
					var neighbor: RoomData = rooms[neighbor_pos]
					# Don't connect to secret rooms via normal doors
					if neighbor.room_type == RoomType.SECRET:
						continue
					
					# Open the door on both sides
					room.doors[dir_name] = true
					neighbor.doors[OPPOSITE[dir_name]] = true
	
	# ----------------------------------------------------------
	# _populate_rooms() — assigns enemy counts and obstacle seeds
	# based on room type and floor number.
	# ----------------------------------------------------------
	func _populate_rooms():
		for pos in rooms:
			var room: RoomData = rooms[pos]
			
			match room.room_type:
				RoomType.NORMAL:
					# Enemies scale with floor number
					room.enemy_count = rng.randi_range(2, 3 + floor_number)
					# Generate obstacle layout data
					room.special_tile_data = _generate_obstacle_data(room.layout_seed)
				
				RoomType.BOSS:
					room.enemy_count = 1  # Just the boss
				
				RoomType.MINIBOSS:
					room.enemy_count = 1
				
				RoomType.START, RoomType.TREASURE, RoomType.SHOP, RoomType.EXIT:
					room.enemy_count = 0  # Safe rooms
				
				RoomType.CURSE:
					# Curse rooms have extra enemies as the cost of the bargain
					room.enemy_count = rng.randi_range(4, 6 + floor_number)
	
	# ----------------------------------------------------------
	# _generate_obstacle_data() — uses a seed to decide where
	# rocks, pits, and pillars appear inside the 64x64 tile room.
	# Returns an Array of Dictionaries describing each obstacle.
	# ----------------------------------------------------------
	func _generate_obstacle_data(seed: int) -> Array:
		var local_rng = RandomNumberGenerator.new()
		local_rng.seed = seed
		
		var obstacles: Array = []
		
		# The playable area inside a room is roughly tiles 2-13 (leaving 1 tile border for walls)
		# We pick a random "layout template" and then sprinkle obstacles
		var template = local_rng.randi() % 5  # 5 possible templates
		
		match template:
			0:  # Four corner pillars (classic Isaac layout)
				for corner in [Vector2i(3,3), Vector2i(10,3), Vector2i(3,8), Vector2i(10,8)]:
					obstacles.append({"type": "pillar", "pos": corner})
			
			1:  # Central cross of rocks
				for offset in [Vector2i(0,0), Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
					obstacles.append({"type": "rock", "pos": Vector2i(6,5) + offset})
			
			2:  # Random scatter of rocks
				var rock_count = local_rng.randi_range(3, 7)
				for i in range(rock_count):
					var rx = local_rng.randi_range(2, 11)
					var ry = local_rng.randi_range(2, 9)
					obstacles.append({"type": "rock", "pos": Vector2i(rx, ry)})
			
			3:  # Pit hazards — stepping in them damages the player
				var pit_count = local_rng.randi_range(2, 5)
				for i in range(pit_count):
					var px = local_rng.randi_range(3, 10)
					var py = local_rng.randi_range(2, 9)
					obstacles.append({"type": "pit", "pos": Vector2i(px, py)})
			
			4:  # Mixed pillars and pits
				obstacles.append({"type": "pillar", "pos": Vector2i(4, 4)})
				obstacles.append({"type": "pillar", "pos": Vector2i(9, 4)})
				obstacles.append({"type": "pit", "pos": Vector2i(6, 6)})
				obstacles.append({"type": "pit", "pos": Vector2i(7, 6)})
		
		return obstacles


# ============================================================
# PUBLIC API — How other scripts use this generator
# ============================================================

# Store the current floor's generated layout
var current_floor: FloorLayout = null

# generate_floor() — Call this from your Game.gd scene to build a new floor
func generate_floor(floor_number: int, seed: int = 0) -> FloorLayout:
	current_floor = FloorLayout.new(floor_number, seed)
	current_floor.generate()
	return current_floor

# get_room(pos) — shorthand to fetch a room by grid position
func get_room(pos: Vector2i) -> RoomData:
	if current_floor and current_floor.rooms.has(pos):
		return current_floor.rooms[pos]
	return null

# get_start_room() — returns the starting room
func get_start_room() -> RoomData:
	if current_floor:
		return current_floor.rooms[current_floor.start_room_pos]
	return null
