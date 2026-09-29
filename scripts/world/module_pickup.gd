extends Area2D

var module: ModuleDefinition


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body is PlayerShip:
		return

	if module == null:
		return

	if body.install_module(module):
		queue_free()
