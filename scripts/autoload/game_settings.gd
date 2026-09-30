extends Node
## Persists and applies gameplay, input, accessibility, performance, audio, and display preferences.

const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "game"
const REMAPPABLE_ACTIONS: Array[StringName] = [
	&"thrust", &"fire", &"pilot_ability", &"interact", &"system_map",
]

signal settings_changed

var master_volume_db: float = 0.0
var master_muted: bool = false
var fullscreen: bool = false
var borderless: bool = false
var vsync_enabled: bool = true
var window_size: Vector2i = Vector2i(1280, 720)
var fps_limit: int = 0
var pause_on_focus_loss: bool = true
var auto_fire: bool = false
var show_minimap: bool = true
var performance_profile: int = 0
var screen_shake_strength: float = 1.0

var _was_paused_before_focus_loss: bool = false
## True only for tree pausing caused by an earlier focus-out event.
var _paused_by_focus_loss: bool = false
## Coalesces the per-frame writes caused by slider drags into one disk save.
var _save_scheduled: bool = false
var default_key_bindings: Dictionary = {}


func _ready() -> void:
	var config := ConfigFile.new()
	var error: int = config.load(SETTINGS_PATH)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		# A corrupt config must not skip default key binding setup below; treat
		# the file as if it did not exist and let the save that follows overwrite it.
		Log.error("Could not load game settings", error_string(error))
		config = ConfigFile.new()

	master_volume_db = clampf(float(config.get_value(SECTION, "master_volume_db", 0.0)), -40.0, 6.0)
	master_muted = bool(config.get_value(SECTION, "master_muted", false))
	fullscreen = bool(config.get_value(SECTION, "fullscreen", false))
	borderless = bool(config.get_value(SECTION, "borderless", false))
	vsync_enabled = bool(config.get_value(SECTION, "vsync_enabled", true))
	fps_limit = int(config.get_value(SECTION, "fps_limit", 0))
	pause_on_focus_loss = bool(config.get_value(SECTION, "pause_on_focus_loss", true))
	auto_fire = bool(config.get_value(SECTION, "auto_fire", false))
	show_minimap = bool(config.get_value(SECTION, "show_minimap", true))
	performance_profile = clampi(int(config.get_value(SECTION, "performance_profile", 0)), 0, 4)
	screen_shake_strength = clampf(float(config.get_value(SECTION, "screen_shake_strength", 1.0)), 0.0, 2.0)
	var saved_size: Variant = config.get_value(SECTION, "window_size", Vector2i(1280, 720))
	if saved_size is Vector2i:
		window_size = saved_size
	if not _has_keyboard_binding(&"fire"):
		set_key_binding(&"fire", KEY_F, false)
	for action in REMAPPABLE_ACTIONS:
		if InputMap.has_action(action):
			default_key_bindings[action] = _read_key_binding(action)
	var saved_bindings: Variant = config.get_value(SECTION, "key_bindings", {})
	if saved_bindings is Dictionary:
		for action_name in saved_bindings:
			var action: StringName = StringName(action_name)
			if InputMap.has_action(action):
				set_key_binding(action, int(saved_bindings[action_name]), false)
	_apply()
	call_deferred("_apply_profily_profile")


func set_master_volume(value_db: float) -> void:
	master_volume_db = clampf(value_db, -40.0, 6.0)
	_apply_audio()
	_queue_save()
	settings_changed.emit()


func set_master_muted(muted: bool) -> void:
	master_muted = muted
	_apply_audio()
	_queue_save()
	settings_changed.emit()


func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	_apply_display()
	_queue_save()
	settings_changed.emit()


func set_borderless(enabled: bool) -> void:
	borderless = enabled
	_apply_display()
	_queue_save()
	settings_changed.emit()


func set_vsync(enabled: bool) -> void:
	vsync_enabled = enabled
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
	)
	_queue_save()
	settings_changed.emit()


func set_window_size(size: Vector2i) -> void:
	window_size = size
	if not fullscreen:
		DisplayServer.window_set_size(window_size)
	_queue_save()
	settings_changed.emit()


func set_fps_limit(value: int) -> void:
	fps_limit = maxi(value, 0)
	Engine.max_fps = fps_limit
	_queue_save()
	settings_changed.emit()


func set_pause_on_focus_loss(enabled: bool) -> void:
	pause_on_focus_loss = enabled
	_queue_save()
	settings_changed.emit()


func set_auto_fire(enabled: bool) -> void:
	auto_fire = enabled
	_queue_save()
	settings_changed.emit()


func set_show_minimap(enabled: bool) -> void:
	show_minimap = enabled
	_queue_save()
	settings_changed.emit()


func set_performance_profile(profile: int) -> void:
	performance_profile = clampi(profile, 0, 4)
	_apply_profily_profile()
	_queue_save()
	settings_changed.emit()


func set_screen_shake_strength(value: float) -> void:
	screen_shake_strength = clampf(value, 0.0, 2.0)
	_queue_save()
	settings_changed.emit()


