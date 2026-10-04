extends PanelContainer
## Scene-authored drag preview shown while moving a module between inventories.
class_name ModuleDragPreview

@export var rarity_icons: Array[Texture2D] = []

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
	if rarity_icons.size() < 5:
		Log.error("ModuleDragPreview scene is missing its rarity icons", get_path())
		return
	module_icon.texture = rarity_icons[clampi(int(module.rarity), 0, rarity_icons.size() - 1)]
	module_icon.show()
