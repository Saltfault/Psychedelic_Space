extends Area2D

@export var shield_amount: float = 25.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body is PlayerShip:
		body.restore_shield(shield_amount)
		queue_free()
