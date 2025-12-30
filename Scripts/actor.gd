@tool
class_name Actor extends CharacterBody2D

@onready var input_delay: Timer = $InputDelay
@onready var position_target : Vector2 = position
@onready var sprite : Sprite2D = $Sprite

# Assign a resource in the Inspector for each unit
@export var stats: UnitResource

const FRIENDLY_COLOR : Color = Color("23ff1e")
const ENEMY_COLOR : Color = Color("d94141")

# Stores valid grid positions the unit can move to (set by World)
var valid_moves: Array[Vector2] = []

var active : bool = false :
	set(value):
		active = value
		if active:
			# Start path tracking at current position
			cells_travelled.clear()
			cells_travelled.append(position / Globals.CELL_SIZE)
			queue_redraw()
		else:
			# Clear visuals when deselected
			cells_travelled.clear()
			valid_moves.clear()
			queue_redraw()

var cells_travelled : Array[Vector2] = []

@export var is_friendly : bool = false : 
	set(value):
		is_friendly = value
		if not is_node_ready(): await ready # Safety for tool script
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
	# Initialize stats if missing to prevent crashes
	if not stats:
		stats = UnitResource.new()
		
	is_friendly = is_friendly
	if sprite == null:
		sprite = $Sprite

func _process(_delta: float) -> void:
	if not active:
		return
	
	# Smooth movement visual
	position = position.move_toward(position_target, 8)
	queue_redraw()
	
	# Wait for movement to finish or input delay
	if not input_delay.is_stopped() or not position.is_equal_approx(position_target):
		return
		
	# Get input from Vectors util
	var movement: Vector2 = Vectors.get_four_direction_vector(false)
	
	if movement != Vector2.ZERO:
		var move_vector: Vector2 = movement * Globals.CELL_SIZE
		var next_pos: Vector2 = position + move_vector
		var next_grid_pos: Vector2 = next_pos / Globals.CELL_SIZE
		
		# Logic 1: Unwinding the path (Backtracking)
		if cells_travelled.size() > 1 and next_grid_pos.is_equal_approx(cells_travelled[cells_travelled.size() - 2]):
			cells_travelled.pop_back() 
			position_target = next_pos
			input_delay.start()
		
		# Logic 2: Moving forward
		# We add a check: Is the next tile in our 'valid_moves' array?
		# This constrains the path drawing to the BFS range calculated by World.
		elif next_grid_pos in valid_moves and not test_move(transform, move_vector):
			
			# Prevent moving if we exceeded stats.movement_range (Path length check)
			# cells_travelled includes start pos, so size-1 is steps taken.
			if cells_travelled.size() - 1 < stats.movement_range:
				position_target = next_pos
				cells_travelled.append(next_grid_pos)
				input_delay.start()

func _draw() -> void:
	if cells_travelled.size() < 2:
		return
		
	var half_cell: Vector2 = Globals.CELL_SIZE / 2
	
	for i in range(cells_travelled.size() - 1):
		var start_draw_pos = (cells_travelled[i] * Globals.CELL_SIZE) + half_cell - position
		var end_draw_pos = (cells_travelled[i + 1] * Globals.CELL_SIZE) + half_cell - position
		
		draw_line(start_draw_pos, end_draw_pos, Color.WHITE, 2.0)
		draw_circle(start_draw_pos, 2.0, Color.WHITE)
	
	var last_draw_pos = (cells_travelled.back() * Globals.CELL_SIZE) + half_cell - position
	draw_circle(last_draw_pos, 2.0, Color.WHITE)

func move_unit() -> void:
	active = false
