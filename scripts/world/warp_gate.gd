extends Area2D
## Physical, animated exit gate that completes a run after its sector is cleared.
class_name WarpGate

## Emitted once when the nearby player activates an unlocked gate.
signal warp_requested

@onready var prompt: Label = $Prompt

var player_inside: PlayerShip = null
var _warp_requested: bool = false


func _ready() -> void:
	collision_layer = 0
	set_collision_mask_value(2, true)
	add_to_group("sensor_contact")
	add_to_group("warp_gate")
	set_meta("contact_type", "warp")
	prompt.hide()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	RunState.run_state_changed.connect(_refresh_prompt)


func _process(_delta: float) -> void:
	if not is_instance_valid(player_inside):
		player_inside = null
		prompt.hide()
		return

	if not Input.is_action_just_pressed("interact"):
		return
	if not RunState.current_sector_clear:
		Log.info("Warp gate locked until all sector hostiles are defeated")
		return
	if _warp_requested:
		return

	_warp_requested = true
	warp_requested.emit()


func _on_body_entered(body: Node2D) -> void:
	if body is PlayerShip:
		player_inside = body
		_refresh_prompt()


func _on_body_exited(body: Node2D) -> void:
	if body == player_inside:
		player_inside = null
		prompt.hide()


func _refresh_prompt() -> void:
	if not is_instance_valid(player_inside):
		prompt.hide()
		return

	if RunState.current_sector_clear:
		prompt.text = "E  •  ENTER WARP GATE"
	else:
		prompt.text = "DEFEAT HOSTILES TO UNLOCK"
	prompt.show()
