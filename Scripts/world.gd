extends Node2D

@onready var actors: Node2D = $Actors
@onready var tilemaps: Node2D = $Tilemaps
@onready var walls: TileMapLayer = $Tilemaps/Walls
@onready var highlights: TileMapLayer = $Tilemaps/Highlights
@onready var grid_cursor: Node2D = $GridCursor # Used to pick units under cursor

@export var highlight_source_id: int = 0              # TileSet source id to paint from
@export var highlight_atlas_pos: Vector2i = Vector2i(2, 5) # Atlas coords to use for tint

var friendly_units: Array[Actor] = []
var enemy_units: Array[Actor] = []
var active_unit: Actor = null

# Global A* graph for all non-wall tiles
var astar_map: AStar2D = AStar2D.new()
var cell_to_id: Dictionary = {}
var id_counter: int = 0

func _ready() -> void:
	_collect_units()
	_build_astar_grid()
	if friendly_units.size() > 0:
		_set_active_unit(friendly_units[0])

func _unhandled_input(event: InputEvent) -> void:
	var action_pressed: bool = event.is_action_pressed("action")
	var back_pressed: bool = event.is_action_pressed("back")
	
	if active_unit != null:
		if action_pressed:
			_handle_action_with_active_unit()
			get_viewport().set_input_as_handled()
		elif back_pressed:
			_cancel_active_unit_move()
			get_viewport().set_input_as_handled()
	else:
		if action_pressed:
			var pick := _pick_friendly_at_cursor()
			if pick != null:
				_set_active_unit(pick)
				get_viewport().set_input_as_handled()

func _handle_action_with_active_unit() -> void:
	if active_unit == null or grid_cursor == null:
		return
	
	var cursor_cell: Vector2i = Vector2i(grid_cursor.global_position / Globals.CELL_SIZE)
	var current_target: Vector2i = active_unit.cells_travelled.back()
	
	# If cursor is on the planned destination, confirm
	if cursor_cell == current_target:
		_confirm_active_unit_move()
		return
	
	# If cursor is reachable, plan an A* path and auto-walk (keep active)
	if cursor_cell in active_unit.reachable_cells:
		var start_cell: Vector2i = Vector2i(active_unit.global_position / Globals.CELL_SIZE)
		var move_range: int = active_unit.stats.movement_range if active_unit.stats else 5
		var occupied := _build_occupancy()
		var path: Array[Vector2i] = _compute_astar_path(start_cell, cursor_cell, active_unit.reachable_cells, move_range, occupied, active_unit.is_friendly)
		if path.size() > 1:
			active_unit.set_autopilot_path(path)
		return
	# If unreachable: do nothing

func _pick_friendly_at_cursor() -> Actor:
	if grid_cursor == null:
		return null
	var cell: Vector2i = Vector2i(grid_cursor.global_position / Globals.CELL_SIZE)
	for unit in friendly_units:
		if not is_instance_valid(unit):
			continue
		if Vector2i(unit.global_position / Globals.CELL_SIZE) == cell:
			return unit
	return null

func _collect_units() -> void:
	friendly_units.clear()
	enemy_units.clear()
	for child in actors.get_children():
		if child is Actor:
			if child.is_friendly:
				friendly_units.append(child)
			else:
				enemy_units.append(child)

func _set_active_unit(unit: Actor) -> void:
	# Disconnect old
	if active_unit and is_instance_valid(active_unit):
		if active_unit.is_connected("moved_to_cell", Callable(self, "_on_active_unit_moved_cell")):
			active_unit.disconnect("moved_to_cell", Callable(self, "_on_active_unit_moved_cell"))
		active_unit.active = false
		active_unit.set_reachable_cells([])
	_clear_highlights()
	
	active_unit = unit
	active_unit.set_origin_cell(Vector2i(active_unit.global_position / Globals.CELL_SIZE))
	active_unit.active = true
	active_unit.moved_to_cell.connect(_on_active_unit_moved_cell)
	
	var move_range: int = active_unit.stats.movement_range if active_unit.stats else 5
	var bounds: Rect2i = _get_map_bounds()
	var occupied := _build_occupancy()
	var reachable: Array[Vector2i] = _compute_reachable_cells(active_unit, move_range, bounds, occupied)
	
	active_unit.set_reachable_cells(reachable)
	_paint_highlights(reachable)
	_on_active_unit_moved_cell(Vector2i(active_unit.global_position / Globals.CELL_SIZE))

func _confirm_active_unit_move() -> void:
	if active_unit == null:
		return
	if active_unit.is_connected("moved_to_cell", Callable(self, "_on_active_unit_moved_cell")):
		active_unit.disconnect("moved_to_cell", Callable(self, "_on_active_unit_moved_cell"))
	active_unit.finalize_move()
	active_unit.active = false
	active_unit.set_reachable_cells([])
	_clear_highlights()
	active_unit = null

func _cancel_active_unit_move() -> void:
	if active_unit == null:
		return
	
	var at_origin: bool = active_unit.cells_travelled.size() <= 1
	if at_origin:
		if active_unit.is_connected("moved_to_cell", Callable(self, "_on_active_unit_moved_cell")):
			active_unit.disconnect("moved_to_cell", Callable(self, "_on_active_unit_moved_cell"))
		active_unit.cancel_move_to_origin()
		active_unit.active = false
		active_unit.set_reachable_cells([])
		_clear_highlights()
		active_unit = null
	else:
		active_unit.cancel_move_to_origin()
		# Keep active; range + highlights remain.

