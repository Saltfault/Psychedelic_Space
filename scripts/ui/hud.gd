extends CanvasLayer
## Presents player status, objectives, settings, station actions, and run completion UI.
class_name GameHUD

@onready var hull_label: Label = $Root/HullLabel
@onready var hull_bar: TextureProgressBar = $Root/HullBar
@onready var shield_label: Label = $Root/ShieldLabel
@onready var shield_bar: TextureProgressBar = $Root/ShieldBar
@onready var credits_label: Label = $Root/CreditsIndicator/CreditsLabel
@onready var ability_charge: TextureProgressBar = $Root/PilotAbilityIndicator/AbilityCharge
@onready var ability_icon: TextureRect = $Root/PilotAbilityIndicator/CooldownBase
@onready var ability_charge_icon: TextureProgressBar = $Root/PilotAbilityIndicator/AbilityCharge
@onready var weapon_icon: TextureRect = $Root/WeaponIcon
@onready var weapon_label: Label = $Root/WeaponLabel
@onready var sensor_status_label: Label = $Root/SensorStatusLabel
@onready var mission_label: Label = $Root/MissionLabel
@onready var pilot_label: Label = $Root/PilotLabel
@onready var pause_button: Button = $Root/PauseButton
@onready var module_inventory_button: Button = $Root/ModuleInventoryButton
@onready var ship_stats_button: Button = $Root/ShipStatsButton
@onready var sector_travel_button: Button = $Root/SectorTravelButton
@onready var system_map: SystemMap = $Root/SystemMap
@onready var settings_panel: PanelContainer = $Root/SettingsPanel
@onready var minimap: Minimap = $Root/Minimap
@onready var long_range_sensor: LongRangeSensor = $Root/LongRangeSensor
@onready var station_panel: PanelContainer = $Root/StationPanel
@onready var run_complete_panel: PanelContainer = $Root/RunCompletePanel
@onready var death_panel: PanelContainer = $Root/DeathPanel
@onready var restart_button: Button = $Root/DeathPanel/MarginContainer/VBoxContainer/RestartButton
@onready var main_menu_button: Button = $Root/DeathPanel/MarginContainer/VBoxContainer/MainMenuButton
@onready var pause_overlay: Control = $Root/PauseMenu
@onready var equipment_screen: EquipmentScreen = $Root/EquipmentScreen
@onready var stats_screen: ShipStatsPanel = $Root/StatsScreen
@onready var pause_resume_button: Button = $Root/PauseMenu/Panel/MarginContainer/VBoxContainer/ResumeButton
@onready var pause_options_button: Button = $Root/PauseMenu/Panel/MarginContainer/VBoxContainer/OptionsButton
@onready var pause_main_menu_button: Button = $Root/PauseMenu/Panel/MarginContainer/VBoxContainer/MainMenuButton

var player: PlayerShip
var sensor_component: SensorComponent
var options_opened_from_pause: bool = false



func _ready() -> void:
	# Escape must continue to work while pause menus and other overlays pause the world.
	process_mode = Node.PROCESS_MODE_ALWAYS
	settings_panel.hide()
	station_panel.hide()
	run_complete_panel.hide()
	death_panel.hide()

	settings_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_connect_ui_sounds($Root)
	settings_panel.close_requested.connect(_on_options_closed)
	pause_button.pressed.connect(_open_pause_menu)
	module_inventory_button.pressed.connect(_open_inventory_screen)
	ship_stats_button.pressed.connect(_open_stats_screen)
	pause_resume_button.pressed.connect(_resume_game)
	pause_options_button.pressed.connect(_open_options)
	pause_main_menu_button.pressed.connect(_return_to_main_menu)
	sector_travel_button.pressed.connect(_on_sector_travel_pressed)
	if not RunState.run_state_changed.is_connected(_refresh_sector_travel_button):
		RunState.run_state_changed.connect(_refresh_sector_travel_button)
	_refresh_sector_travel_button()
	restart_button.pressed.connect(_restart_run)
	main_menu_button.pressed.connect(_return_after_death)
	GameSettings.settings_changed.connect(_sync_game_settings)
	_sync_game_settings()
	equipment_screen.closed.connect(_on_equipment_closed)
	stats_screen.closed.connect(_on_stats_closed)

	# The HUD is a sibling of PlayerShip in Sector; defer until every sibling is ready.
	call_deferred("_configure_player_from_tree")


