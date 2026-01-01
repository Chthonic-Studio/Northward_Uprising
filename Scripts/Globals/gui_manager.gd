extends Node

var gui: CanvasLayer = null # Holds the instanced GUI scene

func register_gui(gui_node: CanvasLayer) -> void:
	# Called by gui.tscn on _ready to register itself globally
	gui = gui_node

func set_highlighted_actor(actor: Actor) -> void:
	# Update hovered panel safely
	if gui and gui.has_method("set_highlighted_actor"):
		gui.set_highlighted_actor(actor)

func set_active_actor(actor: Actor) -> void:
	# Update active panel safely
	if gui and gui.has_method("set_active_actor"):
		gui.set_active_actor(actor)

func clear_all() -> void:
	# Hide both panels
	set_highlighted_actor(null)
	set_active_actor(null)
