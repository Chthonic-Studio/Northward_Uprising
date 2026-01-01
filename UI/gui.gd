extends CanvasLayer

@onready var h_actor_panel: PanelContainer = $HighlightedActor
@onready var a_actor_panel: PanelContainer = $Control/MarginContainer/HBoxContainer/PanelContainer/ActiveActor

@onready var h_actor_name: Label = $HighlightedActor/HBoxContainer/VBoxContainer/H_ActorName
@onready var h_actor_hp: Label = $HighlightedActor/HBoxContainer/VBoxContainer/H_ActorHP
@onready var a_actor_name: Label = $Control/MarginContainer/HBoxContainer/PanelContainer/ActiveActor/VBoxContainer/HBoxContainer/VBoxContainer/A_ActorName
@onready var a_actor_hp: Label = $Control/MarginContainer/HBoxContainer/PanelContainer/ActiveActor/VBoxContainer/HBoxContainer/VBoxContainer/A_ActorHP

@export var battle_preview: PackedScene
@export var unit_combat_options: PackedScene


func _ready() -> void:
	# Hide panels on boot; GUIManager will drive visibility
	h_actor_panel.hide()
	a_actor_panel.hide()
	
	GUIManager.register_gui(self) # Registers this GUI instance globally

func set_highlighted_actor(actor: Actor) -> void:
	# Display hovered actor; hide panel if none
	if actor == null:
		h_actor_panel.hide()
		return
	h_actor_name.text = actor.stats.character_name if actor.stats else "?"
	h_actor_hp.text = "%d/%d" % [actor.current_health, actor.get_max_health()]
	h_actor_panel.show()

func set_active_actor(actor: Actor) -> void:
	# Display active actor; hide panel if none
	if actor == null:
		a_actor_panel.hide()
		return
	a_actor_name.text = actor.stats.character_name if actor.stats else "?"
	a_actor_hp.text = "%d/%d" % [actor.current_health, actor.get_max_health()]
	a_actor_panel.show()
