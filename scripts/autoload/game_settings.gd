extends Node
## Persists and applies gameplay, input, accessibility, performance, audio, and display preferences.

const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "game"
const REMAPPABLE_ACTIONS: Array[StringName] = [
	&"thrust", &"fire", &"pilot_ability", &"interact", &"system_map", &"pause",
]

signal settings_changed

var master_volume_db: float = 0.0
var master_muted: bool = false
var music_volume_db: float = 0.0
var sfx_volume_db: float = 0.0
var menu_volume_db: float = 0.0
var selected_ship_color_id: StringName = &"blue"
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
var controller_vibration: bool = true
var reduced_motion: bool = false
var reduce_flashing: bool = false
var dither_enabled: bool = true
var dither_pixel_size: int = 1
var dither_palette_mode: int = 0
var dither_levels: int = 8
var dither_mode: int = 1
var dither_strength: float = 0.18
var dither_brightness: float = 0.0
var dither_contrast: float = 1.0

var _was_paused_before_focus_loss: bool = false
## True only for tree pausing caused by an earlier focus-out event.
var _paused_by_focus_loss: bool = false
## Coalesces the per-frame writes caused by slider drags into one disk save.
var _save_scheduled: bool = false
var default_key_bindings: Dictionary = {}
var default_controller_bindings: Dictionary = {}


func _ready() -> void:
	_ensure_controller_ui_bindings()
	var config := ConfigFile.new()
	var error: int = config.load(SETTINGS_PATH)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		# A corrupt config must not skip default key binding setup below; treat
		# the file as if it did not exist and let the save that follows overwrite it.
		Log.error("Could not load game settings", error_string(error))
		config = ConfigFile.new()

	master_volume_db = clampf(float(config.get_value(SECTION, "master_volume_db", 0.0)), -40.0, 6.0)
	master_muted = bool(config.get_value(SECTION, "master_muted", false))
	music_volume_db = clampf(float(config.get_value(SECTION, "music_volume_db", 0.0)), -40.0, 6.0)
	sfx_volume_db = clampf(float(config.get_value(SECTION, "sfx_volume_db", 0.0)), -40.0, 6.0)
	menu_volume_db = clampf(float(config.get_value(SECTION, "menu_volume_db", 0.0)), -40.0, 6.0)
	selected_ship_color_id = StringName(str(config.get_value(SECTION, "ship_color_id", "blue")))
	fullscreen = bool(config.get_value(SECTION, "fullscreen", false))
	borderless = bool(config.get_value(SECTION, "borderless", false))
	vsync_enabled = bool(config.get_value(SECTION, "vsync_enabled", true))
	fps_limit = int(config.get_value(SECTION, "fps_limit", 0))
	pause_on_focus_loss = bool(config.get_value(SECTION, "pause_on_focus_loss", true))
	auto_fire = bool(config.get_value(SECTION, "auto_fire", false))
	show_minimap = bool(config.get_value(SECTION, "show_minimap", true))
	performance_profile = clampi(int(config.get_value(SECTION, "performance_profile", 0)), 0, 4)
	screen_shake_strength = clampf(float(config.get_value(SECTION, "screen_shake_strength", 1.0)), 0.0, 2.0)
	controller_vibration = bool(config.get_value(SECTION, "controller_vibration", true))
	reduced_motion = bool(config.get_value(SECTION, "reduced_motion", false))
	reduce_flashing = bool(config.get_value(SECTION, "reduce_flashing", false))
	dither_enabled = bool(config.get_value(SECTION, "dither_enabled", true))
	dither_pixel_size = clampi(int(config.get_value(SECTION, "dither_pixel_size", 1)), 1, 32)
	dither_palette_mode = clampi(int(config.get_value(SECTION, "dither_palette_mode", 0)), 0, 8)
	dither_levels = clampi(int(config.get_value(SECTION, "dither_levels", 8)), 2, 16)
	dither_mode = clampi(int(config.get_value(SECTION, "dither_mode", 1)), 0, 2)
	dither_strength = clampf(float(config.get_value(SECTION, "dither_strength", 0.18)), 0.0, 1.0)
	dither_brightness = clampf(float(config.get_value(SECTION, "dither_brightness", 0.0)), -0.5, 0.5)
	dither_contrast = clampf(float(config.get_value(SECTION, "dither_contrast", 1.0)), 0.5, 2.0)
	var saved_size: Variant = config.get_value(SECTION, "window_size", Vector2i(1280, 720))
	if saved_size is Vector2i:
		window_size = saved_size
	if not _has_keyboard_binding(&"fire"):
		set_key_binding(&"fire", KEY_F, false)
	for action in REMAPPABLE_ACTIONS:
		if InputMap.has_action(action):
			default_key_bindings[action] = _read_key_binding(action)
			default_controller_bindings[action] = _read_controller_binding(action)
	var saved_bindings: Variant = config.get_value(SECTION, "key_bindings", {})
	if saved_bindings is Dictionary:
		for action_name in saved_bindings:
			var action: StringName = StringName(action_name)
			if InputMap.has_action(action):
				set_key_binding(action, int(saved_bindings[action_name]), false)
	var saved_controller_bindings: Variant = config.get_value(SECTION, "controller_bindings", {})
	if saved_controller_bindings is Dictionary:
		for action_name: Variant in saved_controller_bindings:
			var action: StringName = StringName(action_name)
			var binding: Variant = saved_controller_bindings[action_name]
			if InputMap.has_action(action) and binding is Array:
				_set_controller_binding_data(action, binding, false)
	_apply()
	_apply_accessibility()
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