func _unhandled_input(event: InputEvent) -> void:
	var is_escape_key: bool = (
		event is InputEventKey
		and (event as InputEventKey).pressed
		and not (event as InputEventKey).echo
		and (event as InputEventKey).keycode == KEY_ESCAPE
	)
	if not is_escape_key and not event.is_action_pressed("ui_cancel"):
		return
	if death_panel.visible or run_complete_panel.visible:
		return

	if equipment_screen.visible:
		equipment_screen.close_screen()
	elif stats_screen.visible:
		stats_screen.close_panel()
	elif station_panel.visible:
		station_panel.close_panel()
	elif system_map.visible:
		system_map.close_map()
	elif settings_panel.visible:
		settings_panel.hide()
		_on_options_closed()
	elif pause_overlay.visible:
		_resume_game()
	else:
		_open_pause_menu()
	get_viewport().set_input_as_handled()


func _refresh_sector_travel_button() -> void:
	# The final warp sector is exited through its physical gate, not the route map.
	sector_travel_button.visible = (
		RunState.current_sector_clear and RunState.current_sector_id != "warp"
	)


func _sync_game_settings() -> void:
	minimap.visible = GameSettings.show_minimap


func _on_sector_travel_pressed() -> void:
	# Keep the action guarded even if another script invokes the button signal directly.
	# The warp sector is exited through its gate only, mirroring the button's visibility rule.
	if not RunState.current_sector_clear or RunState.current_sector_id == "warp":
		return
	system_map.open_map()


func _configure_player_from_tree() -> void:
	var target_player: PlayerShip = get_tree().get_first_node_in_group("player_ship") as PlayerShip
	if target_player == null:
		Log.error("HUD could not find a player_ship to configure")
		return
	configure(target_player)


func configure(target_player: PlayerShip) -> void:
	if not is_instance_valid(target_player):
		Log.error("HUD configure received an invalid player")
		return

	if is_instance_valid(player) and player.ram_shield.health_changed.is_connected(_on_ram_charge_changed):
		player.ram_shield.health_changed.disconnect(_on_ram_charge_changed)
	player = target_player
	if not player.ram_shield.health_changed.is_connected(_on_ram_charge_changed):
		player.ram_shield.health_changed.connect(_on_ram_charge_changed)
	sensor_component = player.get_node_or_null("SensorComponent") as SensorComponent
	if sensor_component == null:
		Log.error("HUD player is missing SensorComponent")
		return

	minimap.configure(player)
	long_range_sensor.configure(player)

	if not player.hull_changed.is_connected(_on_hull_changed):
		player.hull_changed.connect(_on_hull_changed)
	if not player.shield_changed.is_connected(_on_shield_changed):
		player.shield_changed.connect(_on_shield_changed)
	if not player.weapon_changed.is_connected(_on_weapon_changed):
		player.weapon_changed.connect(_on_weapon_changed)
	if not RunState.credits_changed.is_connected(_on_credits_changed):
		RunState.credits_changed.connect(_on_credits_changed)
	if not RunState.run_state_changed.is_connected(_refresh_mission):
		RunState.run_state_changed.connect(_refresh_mission)

	_on_hull_changed(player.hull, player.max_hull)
	_on_shield_changed(player.shield, player.max_shield)
	_on_credits_changed(RunState.credits)
	_refresh_mission()
	if player.pilot != null:
		ability_icon.texture = player.pilot.ability_icon
		ability_charge_icon.texture_progress = player.pilot.ability_icon
		ability_charge.max_value = 100.0
		ability_charge.value = 100.0 * _pilot_ability_fill_ratio()
	if player.weapon_definition != null:
		_on_weapon_changed(player.weapon_definition)


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	pilot_label.visible = true

	if sensor_component != null:
		var interference: float = sensor_component.nebula_sensor_multiplier
		sensor_status_label.visible = interference < 0.999
		if sensor_status_label.visible:
			sensor_status_label.text = "SENSORS DISRUPTED - RANGE %d%%" % roundi(interference * 100.0)

	if player.pilot == null:
		pilot_label.text = "Pilot: none"
	elif player.pilot.ability == PilotDefinition.ActiveAbility.RAM_SHIELD:
		# Ram's ability icon fill communicates shield charge without a redundant text label.
		pilot_label.text = ""
		pilot_label.visible = false
	elif player.pilot_cooldown_left <= 0.0:
		pilot_label.text = "%s ability: READY" % player.pilot.display_name
	else:
		pilot_label.text = "%s ability: %.1fs" % [
			player.pilot.display_name,
			player.pilot_cooldown_left,
		]
	ability_charge.value = 100.0 * _pilot_ability_fill_ratio()


func _pilot_ability_fill_ratio() -> float:
	if player.pilot == null:
		return 0.0
	var charge_ratio: float = player.get_pilot_cooldown_ratio()
	if player.pilot.ability == PilotDefinition.ActiveAbility.RAM_SHIELD:
		return charge_ratio
	return 1.0 - charge_ratio


