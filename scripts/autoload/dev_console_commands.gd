extends Node
## Registers developer-only gameplay commands with the shipped Developer Console.

const ENEMY_SCENES: Dictionary[String, PackedScene] = {
	"corsair": preload("res://scenes/enemies/enemy_corsair.tscn"),
	"cutter": preload("res://scenes/enemies/enemy_cutter.tscn"),
}
const OUTPOST_SCENE: PackedScene = preload("res://scenes/world/outpost.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/ships/projectile.tscn")
const MODULE_PICKUP_SCENE: PackedScene = preload("res://scenes/world/module_pickup.tscn")
const SHIELD_PICKUP_SCENE: PackedScene = preload("res://scenes/world/shield_booster.tscn")
const INTEL_PICKUP_SCENE: PackedScene = preload("res://scenes/world/intel_beacon.tscn")


func _ready() -> void:
	# RunState creates its own commands earlier; this autoload adds the gameplay test suite.
	_register_commands.call_deferred()


func _register_commands() -> void:
	Console.add_command("godmode", _godmode, ["state"], 0, "Toggle player invulnerability, or use godmode on/off.")
	Console.add_command("add_shield", _add_shield, ["amount"], 0, "Restore the given shield amount (default: full shield).")
	Console.add_command("add_hull", _add_hull, ["amount"], 0, "Repair the given hull amount (default: full hull).")
	Console.add_command("complete_main_obj", _complete_main_obj, 0, 0, "Complete and remove the main objective.")
	Console.add_command("complete_side_obj", _complete_side_obj, 0, 0, "Complete the optional intel objective.")
	Console.add_command("shuffle_main_obj", _shuffle_main_obj, 0, 0, "Move or respawn the main objective at a random sector position.")
	Console.add_command("shuffle_side_obj", _shuffle_side_obj, 0, 0, "Move or respawn the intel objective at a random sector position.")
	Console.add_command("spawn", _spawn, ["kind", "id"], 1, "Spawn enemy, module, shield, or intel; optional id selects an enemy/module.")
	Console.add_command("teleport", _teleport, ["kind", "target"], 1, "Teleport to the nearest sector role or solar-system ID; creates a match if missing.")
	Console.add_command("respawn", _respawn, 0, 0, "Restore the player at the current sector arrival point.")
	Console.add_command("kill", _kill, ["target"], 1, "Kill player, all enemies, or one enemy by runtime instance ID, node name, or YARD ship ID.")
	Console.add_command_autocomplete_list("godmode", PackedStringArray(["on", "off", "toggle"]))
	Console.add_command_autocomplete_list("spawn", PackedStringArray(["enemy", "module", "shield", "intel", "corsair", "cutter"]))
	Console.add_command_autocomplete_list("teleport", PackedStringArray(["sector", "system", "solar_system", "start", "patrol", "station", "nebula", "outpost", "warp", "generic_system"]))
	Console.add_command_autocomplete_list("kill", PackedStringArray(["player", "all", "corsair", "cutter"]))


func _player() -> PlayerShip:
	return get_tree().get_first_node_in_group("player_ship") as PlayerShip


func _active_sector() -> SectorRoot:
	return get_tree().get_first_node_in_group("active_sector") as SectorRoot


func _say(message: String) -> void:
	Console.print_info(message)


func _fail(message: String) -> void:
	Console.print_error(message)


func _godmode(state_text: String) -> void:
	var player: PlayerShip = _player()
	if player == null:
		_fail("No player ship is active.")
		return

	var state: String = state_text.strip_edges().to_lower()
	if state.is_empty() or state == "toggle":
		player.god_mode = not player.god_mode
	elif state == "on" or state == "true":
		player.god_mode = true
	elif state == "off" or state == "false":
		player.god_mode = false
	else:
		_fail("Usage: godmode [on|off|toggle]")
		return

	_say("God mode %s." % ("ON" if player.god_mode else "OFF"))
	Log.info("Developer command changed god mode", player.god_mode)


func _add_shield(amount_text: String) -> void:
	var player: PlayerShip = _player()
	if player == null:
		_fail("No player ship is active.")
		return
	var amount: float = player.max_shield if amount_text.is_empty() else _parse_positive_amount(amount_text)
	if amount <= 0.0:
		_fail("Usage: add_shield [positive amount]")
		return
	player.restore_shield(amount)
	_say("Restored shield. Current: %d / %d." % [roundi(player.shield), roundi(player.max_shield)])
	Log.info("Developer command restored shield", amount)


func _add_hull(amount_text: String) -> void:
	var player: PlayerShip = _player()
	if player == null:
		_fail("No player ship is active.")
		return
	var amount: float = player.max_hull if amount_text.is_empty() else _parse_positive_amount(amount_text)
	if amount <= 0.0:
		_fail("Usage: add_hull [positive amount]")
		return
	player.repair_hull(amount)
	_say("Repaired hull. Current: %d / %d." % [roundi(player.hull), roundi(player.max_hull)])
	Log.info("Developer command repaired hull", amount)


