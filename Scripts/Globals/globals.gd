extends Node

enum States {
	FIELD,
	BATTLE
}

const GAME_SIZE: Vector2 = Vector2( 640, 360 )
const CELL_SIZE: Vector2 = Vector2( 16, 16 )

var current_map: TileMapLayer = null
var target_cell: Vector2 = Vector2.ZERO
# var text_box: Textbox = null
var camera: Camera2D = null
# var screen_shake: ScreenShake2D = null
var music_position: float = 0.0
var state: int = 0

func _ready() -> void:
	randomize()
	process_mode = PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
