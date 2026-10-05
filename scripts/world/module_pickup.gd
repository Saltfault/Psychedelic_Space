extends Area2D
## Adds its configured module to the player's unequipped inventory when collected.
class_name ModulePickup

@export var rarity_textures: Array[Texture2D] = []
var module: ModuleDefinition
@onready var icon: Sprite2D = $Icon


func _ready() -> void:
	if module != null:
		if rarity_textures.size() >= 5:
			icon.texture = rarity_textures[clampi(int(module.rarity), 0, rarity_textures.size() - 1)]
		else:
			Log.error("ModulePickup scene is missing its rarity textures", get_path())
		var module_id: StringName = RunState.get_module_id(module)
		if module_id != &"":
			set_meta("module_id", module_id)
		else:
			Log.error("Module pickup resource is missing from the YARD registry", module.display_name)
		set_meta("contact_type", "module")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	var player: PlayerShip = body as PlayerShip
	if player == null or module == null:
		return

	if player.store_module(module):
		Log.info("Module pickup collected", module.display_name)
		Juicee.preset_pickup(self)
		queue_free()
