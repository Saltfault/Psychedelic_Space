extends PanelContainer
## Reusable settings dialog shared by the main menu and in-game HUD.
class_name GameSettingsPanel

signal close_requested

@onready var volume_slider: HSlider = $MarginContainer/VBoxContainer/Tabs/Audio/VolumeSlider
@onready var volume_value: Label = $MarginContainer/VBoxContainer/Tabs/Audio/VolumeValue
@onready var resolution_option: OptionButton = $MarginContainer/VBoxContainer/Tabs/Video/Options/ResolutionOption
@onready var fullscreen_toggle: CheckButton = $MarginContainer/VBoxContainer/Tabs/Video/Options/FullscreenToggle
@onready var borderless_toggle: CheckButton = $MarginContainer/VBoxContainer/Tabs/Video/Options/BorderlessToggle
@onready var vsync_toggle: CheckButton = $MarginContainer/VBoxContainer/Tabs/Video/Options/VSyncToggle
@onready var fps_limit_option: OptionButton = $MarginContainer/VBoxContainer/Tabs/Video/Options/FPSLimitOption
@onready var dither_toggle: CheckButton = $MarginContainer/VBoxContainer/Tabs/Video/Options/DitherToggle
@onready var dither_palette_option: OptionButton = $MarginContainer/VBoxContainer/Tabs/Video/Options/DitherPaletteOption
@onready var dither_mode_option: OptionButton = $MarginContainer/VBoxContainer/Tabs/Video/Options/DitherModeOption
@onready var dither_pixel_slider: HSlider = $MarginContainer/VBoxContainer/Tabs/Video/Options/DitherPixelRow/DitherPixelSlider
@onready var dither_pixel_value: Label = $MarginContainer/VBoxContainer/Tabs/Video/Options/DitherPixelRow/DitherPixelValue
@onready var dither_levels_slider: HSlider = $MarginContainer/VBoxContainer/Tabs/Video/Options/DitherLevelsRow/DitherLevelsSlider
@onready var dither_levels_value: Label = $MarginContainer/VBoxContainer/Tabs/Video/Options/DitherLevelsRow/DitherLevelsValue
@onready var dither_strength_slider: HSlider = $MarginContainer/VBoxContainer/Tabs/Video/Options/DitherStrengthRow/DitherStrengthSlider
@onready var dither_strength_value: Label = $MarginContainer/VBoxContainer/Tabs/Video/Options/DitherStrengthRow/DitherStrengthValue
@onready var dither_brightness_slider: HSlider = $MarginContainer/VBoxContainer/Tabs/Video/Options/DitherBrightnessRow/DitherBrightnessSlider
@onready var dither_brightness_value: Label = $MarginContainer/VBoxContainer/Tabs/Video/Options/DitherBrightnessRow/DitherBrightnessValue
@onready var dither_contrast_slider: HSlider = $MarginContainer/VBoxContainer/Tabs/Video/Options/DitherContrastRow/DitherContrastSlider
@onready var dither_contrast_value: Label = $MarginContainer/VBoxContainer/Tabs/Video/Options/DitherContrastRow/DitherContrastValue
@onready var dev_mode_toggle: CheckButton = $MarginContainer/VBoxContainer/Tabs/General/DevModeToggle
@onready var pause_focus_toggle: CheckButton = $MarginContainer/VBoxContainer/Tabs/Gameplay/PauseFocusToggle
@onready var auto_fire_toggle: CheckButton = $MarginContainer/VBoxContainer/Tabs/Gameplay/AutoFireToggle
@onready var master_mute_toggle: CheckButton = $MarginContainer/VBoxContainer/Tabs/Audio/MuteToggle
@onready var music_volume_slider: HSlider = $MarginContainer/VBoxContainer/Tabs/Audio/MusicVolumeSlider
@onready var music_volume_value: Label = $MarginContainer/VBoxContainer/Tabs/Audio/MusicVolumeValue
@onready var sfx_volume_slider: HSlider = $MarginContainer/VBoxContainer/Tabs/Audio/SFXVolumeSlider
@onready var sfx_volume_value: Label = $MarginContainer/VBoxContainer/Tabs/Audio/SFXVolumeValue
@onready var menu_volume_slider: HSlider = $MarginContainer/VBoxContainer/Tabs/Audio/MenuVolumeSlider
@onready var menu_volume_value: Label = $MarginContainer/VBoxContainer/Tabs/Audio/MenuVolumeValue
@onready var minimap_toggle: CheckButton = $MarginContainer/VBoxContainer/Tabs/Gameplay/MinimapToggle
@onready var profily_option: OptionButton = $MarginContainer/VBoxContainer/Tabs/Other/ProfilyOption
@onready var profily_description: Label = $MarginContainer/VBoxContainer/Tabs/Other/ProfilyDescription
@onready var shake_slider: HSlider = $MarginContainer/VBoxContainer/Tabs/Gameplay/ScreenShakeSlider
@onready var shake_value: Label = $MarginContainer/VBoxContainer/Tabs/Gameplay/ScreenShakeValue
@onready var vibration_toggle: CheckButton = $MarginContainer/VBoxContainer/Tabs/Gameplay/VibrationToggle
@onready var reduced_motion_toggle: CheckButton = $MarginContainer/VBoxContainer/Tabs/Gameplay/ReducedMotionToggle
@onready var reduce_flashing_toggle: CheckButton = $MarginContainer/VBoxContainer/Tabs/Gameplay/ReduceFlashingToggle
@onready var reset_button: Button = $MarginContainer/VBoxContainer/Tabs/Other/ResetDefaultsButton
@onready var close_button: Button = $MarginContainer/VBoxContainer/CloseButton
@onready var key_buttons: Dictionary = {
	&"thrust": $MarginContainer/VBoxContainer/Tabs/Controls/ThrustRow/KeyButton,
	&"fire": $MarginContainer/VBoxContainer/Tabs/Controls/FireRow/KeyButton,
	&"pilot_ability": $MarginContainer/VBoxContainer/Tabs/Controls/DashRow/KeyButton,
	&"interact": $MarginContainer/VBoxContainer/Tabs/Controls/InteractRow/KeyButton,
	&"system_map": $MarginContainer/VBoxContainer/Tabs/Controls/MapRow/KeyButton,
}

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160),
]
const FPS_LIMITS: Array[int] = [0, 30, 45, 60, 90, 120, 144, 165, 240, 360]
const PROFILY_PROFILE_NAMES: Array[String] = [
	"Off",
	"Level 1 — FPS number",
	"Level 2 — FPS graph",
	"Level 3 — FPS, RAM, audio, and scene stats",
	"Level 4 — Full diagnostics",
]
const PROFILY_PROFILE_DESCRIPTIONS: Array[String] = [
	"Hide the Profily overlay and stop its monitors.",
	"Show only the current frame rate, with minimal overlay detail.",
	"Show the frame-rate graph without the other monitor panels.",
	"Show FPS graphs plus RAM, audio, and current-scene statistics.",
	"Show every Profily monitor, including advanced metrics and full graphs.",
]

