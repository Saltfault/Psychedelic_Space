extends Area2D
## Completes the optional signal-recovery objective when the player reaches the beacon.

@onready var icon: Sprite2D = $Icon


func _ready() -> void:
	add_to_group("sensor_contact")
	add_to_group("side_objective")
	set_meta("contact_type", "intel")
	icon.modulate = Color.RED

	body_entered.connect(_on_body_entered)

	if RunState.side_objective_complete or RunState.side_objective_expired:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if not body is PlayerShip:
		return

	RunState.complete_side_objective()
	Juicee.preset_pickup(self, "INTEL")
	queue_free()
