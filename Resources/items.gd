class_name Items extends Resource

signal uses_changed(current: int, max: int) # Emitted when durability changes
signal broke(item: Items) # Emitted once when durability hits 0

@export var item_name: StringName = "Item"
@export var description: String = ""
@export var icon: Texture2D
@export_range(0, 999) var weight: int = 0
@export_range(0, 99999) var value: int = 0

@export_range(1, 999) var max_uses: int = 1:
	set(value):
		max_uses = max(1, value)
		uses_remaining = clamp(uses_remaining, 0, max_uses)
		uses_changed.emit(uses_remaining, max_uses)

@export_range(0, 999) var uses_remaining: int = 1:
	set(value):
		uses_remaining = clamp(value, 0, max_uses)
		uses_changed.emit(uses_remaining, max_uses)
		if uses_remaining == 0:
			broke.emit(self)

func reset_uses() -> void:
	# Restore durability to full.
	uses_remaining = max_uses

func consume_use() -> bool:
	# Spend 1 use; returns true if action is allowed, false if already broken.
	if uses_remaining <= 0:
		return false
	uses_remaining -= 1
	return true

func is_broken() -> bool:
	# Helper for quick checks.
	return uses_remaining <= 0

func duplicate_item() -> Items:
	# Deep-duplicate for safe copying into inventories.
	return duplicate(true) as Items
