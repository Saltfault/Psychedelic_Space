extends Node

const GENERATED_SECTOR_SCENE: PackedScene = preload("res://scenes/sectors/generated_sector.tscn")

@onready var sector_container: Node2D = $SectorContainer
@onready var player: PlayerShip = $PlayerShip
@onready var hud: GameHUD = $HUD
@onready var system_map: SystemMap = $HUD/Root/SystemMap

var active_sector: SectorRoot = null
var run_finished: bool = false


func _ready() -> void:
	RunState.reset_run()

	hud.configure(player)
	system_map.travel_requested.connect(_on_travel_requested)
	player.died.connect(_on_player_died)

	system_map.generate_new_map(RunState.run_seed)
	_load_map_node(system_map.get_node_data(system_map.start_node_id))


func _process(delta: float) -> void:
	if run_finished:
		return

	if Input.is_action_just_pressed("system_map"):
		if active_sector != null and active_sector.sector_id == "warp":
			return

		if system_map.visible:
			system_map.close_map()
		else:
			system_map.open_map()


func _on_travel_requested(target_node_id: String) -> void:
	# The coordinator is the authoritative gate; do not trust UI visibility or map clicks.
	if not RunState.current_sector_clear:
		Log.warn("Rejected sector travel while the current sector is uncleared", target_node_id)
		return
	if not system_map.can_travel_to_node(target_node_id):
		return

	var node_data: Dictionary = system_map.get_node_data(target_node_id)
	if node_data.is_empty():
		return

	# World time advances once, and only after the route graph accepts the transition.
	if not system_map.commit_travel(target_node_id):
		return
	RunState.advance_world()
	_load_map_node(node_data)


func _load_map_node(node_data: Dictionary) -> void:
	if node_data.is_empty():
		Log.error("Cannot load an empty generated map node")
		return

	RunState.set_current_sector_clear(false)
	if active_sector != null:
		active_sector.remove_from_group("active_sector")
		active_sector.queue_free()
		await active_sector.tree_exited

	RunState.current_sector_id = String(node_data["role"])

	active_sector = GENERATED_SECTOR_SCENE.instantiate() as SectorRoot
	active_sector.configure_for_map_node(node_data)
	sector_container.add_child(active_sector)

	active_sector.add_to_group("active_sector")
	active_sector.clear_state_changed.connect(_on_sector_clear_state_changed)
	_on_sector_clear_state_changed(active_sector.is_clear)

	player.global_position = active_sector.get_spawn_position()
	player.velocity *= 0.35

	_connect_warp_gate_if_present()
	RunState.run_state_changed.emit()


## Load a map destination from a debug teleport, bypassing only normal route/clear checks.
func debug_teleport_to_node(node_id: String) -> void:
	var node_data: Dictionary = system_map.get_node_data(node_id)
	if node_data.is_empty() or not system_map.debug_set_current_node(node_id):
		Log.error("Developer teleport rejected unknown map node", node_id)
		return
	await _load_map_node(node_data)
	Log.info("Developer teleport completed", node_id, RunState.current_sector_id)


func _on_sector_clear_state_changed(is_clear: bool) -> void:
	RunState.set_current_sector_clear(is_clear)


func _connect_warp_gate_if_present() -> void:
	var gate := get_tree().get_first_node_in_group("warp_gate") as WarpGate

	if gate == null:
		gate = _find_warp_gate(active_sector)

	if gate != null and not gate.warp_requested.is_connected(_on_warp_requested):
		gate.warp_requested.connect(_on_warp_requested)


func _find_warp_gate(root: Node) -> WarpGate:
	if root is WarpGate:
		return root

	for child in root.get_children():
		var found := _find_warp_gate(child)
		if found != null:
			return found

	return null


func _on_warp_requested() -> void:
	# Only the unlocked gate in the final warp sector may finish the run.
	if RunState.current_sector_id != "warp" or not RunState.current_sector_clear:
		Log.warn("Rejected warp completion outside a cleared warp sector", RunState.current_sector_id)
		return
	if run_finished:
		return

	run_finished = true
	hud.show_run_complete()
	player.set_physics_process(false)


func _on_player_died(_ship: BaseShip) -> void:
	if run_finished:
		return
	player.set_physics_process(false)
	player.set_process(false)
	hud.show_death_screen()
