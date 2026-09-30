extends Area2D
## Adds its configured module to the player's unequipped inventory when collected.

var module: ModuleDefinition


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	var player: PlayerShip = body as PlayerShip
	if player == null or module == null:
		return

	if player.store_module(module):
		Log.info("Module pickup collected", module.display_name)
		queue_free()
