extends TextureButton
## A saved visual slot that participates in drag-and-drop between module stores.
class_name ModuleInventorySlot

const DRAG_PREVIEW_SCENE: PackedScene = preload("res://scenes/ui/module_drag_preview.tscn")
const RARITY_ICONS: Array[Texture2D] = [
	preload("res://assets/sprites/pickups/module_common_green.png"),
	preload("res://assets/sprites/pickups/module_uncommon_blue.png"),
	preload("res://assets/sprites/pickups/module_rare_violet.png"),
	preload("res://assets/sprites/pickups/module_epic_yellow.png"),
	preload("res://assets/sprites/pickups/module_legendary_red.png"),
]

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
		return
	icon_node.texture = RARITY_ICONS[clampi(int(module.rarity), 0, RARITY_ICONS.size() - 1)]
	icon_node.show()
	label_node.text = module.display_name
	label_node.modulate = Color.WHITE
	tooltip_text = "%s\n\n%s\n\nStat change: %s" % [
		module.display_name,
		module.description,
		_stat_change_text(module),
	]


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
	var preview := DRAG_PREVIEW_SCENE.instantiate() as ModuleDragPreview
	preview.configure(module)
	set_drag_preview(preview)
	return {
		"source_equipped": is_equipped,
		"source_index": slot_index,
		"module": module,
	}


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