var awaiting_key_action: StringName = &""


func _ready() -> void:
	for resolution in RESOLUTIONS:
		resolution_option.add_item("%d x %d" % [resolution.x, resolution.y])
	for limit in FPS_LIMITS:
		fps_limit_option.add_item("Unlimited" if limit == 0 else "%d FPS" % limit, limit)
	for profile_name in PROFILY_PROFILE_NAMES:
		profily_option.add_item(profile_name)
	for palette_name in [
		"Posterize", "PICO-8", "Game Boy", "Sweetie 16", "Commodore 64",
		"Endesga 32", "CGA", "Resurrect 64", "1-bit",
	]:
		dither_palette_option.add_item(palette_name)
	for dither_name in ["Off", "Bayer 4x4", "Bayer 8x8"]:
		dither_mode_option.add_item(dither_name)
	volume_slider.set_value_no_signal(GameSettings.master_volume_db)
	volume_value.text = _format_volume(GameSettings.master_volume_db)
	_sync_audio_sliders()
	_select_resolution()
	_sync_controls()
	volume_slider.value_changed.connect(_on_volume_changed)
	music_volume_slider.value_changed.connect(GameSettings.set_music_volume)
	sfx_volume_slider.value_changed.connect(GameSettings.set_sfx_volume)
	menu_volume_slider.value_changed.connect(GameSettings.set_menu_volume)
	shake_slider.value_changed.connect(GameSettings.set_screen_shake_strength)
	vibration_toggle.toggled.connect(GameSettings.set_controller_vibration)
	reduced_motion_toggle.toggled.connect(GameSettings.set_reduced_motion)
	reduce_flashing_toggle.toggled.connect(GameSettings.set_reduce_flashing)
	resolution_option.item_selected.connect(_on_resolution_selected)
	fps_limit_option.item_selected.connect(_on_fps_limit_selected)
	fullscreen_toggle.toggled.connect(GameSettings.set_fullscreen)
	borderless_toggle.toggled.connect(GameSettings.set_borderless)
	vsync_toggle.toggled.connect(GameSettings.set_vsync)
	master_mute_toggle.toggled.connect(GameSettings.set_master_muted)
	pause_focus_toggle.toggled.connect(GameSettings.set_pause_on_focus_loss)
	auto_fire_toggle.toggled.connect(GameSettings.set_auto_fire)
	minimap_toggle.toggled.connect(GameSettings.set_show_minimap)
	dither_toggle.toggled.connect(GameSettings.set_dither_enabled)
	dither_palette_option.item_selected.connect(GameSettings.set_dither_palette_mode)
	dither_mode_option.item_selected.connect(GameSettings.set_dither_mode)
	dither_pixel_slider.value_changed.connect(_on_dither_pixel_changed)
	dither_levels_slider.value_changed.connect(_on_dither_levels_changed)
	dither_strength_slider.value_changed.connect(_on_dither_strength_changed)
	dither_brightness_slider.value_changed.connect(_on_dither_brightness_changed)
	dither_contrast_slider.value_changed.connect(_on_dither_contrast_changed)
	profily_option.item_selected.connect(GameSettings.set_performance_profile)
	profily_option.item_selected.connect(_on_profily_profile_selected)
	dev_mode_toggle.toggled.connect(RunState.set_dev_mode)
	for action in key_buttons:
		var button: Button = key_buttons[action] as Button
		button.pressed.connect(_begin_key_rebind.bind(action))
	close_button.pressed.connect(_on_close_pressed)
	reset_button.pressed.connect(_on_reset_defaults)
	RunState.dev_mode_changed.connect(_sync_dev_mode)
	_sync_dev_mode(RunState.dev_mode_enabled)
	GameSettings.settings_changed.connect(_sync_controls)
	_refresh_key_labels()


