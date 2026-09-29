extends Area2D
class_name WarpGate

signal warp_requested

var player_inside: PlayerShip = null


func _ready() -> void:
	add_to_group("sensor_contact")
	add_to_group("warp_gate")
	set_meta("contact_type", "warp")

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if player_inside == null:
		return

	if Input.is_action_just_pressed("interact"):
		warp_requested.emit()


func _on_body_entered(body: Node) -> void:
	if body is PlayerShip:
		player_inside = body


func _on_body_exited(bode: Node) -> void:
	if body == player_inside:
		player_inside = null
