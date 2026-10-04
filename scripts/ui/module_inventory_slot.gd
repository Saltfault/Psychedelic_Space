extends TextureButton
## A saved visual slot that participates in drag-and-drop between module stores.
class_name ModuleInventorySlot

@export var drag_preview_scene: PackedScene
@export var rarity_icons: Array[Texture2D] = []

var module: ModuleDefinition
var slot_index: int = -1
var is_equipped: bool = false
var inventory_screen: Control
var unlocked_equipped_slots: int = 0


## Populate this reusable scene instance with one inventory entry and its source.
func configure(
	definition: ModuleDefinition,
	index: int,
	equipped: bool,
	screen: Control,
	equipped_capacity: int,
) -> void:
	var icon_node: TextureRect = get_node("Icon") as TextureRect
	var label_node: Label = get_node("Label") as Label
	module = definition
	slot_index = index
	is_equipped = equipped
	inventory_screen = screen
	unlocked_equipped_slots = equipped_capacity
	if module == null:
		icon_node.hide()
		label_node.text = "LOCKED" if equipped and index >= unlocked_equipped_slots else "EMPTY"
		label_node.modulate = Color(0.72, 0.83, 0.9, 0.65)
		tooltip_text = "Drop a module here to equip it." if equipped else "Drop a module here to store it."
		return
	if rarity_icons.size() < 5:
		Log.error("ModuleInventorySlot scene is missing its rarity icons", get_path())
		icon_node.hide()
		return
	icon_node.texture = rarity_icons[clampi(int(module.rarity), 0, rarity_icons.size() - 1)]
	icon_node.show()
	label_node.text = module.display_name
	label_node.modulate = Color.WHITE
	tooltip_text = "%s\n\n%s\n\nStat change: %s" % [
		module.display_name,
		module.description,
		_stat_change_text(module),
	]
	tooltip_text += "\n\nDouble-click to %s; drag to move." % ("unequip" if equipped else "equip")


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if (
		module == null
		or mouse_event.button_index != MOUSE_BUTTON_LEFT
		or not mouse_event.pressed
		or not mouse_event.double_click
		or not is_instance_valid(inventory_screen)
		or not inventory_screen.has_method("quick_move_module")
	):
		return
	inventory_screen.call("quick_move_module", is_equipped, slot_index)
	accept_event()


func _stat_change_text(definition: ModuleDefinition) -> String:
	match definition.effect:
		ModuleDefinition.Effect.MAX_HULL_ADD:
			return "Maximum hull +%s" % _format_stat(definition.value)
		ModuleDefinition.Effect.MAX_SHIELD_ADD:
			return "Maximum shield +%s" % _format_stat(definition.value)
		ModuleDefinition.Effect.FIRE_COOLDOWN_MULTIPLY:
			var timing: String = "shorter" if definition.value < 1.0 else "longer"
			var difference: int = roundi(absf(definition.value - 1.0) * 100.0)
			return "Fire cooldown x%.2f (%d%% %s)" % [
				definition.value,
				difference,
				timing,
			]
		ModuleDefinition.Effect.PROJECTILE_DAMAGE_MULTIPLY:
			return "Weapon damage x%.2f (%+d%%)" % [
				definition.value,
				roundi((definition.value - 1.0) * 100.0),
			]
		ModuleDefinition.Effect.THRUST_MULTIPLY:
			return "Thrust acceleration x%.2f (%+d%%)" % [
				definition.value,
				roundi((definition.value - 1.0) * 100.0),
			]
		ModuleDefinition.Effect.SENSOR_RANGE_MULTIPLY:
			return "Sensor range x%.2f (%+d%%)" % [
				definition.value,
				roundi((definition.value - 1.0) * 100.0),
			]
	return "No stat effect"


func _format_stat(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value


func _get_drag_data(_at_position: Vector2) -> Variant:
	if module == null:
		return null
	if inventory_screen.has_method("begin_module_drag"):
		inventory_screen.call("begin_module_drag", module)
	else:
		# Preserve the engine preview for other reusable inventory contexts.
		if drag_preview_scene == null:
			Log.error("ModuleInventorySlot scene has no saved drag-preview scene", get_path())
			return null
		var preview := drag_preview_scene.instantiate() as ModuleDragPreview
		preview.configure(module)
		set_drag_preview(preview)
	return {
		"source_equipped": is_equipped,
		"source_index": slot_index,
		"module": module,
	}


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and is_instance_valid(inventory_screen):
		if inventory_screen.has_method("end_module_drag"):
			inventory_screen.call("end_module_drag")


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary) or inventory_screen == null:
		return false
	return bool(inventory_screen.call(
		"can_accept_drop",
		bool(data.get("source_equipped", false)),
		int(data.get("source_index", -1)),
		is_equipped,
		slot_index,
	))


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary) or inventory_screen == null:
		return
	inventory_screen.call(
		"move_module_by_drop",
		bool(data.get("source_equipped", false)),
		int(data.get("source_index", -1)),
		is_equipped,
		slot_index,
	)
