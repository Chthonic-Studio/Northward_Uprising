extends Node2D

@onready var actors : Node2D = $Actors



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	actors.get_child(0).active = true
	
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_grid_cursor_moved(position: Vector2) -> void:
	pass # Replace with function body.
