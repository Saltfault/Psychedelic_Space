extends Area2D

var player_inside: PlayerShip = null


func _ready() -> void:
	add_to_group("sensor_contact")
	set_meta("contact_type", "station")

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if player_inside == null:
		return

	if Input.is_action_just_pressed("interact"):
		var panel = get_tree().get_first_node_in_group("station_panel")

		if panel != null and panel.has_method("open_for"):
			panel.open_for(player_inside)
			Log.info("Station shop opened", player_inside.name)


func _on_body_entered(body: Node) -> void:
	if body is PlayerShip:
		player_inside = body


func _on_body_exited(body: Node) -> void:
	if body == player_inside:
		player_inside = null
