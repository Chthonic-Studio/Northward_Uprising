extends Node2D

@onready var actors : Node2D = $Actors
@onready var tilemap_walls: TileMapLayer = $Tilemaps/Walls
@onready var tilemap_highlights: TileMapLayer = $Tilemaps/Highlights

# We need a reference to know which tile ID to use for highlighting
# Ideally, this comes from a dedicated UI tileset, but we'll use a placeholder coords
const HIGHLIGHT_ATLAS_COORDS: Vector2i = Vector2i(0, 0) # Change this to a valid tile in your set!
const HIGHLIGHT_SOURCE_ID: int = 0 # Change if your source ID differs

var active_unit: Actor = null

func _ready() -> void:
	# Initialize first unit as active for testing, similar to previous code
	if actors.get_child_count() > 0:
		select_unit(actors.get_child(0))

func _unhandled_input(event: InputEvent) -> void:
	# Handle confirming movement with "ui_accept" (Space/Enter) or Click
	if active_unit and active_unit.active:
		if event.is_action_pressed("ui_accept"):
			confirm_movement()

func select_unit(unit: Actor) -> void:
	# Deselect previous if exists
	if active_unit:
		active_unit.active = false
		tilemap_highlights.clear()
	
	active_unit = unit
	active_unit.active = true
	
	# Calculate valid movement tiles
	var start_pos_grid = Vector2i(unit.position / Globals.CELL_SIZE)
	var move_range = unit.stats.movement_range
	var valid_tiles = get_bfs_move_area(start_pos_grid, move_range)
	
	# Pass valid tiles to the unit so it knows where it can draw paths
	# We convert Vector2i back to Vector2 for the Actor script compatibility
	var valid_moves_vec2: Array[Vector2] = []
	for tile in valid_tiles:
		valid_moves_vec2.append(Vector2(tile))
	
	active_unit.valid_moves = valid_moves_vec2
	
	# Draw highlights
	draw_highlights(valid_tiles)

func confirm_movement() -> void:
	if active_unit:
		active_unit.move_unit()
		tilemap_highlights.clear()

# Breadth-First Search to find all reachable tiles
func get_bfs_move_area(start_point: Vector2i, max_steps: int) -> Array[Vector2i]:
	var reachable: Array[Vector2i] = []
	var queue: Array = [] # Stores [current_pos, steps_remaining]
	var visited: Dictionary = {} # Stores visited coords to prevent loops
	
	queue.append([start_point, max_steps])
	visited[start_point] = true
	reachable.append(start_point)
	
	while queue.size() > 0:
		var current_data = queue.pop_front()
		var current_pos: Vector2i = current_data[0]
		var steps: int = current_data[1]
		
		if steps <= 0:
			continue
			
		# Check neighbors (Up, Down, Left, Right)
		var neighbors = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
		
		for dir in neighbors:
			var next_pos = current_pos + dir
			
			if visited.has(next_pos):
				continue
				
			# Check collisions (Walls)
			# Assuming walls are on a specific layer or have collision data
			# Here we check if the wall tilemap has a tile at this location
			if tilemap_walls.get_cell_source_id(next_pos) != -1:
				continue
				
			# Check for other units (blocking)
			if is_occupied_by_enemy(next_pos):
				continue
				
			visited[next_pos] = true
			reachable.append(next_pos)
			queue.append([next_pos, steps - 1])
			
	return reachable

func draw_highlights(tiles: Array[Vector2i]) -> void:
	tilemap_highlights.clear()
	for tile in tiles:
		tilemap_highlights.set_cell(tile, HIGHLIGHT_SOURCE_ID, HIGHLIGHT_ATLAS_COORDS)

# Helper to check if a tile is occupied by a unit
func is_occupied_by_enemy(grid_pos: Vector2i) -> bool:
	# Convert grid to world for distance check, or loop through actors
	# This is a basic implementation; optimization would use a dictionary registry of unit positions
	for child in actors.get_children():
		if child is Actor and child != active_unit and not child.is_friendly:
			var child_grid = Vector2i(child.position / Globals.CELL_SIZE)
			if child_grid == grid_pos:
				return true
	return false

func _on_grid_cursor_moved(position: Vector2) -> void:
	pass 
