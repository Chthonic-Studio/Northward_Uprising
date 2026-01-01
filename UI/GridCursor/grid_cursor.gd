class_name GridCursor extends Area2D

signal moved(position: Vector2)

var cell_size: Vector2 = Globals.CELL_SIZE

@onready var sprite: Sprite2D = $GridCursor          # Visual corners sprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D # Hover/click hit box

func _ready() -> void:
	cell_size = Globals.CELL_SIZE
	_resync_visuals_to_cell_size()
	show()

func _process(_delta: float) -> void:
	var previous_position: Vector2 = global_position
	
	# Snap to grid using floor to handle negatives correctly.
	global_position = (get_global_mouse_position() / cell_size).floor() * cell_size
	
	if not global_position.is_equal_approx(previous_position):
		moved.emit(global_position)

func _resync_visuals_to_cell_size() -> void:
	# Resize sprite and collision to match current cell size; keeps cursor correct when cell size changes.
	if sprite.texture:
		var tex_size: Vector2 = sprite.texture.get_size()
		if tex_size.x != 0 and tex_size.y != 0:
			sprite.scale = cell_size / tex_size
	if collision_shape.shape is RectangleShape2D:
		var rect: RectangleShape2D = collision_shape.shape
		rect.size = cell_size