## Apply and persist the dedicated music bus level.
func set_music_volume(value_db: float) -> void:
	music_volume_db = clampf(value_db, -40.0, 6.0)
	_apply_audio()
	_queue_save()
	settings_changed.emit()


## Apply and persist the gameplay sound-effects bus level.
func set_sfx_volume(value_db: float) -> void:
	sfx_volume_db = clampf(value_db, -40.0, 6.0)
	_apply_audio()
	_queue_save()
	settings_changed.emit()


## Apply and persist the menu/interface sound bus level.
func set_menu_volume(value_db: float) -> void:
	menu_volume_db = clampf(value_db, -40.0, 6.0)
	_apply_audio()
	_queue_save()
	settings_changed.emit()


## Save the cosmetic hull palette selection made in the ship-selection screen.
func set_selected_ship_color(color_id: StringName) -> void:
	selected_ship_color_id = color_id
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


## Persist and broadcast whether the global screen dither is active.
func set_dither_enabled(enabled: bool) -> void:
	dither_enabled = enabled
	_queue_save()
	settings_changed.emit()


## Set one shader tuning value while keeping it inside the shader's supported range.
func set_dither_pixel_size(value: int) -> void:
	dither_pixel_size = clampi(value, 1, 32)
	_queue_save()
	settings_changed.emit()


func set_dither_palette_mode(value: int) -> void:
	dither_palette_mode = clampi(value, 0, 8)
	_queue_save()
	settings_changed.emit()


func set_dither_levels(value: int) -> void:
	dither_levels = clampi(value, 2, 16)
	_queue_save()
	settings_changed.emit()


func set_dither_mode(value: int) -> void:
	dither_mode = clampi(value, 0, 2)
	_queue_save()
	settings_changed.emit()


func set_dither_strength(value: float) -> void:
	dither_strength = clampf(value, 0.0, 1.0)
	_queue_save()
	settings_changed.emit()


func set_dither_brightness(value: float) -> void:
	dither_brightness = clampf(value, -0.5, 0.5)
	_queue_save()
	settings_changed.emit()


func set_dither_contrast(value: float) -> void:
	dither_contrast = clampf(value, 0.5, 2.0)
	_queue_save()
	settings_changed.emit()


func set_performance_profile(profile: int) -> void:
	performance_profile = clampi(profile, 0, 4)
	_apply_profily_profile()
	_queue_save()
	settings_changed.emit()


func set_screen_shake_strength(value: float) -> void:
	screen_shake_strength = clampf(value, 0.0, 2.0)
	_apply_accessibility()
	_queue_save()
	settings_changed.emit()


func set_controller_vibration(enabled: bool) -> void:
	controller_vibration = enabled
	_queue_save()
	settings_changed.emit()


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	_apply_accessibility()
	_queue_save()
	settings_changed.emit()


func set_reduce_flashing(enabled: bool) -> void:
	reduce_flashing = enabled
	_apply_accessibility()
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
	key_event.physical_keycode = physical_keycode as Key
	InputMap.action_add_event(action, key_event)
	if save_changes:
		_save()
		settings_changed.emit()


