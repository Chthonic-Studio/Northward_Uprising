class_name UnitCombatOptions extends PanelContainer

signal fight_pressed
signal item_pressed
signal wait_pressed

@onready var btn_fight: Button = $VBoxContainer/VBoxContainer/Fight
@onready var btn_skill: Button = $VBoxContainer/VBoxContainer/Skill
@onready var btn_item: Button = $VBoxContainer/VBoxContainer/Item
@onready var btn_wait: Button = $VBoxContainer/VBoxContainer/Wait
@onready var btn_talk: Button = $VBoxContainer/VBoxContainer/Talk
@onready var btn_interact: Button = $VBoxContainer/VBoxContainer/Interact

func _ready() -> void:
	# Connect actionable buttons
	btn_fight.pressed.connect(_on_fight_pressed)
	btn_item.pressed.connect(_on_item_pressed)
	btn_wait.pressed.connect(_on_wait_pressed)
	
	# Disable unused actions but keep them visible
	btn_skill.disabled = true
	btn_talk.disabled = true
	btn_interact.disabled = true
	
	# Ensure focusable for keyboard/joypad navigation
	btn_fight.focus_mode = Control.FOCUS_ALL
	btn_item.focus_mode = Control.FOCUS_ALL
	btn_wait.focus_mode = Control.FOCUS_ALL
	
	# Auto-highlight first option for immediate arrow/confirm use
	btn_fight.grab_focus()

func _on_fight_pressed() -> void:
	fight_pressed.emit()

func _on_item_pressed() -> void:
	item_pressed.emit() # placeholder for future behavior

func _on_wait_pressed() -> void:
	wait_pressed.emit()
