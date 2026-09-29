extends Node
## Owns mutable run progress and the player's persisted developer-mode preference.

signal run_state_changed
signal credits_changed(new_value: int)
signal dev_mode_changed(enabled: bool)

# Registry assets are the source of truth for authored module content.
const MODULES: Registry = preload("res://assets/data/registries/modules.tres")
const SETTINGS_PATH: String = "user://settings.cfg"
const SETTINGS_SECTION: String = "developer"
const DEV_MODE_KEY: String = "dev_mode_enabled"

const SYSTEM_GRAPH := {
	"start": ["patrol", "station"],
	"patrol": ["outpost", "nebula"],
	"station": ["outpost", "nebula"],
	"outpost": ["warp"],
	"nebula": ["warp"],
	"warp": [],
}

const CARAVAN_ROUTE := ["start", "patrol", "nebula", "warp"]

var current_sector_id: String = "start"
var world_tick: int = 0
var credits: int = 25

var main_objective_complete: bool = false
var side_objective_complete: bool = false
var side_objective_expired: bool = false

var outpost_alerted: bool = false
var outpost_destroyed: bool = false
var outpost_reinforcement_level: int = 0

var caravan_route_index: int = 0
var known_caravan_sector: String = "start"
var dev_mode_enabled: bool = false


func _ready() -> void:
	# Register commands once, then apply the safe (off) default before gameplay starts.
	_register_console_commands()
	_apply_dev_mode()
	_load_dev_mode_setting()


func reset_run() -> void:
	# Reset only run progress; the user's developer-mode preference is not run data.
	current_sector_id = "start"
	world_tick = 0
	credits = 25

	main_objective_complete = false
	side_objective_complete = false
	side_objective_expired = false

	outpost_alerted = false
	outpost_destroyed = false
	outpost_reinforcement_level = 0

	caravan_route_index = 0
	known_caravan_sector = "start"

	run_state_changed.emit()
	credits_changed.emit(credits)
	Log.info("Run state reset", current_sector_id, credits)


func add_credits(amount: int) -> void:
	# Positive rewards go through this API; purchases use spend_credits instead.
	if amount <= 0:
		return

	credits += amount
	credits_changed.emit(credits)
	run_state_changed.emit()
	Log.debug("Credits added", amount, credits)


func spend_credits(amount: int) -> bool:
	# Reject negative costs so a malicious or mistaken price cannot grant credits.
	if amount < 0 or credits < amount:
		return false

	credits -= amount
	credits_changed.emit(credits)
	run_state_changed.emit()
	Log.debug("Credits spent", amount, credits)
	return true


func can_travel_to(target_sector: String) -> bool:
	# A destination is legal only when it is an outgoing edge from the current node.
	if not SYSTEM_GRAPH.has(current_sector_id):
		return false

	return target_sector in SYSTEM_GRAPH[current_sector_id]


func get_actual_caravan_sector() -> String:
	# The route index advances with world time and stops at its final destination.
	return CARAVAN_ROUTE[caravan_route_index]


func reveal_caravan_here() -> void:
	# Update the player's last-known location without changing the caravan's route.
	known_caravan_sector = current_sector_id
	run_state_changed.emit()
	Log.info("Caravan location discovered", known_caravan_sector)


func advance_world() -> void:
	# A sector transition is the discrete event that advances world systems.
	world_tick += 1

	if caravan_route_index < CARAVAN_ROUTE.size() - 1:
		caravan_route_index += 1

	if outpost_alerted and not outpost_destroyed:
		outpost_reinforcement_level = min(outpost_reinforcement_level + 1, 3)

	if world_tick >= 3 and not side_objective_complete:
		side_objective_expired = true

	run_state_changed.emit()
	Log.debug("World advanced", world_tick, get_actual_caravan_sector())


func complete_main_objective() -> void:
	# Make completion idempotent so duplicate triggers do not award credits twice.
	if main_objective_complete:
		return

	main_objective_complete = true
	outpost_destroyed = true
	add_credits(150)
	Log.info("Main objective completed", current_sector_id)


func complete_side_objective() -> void:
	# The optional reward is unavailable after completion or expiration.
	if side_objective_complete or side_objective_expired:
		return

	side_objective_complete = true
	add_credits(75)
	Log.info("Side objective completed", current_sector_id)


func get_module(module_id: StringName) -> ModuleDefinition:
	# Resolve one stable YARD ID and keep callers independent of resource paths.
	return MODULES.load_entry(module_id) as ModuleDefinition


func get_all_modules() -> Array[ModuleDefinition]:
	# Load the small prototype catalogue and discard entries of an unexpected type.
	var loaded: Dictionary[StringName, Resource] = MODULES.load_all_blocking()
	var result: Array[ModuleDefinition] = []

	for resource in loaded.values():
		if resource is ModuleDefinition:
			result.append(resource)

	return result


func get_modules_by_category(category: String) -> Array[ModuleDefinition]:
	# Use the registry index to load only modules matching this category.
	var result: Array[ModuleDefinition] = []
	var ids: Array[StringName] = MODULES.filter(&"category", category)

	for module_id in ids:
		var module := MODULES.load_entry(module_id) as ModuleDefinition

		if module != null:
			result.append(module)

	return result