## Return a short readable label for this action's active gamepad binding.
func get_controller_binding_label(action: StringName) -> String:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			return _joypad_button_label((event as InputEventJoypadButton).button_index)
		if event is InputEventJoypadMotion:
			var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
			var axis_name: String = "AXIS %d" % motion.axis
			if motion.axis == JOY_AXIS_TRIGGER_LEFT:
				axis_name = "LT"
			elif motion.axis == JOY_AXIS_TRIGGER_RIGHT:
				axis_name = "RT"
			return ("-" if motion.axis_value < 0.0 else "") + axis_name
	return "UNBOUND"


## Replace only this action's gamepad event, keeping its keyboard and mouse events intact.
func set_controller_binding(action: StringName, event: InputEvent, save_changes: bool = true) -> void:
	if not InputMap.has_action(action):
		return
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	for existing: InputEvent in InputMap.action_get_events(action):
		if existing is InputEventJoypadButton or existing is InputEventJoypadMotion:
			InputMap.action_erase_event(action, existing)
	var stored_event: InputEvent = event.duplicate() as InputEvent
	stored_event.device = -1
	InputMap.action_add_event(action, stored_event)
	if save_changes:
		_save()
		settings_changed.emit()


func _read_controller_binding(action: StringName) -> Array[int]:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			return [0, (event as InputEventJoypadButton).button_index]
		if event is InputEventJoypadMotion:
			var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
			return [1, motion.axis, -1 if motion.axis_value < 0.0 else 1]
	return []


func _set_controller_binding_data(action: StringName, binding: Array, save_changes: bool) -> void:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			InputMap.action_erase_event(action, event)
	if binding.size() >= 2 and int(binding[0]) == 0:
		var button_event: InputEventJoypadButton = InputEventJoypadButton.new()
		button_event.button_index = int(binding[1]) as JoyButton
		button_event.device = -1
		InputMap.action_add_event(action, button_event)
	elif binding.size() >= 3 and int(binding[0]) == 1:
		var axis_event: InputEventJoypadMotion = InputEventJoypadMotion.new()
		axis_event.axis = int(binding[1]) as JoyAxis
		axis_event.axis_value = float(binding[2])
		axis_event.device = -1
		InputMap.action_add_event(action, axis_event)
	if save_changes:
		_save()
		settings_changed.emit()


func _joypad_button_label(button_index: int) -> String:
	match button_index:
		JOY_BUTTON_A: return "A"
		JOY_BUTTON_B: return "B"
		JOY_BUTTON_X: return "X"
		JOY_BUTTON_Y: return "Y"
		JOY_BUTTON_BACK: return "BACK"
		JOY_BUTTON_GUIDE: return "GUIDE"
		JOY_BUTTON_START: return "START"
		JOY_BUTTON_LEFT_STICK: return "L3"
		JOY_BUTTON_RIGHT_STICK: return "R3"
		JOY_BUTTON_LEFT_SHOULDER: return "LB"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB"
		JOY_BUTTON_DPAD_UP: return "DPAD UP"
		JOY_BUTTON_DPAD_DOWN: return "DPAD DOWN"
		JOY_BUTTON_DPAD_LEFT: return "DPAD LEFT"
		JOY_BUTTON_DPAD_RIGHT: return "DPAD RIGHT"
		_: return "BUTTON %d" % button_index


func _ensure_controller_ui_bindings() -> void:
	var button_actions: Dictionary = {
		"ui_accept": JOY_BUTTON_A,
		"ui_cancel": JOY_BUTTON_B,
		"ui_up": JOY_BUTTON_DPAD_UP,
		"ui_down": JOY_BUTTON_DPAD_DOWN,
		"ui_left": JOY_BUTTON_DPAD_LEFT,
		"ui_right": JOY_BUTTON_DPAD_RIGHT,
	}
	for action_name: String in button_actions:
		var action: StringName = StringName(action_name)
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var button_event: InputEventJoypadButton = InputEventJoypadButton.new()
		button_event.button_index = int(button_actions[action_name]) as JoyButton
		button_event.device = -1
		if not InputMap.action_has_event(action, button_event):
			InputMap.action_add_event(action, button_event)
	var axes: Array[Dictionary] = [
		{"action": "ui_left", "axis": JOY_AXIS_LEFT_X, "value": -1.0},
		{"action": "ui_right", "axis": JOY_AXIS_LEFT_X, "value": 1.0},
		{"action": "ui_up", "axis": JOY_AXIS_LEFT_Y, "value": -1.0},
		{"action": "ui_down", "axis": JOY_AXIS_LEFT_Y, "value": 1.0},
	]
	for data: Dictionary in axes:
		var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
		motion.axis = int(data["axis"]) as JoyAxis
		motion.axis_value = float(data["value"])
		motion.device = -1
		var action: StringName = StringName(data["action"])
		if not InputMap.action_has_event(action, motion):
			InputMap.action_add_event(action, motion)


