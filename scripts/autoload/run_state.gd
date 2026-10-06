extends Node
## Owns mutable run progress and the player's persisted developer-mode preference.

## Emitted after run progress or objective state changes.
signal run_state_changed
## Emitted after the credit balance changes.
signal credits_changed(new_value: int)
## Emitted whenever the persisted Dev Mode preference changes.
signal dev_mode_changed(enabled: bool)

@export var module_registry: Registry
@export var weapon_registry: Registry
@export var planet_registry: Registry
@export var ship_registry: Registry
@export var pilot_registry: Registry
@export var solar_system_registry: Registry
## Every authored player hull shares this palette; all textures use the same atlas regions.
const SHIP_COLOR_IDS: Array[StringName] = [
	&"blue", &"gold", &"green", &"green_yellow", &"green_yellow_blue", &"light_blue",
	&"orange_blue_white", &"pink_blue_orange", &"red_blue_yellow",
	&"silver_charcoal_red", &"violet_red_orange",
]
const SHIP_COLOR_LABELS: Array[String] = [
	"Blue", "Gold", "Green", "Green / Yellow", "Green / Yellow / Blue", "Light Blue",
	"Orange / Blue / White", "Pink / Blue / Orange", "Red / Blue / Yellow",
	"Silver / Charcoal / Red", "Violet / Red / Orange",
]
@export var ship_color_textures: Array[Texture2D] = []
const SETTINGS_PATH: String = "user://settings.cfg"
const RUN_SAVE_PATH: String = "user://current_run.cfg"
const SETTINGS_SECTION: String = "developer"
const DEV_MODE_KEY: String = "dev_mode_enabled"

## The hostile caravan avoids both the player start and peaceful station sectors.
const CARAVAN_ROUTE: Array[String] = ["patrol", "nebula", "generic"]

## Authored economy and pacing constants (RULE 2: no bare literals in logic).
const STARTING_CREDITS: int = 25
const MAIN_OBJECTIVE_REWARD_CREDITS: int = 150
const SIDE_OBJECTIVE_REWARD_CREDITS: int = 75
const OUTPOST_REINFORCEMENT_MAX_LEVEL: int = 3
const SIDE_OBJECTIVE_EXPIRE_TICKS: int = 3
const ENEMY_DIFFICULTY_GROWTH_PER_TICK: float = 1.002

const CAMPAIGN_SYSTEM_IDS: Array[StringName] = [&"frontier", &"ember", &"glacial"]

var current_system_index: int = 0
var current_system_id: StringName = &"frontier"
## Stable YARD selections retained across menu transitions and Continue.
var selected_ship_id: StringName = &"prototype_ship"
var selected_pilot_id: StringName = &"dash"
## Set by ship selection so Game does not reset a just-created campaign twice.
var fresh_campaign_pending: bool = false

## Seed shared by this run's procedurally generated route and sector layouts.
var run_seed: int = 0
var current_sector_id: String = "start"
## True when the active sector's required objective and hostile ships are resolved for route travel.
var current_sector_clear: bool = false
## Number of accepted sector transitions in this run.
var world_tick: int = 0
## Spendable credits; changes emit credits_changed and run_state_changed.
var credits: int = STARTING_CREDITS

## True once the outpost has been destroyed during this run.
var main_objective_complete: bool = false
## True once the optional intel objective has been collected.
var side_objective_complete: bool = false
## True once the optional intel deadline has passed without collection.
var side_objective_expired: bool = false

var outpost_alerted: bool = false
var outpost_destroyed: bool = false
var outpost_reinforcement_level: int = 0

var caravan_route_index: int = 0
var known_caravan_sector: String = CARAVAN_ROUTE[0]
var dev_mode_enabled: bool = false
## Set by the main menu when Continue is selected; consumed by Game on scene entry.
var resume_pending: bool = false
## Saved map-node identity used to rebuild the deterministic route on Continue.
var saved_map_node_id: String = "node_start"
## Whether the saved sector had already reached its clear state.
var saved_sector_clear: bool = false
var _saved_player_data: Dictionary = {}


func _ready() -> void:
	# Register commands once, then apply the safe (off) default before gameplay starts.
	_register_console_commands()
	_apply_dev_mode()
	_load_dev_mode_setting()


