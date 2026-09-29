extends Node
## Wraps positions and measures distances on the prototype's toroidal sector map.

# The playable area is a rectangle whose opposite edges connect.
var sector_size: Vector2 = Vector2(8000.0, 8000.0)


func wrap_position(position: Vector2) -> Vector2:
	# fposmod also maps negative coordinates back into the positive sector range.
	if not _has_valid_sector_size():
		return position
	return Vector2(fposmod(position.x, sector_size.x), fposmod(position.y, sector_size.y))


func shortest_delta(from_position: Vector2, to_position: Vector2) -> Vector2:
	# Choose the shorter wrapped vector independently on each axis.
	var delta := to_position - from_position
	if not _has_valid_sector_size():
		return delta

	if delta.x > sector_size.x * 0.5:
		delta.x -= sector_size.x
	elif delta.x < -sector_size.x * 0.5:
		delta.x += sector_size.x

	if delta.y > sector_size.y * 0.5:
		delta.y -= sector_size.y
	elif delta.y < -sector_size.y * 0.5:
		delta.y += sector_size.y

	return delta


func wrapped_distance(from_position: Vector2, to_position: Vector2) -> float:
	# Distance uses the seam-aware delta so ships near opposite edges stay nearby.
	return shortest_delta(from_position, to_position).length()


func _has_valid_sector_size() -> bool:
	# Modulo and half-size comparisons require both dimensions to be positive.
	return sector_size.x > 0.0 and sector_size.y > 0.0


## Keep transient combat actors under the sector so they are removed on transition.
func effect_parent() -> Node:
	var active_sector: Node = get_tree().get_first_node_in_group("active_sector")
	if active_sector != null:
		return active_sector

	# Until the game coordinator exists, the directly-run sector is the scene root.
	return get_tree().current_scene


## Add an effect or projectile to its owning sector at a global position.
func spawn_owned(node: Node, at: Vector2) -> Node:
	var parent: Node = effect_parent()
	if node == null or parent == null:
		return null

	# NEW CODE STARTS HERE
	# Wait until physics callbacks finish before adding areas or other gameplay nodes.
	_attach_owned_node.call_deferred(node, parent, at)
	# NEW CODE ENDS HERE
	return node


# NEW CODE STARTS HERE
func _attach_owned_node(node: Node, parent: Node, at: Vector2) -> void:
	# Discard the pending spawn if its node or owning sector has already left.
	if not is_instance_valid(node) or not is_instance_valid(parent) or parent.is_queued_for_deletion():
		if is_instance_valid(node):
			node.queue_free()
		return

	parent.add_child(node)
	var node_2d: Node2D = node as Node2D
	if node_2d != null:
		node_2d.global_position = at
# NEW CODE ENDS HERE

# NEW CODE STARTS HERE
# Track cloned visuals that render actors from the neighboring toroidal tiles.
var _wrap_visual_entries: Array[Dictionary] = []
const WRAP_VISUAL_PADDING := 256.0


func _process(_delta: float) -> void:
	_update_wrap_visuals()


func register_wrap_visual(owner: Node2D, source: Node2D) -> void:
	# Create visual-only copies around the camera-nearest tile; physics stays on the original.
	if owner == null or source == null or get_tree().current_scene == null:
		return

	unregister_wrap_visual(owner)
	var copies: Array[Dictionary] = []
	var scene_root: Node = get_tree().current_scene

	# Keep a 3x3 tile of visual copies available around the camera-nearest image.
	for x_offset in range(-1, 2):
		for y_offset in range(-1, 2):
			var ghost := source.duplicate() as Node2D
			if ghost == null:
				continue

			ghost.name = "%s_WrapGhost_%d_%d" % [source.name, x_offset, y_offset]
			ghost.top_level = true
			ghost.visible = false
			scene_root.add_child.call_deferred(ghost)
			ghost.global_transform = source.global_transform

			var pairs: Array[Dictionary] = []
			_collect_wrap_visual_pairs(source, ghost, pairs)
			copies.append({
				"node": ghost,
				"tile_delta": Vector2i(x_offset, y_offset),
				"pairs": pairs,
			})

	_wrap_visual_entries.append({"owner": owner, "source": source, "copies": copies})


