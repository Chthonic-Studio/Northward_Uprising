extends Node

@export var debug_mouse_inspector: bool = true	# Toggle debug logging of mouse hits
@export var max_hits_logged: int = 8			# Limit logged collisions to avoid spam

func _input(event: InputEvent) -> void:
	# Log only when inspector is enabled and a button is pressed
	if !debug_mouse_inspector:
		return
	if event is InputEventMouseButton and event.pressed:
		_debug_log_mouse_hits(event.position) # Godot 4.5.1 mouse inspector

func _debug_log_mouse_hits(pos: Vector2) -> void:
	# GUI: which Control is hovered at mouse position (top-most)
	var gui_hit: Control = get_viewport().gui_get_hovered_control()
	if gui_hit:
		var chain: Array[String] = []
		var walker: Node = gui_hit
		while walker is Control:
			var c := walker as Control
			chain.append("%s (filter=%s, visible=%s)" % [
				c.get_path(),
				_str_mouse_filter(c.mouse_filter),
				str(c.visible)
			])
			walker = walker.get_parent()
		print_rich("[color=cyan]GUI hit:[/color] ", _join_strings(chain, " -> "))
	else:
		print_rich("[color=cyan]GUI hit:[/color] none")
	
	# 2D physics: Areas/Bodies under cursor
	var params := PhysicsPointQueryParameters2D.new()
	params.position = pos
	params.collide_with_areas = true
	params.collide_with_bodies = true
	params.collision_mask = 0x7FFFFFFF # Query all layers
	
	var space_state: PhysicsDirectSpaceState2D = get_viewport().get_world_2d().direct_space_state
	var results: Array[Dictionary] = space_state.intersect_point(params, max_hits_logged)
	if results.is_empty():
		print_rich("[color=yellow]2D hits:[/color] none")
	else:
		var lines: Array[String] = []
		for r in results:
			var col: Object = r.get("collider")
			if col:
				lines.append("%s (class=%s, path=%s)" % [
					col.name,
					col.get_class(),
					col.get_path()
				])
		print_rich("[color=yellow]2D hits:[/color] ", _join_strings(lines, " | "))

func _str_mouse_filter(filter_val: int) -> String:
	# Human-readable mouse_filter value
	match filter_val:
		Control.MOUSE_FILTER_STOP:
			return "STOP"
		Control.MOUSE_FILTER_PASS:
			return "PASS"
		Control.MOUSE_FILTER_IGNORE:
			return "IGNORE"
		_:
			return str(filter_val)

func _join_strings(arr: Array[String], sep: String) -> String:
	# Manual join to avoid TypedArray join() issues
	if arr.is_empty():
		return ""
	var out: String = arr[0]
	for i in range(1, arr.size()):
		out += sep + arr[i]
	return out