## Reset run progress to its starting values while preserving the user's Dev Mode preference.
func reset_run() -> void:
	# Reset only run progress; the user's developer-mode preference is not run data.
	current_system_index = 0
	current_system_id = CAMPAIGN_SYSTEM_IDS[0]
	current_sector_id = "start"
	current_sector_clear = false
	world_tick = 0
	credits = STARTING_CREDITS
	# A fresh run rolls a fresh map; without this the seed stays 0 across runs
	# and system_map.generate_new_map() would rebuild the identical route.
	run_seed = randi()

	main_objective_complete = false
	side_objective_complete = false
	side_objective_expired = false

	outpost_alerted = false
	outpost_destroyed = false
	outpost_reinforcement_level = 0

	caravan_route_index = 0
	known_caravan_sector = CARAVAN_ROUTE[0]

	run_state_changed.emit()
	credits_changed.emit(credits)
	Log.info("Run state reset", current_sector_id, credits)
	resume_pending = false
	_saved_player_data.clear()
	clear_saved_run()


## Start a new campaign from the first authored solar system.
func start_new_campaign() -> void:
	reset_run()
	fresh_campaign_pending = true
	Log.info("Phase 2 campaign started", current_system_id)


## Return the authored solar system selected by the current campaign index.
func get_current_system() -> SolarSystemDefinition:
	if solar_system_registry == null:
		Log.error("RunState scene has no solar-system YARD registry")
		return null
	return solar_system_registry.load_entry(current_system_id) as SolarSystemDefinition


## Return the shared atlas texture selected for player hulls, defaulting safely to blue.
func get_ship_color_texture(color_id: StringName) -> Texture2D:
	var color_index: int = SHIP_COLOR_IDS.find(color_id)
	if color_index < 0 or color_index >= ship_color_textures.size():
		color_index = 0
	return ship_color_textures[color_index] if not ship_color_textures.is_empty() else null


## Move to the next campaign system; false means the final system was active.
func advance_solar_system() -> bool:
	if current_system_index + 1 >= CAMPAIGN_SYSTEM_IDS.size():
		return false
	current_system_index += 1
	current_system_id = CAMPAIGN_SYSTEM_IDS[current_system_index]
	current_sector_id = ""
	current_sector_clear = false
	main_objective_complete = false
	side_objective_complete = false
	side_objective_expired = false
	outpost_alerted = false
	outpost_destroyed = false
	outpost_reinforcement_level = 0
	world_tick = 0
	run_state_changed.emit()
	Log.info("Solar system advanced", current_system_index, current_system_id)
	return true


## Return whether a readable resumable run save exists for the main menu.
func has_saved_run() -> bool:
	var config := ConfigFile.new()
	return config.load(RUN_SAVE_PATH) == OK and bool(config.get_value("run", "valid", false))


## Restore campaign state into the autoload and flag the next Game scene to resume it.
func load_saved_run() -> bool:
	var config := ConfigFile.new()
	var load_error: Error = config.load(RUN_SAVE_PATH)
	if load_error != OK or not bool(config.get_value("run", "valid", false)):
		Log.warn("Continue requested without a valid run save", error_string(load_error))
		return false

	run_seed = int(config.get_value("run", "run_seed", 0))
	current_sector_id = str(config.get_value("run", "sector_id", "start"))
	saved_map_node_id = str(config.get_value("run", "map_node_id", "node_start"))
	saved_sector_clear = bool(config.get_value("run", "sector_clear", false))
	world_tick = int(config.get_value("run", "world_tick", 0))
	credits = int(config.get_value("run", "credits", STARTING_CREDITS))
	main_objective_complete = bool(config.get_value("run", "main_objective_complete", false))
	side_objective_complete = bool(config.get_value("run", "side_objective_complete", false))
	side_objective_expired = bool(config.get_value("run", "side_objective_expired", false))
	outpost_alerted = bool(config.get_value("run", "outpost_alerted", false))
	outpost_destroyed = bool(config.get_value("run", "outpost_destroyed", false))
	outpost_reinforcement_level = int(config.get_value("run", "outpost_reinforcement_level", 0))
	caravan_route_index = clampi(int(config.get_value("run", "caravan_route_index", 0)), 0, CARAVAN_ROUTE.size() - 1)
	current_system_index = clampi(int(config.get_value("run", "system_index", 0)), 0, CAMPAIGN_SYSTEM_IDS.size() - 1)
	current_system_id = CAMPAIGN_SYSTEM_IDS[current_system_index]
	known_caravan_sector = str(config.get_value("run", "known_caravan_sector", CARAVAN_ROUTE[caravan_route_index]))
	var player_snapshot: Variant = config.get_value("player", "data", {})
	_saved_player_data = player_snapshot.duplicate(true) if player_snapshot is Dictionary else {}
	# Phase 1 saves may lack these IDs; validate each against YARD before scene entry.
	var saved_ship_id: StringName = StringName(str(_saved_player_data.get("ship_id", "prototype_ship")))
	var saved_pilot_id: StringName = StringName(str(_saved_player_data.get("pilot_id", "dash")))
	selected_ship_id = saved_ship_id if get_ship(saved_ship_id) != null else &"prototype_ship"
	selected_pilot_id = saved_pilot_id if get_pilot(saved_pilot_id) != null else &"dash"
	resume_pending = true
	run_state_changed.emit()
	credits_changed.emit(credits)
	Log.info("Saved run loaded", current_sector_id, world_tick, credits)
	return true


