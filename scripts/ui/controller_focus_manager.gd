extends Node
## Enables focus navigation on scene-authored controls and gives each visible menu a starting focus.

var focus_root: Control
@export var focus_on_ready: bool = true


func _ready() -> void:
	focus_root = get_parent() as Control
	if focus_root == null:
		Log.error("Controller focus manager must be a child of a Control", get_path())
		set_process_input(false)
		return
	focus_root.visibility_changed.connect(_on_root_visibility_changed)
	_bind_visibility_changes(focus_root)
	call_deferred("_refresh_focus", focus_on_ready)


func _input(event: InputEvent) -> void:
	if focus_root == null or not focus_root.is_visible_in_tree():
		return
	var controller_pressed: bool = event is InputEventJoypadButton and event.pressed
	var stick_moved: bool = event is InputEventJoypadMotion and absf(event.axis_value) >= 0.65
	if controller_pressed or stick_moved:
		call_deferred("_ensure_focus", false)


func _on_root_visibility_changed() -> void:
	if focus_root != null and focus_root.is_visible_in_tree():
		call_deferred("_refresh_focus", true)


func _on_descendant_visibility_changed() -> void:
	if focus_root != null and focus_root.is_visible_in_tree():
		call_deferred("_refresh_focus", false)


func _bind_visibility_changes(parent: Node) -> void:
	for child: Node in parent.get_children():
		if child is Control:
			var control: Control = child as Control
			if not control.visibility_changed.is_connected(_on_descendant_visibility_changed):
				control.visibility_changed.connect(_on_descendant_visibility_changed)
		_bind_visibility_changes(child)


func _refresh_focus(force_start: bool) -> void:
	if focus_root == null or not focus_root.is_visible_in_tree():
		return
	_bind_visibility_changes(focus_root)
	var controls: Array[Control] = _get_visible_focusables(focus_root)
	for control: Control in controls:
		control.focus_mode = Control.FOCUS_ALL
	_wire_missing_focus_neighbors(controls)
	_ensure_focus(force_start)


func _ensure_focus(force: bool) -> void:
	if focus_root == null or not focus_root.is_visible_in_tree():
		return
	var current_owner: Control = focus_root.get_viewport().gui_get_focus_owner()
	if not force and is_instance_valid(current_owner) and current_owner.is_visible_in_tree():
		return
	var controls: Array[Control] = _get_visible_focusables(focus_root)
	if controls.is_empty():
		return
	controls[0].grab_focus()


func _get_visible_focusables(parent: Node) -> Array[Control]:
	var result: Array[Control] = []
	for child: Node in parent.get_children():
		if child is Control:
			var control: Control = child as Control
			if control.is_visible_in_tree() and _is_interactive_control(control):
				result.append(control)
		result.append_array(_get_visible_focusables(child))
	return result


func _is_interactive_control(control: Control) -> bool:
	return (
		control is BaseButton
		or control is Range
		or control is LineEdit
		or control is TextEdit
		or control is TabBar
	)


func _wire_missing_focus_neighbors(controls: Array[Control]) -> void:
	var directions: Dictionary = {
		"left": Vector2.LEFT,
		"right": Vector2.RIGHT,
		"top": Vector2.UP,
		"bottom": Vector2.DOWN,
	}
	for control: Control in controls:
		for direction_name: String in directions:
			var property_name: String = "focus_neighbor_" + direction_name
			var configured_path: NodePath = control.get(property_name)
			if not configured_path.is_empty():
				continue
			var direction: Vector2 = directions[direction_name]
			var neighbor: Control = _nearest_neighbor(control, controls, direction)
			if neighbor != null:
				control.set(property_name, control.get_path_to(neighbor))


func _nearest_neighbor(
	source: Control,
	controls: Array[Control],
	direction: Vector2,
) -> Control:
	var source_center: Vector2 = source.get_global_rect().get_center()
	var perpendicular: Vector2 = Vector2(-direction.y, direction.x)
	var best: Control = null
	var best_score: float = INF
	for candidate: Control in controls:
		if candidate == source:
			continue
		var offset: Vector2 = candidate.get_global_rect().get_center() - source_center
		var forward_distance: float = offset.dot(direction)
		if forward_distance <= 1.0:
			continue
		var cross_distance: float = absf(offset.dot(perpendicular))
		var score: float = forward_distance + cross_distance * 1.5
		if score < best_score:
			best_score = score
			best = candidate
	return best
