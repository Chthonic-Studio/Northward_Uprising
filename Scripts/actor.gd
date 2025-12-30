@tool
class_name Actor extends CharacterBody2D

@onready var input_delay: Timer = $InputDelay
@onready var position_target : Vector2 = position
@onready var sprite : Sprite2D = $Sprite

const FRIENDLY_COLOR : Color = Color("23ff1e")
const ENEMY_COLOR : Color = Color("d94141")

var active : bool = false :
	set(value):
		active = value
		if active:
			cells_travelled.clear()
			cells_travelled.append(position / Globals.CELL_SIZE)
			queue_redraw()
		else:
			cells_travelled.clear()
			queue_redraw()

var cells_travelled : Array[Vector2] = []

@export var is_friendly : bool = false : 
	set(value):
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

func _process(_delta: float) -> void:
	if not active:
		return
	
	position = position.move_toward(position_target, 8)
	
	# Request redraw every frame to keep the path visually stationary in the world
	# as the actor's local origin moves away from it.
	queue_redraw()
	
	if not input_delay.is_stopped() or not position.is_equal_approx(position_target):
		return
		
	var movement: Vector2 = Vectors.get_four_direction_vector(false)
	
	if movement != Vector2.ZERO:
		var move_vector: Vector2 = movement * Globals.CELL_SIZE
		var next_pos: Vector2 = position + move_vector
		var next_grid_pos: Vector2 = next_pos / Globals.CELL_SIZE
		
		# If the input points to the 2nd to last cell we visited, we are "unwinding" the path.
		if cells_travelled.size() > 1 and next_grid_pos.is_equal_approx(cells_travelled[cells_travelled.size() - 2]):
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
	
	# Iterate through the tracked cells to draw lines connecting them
	for i in range(cells_travelled.size() - 1):
		# Convert Grid Coordinates (Global) to Local Drawing Coordinates.
		# Formula: (Grid * 16) + CenterOffset - CurrentPixelPosition
		var start_draw_pos = (cells_travelled[i] * Globals.CELL_SIZE) + half_cell - position
		var end_draw_pos = (cells_travelled[i + 1] * Globals.CELL_SIZE) + half_cell - position
		
		draw_line(start_draw_pos, end_draw_pos, Color.WHITE, 2.0)
		draw_circle(start_draw_pos, 2.0, Color.WHITE)
	
	# Draw a final dot at the current target
	var last_draw_pos = (cells_travelled.back() * Globals.CELL_SIZE) + half_cell - position
	draw_circle(last_draw_pos, 2.0, Color.WHITE)
