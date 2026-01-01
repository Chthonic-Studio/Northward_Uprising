extends Node2D

signal active_unit_changed(unit: Actor) # Fires when active unit is set/cleared
signal hovered_actor_changed(actor: Actor) # Fires when cursor hover changes

@onready var actors: Node2D = $Actors
@onready var tilemaps: Node2D = $Tilemaps
@onready var walls: TileMapLayer = $Tilemaps/Walls
@onready var highlights: TileMapLayer = $Tilemaps/Highlights
@onready var grid_cursor: Node2D = $GridCursor # Used to pick units under cursor
@onready var gui: CanvasLayer = $GUI

@export var highlight_source_id: int = 0              # TileSet source id to paint from
@export var highlight_atlas_pos: Vector2i = Vector2i(2, 5) # Atlas coords to use for tint

@export_range(0, 400) var top_ui_gutter: int = 40     # Vertical space reserved for top GUI
@export_range(0, 400) var bottom_ui_gutter: int = 40 

var friendly_units: Array[Actor] = []
var enemy_units: Array[Actor] = []
var active_unit: Actor = null
var hovered_actor: Actor = null # Tracks last hovered actor to avoid duplicate emits

# Global A* graph for all non-wall tiles
var astar_map: AStar2D = AStar2D.new()
var cell_to_id: Dictionary = {}
var id_counter: int = 0

func _ready() -> void:
	_collect_units()
	_build_astar_grid()
	print("AStar nodes=", astar_map.get_point_count(), " map_bounds=", _get_map_bounds())
	
	#position.y = top_ui_gutter
	
	if grid_cursor and grid_cursor.has_signal("moved"):
		grid_cursor.moved.connect(_on_grid_cursor_moved)
	if friendly_units.size() > 0:
		_set_active_unit(friendly_units[0])
	else:
		GUIManager.set_active_actor(null)
	GUIManager.set_highlighted_actor(null)

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
	if active_unit == null: # Removed "or grid_cursor == null" check as we use mouse pos now
		return
	
	if !active_unit.position.is_equal_approx(active_unit.position_target):
		return
		
	var cursor_cell: Vector2i = _world_to_cell(get_global_mouse_position())
	var current_target: Vector2i = active_unit.cells_travelled.back()
	
		# TEMP DEBUG: log click, reachable, and path result
	var is_reachable: bool = cursor_cell in active_unit.reachable_cells
	var path_dbg: Array[Vector2i] = []
	if is_reachable:
		path_dbg = _compute_astar_path(
			active_unit.origin_cell,
			cursor_cell,
			active_unit.reachable_cells,
			active_unit.stats.movement_range if active_unit.stats else 5,
			_build_occupancy(),
			active_unit.is_friendly
		)
	print("CLICK cell=", cursor_cell,
		" reachable=", is_reachable,
		" path_len=", path_dbg.size(),
		" origin=", active_unit.origin_cell,
		" current_target=", current_target)
	
	# If auto-walking and player clicks again:
	# - Same destination: ignore until arrival (prevents double-click cancel)
	# - Different destination: snap back to origin, then re-plan from origin
	if active_unit.is_autopiloting():
		var planned_dest: Vector2i = active_unit.get_planned_destination()
		if cursor_cell == planned_dest:
			return # Let the current autopilot finish
		active_unit.cancel_move_to_origin() # Reset path so new request starts clean
	
	# If cursor is on the planned destination, confirm
	if cursor_cell == current_target:
		_confirm_active_unit_move()
		return
	
	
	
	# If cursor is reachable, plan an A* path and auto-walk (keep active)
	if cursor_cell in active_unit.reachable_cells:
		var start_cell: Vector2i = active_unit.origin_cell # Always plan from origin, Fire Emblem style
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
	var cell: Vector2i = _world_to_cell(grid_cursor.global_position)
	for unit in friendly_units:
		if not is_instance_valid(unit):
			continue
		if _world_to_cell(unit.global_position) == cell:
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
	if active_unit == null:
		active_unit_changed.emit(null)
		GUIManager.set_active_actor(null)
		return
	
	active_unit.set_origin_cell(_world_to_cell(active_unit.global_position))
	active_unit.active = true
	active_unit.moved_to_cell.connect(_on_active_unit_moved_cell)
	
	var move_range: int = active_unit.stats.movement_range if active_unit.stats else 5
	var bounds: Rect2i = _get_map_bounds()
	var occupied := _build_occupancy()
	var reachable: Array[Vector2i] = _compute_reachable_cells(active_unit, move_range, bounds, occupied)
	
	active_unit.set_reachable_cells(reachable)
	_paint_highlights(reachable)
	_on_active_unit_moved_cell(_world_to_cell(active_unit.global_position))
	active_unit_changed.emit(active_unit)
	GUIManager.set_active_actor(active_unit)

func _confirm_active_unit_move() -> void:
	if active_unit == null:
		return
	if !active_unit.position.is_equal_approx(active_unit.position_target):
		return
	if active_unit.is_connected("moved_to_cell", Callable(self, "_on_active_unit_moved_cell")):
		active_unit.disconnect("moved_to_cell", Callable(self, "_on_active_unit_moved_cell"))
	active_unit.finalize_move()
	active_unit.active = false
	active_unit.set_reachable_cells([])
	_clear_highlights()
	active_unit = null
	active_unit_changed.emit(null)
	GUIManager.set_active_actor(null)

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
		active_unit_changed.emit(null)
		GUIManager.set_active_actor(null)
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
			var cell := _world_to_cell(child.global_position) # Floor convert for consistent blocking
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
			# BIDIRECTIONAL ON PURPOSE: without this, edges become one-way and paths fail to up/left tiles
			astar_map.connect_points(id, nid, true)

func _compute_reachable_cells(unit: Actor, move_range: int, bounds: Rect2i, occupied: Dictionary) -> Array[Vector2i]:
	var reachable: Array[Vector2i] = []
	var best_cost: Dictionary = {}
	var start: Vector2i = _world_to_cell(unit.global_position)
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

func _world_to_cell(pos: Vector2) -> Vector2i:
	# Floor-based world->grid mapping; fixes clicks on tiles left/up of origin
	return Vector2i(floor(pos.x / Globals.CELL_SIZE.x), floor(pos.y / Globals.CELL_SIZE.y))

func _on_grid_cursor_moved(pos: Vector2) -> void:
	# Update hovered actor when cursor moves
	var cell: Vector2i = _world_to_cell(pos)
	var found: Actor = _find_actor_at_cell(cell)
	if found == hovered_actor:
		return
	hovered_actor = found
	hovered_actor_changed.emit(hovered_actor)
	GUIManager.set_highlighted_actor(hovered_actor)

func _find_actor_at_cell(cell: Vector2i) -> Actor:
	# Returns any actor located at the grid cell
	for child in actors.get_children():
		if child is Actor:
			if _world_to_cell(child.global_position) == cell:
				return child
	return null
