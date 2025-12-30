extends Node2D

@onready var actors : Node2D = $Actors
@onready var tilemaps : Node2D = $Tilemaps
@onready var walls : TileMapLayer = $Tilemaps/Walls
@onready var highlights : TileMapLayer = $Tilemaps/Highlights

@export var highlight_source_id: int = 0            # TileSet source id to paint from
@export var highlight_atlas_pos: Vector2i = Vector2i(2, 5) # Atlas coords to use for tint

var friendly_units : Array[Actor] = []
var enemy_units : Array[Actor] = []
var active_unit : Actor = null

func _ready() -> void:
	_collect_units()
	if friendly_units.size() > 0:
		_set_active_unit(friendly_units[0])

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
	if active_unit and is_instance_valid(active_unit):
		active_unit.active = false
		active_unit.set_reachable_cells([])
	_clear_highlights()
	
	active_unit = unit
	active_unit.active = true
	
	var move_range: int = active_unit.stats.movement_range if active_unit.stats else 5
	var bounds: Rect2i = _get_map_bounds()
	var occupied := _build_occupancy()
	var reachable: Array[Vector2i] = _compute_reachable_cells(active_unit, move_range, bounds, occupied)
	
	active_unit.set_reachable_cells(reachable)
	_paint_highlights(reachable)

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

func _clear_highlights() -> void:
	highlights.clear()

func _paint_highlights(cells: Array[Vector2i]) -> void:
	if highlights.tile_set == null:
		return
	for cell in cells:
		highlights.set_cell(cell, highlight_source_id, highlight_atlas_pos)