## Capture campaign and player equipment state before leaving an active run for the menu.
func save_active_run() -> bool:
	var player: PlayerShip = get_tree().get_first_node_in_group("player_ship") as PlayerShip
	var map: SystemMap = get_tree().get_first_node_in_group("system_map") as SystemMap
	if not is_instance_valid(player) or not is_instance_valid(map):
		Log.error("Cannot save run without the active player and system map")
		return false

	var installed_ids: Array[String] = []
	for module in player.installed_modules:
		var installed_module_id: StringName = get_module_id(module)
		if installed_module_id == &"":
			Log.error("Cannot save a module without a stable YARD ID", module.display_name)
			return false
		installed_ids.append(String(installed_module_id))
	var reserve_ids: Array[String] = []
	for module in player.unequipped_modules:
		var reserve_module_id: StringName = get_module_id(module)
		if reserve_module_id == &"":
			Log.error("Cannot save a module without a stable YARD ID", module.display_name)
			return false
		reserve_ids.append(String(reserve_module_id))

	var config := ConfigFile.new()
	config.set_value("run", "valid", true)
	config.set_value("run", "run_seed", run_seed)
	config.set_value("run", "sector_id", current_sector_id)
	config.set_value("run", "map_node_id", map.current_node_id)
	config.set_value("run", "sector_clear", current_sector_clear)
	config.set_value("run", "world_tick", world_tick)
	config.set_value("run", "credits", credits)
	config.set_value("run", "main_objective_complete", main_objective_complete)
	config.set_value("run", "side_objective_complete", side_objective_complete)
	config.set_value("run", "side_objective_expired", side_objective_expired)
	config.set_value("run", "outpost_alerted", outpost_alerted)
	config.set_value("run", "outpost_destroyed", outpost_destroyed)
	config.set_value("run", "outpost_reinforcement_level", outpost_reinforcement_level)
	config.set_value("run", "caravan_route_index", caravan_route_index)
	config.set_value("run", "known_caravan_sector", known_caravan_sector)
	config.set_value("run", "system_index", current_system_index)
	config.set_value("run", "system_id", String(current_system_id))
	config.set_value("player", "ship_id", String(player.ship_id))
	config.set_value("player", "pilot_id", String(player.pilot_id))
	config.set_value("player", "weapon_id", String(player.active_weapon_id))
	config.set_value("player", "data", {
		"hull": player.hull,
		"shield": player.shield,
		"position": player.global_position,
		"velocity": player.velocity,
		"pilot_cooldown_left": player.pilot_cooldown_left,
		"ship_id": String(player.ship_id),
		"pilot_id": String(player.pilot_id),
		"weapon_id": String(player.active_weapon_id),
		"installed_modules": installed_ids,
		"unequipped_modules": reserve_ids,
	})
	var save_error: Error = config.save(RUN_SAVE_PATH)
	if save_error != OK:
		Log.error("Could not save current run", error_string(save_error))
		return false
	Log.info("Current run saved", current_sector_id, map.current_node_id, world_tick)
	return true


## Reinstall saved YARD modules and restore player damage, movement, and ability cooldown.
func apply_saved_player_state(player: PlayerShip) -> void:
	if not resume_pending or not is_instance_valid(player):
		return
	player.installed_modules.clear()
	player.unequipped_modules.clear()
	for module_id in _saved_player_data.get("installed_modules", []):
		var module: ModuleDefinition = get_module(StringName(str(module_id)))
		if module != null:
			player.install_module(module)
	for module_id in _saved_player_data.get("unequipped_modules", []):
		var module: ModuleDefinition = get_module(StringName(str(module_id)))
		if module != null:
			player.store_module(module)
	player.hull = clampf(float(_saved_player_data.get("hull", player.max_hull)), 0.0, player.max_hull)
	player.shield = clampf(float(_saved_player_data.get("shield", player.max_shield)), 0.0, player.max_shield)
	var saved_velocity: Variant = _saved_player_data.get("velocity", Vector2.ZERO)
	if saved_velocity is Vector2:
		player.velocity = saved_velocity
	player.pilot_cooldown_left = maxf(float(_saved_player_data.get("pilot_cooldown_left", 0.0)), 0.0)
	var saved_weapon_id: StringName = StringName(str(_saved_player_data.get("weapon_id", "")))
	if saved_weapon_id != &"" and not player.equip_weapon(saved_weapon_id, false):
		player.equip_weapon(BaseShip.STARTING_WEAPON_ID, false)
	player.hull_changed.emit(player.hull, player.max_hull)
	player.shield_changed.emit(player.shield, player.max_shield)
	player.modules_changed.emit()


