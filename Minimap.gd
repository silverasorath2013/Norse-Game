extends Control

# ============================================================
# Minimap.gd
# ============================================================
# Draws the HUD minimap — a small grid of coloured squares
# in the corner of the screen, exactly like Isaac's minimap.
#
# HOW IT WORKS:
# - Listens for the minimap_updated signal from RoomManager
# - Receives the rooms Dictionary from the floor layout
# - In _draw(), paints a small square for each room
# - Colour indicates room type (grey=normal, red=boss, gold=treasure, etc.)
# - Unvisited rooms appear as a dim outline only
# ============================================================

# --- MINIMAP VISUAL SETTINGS ---
const CELL_SIZE   = 8    # Each room is 8×8 pixels on the minimap
const CELL_GAP    = 2    # 2px gap between room cells
const MAP_OFFSET  = Vector2(8, 8)  # Padding from top-left of this Control

# Colour scheme for each room type — dark Norse palette
const ROOM_COLORS = {
	DungeonGenerator.RoomType.NORMAL:    Color(0.5, 0.5, 0.55),   # Stone grey
	DungeonGenerator.RoomType.START:     Color(0.3, 0.7, 0.4),    # Green
	DungeonGenerator.RoomType.BOSS:      Color(0.85, 0.2, 0.2),   # Blood red
	DungeonGenerator.RoomType.TREASURE:  Color(0.9, 0.75, 0.2),   # Gold
	DungeonGenerator.RoomType.SHOP:      Color(0.3, 0.6, 0.9),    # Blue
	DungeonGenerator.RoomType.SECRET:    Color(0.5, 0.2, 0.7),    # Purple
	DungeonGenerator.RoomType.CURSE:     Color(0.6, 0.1, 0.6),    # Dark purple
	DungeonGenerator.RoomType.MINIBOSS:  Color(0.8, 0.45, 0.1),   # Orange
	DungeonGenerator.RoomType.EXIT:      Color(0.2, 0.9, 0.6),    # Teal/cyan
}

const COLOR_OUTLINE   = Color(0.3, 0.3, 0.35, 0.7)  # Unvisited room outline
const COLOR_CURRENT   = Color(1.0, 1.0, 1.0, 1.0)    # White border on current room
const COLOR_CLEARED   = Color(0.0, 0.0, 0.0, 0.3)    # Dark overlay for cleared rooms
const COLOR_BG        = Color(0.05, 0.05, 0.08, 0.85) # Minimap background panel

# --- STATE ---
var rooms_data: Dictionary = {}        # Reference to the floor layout rooms dict
var current_pos: Vector2i = Vector2i(-1, -1)  # Grid pos of room player is in
var grid_bounds: Rect2i = Rect2i(0, 0, 10, 10)  # Bounding box of room positions

# ============================================================
# update_minimap() — called by RoomManager when the layout changes
# or the player moves.
# ============================================================
func update_minimap(rooms: Dictionary, player_pos: Vector2i):
	rooms_data = rooms
	current_pos = player_pos
	
	# Calculate the bounding box of all rooms so we can center the minimap
	if not rooms.is_empty():
		var min_x = 999; var max_x = -999
		var min_y = 999; var max_y = -999
		for pos in rooms:
			min_x = min(min_x, pos.x); max_x = max(max_x, pos.x)
			min_y = min(min_y, pos.y); max_y = max(max_y, pos.y)
		grid_bounds = Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
	
	# queue_redraw() tells Godot to call _draw() again next frame
	queue_redraw()

