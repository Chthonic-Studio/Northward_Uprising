extends CanvasLayer

@onready var h_actor_panel: PanelContainer = $HighlightedActor
@onready var a_actor_panel: PanelContainer = $Control/MarginContainer/HBoxContainer/PanelContainer/ActiveActor

@onready var h_actor_name: Label = $HighlightedActor/HBoxContainer/VBoxContainer/H_ActorName
@onready var h_actor_hp: Label = $HighlightedActor/HBoxContainer/VBoxContainer/H_ActorHP
@onready var a_actor_name: Label = $Control/MarginContainer/HBoxContainer/PanelContainer/ActiveActor/VBoxContainer/HBoxContainer/VBoxContainer/A_ActorName
@onready var a_actor_hp: Label = $Control/MarginContainer/HBoxContainer/PanelContainer/ActiveActor/VBoxContainer/HBoxContainer/VBoxContainer/A_ActorHP

@export var battle_preview: PackedScene
@export var unit_combat_options: PackedScene

var combat_options_instance: UnitCombatOptions = null # Only one menu at a time

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

func spawn_unit_combat_options(screen_pos: Vector2) -> UnitCombatOptions:
	# screen_pos is in viewport coordinates
	if combat_options_instance and is_instance_valid(combat_options_instance):
		combat_options_instance.queue_free()
	combat_options_instance = unit_combat_options.instantiate() as UnitCombatOptions
	add_child(combat_options_instance)
	# Defer positioning to ensure size is valid
	call_deferred("_position_combat_options", combat_options_instance, screen_pos)
	return combat_options_instance

func _position_combat_options(menu: UnitCombatOptions, screen_pos: Vector2) -> void:
	if !is_instance_valid(menu):
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var menu_size: Vector2 = menu.get_combined_minimum_size()
	var offset: Vector2 = Vector2(15, 0)
	var desired: Vector2 = screen_pos + offset
	# Flip to left if overflowing on the right
	if desired.x + menu_size.x > viewport_size.x:
		desired.x = screen_pos.x - offset.x - menu_size.x
	# Clamp vertically inside the screen
	desired.y = clamp(desired.y, 0.0, max(0.0, viewport_size.y - menu_size.y))
	menu.position = desired

func close_unit_combat_options() -> void:
	if combat_options_instance and is_instance_valid(combat_options_instance):
		combat_options_instance.queue_free()
	combat_options_instance = null
