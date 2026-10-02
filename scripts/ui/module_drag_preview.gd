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
	var module_name: Label = get_node("MarginContainer/Content/ModuleName") as Label
	var module_icon: TextureRect = get_node("MarginContainer/Content/ModuleIcon") as TextureRect
	module_name.text = module.display_name
	module_icon.texture = RARITY_ICONS[clampi(
		int(module.rarity), 0, RARITY_ICONS.size() - 1
	)]