func get_random_module() -> ModuleDefinition:
	# Return null for an empty registry so callers can handle missing content safely.
	var modules := get_all_modules()

	if modules.is_empty():
		return null

	return modules.pick_random()


func set_dev_mode(enabled: bool) -> void:
	# Load first so saving this preference does not erase unrelated game settings.
	var config := ConfigFile.new()
	var load_error := config.load(SETTINGS_PATH)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		Log.error("Could not read settings before saving Dev Mode", error_string(load_error))
		dev_mode_changed.emit(dev_mode_enabled)
		return

	# Apply immediately so the Settings toggle controls the console in this session.
	dev_mode_enabled = enabled
	_apply_dev_mode()
	config.set_value(SETTINGS_SECTION, DEV_MODE_KEY, dev_mode_enabled)
	dev_mode_changed.emit(dev_mode_enabled)

	var save_error := config.save(SETTINGS_PATH)
	if save_error != OK:
		Log.error("Could not save the Dev Mode setting", error_string(save_error))
	else:
		Log.info("Developer mode changed", dev_mode_enabled)


func _load_dev_mode_setting() -> void:
	# Missing preferences mean Dev Mode remains off; malformed files fail closed.
	var config := ConfigFile.new()
	var load_error := config.load(SETTINGS_PATH)
	if load_error == ERR_FILE_NOT_FOUND:
		Log.info("No saved settings; developer mode is off by default")
		return
	if load_error != OK:
		Log.error("Could not load settings; developer mode remains off", error_string(load_error))
		return

	var saved_value: Variant = config.get_value(SETTINGS_SECTION, DEV_MODE_KEY, false)
	if typeof(saved_value) != TYPE_BOOL:
		Log.warn("Saved Dev Mode preference was not a boolean; keeping it disabled")
		return

	dev_mode_enabled = saved_value
	_apply_dev_mode()
	dev_mode_changed.emit(dev_mode_enabled)


func _apply_dev_mode() -> void:
	# The console ships with the game but is unavailable until the player opts in.
	if dev_mode_enabled:
		Console.enable()
	else:
		Console.disable()


func _register_console_commands() -> void:
	# Keep prototype-only cheats discoverable through the console's built-in help.
	Console.add_command("run_status", _console_run_status, 0, 0, "Show current run status.")
	Console.add_command(
		"add_credits",
		_console_add_credits,
		["amount"],
		1,
		"Add credits for testing.",
	)
	Console.add_command("reset_run", _console_reset_run, 0, 0, "Reset run progress.")
	Console.add_command(
		"test_module",
		_console_test_module,
		["module_id"],
		1,
		"Install a YARD module on the player.",
	)
	Console.add_command(
		"list_modules",
		_console_list_modules,
		["category"],
		1,
		"List YARD modules in a category.",
	)


func _console_run_status() -> void:
	# Print the key state needed to diagnose a run without inspecting the Remote tree.
	Console.print_info(
		"Sector: %s | Tick: %d | Credits: %d" % [current_sector_id, world_tick, credits]
	)
	Log.debug("Console run status requested", current_sector_id, world_tick, credits)


func _console_add_credits(amount_text: String) -> void:
	# Validate console text before converting it to the integer reward API.
	if not amount_text.is_valid_int():
		Console.print_error("Usage: add_credits <positive integer>")
		return

	var amount := int(amount_text)
	if amount <= 0:
		Console.print_error("Credit amount must be greater than zero.")
		return

	add_credits(amount)
	Console.print_info("Added %d credits. Balance: %d." % [amount, credits])
	Log.info("Developer console granted credits", amount, credits)


func _console_reset_run() -> void:
	# Keep the command behavior identical to the normal new-run reset path.
	reset_run()
	Console.print_info("Run progress reset.")
	Log.info("Run reset from developer console")


func _console_test_module(module_id_text: String) -> void:
	var player: PlayerShip = get_tree().get_first_node_in_group("player_ship") as PlayerShip

	if player == null:
		Console.print_error(
			"No player_ship is active. Load into a sector before running this command."
		)
		return

	var module: ModuleDefinition = get_module(StringName(module_id_text))

	if module == null:
		Console.print_error("Unknown YARD module ID: %s" % module_id_text)
		return

	if not player.install_module(module):
		Console.print_error("Install failed; check whether the player's module slots are full.")
		return

	Console.print_info(
		"Installed %s | thrust %.1f | cooldown %.2f | damage %.1f | sensors %.1f"
		% [
			module.display_name,
			player.thrust_acceleration,
			player.weapon_cooldown,
			player.projectile_damage,
			player.sensor_range,
		]
	)
	Log.info("Developer tested YARD module", module.display_name, module_id_text)


func _console_list_modules(category: String) -> void:
	var modules: Array[ModuleDefinition] = get_modules_by_category(category)

	if modules.is_empty():
		Console.print_error(
			"No modules found for category '%s'. Check the YARD registry index and category spelling."
			% category
		)
		return

	for module in modules:
		Console.print_info("%s [%s]" % [module.display_name, module.category])
		Log.debug("YARD category query result", category, module.display_name)

	Console.print_info("Found %d module(s) in '%s'." % [modules.size(), category])