func _on_ram_charge_changed(current: float, maximum: float) -> void:
	if not is_instance_valid(player) or player.pilot == null:
		return
	if player.pilot.ability != PilotDefinition.ActiveAbility.RAM_SHIELD:
		return
	ability_charge.max_value = 100.0
	ability_charge.value = 100.0 * clampf(current / maxf(maximum, 1.0), 0.0, 1.0)


func _on_hull_changed(current: float, maximum: float) -> void:
	hull_bar.max_value = maxf(maximum, 1.0)
	hull_bar.value = current
	hull_label.text = "HULL %d / %d" % [roundi(current), roundi(maximum)]


func _on_shield_changed(current: float, maximum: float) -> void:
	shield_bar.max_value = maxf(maximum, 1.0)
	shield_bar.value = current
	shield_label.text = "SHIELD %d / %d" % [roundi(current), roundi(maximum)]


func _on_weapon_changed(weapon: WeaponDefinition) -> void:
	if weapon == null:
		return
	weapon_icon.texture = weapon.icon
	weapon_label.text = "WEAPON: %s" % weapon.display_name.to_upper()


func _on_credits_changed(value: int) -> void:
	credits_label.text = "CR %d" % value


func _refresh_mission() -> void:
	var main_text: String = "MAIN: Destroy listening outpost"
	if RunState.main_objective_complete:
		main_text = "MAIN: Listening outpost destroyed"

	var side_text: String = "SIDE: Recover experimental intel"
	if RunState.side_objective_complete:
		side_text = "SIDE: Intel recovered"
	elif RunState.side_objective_expired:
		side_text = "SIDE: Intel signal lost"

	mission_label.text = "%s\n%s\nLast known caravan: %s" % [
		main_text,
		side_text,
		RunState.known_caravan_sector.to_upper(),
	]


func show_run_complete() -> void:
	RunState.clear_saved_run()
	_play_run_finished_music()
	run_complete_panel.show()


## Show end-of-run choices without silently resetting the player's progress.
func show_death_screen() -> void:
	RunState.clear_saved_run()
	_play_run_finished_music()
	pause_overlay.hide()
	settings_panel.hide()
	station_panel.hide()
	death_panel.show()


func _restart_run() -> void:
	get_tree().reload_current_scene()


func _return_to_main_menu() -> void:
	RunState.save_active_run()
	get_tree().paused = false
	_change_to_main_menu()


func _return_after_death() -> void:
	RunState.clear_saved_run()
	get_tree().paused = false
	_change_to_main_menu()


func _change_to_main_menu() -> void:
	SceneRouter.show_main_menu()


func _open_pause_menu() -> void:
	if death_panel.visible or station_panel.visible or system_map.visible:
		return
	pause_overlay.show()
	get_tree().paused = true
	var director: MusicDirector = get_tree().get_first_node_in_group("music_director") as MusicDirector
	if director != null:
		director.play_pause_track()


func _resume_game() -> void:
	pause_overlay.hide()
	get_tree().paused = false
	var director: MusicDirector = get_tree().get_first_node_in_group("music_director") as MusicDirector
	if director != null:
		director.resume_gameplay_track()


func _play_run_finished_music() -> void:
	var director: MusicDirector = get_tree().get_first_node_in_group("music_director") as MusicDirector
	if director != null:
		director.play_run_finished()


func _open_inventory_screen() -> void:
	if death_panel.visible or station_panel.visible or system_map.visible or not is_instance_valid(player):
		return
	get_tree().paused = true
	equipment_screen.configure(player)
	equipment_screen.open_inventory()


func _open_stats_screen() -> void:
	if death_panel.visible or station_panel.visible or system_map.visible or not is_instance_valid(player):
		return
	get_tree().paused = true
	stats_screen.configure(player)
	stats_screen.show()


func _on_equipment_closed() -> void:
	get_tree().paused = false


func _on_stats_closed() -> void:
	get_tree().paused = false


func _connect_ui_sounds(parent: Node) -> void:
	for child: Node in parent.get_children():
		if child is BaseButton and not child.button_down.is_connected(_play_ui_select):
			child.button_down.connect(_play_ui_select)
		_connect_ui_sounds(child)


func _play_ui_select() -> void:
	if EventAudio.instance != null:
		EventAudio.instance.play_2d("ui_select", null, "Menu")


func _open_options() -> void:
	options_opened_from_pause = true
	pause_overlay.hide()
	settings_panel.show()
	get_tree().paused = true


func _on_options_closed() -> void:
	if options_opened_from_pause and not death_panel.visible:
		options_opened_from_pause = false
		pause_overlay.show()
