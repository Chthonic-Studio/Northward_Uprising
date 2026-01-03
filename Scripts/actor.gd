class_name Actor extends CharacterBody2D

signal moved_to_cell(cell: Vector2i) # Emits whenever the planned/current cell changes

@onready var input_delay: Timer = $InputDelay
@onready var position_target: Vector2 = position
@onready var sprite: Sprite2D = $Sprite

const FRIENDLY_COLOR: Color = Color("23ff1e")
const ENEMY_COLOR: Color = Color("d94141")

@export var stats: UnitResource = null
@export var current_health: int = -1

var origin_cell: Vector2i = Vector2i.ZERO # Starting cell before planning a move
var cells_travelled: Array[Vector2i] = [] # Planned path cells (grid coords)
var reachable_cells: Array[Vector2i] = [] # Cells this unit may enter this turn
var autopilot_path: Array[Vector2i] = [] # Remaining steps when auto-moving
var input_locked: bool = false # When true, ignores manual input (menus, cutscenes)

var active: bool = false:
	set(value):
		active = value
		if active:
			origin_cell = _world_to_cell(position) # Floor convert so negatives map correctly
			cells_travelled.clear()
			cells_travelled.append(origin_cell)
			autopilot_path.clear()
			_emit_current_cell()
			queue_redraw()
		else:
			cells_travelled.clear()
			autopilot_path.clear()
			queue_redraw()

@export var is_friendly: bool = false:
	set(value):
		if sprite == null:
			sprite = $Sprite
		is_friendly = value
		if is_friendly:
			sprite.self_modulate = FRIENDLY_COLOR
			name = "ActorPlayer"
			set_collision_layer_value(2, true)
			set_collision_layer_value(3, false)
		else:
			sprite.self_modulate = ENEMY_COLOR
			name = "ActorEnemy"
			set_collision_layer_value(2, false)
			set_collision_layer_value(3, true)

func _ready() -> void:
	is_friendly = is_friendly
	if sprite == null:
		sprite = $Sprite
	if current_health < 0 and stats:
		current_health = stats.max_health

func get_max_health() -> int:
	return stats.max_health if stats else 1

func set_origin_cell(cell: Vector2i) -> void:
	origin_cell = cell

func set_reachable_cells(cells: Array[Vector2i]) -> void:
	reachable_cells = cells.duplicate()

func set_autopilot_path(path: Array[Vector2i]) -> void:
	# Path must include current cell first
	if path.is_empty():
		return
	cells_travelled = path.duplicate() # Keep full path for drawing/backtracking
	autopilot_path = path.duplicate()
	autopilot_path.pop_front() # Remove current cell
	_emit_current_cell()
	# Start first leg immediately if idle
	if autopilot_path.size() > 0 and position.is_equal_approx(position_target):
		var next_cell: Vector2i = autopilot_path.pop_front()
		position_target = Vector2(next_cell) * Globals.CELL_SIZE
		input_delay.start()

func cancel_move_to_origin() -> void:
	position = Vector2(origin_cell) * Globals.CELL_SIZE
	position_target = position
	cells_travelled.clear()
	cells_travelled.append(origin_cell)
	autopilot_path.clear()
	input_delay.stop() # Ensure no leftover delay blocks new input after cancel
	_emit_current_cell()
	queue_redraw()

# Helper: returns true when auto-walking a planned path
func is_autopiloting() -> bool:
	return autopilot_path.size() > 0

# Helper: returns last planned cell (used to ignore duplicate clicks mid-path)
func get_planned_destination() -> Vector2i:
	return cells_travelled.back() if cells_travelled.size() > 0 else Vector2i(position / Globals.CELL_SIZE)

func finalize_move() -> void:
	origin_cell = _world_to_cell(position) # Floor convert on finalize for consistency
	autopilot_path.clear()

func _process(_delta: float) -> void:
	if not active:
		return
	
	# Move toward current target pixel position
	position = position.move_toward(position_target, 16)
	queue_redraw()
	
	# Auto-advance along autopilot path when arrived
	if autopilot_path.size() > 0 and input_delay.is_stopped() and position.is_equal_approx(position_target):
		_emit_current_cell() # Reached this cell
		if autopilot_path.size() > 0:
			var next_cell: Vector2i = autopilot_path.pop_front()
			position_target = Vector2(next_cell) * Globals.CELL_SIZE
			input_delay.start()
		return
	
	# If autopiloting, ignore manual input
	if autopilot_path.size() > 0:
		return
	
	# Wait until at target and delay elapsed before manual input
	if not input_delay.is_stopped() or not position.is_equal_approx(position_target):
		return
		
	# If autopiloting, ignore manual input
	if autopilot_path.size() > 0:
		return
	
	# Lock manual input when requested (e.g., menus)
	if input_locked:
		return
	
	# Wait until at target and delay elapsed before manual input
	if not input_delay.is_stopped() or not position.is_equal_approx(position_target):
		return
		
	var movement: Vector2 = Vectors.get_four_direction_vector(false)
	
	if movement != Vector2.ZERO:
		var move_vector: Vector2 = movement * Globals.CELL_SIZE
		var next_pos: Vector2 = position + move_vector
		var next_grid_pos: Vector2i = _world_to_cell(next_pos) # Floor convert step target
		
		if reachable_cells.size() > 0 and not next_grid_pos in reachable_cells:
			return
		
		# Backtrack one step
		if cells_travelled.size() > 1 and next_grid_pos == cells_travelled[cells_travelled.size() - 2]:
			cells_travelled.pop_back()
			position_target = next_pos
			_emit_current_cell()
			input_delay.start()
		# Extend path if no collision
		elif not test_move(transform, move_vector):
			position_target = next_pos
			cells_travelled.append(next_grid_pos)
			_emit_current_cell()
			input_delay.start()

func _emit_current_cell() -> void:
	if cells_travelled.size() == 0:
		return
	moved_to_cell.emit(cells_travelled.back())

func _draw() -> void:
	if cells_travelled.size() < 2:
		return
		
	var half_cell: Vector2 = Globals.CELL_SIZE / 2
	
	for i in range(cells_travelled.size() - 1):
		var start_draw_pos = (Vector2(cells_travelled[i]) * Globals.CELL_SIZE) + half_cell - position
		var end_draw_pos = (Vector2(cells_travelled[i + 1]) * Globals.CELL_SIZE) + half_cell - position
		draw_line(start_draw_pos, end_draw_pos, Color.WHITE, 2.0)
		draw_circle(start_draw_pos, 2.0, Color.WHITE)
	
	var last_draw_pos = (Vector2(cells_travelled.back()) * Globals.CELL_SIZE) + half_cell - position
	draw_circle(last_draw_pos, 2.0, Color.WHITE)

func _world_to_cell(pos: Vector2) -> Vector2i:
	# Floor-based world->grid mapping; works for negative/world-offset coords
	return Vector2i(floor(pos.x / Globals.CELL_SIZE.x), floor(pos.y / Globals.CELL_SIZE.y))