## Return the saved player coordinate, or a zero vector when no usable snapshot exists.
func get_saved_player_position() -> Vector2:
	var saved_position: Variant = _saved_player_data.get("position", Vector2.ZERO)
	return saved_position if saved_position is Vector2 else Vector2.ZERO


## Remove the continue save after starting or completing a run.
func clear_saved_run() -> void:
	if FileAccess.file_exists(RUN_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_SAVE_PATH))
	resume_pending = false
	_saved_player_data.clear()


## Publish the active sector's objective-and-hostile clear state when it changes.
func set_current_sector_clear(is_clear: bool) -> void:
	if current_sector_clear == is_clear:
		return

	current_sector_clear = is_clear
	run_state_changed.emit()
	Log.info("Sector clear state changed", current_sector_id, current_sector_clear)


## Add a positive credit reward; ignores zero and negative values.
func add_credits(amount: int) -> void:
	# Positive rewards go through this API; purchases use spend_credits instead.
	if amount <= 0:
		return

	credits += amount
	credits_changed.emit(credits)
	run_state_changed.emit()
	Log.debug("Credits added", amount, credits)


## Spend a nonnegative amount; returns false and leaves credits unchanged when unaffordable.
func spend_credits(amount: int) -> bool:
	# Reject negative costs so a malicious or mistaken price cannot grant credits.
	if amount < 0 or credits < amount:
		return false

	credits -= amount
	credits_changed.emit(credits)
	run_state_changed.emit()
	Log.debug("Credits spent", amount, credits)
	return true

## Return the caravan's true route sector, which can differ from the player's stale intel.
func get_actual_caravan_sector() -> String:
	# The route index advances with world time and stops at its final destination.
	return CARAVAN_ROUTE[caravan_route_index]


## Update last-known caravan intel to the current sector and notify UI listeners.
func reveal_caravan_here() -> void:
	# Update the player's last-known location without changing the caravan's route.
	known_caravan_sector = current_sector_id
	run_state_changed.emit()
	Log.info("Caravan location discovered", known_caravan_sector)


## Advance discrete world systems once; the coordinator calls this on accepted travel.
func advance_world() -> void:
	# A sector transition is the discrete event that advances world systems.
	world_tick += 1

	if caravan_route_index < CARAVAN_ROUTE.size() - 1:
		caravan_route_index += 1

	if outpost_alerted and not outpost_destroyed:
		outpost_reinforcement_level = min(outpost_reinforcement_level + 1, OUTPOST_REINFORCEMENT_MAX_LEVEL)

	if world_tick >= SIDE_OBJECTIVE_EXPIRE_TICKS and not side_objective_complete:
		side_objective_expired = true

	run_state_changed.emit()
	Log.debug("World advanced", world_tick, get_actual_caravan_sector())


## Return the compounded hostile-stat multiplier for the committed sector count.
func enemy_difficulty_multiplier() -> float:
	return pow(ENEMY_DIFFICULTY_GROWTH_PER_TICK, float(maxi(world_tick, 0)))


## Idempotently complete the main objective, persist outpost destruction, and award credits.
func complete_main_objective() -> void:
	# Make completion idempotent so duplicate triggers do not award credits twice.
	if main_objective_complete:
		return

	main_objective_complete = true
	outpost_destroyed = true
	# add_credits() itself emits run_state_changed (RULE 2's dual-signal path),
	# so the objective-flag change is broadcast exactly once, with the credit.
	add_credits(MAIN_OBJECTIVE_REWARD_CREDITS)
	Log.info("Main objective completed", current_sector_id)


