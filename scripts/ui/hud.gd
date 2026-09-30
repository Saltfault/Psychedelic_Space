extends CanvasLayer
## Presents player status, objectives, settings, station actions, and run completion UI.
class_name GameHUD

@onready var hull_label: Label = $Root/HullLabel
@onready var hull_bar: TextureProgressBar = $Root/HullBar
@onready var shield_label: Label = $Root/ShieldLabel
@onready var shield_bar: TextureProgressBar = $Root/ShieldBar
@onready var credits_label: Label = $Root/CreditsLabel
@onready var sensor_status_label: Label = $Root/SensorStatusLabel
@onready var mission_label: Label = $Root/MissionLabel
@onready var pilot_label: Label = $Root/PilotLabel
@onready var settings_button: Button = $Root/SettingsButton
@onready var sector_travel_button: Button = $Root/SectorTravelButton
@onready var system_map: SystemMap = $Root/SystemMap
@onready var settings_panel: PanelContainer = $Root/SettingsPanel
@onready var minimap: Minimap = $Root/Minimap
@onready var station_panel: PanelContainer = $Root/StationPanel
@onready var run_complete_panel: PanelContainer = $Root/RunCompletePanel
@onready var death_panel: PanelContainer = $Root/DeathPanel
@onready var restart_button: Button = $Root/DeathPanel/MarginContainer/VBoxContainer/RestartButton
@onready var main_menu_button: Button = $Root/DeathPanel/MarginContainer/VBoxContainer/MainMenuButton

var player: PlayerShip
var sensor_component: SensorComponent


func _ready() -> void:
	settings_panel.hide()
	station_panel.hide()
	run_complete_panel.hide()
	death_panel.hide()

	settings_button.pressed.connect(settings_panel.show)
	sector_travel_button.pressed.connect(_on_sector_travel_pressed)
	if not RunState.run_state_changed.is_connected(_refresh_sector_travel_button):
		RunState.run_state_changed.connect(_refresh_sector_travel_button)
	_refresh_sector_travel_button()
	restart_button.pressed.connect(_restart_run)
	main_menu_button.pressed.connect(_return_to_main_menu)
	GameSettings.settings_changed.connect(_sync_game_settings)
	_sync_game_settings()

	# The HUD is a sibling of PlayerShip in Sector; defer until every sibling is ready.
	call_deferred("_configure_player_from_tree")


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

	player = target_player
	sensor_component = player.get_node_or_null("SensorComponent") as SensorComponent
	if sensor_component == null:
		Log.error("HUD player is missing SensorComponent")
		return

	minimap.configure(player)

	if not player.hull_changed.is_connected(_on_hull_changed):
		player.hull_changed.connect(_on_hull_changed)
	if not player.shield_changed.is_connected(_on_shield_changed):
		player.shield_changed.connect(_on_shield_changed)
	if not RunState.credits_changed.is_connected(_on_credits_changed):
		RunState.credits_changed.connect(_on_credits_changed)
	if not RunState.run_state_changed.is_connected(_refresh_mission):
		RunState.run_state_changed.connect(_refresh_mission)

	_on_hull_changed(player.hull, player.max_hull)
	_on_shield_changed(player.shield, player.max_shield)
	_on_credits_changed(RunState.credits)
	_refresh_mission()


func _process(_delta: float) -> void:
	if not is_instance_valid(player) or sensor_component == null:
		return

	var interference: float = sensor_component.nebula_sensor_multiplier
	sensor_status_label.visible = interference < 0.999
	if sensor_status_label.visible:
		sensor_status_label.text = "SENSORS DISRUPTED - RANGE %d%%" % roundi(interference * 100.0)

	if player.pilot == null:
		pilot_label.text = "Pilot: none"
	elif player.pilot_cooldown_left <= 0.0:
		pilot_label.text = "%s ability: READY" % player.pilot.display_name
	else:
		pilot_label.text = "%s ability: %.1fs" % [
			player.pilot.display_name,
			player.pilot_cooldown_left,
		]


func _on_hull_changed(current: float, maximum: float) -> void:
	hull_bar.max_value = maxf(maximum, 1.0)
	hull_bar.value = current
	hull_label.text = "HULL %d / %d" % [roundi(current), roundi(maximum)]


func _on_shield_changed(current: float, maximum: float) -> void:
	shield_bar.max_value = maxf(maximum, 1.0)
	shield_bar.value = current
	shield_label.text = "SHIELD %d / %d" % [roundi(current), roundi(maximum)]


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
	run_complete_panel.show()


## Show end-of-run choices without silently resetting the player's progress.
func show_death_screen() -> void:
	settings_panel.hide()
	station_panel.hide()
	death_panel.show()


func _restart_run() -> void:
	get_tree().reload_current_scene()


func _return_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