func _on_volume_changed(value: float) -> void:
	GameSettings.set_master_volume(value)
	volume_value.text = _format_volume(value)


func _sync_audio_sliders() -> void:
	music_volume_slider.set_value_no_signal(GameSettings.music_volume_db)
	music_volume_value.text = _format_volume(GameSettings.music_volume_db)
	sfx_volume_slider.set_value_no_signal(GameSettings.sfx_volume_db)
	sfx_volume_value.text = _format_volume(GameSettings.sfx_volume_db)
	menu_volume_slider.set_value_no_signal(GameSettings.menu_volume_db)
	menu_volume_value.text = _format_volume(GameSettings.menu_volume_db)


func _on_resolution_selected(index: int) -> void:
	if index >= 0 and index < RESOLUTIONS.size():
		GameSettings.set_window_size(RESOLUTIONS[index])


func _on_fps_limit_selected(index: int) -> void:
	if index >= 0 and index < FPS_LIMITS.size():
		GameSettings.set_fps_limit(FPS_LIMITS[index])


func _on_dither_pixel_changed(value: float) -> void:
	GameSettings.set_dither_pixel_size(roundi(value))


func _on_dither_levels_changed(value: float) -> void:
	GameSettings.set_dither_levels(roundi(value))


func _on_dither_strength_changed(value: float) -> void:
	GameSettings.set_dither_strength(value)


func _on_dither_brightness_changed(value: float) -> void:
	GameSettings.set_dither_brightness(value)


func _on_dither_contrast_changed(value: float) -> void:
	GameSettings.set_dither_contrast(value)


func _select_resolution() -> void:
	var nearest_index: int = 0
	var nearest_distance: int = 2147483647
	for index in range(RESOLUTIONS.size()):
		var candidate: Vector2i = RESOLUTIONS[index]
		var distance: int = absi(candidate.x - GameSettings.window_size.x) + absi(candidate.y - GameSettings.window_size.y)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index
	# Programmatic selection must not re-fire item_selected on every settings sync.
	if resolution_option.selected != nearest_index:
		resolution_option.select(nearest_index)


func _sync_dev_mode(enabled: bool) -> void:
	dev_mode_toggle.set_pressed_no_signal(enabled)


