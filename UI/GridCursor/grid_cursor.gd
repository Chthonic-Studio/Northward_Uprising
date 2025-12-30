class_name GridCursor extends Area2D

signal moved(position:Vector2)


var cell_size: Vector2 = Globals.CELL_SIZE

func _ready() -> void:
	show()

func _process(_delta: float) -> void:
	var previous_position : Vector2 = global_position
	global_position = get_global_mouse_position()
	global_position.x -= int(global_position.x) % int(cell_size.x)
	global_position.y -= int(global_position.y) % int(cell_size.y)
	global_position = global_position.snapped(cell_size)
	
	if not global_position.is_equal_approx(previous_position):
		moved.emit(global_position)
