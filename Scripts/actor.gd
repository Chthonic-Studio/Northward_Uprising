@tool
class_name Actor extends CharacterBody2D

@onready var input_delay: Timer = $InputDelay
@onready var position_target : Vector2 = position

const FRIENDLY_COLOR : Color = Color("23ff1e")
const ENEMY_COLOR : Color = Color("d94141")

var active : bool = false

@export var is_friendly : bool = false : 
	set(value):
		is_friendly = value
		$Sprite.self_modulate = FRIENDLY_COLOR if is_friendly else ENEMY_COLOR
		name = "ActorPlayer" if is_friendly else "ActorEnemy"

func _ready() -> void:
	is_friendly = is_friendly

func _process(_delta: float) -> void:
	if not active:
		return
	position = position.move_toward(position_target, 8)
	
	if not input_delay.is_stopped() or not position.is_equal_approx(position_target):
		return
		
	var movement: Vector2 = Vectors.get_four_direction_vector(false)
	
	if movement != Vector2.ZERO:
		var move_vector: Vector2 = movement * Globals.CELL_SIZE
		
		if not test_move(transform, move_vector):
			position_target = position + move_vector
			input_delay.start()


		