func _on_active_unit_moved_cell(cell: Vector2i) -> void:
	# Snap grid cursor to the unit's current planned cell
	if grid_cursor != null:
		grid_cursor.global_position = Vector2(cell) * Globals.CELL_SIZE

# --- Map / Graph helpers ---

func _get_map_bounds() -> Rect2i:
	var merged: Rect2i = Rect2i()
	var has_rect: bool = false
	for child in tilemaps.get_children():
		if child is TileMapLayer:
			var r: Rect2i = child.get_used_rect()
			if r.size == Vector2i.ZERO:
				continue
			if has_rect:
				merged = merged.merge(r)
			else:
				merged = r
				has_rect = true
	if not has_rect:
		merged = Rect2i(
			Vector2i.ZERO,
			Vector2i(int(Globals.GAME_SIZE.x / Globals.CELL_SIZE.x), int(Globals.GAME_SIZE.y / Globals.CELL_SIZE.y))
		)
	return merged

func _build_occupancy() -> Dictionary:
	var occupied: Dictionary = {}
	for child in actors.get_children():
		if child is Actor:
			var cell := Vector2i(child.global_position / Globals.CELL_SIZE)
			occupied[cell] = child
	return occupied

func _is_wall(cell: Vector2i) -> bool:
	return walls.get_cell_tile_data(cell) != null

func _tile_cost(_cell: Vector2i) -> int:
	return 1 # Placeholder for future terrain cost

func _build_astar_grid() -> void:
	# Build reusable graph on all non-wall tiles
	astar_map = AStar2D.new()
	cell_to_id.clear()
	id_counter = 0
	var bounds: Rect2i = _get_map_bounds()
	for y in range(bounds.position.y, bounds.position.y + bounds.size.y):
		for x in range(bounds.position.x, bounds.position.x + bounds.size.x):
			var cell := Vector2i(x, y)
			if _is_wall(cell):
				continue
			cell_to_id[cell] = id_counter
			astar_map.add_point(id_counter, Vector2(cell))
			id_counter += 1
	# Connect 4-dir neighbors
	for cell in cell_to_id.keys():
		var id: int = cell_to_id[cell]
		for dir in Vectors.get_four_directions():
			var nxt: Vector2i = cell + Vector2i(dir)
			if not cell_to_id.has(nxt):
				continue
			var nid: int = cell_to_id[nxt]
			if not astar_map.are_points_connected(id, nid):
				astar_map.connect_points(id, nid, false)

func _compute_reachable_cells(unit: Actor, move_range: int, bounds: Rect2i, occupied: Dictionary) -> Array[Vector2i]:
	var reachable: Array[Vector2i] = []
	var best_cost: Dictionary = {}
	var start: Vector2i = Vector2i(unit.global_position / Globals.CELL_SIZE)
	var queue: Array = []
	queue.append({ "cell": start, "cost": 0 })
	best_cost[start] = 0
	
	while queue.size() > 0:
		var current = queue.pop_front()
		var cell: Vector2i = current["cell"]
		var cost: int = current["cost"]
		
		for dir in Vectors.get_four_directions():
			var next: Vector2i = cell + Vector2i(dir)
			if not bounds.has_point(next):
				continue
			if _is_wall(next):
				continue
			
			var occupant: Actor = occupied.get(next, null)
			var is_enemy: bool = occupant != null and occupant.is_friendly != unit.is_friendly
			var is_friendly_block: bool = occupant != null and occupant.is_friendly == unit.is_friendly and occupant != unit
			if is_enemy:
				continue
			
			var step_cost: int = cost + _tile_cost(next)
			if step_cost > move_range:
				continue
			if best_cost.has(next) and best_cost[next] <= step_cost:
				continue
			
			best_cost[next] = step_cost
			queue.append({ "cell": next, "cost": step_cost })
			if not is_friendly_block:
				reachable.append(next)
	
	if not start in reachable:
		reachable.append(start)
	return reachable

func _compute_astar_path(start: Vector2i, goal: Vector2i, reachable: Array[Vector2i], move_range: int, occupied: Dictionary, is_friendly: bool) -> Array[Vector2i]:
	# Use global graph, then validate against reachability, range, and occupancy
	if not cell_to_id.has(goal) or not cell_to_id.has(start):
		return []
	var start_id: int = cell_to_id[start]
	var goal_id: int = cell_to_id[goal]
	var path_vec2: PackedVector2Array = astar_map.get_point_path(start_id, goal_id)
	var path: Array[Vector2i] = []
	for p in path_vec2:
		path.append(Vector2i(p))
	if path.size() == 0:
		return []
	# Steps = nodes - 1
	if path.size() - 1 > move_range:
		return []
	# Validate occupancy and reachability: enemies block; cannot end on any occupied; friendly can be traversed
	for i in range(path.size()):
		var cell: Vector2i = path[i]
		var occ: Actor = occupied.get(cell, null)
		var is_goal: bool = (i == path.size() - 1)
		if occ != null:
			if occ.is_friendly != is_friendly:
				return [] # enemy anywhere blocks
			if is_goal:
				return [] # cannot end on occupied tile
			# friendly and not goal: allowed to pass through
		if is_goal and not cell in reachable:
			return [] # goal must be in reachable set
	return path

func _clear_highlights() -> void:
	highlights.clear()

func _paint_highlights(cells: Array[Vector2i]) -> void:
	if highlights.tile_set == null:
		return
	for cell in cells:
		highlights.set_cell(cell, highlight_source_id, highlight_atlas_pos)