func _parse_positive_amount(value: String) -> float:
	if not value.is_valid_float():
		return 0.0
	var amount: float = value.to_float()
	return amount if amount > 0.0 else 0.0


func _complete_main_obj() -> void:
	var sector: SectorRoot = _active_sector()
	if sector != null:
		for node in sector.find_children("*", "Outpost", true, false):
			var outpost: Outpost = node as Outpost
			if outpost != null and not outpost.is_queued_for_deletion():
				outpost.take_damage(outpost.hull)
				_say("Main objective completed.")
				Log.info("Developer command completed main objective")
				return
	RunState.complete_main_objective()
	_say("Main objective completed.")
	Log.info("Developer command completed main objective")


func _complete_side_obj() -> void:
	# Developer completion intentionally clears expiry so this remains useful after the deadline.
	RunState.side_objective_expired = false
	RunState.complete_side_objective()
	var sector: SectorRoot = _active_sector()
	if sector != null:
		for objective in sector.find_children("*", "Area2D", true, false):
			if objective.is_in_group("side_objective"):
				objective.queue_free()
	_say("Side objective completed.")
	Log.info("Developer command completed side objective")


func _shuffle_main_obj() -> void:
	if RunState.main_objective_complete:
		_fail("The main objective is already complete; use reset_run before placing it again.")
		return
	var sector: SectorRoot = _active_sector()
	if sector == null:
		_fail("No active sector is loaded.")
		return

	var objectives: Array[Node] = sector.find_children("*", "Outpost", true, false)
	var outpost: Outpost = objectives[0] as Outpost if not objectives.is_empty() else null
	if outpost == null:
		var landmarks: Node = sector.get_node_or_null("Landmarks")
		if landmarks == null:
			_fail("The active sector has no Landmarks node.")
			return
		outpost = OUTPOST_SCENE.instantiate() as Outpost
		if outpost == null:
			_fail("Could not instantiate the outpost scene.")
			return
		outpost.projectile_scene = PROJECTILE_SCENE
		landmarks.add_child(outpost)

	outpost.global_position = _random_sector_position(sector)
	outpost.hull = outpost.max_hull
	_say("Main objective moved to a new position.")
	Log.info("Developer shuffled main objective", outpost.global_position)


func _shuffle_side_obj() -> void:
	var sector: SectorRoot = _active_sector()
	if sector == null:
		_fail("No active sector is loaded.")
		return
	var landmarks: Node = sector.get_node_or_null("Landmarks")
	if landmarks == null:
		_fail("The active sector has no Landmarks node.")
		return

	RunState.side_objective_complete = false
	RunState.side_objective_expired = false
	var beacons: Array[Node] = sector.find_children("*", "Area2D", true, false)
	var intel: Node2D = null
	for candidate in beacons:
		if candidate.is_in_group("side_objective"):
			intel = candidate as Node2D
			break
	if intel == null:
		intel = INTEL_PICKUP_SCENE.instantiate() as Node2D
		if intel == null:
			_fail("Could not instantiate the intel pickup scene.")
			return
		if intel is Area2D:
			(intel as Area2D).collision_layer = 0
			(intel as Area2D).collision_mask = 2
		landmarks.add_child(intel)
	RunState.run_state_changed.emit()
	intel.global_position = _random_sector_position(sector)
	_say("Intel objective moved to a new position.")
	Log.info("Developer shuffled side objective", intel.global_position)


func _spawn(kind_text: String, id_text: String) -> void:
	var player: PlayerShip = _player()
	var sector: SectorRoot = _active_sector()
	if player == null or sector == null:
		_fail("Load into a sector before spawning gameplay objects.")
		return

	var kind: String = kind_text.strip_edges().to_lower()
	var requested_id: String = id_text.strip_edges().to_lower()
	var node: Node2D = null
	match kind:
		"enemy":
			var enemy_id: String = requested_id if not requested_id.is_empty() else "corsair"
			var enemy_scene: PackedScene = ENEMY_SCENES.get(enemy_id) as PackedScene
			if enemy_scene == null:
				_fail("Unknown enemy. Available: corsair, cutter.")
				return
			node = enemy_scene.instantiate() as Node2D
		"module":
			var module: ModuleDefinition = (
				RunState.get_module(StringName(requested_id))
				if not requested_id.is_empty()
				else RunState.get_random_module()
			)
			if module == null:
				_fail("Unknown module ID or empty module registry.")
				return
			var module_pickup: Node = MODULE_PICKUP_SCENE.instantiate()
			module_pickup.set("module", module)
			node = module_pickup as Node2D
		"shield", "shield_pickup":
			node = SHIELD_PICKUP_SCENE.instantiate() as Node2D
		"intel", "intel_pickup":
			RunState.side_objective_complete = false
			RunState.side_objective_expired = false
			RunState.run_state_changed.emit()
			node = INTEL_PICKUP_SCENE.instantiate() as Node2D
			if node is Area2D:
				(node as Area2D).collision_layer = 0
				(node as Area2D).collision_mask = 2
		_:
			_fail("Usage: spawn enemy [corsair|cutter] | module [YARD_ID] | shield | intel")
			return

	if node == null:
		_fail("Could not instantiate the requested object.")
		return
	var angle: float = randf() * TAU
	var distance: float = 500.0 if kind == "enemy" else 120.0
	var spawn_position: Vector2 = SectorSpace.wrap_position(
		player.global_position + Vector2.RIGHT.rotated(angle) * distance
	)
	SectorSpace.spawn_owned(node, spawn_position)
	_say("Spawned %s%s (runtime ID %d)." % [
		kind,
		(" " + requested_id) if not requested_id.is_empty() else "",
		node.get_instance_id(),
	])
	Log.info("Developer spawned object", kind, requested_id, node.get_instance_id())