func reset_to_defaults() -> void:
	master_volume_db = 0.0
	master_muted = false
	music_volume_db = 0.0
	sfx_volume_db = 0.0
	menu_volume_db = 0.0
	selected_ship_color_id = &"blue"
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
	controller_vibration = true
	reduced_motion = false
	reduce_flashing = false
	dither_enabled = true
	dither_pixel_size = 1
	dither_palette_mode = 0
	dither_levels = 8
	dither_mode = 1
	dither_strength = 0.18
	dither_brightness = 0.0
	dither_contrast = 1.0
	for action in default_key_bindings:
		set_key_binding(action, int(default_key_bindings[action]), false)
	for action in default_controller_bindings:
		var default_binding: Array = default_controller_bindings[action]
		_set_controller_binding_data(StringName(action), default_binding, false)
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
	_apply_accessibility()


func _apply_accessibility() -> void:
	Juicee.accessibility.reduced_motion = reduced_motion
	Juicee.accessibility.no_screenshake = reduced_motion or screen_shake_strength <= 0.0
	Juicee.accessibility.no_flash = reduce_flashing


func _apply_audio() -> void:
	var master_bus: int = AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_volume_db(master_bus, master_volume_db)
		AudioServer.set_bus_mute(master_bus, master_muted)
	for bus_control: Dictionary in [
		{"name": "Music", "volume": music_volume_db},
		{"name": "SFX", "volume": sfx_volume_db},
		{"name": "Menu", "volume": menu_volume_db},
	]:
		var bus_index: int = AudioServer.get_bus_index(String(bus_control["name"]))
		if bus_index >= 0:
			AudioServer.set_bus_volume_db(bus_index, float(bus_control["volume"]))


func _apply_display() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		# Never let the window be larger than the desktop. Windows computes the
		# desktop in OS-scaled units (125% desktop = 1536x864 logical on a 1080p
		# panel), so an authored 1920x1080 window can physically cover MORE than
		# the visible screen; content near the viewport edges then renders off
		# the monitor entirely. Clamp to the usable area and pin to its origin.
		var usable: Rect2i = DisplayServer.screen_get_usable_rect(
			DisplayServer.window_get_current_screen()
		)
		var fitted_size: Vector2i = Vector2i(
			mini(window_size.x, usable.size.x),
			mini(window_size.y, usable.size.y),
		)
		DisplayServer.window_set_size(fitted_size)
		if not fullscreen:
			DisplayServer.window_set_position(usable.position)
		# The settings persist the authored preference, not the clamped surface.
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
	config.set_value(SECTION, "music_volume_db", music_volume_db)
	config.set_value(SECTION, "sfx_volume_db", sfx_volume_db)
	config.set_value(SECTION, "menu_volume_db", menu_volume_db)
	config.set_value(SECTION, "ship_color_id", String(selected_ship_color_id))
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
	config.set_value(SECTION, "controller_vibration", controller_vibration)
	config.set_value(SECTION, "reduced_motion", reduced_motion)
	config.set_value(SECTION, "reduce_flashing", reduce_flashing)
	config.set_value(SECTION, "dither_enabled", dither_enabled)
	config.set_value(SECTION, "dither_pixel_size", dither_pixel_size)
	config.set_value(SECTION, "dither_palette_mode", dither_palette_mode)
	config.set_value(SECTION, "dither_levels", dither_levels)
	config.set_value(SECTION, "dither_mode", dither_mode)
	config.set_value(SECTION, "dither_strength", dither_strength)
	config.set_value(SECTION, "dither_brightness", dither_brightness)
	config.set_value(SECTION, "dither_contrast", dither_contrast)
	var bindings: Dictionary = {}
	var controller_bindings: Dictionary = {}
	for action in REMAPPABLE_ACTIONS:
		bindings[String(action)] = get_key_binding(action)
		controller_bindings[String(action)] = _read_controller_binding(action)
	config.set_value(SECTION, "key_bindings", bindings)
	config.set_value(SECTION, "controller_bindings", controller_bindings)
	error = config.save(SETTINGS_PATH)
	if error != OK:
		Log.error("Could not save game settings", error_string(error))