## Complete the optional objective once before expiry and award its credit reward.
func complete_side_objective() -> void:
	# The optional reward is unavailable after completion or expiration.
	if side_objective_complete or side_objective_expired:
		return

	side_objective_complete = true
	# Same dual-signal path: add_credits() broadcasts run_state_changed.
	add_credits(SIDE_OBJECTIVE_REWARD_CREDITS)
	Log.info("Side objective completed", current_sector_id)


## Load a module by its stable YARD ID; returns null if the registry entry is missing.
func get_module(module_id: StringName) -> ModuleDefinition:
	# Resolve one stable YARD ID and keep callers independent of resource paths.
	return module_registry.load_entry(module_id) as ModuleDefinition if module_registry != null else null


## Return the stable YARD ID registered for a module resource, or empty when unregistered.
func get_module_id(module: ModuleDefinition) -> StringName:
	if module_registry == null or module == null:
		return &""
	# Compare the loaded definition against registry entries; save identity stays in YARD IDs.
	for module_id: StringName in module_registry.get_all_string_ids():
		var registered_module: ModuleDefinition = module_registry.load_entry(module_id) as ModuleDefinition
		if registered_module == module:
			return module_id
	return &""


## Load a weapon by its stable YARD ID; null signals an invalid or removed entry.
func get_weapon(weapon_id: StringName) -> WeaponDefinition:
	return weapon_registry.load_entry(weapon_id) as WeaponDefinition if weapon_registry != null else null


## Load a celestial-body definition by its stable YARD ID.
func get_planet(planet_id: StringName) -> PlanetDefinition:
	return planet_registry.load_entry(planet_id) as PlanetDefinition if planet_registry != null else null


## Load a hull definition by stable ID for selection and player setup.
func get_ship(ship_id: StringName) -> ShipDefinition:
	return ship_registry.load_entry(ship_id) as ShipDefinition if ship_registry != null else null


## Load a pilot definition by stable ID for selection and player setup.
func get_pilot(pilot_id: StringName) -> PilotDefinition:
	return pilot_registry.load_entry(pilot_id) as PilotDefinition if pilot_registry != null else null


## Return every valid weapon entry for weighted drops and UI selection.
func get_all_weapons() -> Array[WeaponDefinition]:
	if weapon_registry == null:
		return []
	var loaded: Dictionary[StringName, Resource] = weapon_registry.load_all_blocking()
	var by_id: Dictionary[StringName, WeaponDefinition] = {}
	for resource in loaded.values():
		if resource is WeaponDefinition:
			var weapon: WeaponDefinition = resource as WeaponDefinition
			by_id[weapon.weapon_id] = weapon
	var result: Array[WeaponDefinition] = []
	for weapon in by_id.values():
		result.append(weapon)
	return result


## Load all valid module resources from the canonical YARD registry.
func get_all_modules() -> Array[ModuleDefinition]:
	# Load the small prototype catalogue and discard entries of an unexpected type.
	if module_registry == null:
		return []
	var loaded: Dictionary[StringName, Resource] = module_registry.load_all_blocking()
	var result: Array[ModuleDefinition] = []

	for resource in loaded.values():
		if resource is ModuleDefinition:
			result.append(resource)

	return result


## Query the YARD category index and load only matching module entries.
func get_modules_by_category(category: String) -> Array[ModuleDefinition]:
	# Use the registry index to load only modules matching this category.
	var result: Array[ModuleDefinition] = []
	if module_registry == null:
		return []
	var ids: Array[StringName] = module_registry.filter(&"category", category)

	for module_id in ids:
		var module := module_registry.load_entry(module_id) as ModuleDefinition

		if module != null:
			result.append(module)

	return result


## Return a random registered module, or null if the registry has no valid modules.
func get_random_module() -> ModuleDefinition:
	# Return null for an empty registry so callers can handle missing content safely.
	var modules := get_all_modules()

	if modules.is_empty():
		return null

	return modules.pick_random()


## Choose a weapon using YARD's relative drop weights.
func get_random_weapon() -> WeaponDefinition:
	var candidates: Array[WeaponDefinition] = []
	var total_weight: float = 0.0
	for weapon: WeaponDefinition in get_all_weapons():
		if weapon.drop_weight > 0.0 and weapon.projectile_scene != null:
			candidates.append(weapon)
			total_weight += weapon.drop_weight
	if candidates.is_empty() or total_weight <= 0.0:
		return null
	var roll: float = randf() * total_weight
	for weapon: WeaponDefinition in candidates:
		roll -= weapon.drop_weight
		if roll <= 0.0:
			return weapon
	return candidates.back()


## Persist and immediately apply the Developer Console preference; failures stay fail-closed.
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