func _teleport(kind_text: String, target_text: String) -> void:
	var kind: String = kind_text.strip_edges().to_lower()
	var target: String = target_text.strip_edges().to_lower()
	if target.is_empty():
		target = kind
		kind = "system" if kind in ["system", "solar_system", "generic_system"] else "sector"
	if kind in ["solar_system", "generic_system"]:
		kind = "system"
		if target == "generic_system":
			target = "generic"
	if kind not in ["sector", "system"] or target.is_empty():
		_fail("Usage: teleport sector <role> | teleport system <solar-system-id>")
		return

	var game: Node = get_tree().current_scene
	if game == null or not game.has_node("HUD/Root/SystemMap"):
		_fail("The active scene has no SystemMap.")
		return
	var system_map: SystemMap = game.get_node("HUD/Root/SystemMap") as SystemMap
	if system_map == null:
		_fail("Could not access the active SystemMap.")
		return

	var node_id: String = system_map.debug_find_or_create_node(kind, target)
	if node_id.is_empty():
		_fail("Could not locate or create that destination.")
		return
	if game.has_method("debug_teleport_to_node"):
		game.call("debug_teleport_to_node", node_id)
		_say("Teleporting to %s '%s'." % [kind, target])
		Log.info("Developer teleported to route node", kind, target, node_id)
	else:
		_fail("The active game coordinator does not support debug teleports.")


func _respawn() -> void:
	var player: PlayerShip = _player()
	var sector: SectorRoot = _active_sector()
	if player == null or sector == null:
		_fail("No player or active sector is available.")
		return
	player.is_dead = false
	player.hull = player.max_hull
	player.shield = player.max_shield
	player.velocity = Vector2.ZERO
	player.global_position = sector.get_spawn_position()
	player.unwrapped_world_position = player.global_position
	player._previous_wrapped_position = player.global_position
	player.set_physics_process(true)
	player.call("_update_shield_visual")
	player.hull_changed.emit(player.hull, player.max_hull)
	player.shield_changed.emit(player.shield, player.max_shield)
	_say("Player respawned at the sector arrival point.")
	Log.info("Developer respawned player", RunState.current_sector_id)


func _kill(target_text: String) -> void:
	var target: String = target_text.strip_edges().to_lower()
	if target == "player":
		var player: PlayerShip = _player()
		if player == null:
			_fail("No player ship is active.")
			return
		player.debug_kill()
		_say("Killed the player.")
		Log.warn("Developer killed player")
		return

	var sector: SectorRoot = _active_sector()
	if sector == null:
		_fail("No active sector is loaded.")
		return
	var enemies: Array[Node] = sector.find_children("*", "EnemyShip", true, false)
	var killed_count: int = 0
	for candidate in enemies:
		var enemy: EnemyShip = candidate as EnemyShip
		if enemy == null or enemy.is_dead:
			continue
		var matches: bool = (
			target == "all"
			or str(enemy.get_instance_id()) == target
			or enemy.name.to_lower() == target
			or String(enemy.ship_id).to_lower() == target
		)
		if matches:
			enemy.take_damage(enemy.hull + enemy.shield + 1.0)
			killed_count += 1
			if target != "all":
				break
	if killed_count == 0:
		_fail("No enemy matched '%s'. Use kill all or pass an enemy runtime ID/name/YARD ID." % target)
		return
	_say("Killed %d enemy ship(s)." % killed_count)
	Log.warn("Developer killed enemy ships", target, killed_count)


func _random_sector_position(sector: SectorRoot) -> Vector2:
	return Vector2(
		randf_range(350.0, sector.sector_size.x - 350.0),
		randf_range(350.0, sector.sector_size.y - 350.0),
	)