func unregister_wrap_visual(owner: Node) -> void:
	# Free every copy when its real actor leaves the scene.
	for index in range(_wrap_visual_entries.size() - 1, -1, -1):
		var entry: Dictionary = _wrap_visual_entries[index]
		if entry.get("owner") != owner:
			continue
		_free_wrap_visual_copies(entry.get("copies", []))
		_wrap_visual_entries.remove_at(index)


func _update_wrap_visuals() -> void:
	# Retire stale actors before doing viewport work.
	for index in range(_wrap_visual_entries.size() - 1, -1, -1):
		var entry: Dictionary = _wrap_visual_entries[index]
		var owner: Node = entry.get("owner")
		var source: Node2D = entry.get("source")
		if not is_instance_valid(owner) or not is_instance_valid(source):
			_free_wrap_visual_copies(entry.get("copies", []))
			_wrap_visual_entries.remove_at(index)

	var camera := get_viewport().get_camera_2d()
	if camera == null or camera.zoom.x <= 0.0 or camera.zoom.y <= 0.0 or not _has_valid_sector_size():
		return

	var half_view := get_viewport().get_visible_rect().size * 0.5 / camera.zoom
	half_view += Vector2.ONE * WRAP_VISUAL_PADDING
	var view_center := camera.get_screen_center_position()

	for entry in _wrap_visual_entries:
		var source: Node2D = entry["source"]
		var source_position: Vector2 = source.global_position
		var nearest_tile := Vector2i(
			roundi((view_center.x - source_position.x) / sector_size.x),
			roundi((view_center.y - source_position.y) / sector_size.y)
		)
		var copies: Array = entry["copies"]
		for copy in copies:
			var ghost: Node2D = copy["node"]
			var tile_delta: Vector2i = copy["tile_delta"]
			var tile: Vector2i = nearest_tile + tile_delta
			var pairs: Array[Dictionary] = copy["pairs"]
			_sync_wrap_visual_pairs(pairs)
			if tile == Vector2i.ZERO:
				ghost.visible = false
				continue

			var offset := Vector2(tile.x * sector_size.x, tile.y * sector_size.y)
			ghost.global_transform = source.global_transform
			ghost.global_position = source_position + offset

			var ghost_position := source_position + offset
			var inside_x: bool = absf(ghost_position.x - view_center.x) <= half_view.x
			var inside_y: bool = absf(ghost_position.y - view_center.y) <= half_view.y
			var inside_view: bool = inside_x and inside_y
			ghost.visible = source.is_visible_in_tree() and inside_view


func _collect_wrap_visual_pairs(source: Node, ghost: Node, pairs: Array[Dictionary]) -> void:
	# Store corresponding nodes once so animated frames and transforms stay in sync.
	pairs.append({"source": source, "ghost": ghost})
	var child_count: int = mini(source.get_child_count(), ghost.get_child_count())
	for child_index in range(child_count):
		_collect_wrap_visual_pairs(source.get_child(child_index), ghost.get_child(child_index), pairs)


func _sync_wrap_visual_pairs(pairs: Array[Dictionary]) -> void:
	# Mirror the original visual tree without cloning its physics or gameplay owner.
	for pair in pairs:
		var source: Node = pair["source"]
		var ghost: Node = pair["ghost"]
		if source is CanvasItem and ghost is CanvasItem:
			ghost.visible = source.visible
			ghost.modulate = source.modulate
			ghost.self_modulate = source.self_modulate
			ghost.z_index = source.z_index
			ghost.z_as_relative = source.z_as_relative
		if source is Node2D and ghost is Node2D:
			ghost.position = source.position
			ghost.rotation = source.rotation
			ghost.scale = source.scale
			ghost.skew = source.skew
		if source is Sprite2D and ghost is Sprite2D:
			ghost.frame = source.frame
			ghost.frame_coords = source.frame_coords


func _free_wrap_visual_copies(copies: Array) -> void:
	# Queue copies for deletion after the current render/update callback.
	for copy in copies:
		var ghost: Node = copy.get("node")
		if is_instance_valid(ghost):
			ghost.queue_free()
# NEW CODE ENDS HERE