func _sync_controls() -> void:
	fullscreen_toggle.set_pressed_no_signal(GameSettings.fullscreen)
	borderless_toggle.set_pressed_no_signal(GameSettings.borderless)
	vsync_toggle.set_pressed_no_signal(GameSettings.vsync_enabled)
	master_mute_toggle.set_pressed_no_signal(GameSettings.master_muted)
	_sync_audio_sliders()
	pause_focus_toggle.set_pressed_no_signal(GameSettings.pause_on_focus_loss)
	auto_fire_toggle.set_pressed_no_signal(GameSettings.auto_fire)
	minimap_toggle.set_pressed_no_signal(GameSettings.show_minimap)
	dither_toggle.set_pressed_no_signal(GameSettings.dither_enabled)
	dither_palette_option.select(GameSettings.dither_palette_mode)
	dither_mode_option.select(GameSettings.dither_mode)
	dither_pixel_slider.set_value_no_signal(GameSettings.dither_pixel_size)
	dither_pixel_value.text = str(GameSettings.dither_pixel_size)
	dither_levels_slider.set_value_no_signal(GameSettings.dither_levels)
	dither_levels_value.text = str(GameSettings.dither_levels)
	dither_strength_slider.set_value_no_signal(GameSettings.dither_strength)
	dither_strength_value.text = "%d%%" % roundi(GameSettings.dither_strength * 100.0)
	dither_brightness_slider.set_value_no_signal(GameSettings.dither_brightness)
	dither_brightness_value.text = "%.2f" % GameSettings.dither_brightness
	dither_contrast_slider.set_value_no_signal(GameSettings.dither_contrast)
	dither_contrast_value.text = "%.2f" % GameSettings.dither_contrast
	shake_slider.set_value_no_signal(GameSettings.screen_shake_strength)
	shake_value.text = "%d%%" % roundi(GameSettings.screen_shake_strength * 100.0)
	vibration_toggle.set_pressed_no_signal(GameSettings.controller_vibration)
	reduced_motion_toggle.set_pressed_no_signal(GameSettings.reduced_motion)
	reduce_flashing_toggle.set_pressed_no_signal(GameSettings.reduce_flashing)
	for index in range(FPS_LIMITS.size()):
		if FPS_LIMITS[index] == GameSettings.fps_limit:
			# Only reselect on an actual change so item_selected never loops back
			# into a setter while the panel syncs from settings_changed.
			if fps_limit_option.selected != index:
				fps_limit_option.select(index)
			break
	if profily_option.selected != GameSettings.performance_profile:
		profily_option.select(GameSettings.performance_profile)
	_sync_profily_description(GameSettings.performance_profile)
	_select_resolution()


func _on_profily_profile_selected(index: int) -> void:
	_sync_profily_description(index)


func _sync_profily_description(index: int) -> void:
	if index >= 0 and index < PROFILY_PROFILE_DESCRIPTIONS.size():
		profily_description.text = PROFILY_PROFILE_DESCRIPTIONS[index]


func _on_reset_defaults() -> void:
	GameSettings.reset_to_defaults()
	RunState.set_dev_mode(false)
	volume_slider.set_value_no_signal(GameSettings.master_volume_db)
	volume_value.text = _format_volume(GameSettings.master_volume_db)
	_refresh_key_labels()
	_sync_controls()


func _begin_key_rebind(action: StringName) -> void:
	awaiting_key_action = action
	var button: Button = key_buttons[action] as Button
	button.text = "PRESS A KEY…"


func _input(event: InputEvent) -> void:
	if awaiting_key_action.is_empty() or not visible:
		return
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_ESCAPE:
		awaiting_key_action = &""
		_refresh_key_labels()
		get_viewport().set_input_as_handled()
		return
	var physical_code: int = key_event.physical_keycode
	if physical_code == KEY_NONE:
		physical_code = key_event.keycode
	GameSettings.set_key_binding(awaiting_key_action, physical_code)
	awaiting_key_action = &""
	_refresh_key_labels()
	get_viewport().set_input_as_handled()


func _refresh_key_labels() -> void:
	for action in key_buttons:
		var button: Button = key_buttons[action] as Button
		if action == awaiting_key_action:
			button.text = "PRESS A KEY…"
		else:
			button.text = OS.get_keycode_string(GameSettings.get_key_binding(action))


func _format_volume(value: float) -> String:
	if value <= -39.9:
		return "Muted"
	return "%d dB" % roundi(value)


func _on_close_pressed() -> void:
	#Cancel any pending rebind so reopening the panel does not show a stale prompt.
	if not awaiting_key_action.is_empty():
		awaiting_key_action = &""
		_refresh_key_labels()
	hide()
	close_requested.emit()
