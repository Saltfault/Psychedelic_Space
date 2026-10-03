extends PanelContainer
## Scene-authored drag preview shown while moving a module between inventories.
class_name ModuleDragPreview

const RARITY_ICONS: Array[Texture2D] = [
	preload("res://assets/sprites/pickups/module_common_green.png"),
	preload("res://assets/sprites/pickups/module_uncommon_blue.png"),
	preload("res://assets/sprites/pickups/module_rare_violet.png"),
	preload("res://assets/sprites/pickups/module_epic_yellow.png"),
	preload("res://assets/sprites/pickups/module_legendary_red.png"),
]

## Populate the icon and name controls already authored in this saved preview scene.
func configure(module: ModuleDefinition) -> void:
	# Godot sizes a drag preview before its first draw, so give its saved controls
	# an explicit visible footprint instead of relying on the source slot's layout.
	size = Vector2(104.0, 104.0)
	custom_minimum_size = size
	show()
	var module_name: Label = get_node("MarginContainer/Content/ModuleName") as Label
	var module_icon: TextureRect = get_node("MarginContainer/Content/ModuleIcon") as TextureRect
	module_name.text = module.display_name
	module_icon.texture = RARITY_ICONS[clampi(
		int(module.rarity), 0, RARITY_ICONS.size() - 1
	)]
	module_icon.show()