# ============================================================
# _draw() — Godot calls this automatically when queue_redraw() fires.
# Everything drawn here appears on screen.
# ============================================================
func _draw():
	if rooms_data.is_empty():
		return
	
	# Calculate the total pixel size of the minimap
	var map_pixel_width  = grid_bounds.size.x * (CELL_SIZE + CELL_GAP)
	var map_pixel_height = grid_bounds.size.y * (CELL_SIZE + CELL_GAP)
	
	# Draw semi-transparent background panel
	var panel_rect = Rect2(
		MAP_OFFSET.x - 4,
		MAP_OFFSET.y - 4,
		map_pixel_width + 8,
		map_pixel_height + 8
	)
	draw_rect(panel_rect, COLOR_BG)
	
	# Draw each room as a coloured rectangle
	for grid_pos in rooms_data:
		var room: RoomData = rooms_data[grid_pos]
		
		# Calculate the pixel position of this room on the minimap
		# We offset by grid_bounds.position so the map starts at (0,0)
		var local_x = (grid_pos.x - grid_bounds.position.x) * (CELL_SIZE + CELL_GAP)
		var local_y = (grid_pos.y - grid_bounds.position.y) * (CELL_SIZE + CELL_GAP)
		var cell_rect = Rect2(
			MAP_OFFSET.x + local_x,
			MAP_OFFSET.y + local_y,
			CELL_SIZE,
			CELL_SIZE
		)
		
		# SECRET rooms: only shown if player has visited an adjacent room
		if room.room_type == DungeonGenerator.RoomType.SECRET:
			if not _is_secret_room_hinted(grid_pos):
				continue  # Skip drawing entirely
		
		if room.visited:
			# Draw filled, coloured cell for visited rooms
			var room_color = ROOM_COLORS.get(room.room_type, Color.GRAY)
			draw_rect(cell_rect, room_color)
			
			# Overlay a dark tint if the room has been cleared
			if room.cleared:
				draw_rect(cell_rect, COLOR_CLEARED)
			
			# Draw door connectors (thin lines linking adjacent rooms)
			_draw_door_connectors(grid_pos, room, local_x, local_y)
		
		else:
			# Unvisited: just a dim outline so the player can see the shape
			draw_rect(cell_rect, COLOR_OUTLINE, false, 1.0)
		
		# Highlight current room with a white border
		if grid_pos == current_pos:
			draw_rect(cell_rect, COLOR_CURRENT, false, 1.5)
			# Draw a tiny white dot in the centre to show player position
			draw_circle(
				Vector2(cell_rect.position.x + CELL_SIZE / 2, cell_rect.position.y + CELL_SIZE / 2),
				1.5,
				Color.WHITE
			)

# ============================================================
# _draw_door_connectors() — draws tiny lines between adjacent
# visited rooms to show the connections clearly.
# ============================================================
func _draw_door_connectors(grid_pos: Vector2i, room: RoomData, lx: float, ly: float):
	var half = CELL_SIZE / 2.0
	var connector_color = Color(0.7, 0.7, 0.75, 0.9)
	
	var open_doors = room.get_open_doors()
	
	for dir in open_doors:
		var neighbor_pos = grid_pos + DungeonGenerator.DIRECTIONS[dir]
		
		# Only draw connector if neighbor is also visited
		if rooms_data.has(neighbor_pos) and rooms_data[neighbor_pos].visited:
			var start_x = MAP_OFFSET.x + lx + half
			var start_y = MAP_OFFSET.y + ly + half
			
			match dir:
				"north":
					draw_line(
						Vector2(start_x, MAP_OFFSET.y + ly),
						Vector2(start_x, MAP_OFFSET.y + ly - CELL_GAP),
						connector_color, 2.0
					)
				"south":
					draw_line(
						Vector2(start_x, MAP_OFFSET.y + ly + CELL_SIZE),
						Vector2(start_x, MAP_OFFSET.y + ly + CELL_SIZE + CELL_GAP),
						connector_color, 2.0
					)
				"east":
					draw_line(
						Vector2(MAP_OFFSET.x + lx + CELL_SIZE, start_y),
						Vector2(MAP_OFFSET.x + lx + CELL_SIZE + CELL_GAP, start_y),
						connector_color, 2.0
					)
				"west":
					draw_line(
						Vector2(MAP_OFFSET.x + lx, start_y),
						Vector2(MAP_OFFSET.x + lx - CELL_GAP, start_y),
						connector_color, 2.0
					)

# ============================================================
# _is_secret_room_hinted() — checks if the player has been
# adjacent to a secret room (which reveals it on the minimap
# as a purple outline, encouraging them to look for the wall to bomb)
# ============================================================
func _is_secret_room_hinted(secret_pos: Vector2i) -> bool:
	for dir_vec in DungeonGenerator.DIRECTIONS.values():
		var neighbor = secret_pos + dir_vec
		if rooms_data.has(neighbor) and rooms_data[neighbor].visited:
			return true
	return false
