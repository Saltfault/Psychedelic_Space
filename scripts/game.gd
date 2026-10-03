extends Node

const GENERATED_SECTOR_SCENE: PackedScene = preload("res://scenes/sectors/generated_sector.tscn")

@onready var sector_container: Node2D = $SectorContainer
@onready var player: PlayerShip = $PlayerShip
@onready var hud: GameHUD = $HUD
@onready var system_map: SystemMap = $HUD/Root/SystemMap
@onready var music_director: MusicDirector = $MusicDirector

var active_sector: SectorRoot = null
var run_finished: bool = false


func _ready() -> void:
	var restoring_run: bool = RunState.resume_pending
	if not restoring_run and not RunState.fresh_campaign_pending:
		RunState.reset_run()
	RunState.fresh_campaign_pending = false

	hud.configure(player)
	system_map.travel_requested.connect(_on_travel_requested)
	player.died.connect(_on_player_died)

	var system_seed: int = hash([RunState.run_seed, RunState.current_system_id])
	system_map.generate_new_map(system_seed)
	var initial_node_id: String = system_map.start_node_id
	if restoring_run and system_map.nodes_by_id.has(RunState.saved_map_node_id):
		initial_node_id = RunState.saved_map_node_id
		system_map.debug_set_current_node(initial_node_id)
	elif restoring_run:
		Log.warn("Saved map node is not in the regenerated route; resuming at its start", RunState.saved_map_node_id)
	var restore_clear: bool = restoring_run and RunState.saved_sector_clear
	_load_map_node(system_map.get_node_data(initial_node_id), restore_clear)
	if restoring_run:
		RunState.apply_saved_player_state(player)
		var saved_position: Vector2 = RunState.get_saved_player_position()
		if saved_position != Vector2.ZERO:
			player.global_position = SectorSpace.wrap_position(saved_position)
		RunState.resume_pending = false


func _process(delta: float) -> void:
	if run_finished:
		return

	if Input.is_action_just_pressed("system_map"):
		# Tab is only a travel action after the sector is clear; warp uses its physical gate.
		if not RunState.current_sector_clear or active_sector == null:
			return
		if active_sector.sector_id == "warp":
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


func _load_map_node(node_data: Dictionary, restore_clear: bool = false) -> void:
	if node_data.is_empty():
		Log.error("Cannot load an empty generated map node")
		return

	if not restore_clear:
		RunState.set_current_sector_clear(false)
	if active_sector != null:
		active_sector.remove_from_group("active_sector")
		active_sector.queue_free()
		await active_sector.tree_exited

	RunState.current_sector_id = String(node_data["role"])

	active_sector = GENERATED_SECTOR_SCENE.instantiate() as SectorRoot
	active_sector.configure_for_map_node(node_data)
	active_sector.skip_hostile_spawns = restore_clear
	# Move the live player before generated content reads its location.
	var player_start_position: Vector2 = active_sector.get_spawn_position()
	if RunState.resume_pending and active_sector.map_node_id == RunState.saved_map_node_id:
		var saved_position: Vector2 = RunState.get_saved_player_position()
		if saved_position != Vector2.ZERO:
			player_start_position = SectorSpace.wrap_position(saved_position)
	player.global_position = player_start_position
	player.velocity *= 0.35
	sector_container.add_child(active_sector)

	active_sector.add_to_group("active_sector")
	active_sector.clear_state_changed.connect(_on_sector_clear_state_changed)
	_on_sector_clear_state_changed(active_sector.is_clear)

	music_director.play_sector_track(active_sector.sector_id, active_sector.has_outpost_objective)
	if GameSettings.screen_shake_strength > 0.0:
		Juicee.shake_camera(player, 2.5 * GameSettings.screen_shake_strength, 0.2, 20.0)
	if EventAudio.instance != null:
		EventAudio.instance.play_2d("warp_arrival", player, "SFX")

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
	if RunState.current_sector_id != "warp" or not RunState.current_sector_clear:
		Log.warn("Rejected warp outside a cleared warp sector", RunState.current_sector_id)
		return
	if run_finished:
		return
	if not RunState.advance_solar_system():
		run_finished = true
		hud.show_run_complete()
		player.set_physics_process(false)
		return
	system_map.generate_new_map(hash([RunState.run_seed, RunState.current_system_id]))
	var start_data: Dictionary = system_map.get_node_data(system_map.start_node_id)
	if start_data.is_empty():
		Log.error("Generated solar system has no start node", RunState.current_system_id)
		return
	await _load_map_node(start_data)


func _on_player_died(_ship: BaseShip) -> void:
	if run_finished:
		return
	player.set_physics_process(false)
	player.set_process(false)
	hud.show_death_screen()
