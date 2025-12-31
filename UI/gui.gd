extends Node

@onready var h_actor_name: Label = $Control/HighlightedActor/HBoxContainer/VBoxContainer/H_ActorName
@onready var h_actor_hp: Label = $Control/HighlightedActor/HBoxContainer/VBoxContainer/H_ActorHP
@onready var a_actor_name: Label = $Control/ActiveActor/HBoxContainer/VBoxContainer/A_ActorName
@onready var a_actor_hp: Label = $Control/ActiveActor/HBoxContainer/VBoxContainer/A_ActorHP


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
