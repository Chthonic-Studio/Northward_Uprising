@tool
class_name Actor extends CharacterBody2D

@onready var input_delay: Timer = $InputDelay
@onready var position_target : Vector2 = position
@onready var sprite : Sprite2D = $Sprite

const FRIENDLY_COLOR : Color = Color("23ff1e")
const ENEMY_COLOR : Color = Color("d94141")

@export var stats: UnitResource = null # Holds unit stats such as movement_range

var origin_cell: Vector2i = Vector2i.ZERO # Where the unit started before planning a move

var active : bool = false :
	set(value):
		active = value
		if active:
			origin_cell = Vector2i(position / Globals.CELL_SIZE)
			cells_travelled.clear()
			cells_travelled.append(origin_cell)
			queue_redraw()
		else:
			cells_travelled.clear()
			queue_redraw()

var cells_travelled : Array[Vector2i] = [] # Path cells (grid coords)
var reachable_cells : Array[Vector2i] = [] # Cells this unit may enter this turn

@export var is_friendly : bool = false : 
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

func set_origin_cell(cell: Vector2i) -> void:
	# Store starting cell for future cancel/backtracking
	origin_cell = cell

func set_reachable_cells(cells: Array[Vector2i]) -> void:
	# Called by world to constrain movement and draw range
	reachable_cells = cells.duplicate()

func cancel_move_to_origin() -> void:
	# Teleport back to start, reset path, keep actor ready to deactivate if needed
	position = Vector2(origin_cell) * Globals.CELL_SIZE
	position_target = position
	cells_travelled.clear()
	cells_travelled.append(origin_cell)
	queue_redraw()

func finalize_move() -> void:
	# Commit current position as new origin for future turns
	origin_cell = Vector2i(position / Globals.CELL_SIZE)

func _process(_delta: float) -> void:
	if not active:
		return
	
	position = position.move_toward(position_target, 8)
	queue_redraw()
	
	if not input_delay.is_stopped() or not position.is_equal_approx(position_target):
		return
		
	var movement: Vector2 = Vectors.get_four_direction_vector(false)
	
	if movement != Vector2.ZERO:
		var move_vector: Vector2 = movement * Globals.CELL_SIZE
		var next_pos: Vector2 = position + move_vector
		var next_grid_pos: Vector2i = Vector2i(next_pos / Globals.CELL_SIZE)
		
		# Disallow stepping outside the computed reachable range (if provided)
		if reachable_cells.size() > 0 and not next_grid_pos in reachable_cells:
			return
		
		# If the input points to the 2nd to last cell we visited, we are "unwinding" the path.
		if cells_travelled.size() > 1 and next_grid_pos == cells_travelled[cells_travelled.size() - 2]:
			cells_travelled.pop_back() # Remove the last step
			position_target = next_pos
			input_delay.start()
		
		# If not backtracking, check for collisions and extend the path.
		elif not test_move(transform, move_vector):
			position_target = next_pos
			cells_travelled.append(next_grid_pos)
			input_delay.start()

func _draw() -> void:
	# Only draw if we have a path (start + at least 1 step)
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
