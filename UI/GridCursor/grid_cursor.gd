class_name GridCursor extends Area2D

signal moved(position: Vector2)

var cell_size: Vector2 = Globals.CELL_SIZE

func _ready() -> void:
	show()

func _process(_delta: float) -> void:
	var previous_position: Vector2 = global_position
	
	# CHANGED: Use floor() logic instead of modulo (%).
	# Modulo snaps negative numbers towards zero (e.g., -5 becomes 0), causing offsets.
	# floor() correctly snaps to the lower integer (e.g., -5 becomes -16).
	global_position = (get_global_mouse_position() / cell_size).floor() * cell_size
	
	if not global_position.is_equal_approx(previous_position):
		moved.emit(global_position)
