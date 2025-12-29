extends CharacterBody2D

@onready var input_delay: Timer = $InputDelay

@onready var position_target : Vector2 = position

func _process(delta: float) -> void:
	position = position.move_toward(position_target, 8)
	
	if input_delay.is_stopped() or not position.is_equal_approx(position_target):
		return
		
	var movement : Vector2 = Vectors.get_four_direction_vector(false)
	position_target = position + movement * Globals.CELL_SIZE
	#move_and_collide(movement * 16)
	input_delay.start()