func get_key_binding(action: StringName) -> int:
	return _read_key_binding(action)


func _read_key_binding(action: StringName) -> int:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key_event: InputEventKey = event as InputEventKey
			if key_event.physical_keycode != KEY_NONE:
				return key_event.physical_keycode
			return key_event.keycode
	return int(default_key_bindings.get(action, KEY_NONE))


func set_key_binding(action: StringName, physical_keycode: int, save_changes: bool = true) -> void:
	if not InputMap.has_action(action) or physical_keycode == KEY_NONE:
		return
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = physical_keycode
	InputMap.action_add_event(action, key_event)
	if save_changes:
		_save()
		settings_changed.emit()


func reset_to_defaults() -> void:
	master_volume_db = 0.0
	master_muted = false
	fullscreen = false
	borderless = false
	vsync_enabled = true
	window_size = Vector2i(1280, 720)
	fps_limit = 0
	pause_on_focus_loss = true
	auto_fire = false
	show_minimap = true
	performance_profile = 0
	screen_shake_strength = 1.0
	for action in default_key_bindings:
		set_key_binding(action, int(default_key_bindings[action]), false)
	_apply()
	_apply_profily_profile()
	_queue_save()
	settings_changed.emit()


func _apply() -> void:
	_apply_audio()
	_apply_display()
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	)
	Engine.max_fps = fps_limit


func _apply_audio() -> void:
	var master_bus: int = AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_volume_db(master_bus, master_volume_db)
		AudioServer.set_bus_mute(master_bus, master_muted)


func _apply_display() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(window_size)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, borderless and not fullscreen)


func _notification(what: int) -> void:
	if not is_inside_tree():
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if pause_on_focus_loss:
			_was_paused_before_focus_loss = get_tree().paused
			_paused_by_focus_loss = not _was_paused_before_focus_loss
			get_tree().paused = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		# Restore even when the setting was disabled while paused, otherwise the
		# tree would stay permanently paused.
		if _paused_by_focus_loss:
			_paused_by_focus_loss = false
			get_tree().paused = false


## Coalesce frequent saves (slider drags fire value_changed per pixel) into one disk write per frame.
func _queue_save() -> void:
	if _save_scheduled:
		return
	_save_scheduled = true
	_flush_save.call_deferred()


func _flush_save() -> void:
	_save_scheduled = false
	_save()


func _apply_profily_profile() -> void:
	var manager: ProfilyManager = get_tree().root.get_node_or_null("Profily") as ProfilyManager
	if manager == null:
		return
	if performance_profile == 0:
		manager.disable()
		return
	manager.enable()
	match performance_profile:
		1:
			manager.set_preset(ProfilyTypes.ModulePreset.FPS_BASIC)
			manager.set_module_mode(ProfilyTypes.ModuleType.SCENE, ProfilyTypes.ModuleState.OFF)
		2:
			manager.set_preset(ProfilyTypes.ModulePreset.FPS_FULL)
			manager.set_module_mode(ProfilyTypes.ModuleType.SCENE, ProfilyTypes.ModuleState.OFF)
		3:
			manager.set_preset(ProfilyTypes.ModulePreset.FPS_FULL_RAM_TEXT_AUDIO_TEXT)
			manager.set_module_mode(ProfilyTypes.ModuleType.SCENE, ProfilyTypes.ModuleState.TEXT)
		4:
			manager.set_preset(ProfilyTypes.ModulePreset.FPS_FULL_RAM_FULL_AUDIO_FULL_ADVANCED_FULL)
			manager.set_module_mode(ProfilyTypes.ModuleType.SCENE, ProfilyTypes.ModuleState.FULL)


func _has_keyboard_binding(action: StringName) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return true
	return false


func _save() -> void:
	var config := ConfigFile.new()
	var error: int = config.load(SETTINGS_PATH)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		Log.error("Could not read settings before saving display/audio preferences", error_string(error))
		return
	config.set_value(SECTION, "master_volume_db", master_volume_db)
	config.set_value(SECTION, "master_muted", master_muted)
	config.set_value(SECTION, "fullscreen", fullscreen)
	config.set_value(SECTION, "borderless", borderless)
	config.set_value(SECTION, "vsync_enabled", vsync_enabled)
	config.set_value(SECTION, "window_size", window_size)
	config.set_value(SECTION, "fps_limit", fps_limit)
	config.set_value(SECTION, "pause_on_focus_loss", pause_on_focus_loss)
	config.set_value(SECTION, "auto_fire", auto_fire)
	config.set_value(SECTION, "show_minimap", show_minimap)
	config.set_value(SECTION, "performance_profile", performance_profile)
	config.set_value(SECTION, "screen_shake_strength", screen_shake_strength)
	var bindings: Dictionary = {}
	for action in REMAPPABLE_ACTIONS:
		bindings[String(action)] = get_key_binding(action)
	config.set_value(SECTION, "key_bindings", bindings)
	error = config.save(SETTINGS_PATH)
	if error != OK:
		Log.error("Could not save game settings", error_string(error))
