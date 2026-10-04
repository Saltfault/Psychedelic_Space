extends Control
## Drives the saved hull/pilot selection screen using existing YARD definitions.

const SHIP_IDS: Array[StringName] = [&"prototype_ship", &"corsair", &"cutter"]
const PILOT_IDS: Array[StringName] = [&"dash", &"ram"]

@onready var ship_name: Label = $CenterContainer/SelectionPanel/Content/ShipName
@onready var ship_description: Label = $CenterContainer/SelectionPanel/Content/ShipDescription
@onready var preview: Sprite2D = $CenterContainer/SelectionPanel/Preview
@onready var color_option: OptionButton = $CenterContainer/SelectionPanel/Content/ColorRow/ColorOption
@onready var pilot_name: Label = $CenterContainer/SelectionPanel/Content/PilotRow/PilotName
@onready var ability_icon: TextureRect = $CenterContainer/SelectionPanel/Content/PilotRow/AbilityIcon
@onready var confirm_button: Button = $CenterContainer/SelectionPanel/Content/Confirm
@onready var music_director: MusicDirector = $MusicDirector

var _ship_buttons: Array[Button] = []
var _ship_id: StringName = &"prototype_ship"
var _pilot_index: int = 0


func _ready() -> void:
	music_director.play_main_menu()
	_ship_buttons = [
		$CenterContainer/SelectionPanel/Content/HullButtons/Scout,
		$CenterContainer/SelectionPanel/Content/HullButtons/Corsair,
		$CenterContainer/SelectionPanel/Content/HullButtons/Cutter,
	]
	for index in range(SHIP_IDS.size()):
		_ship_buttons[index].pressed.connect(_select_ship.bind(SHIP_IDS[index]))
	for color_label: String in RunState.SHIP_COLOR_LABELS:
		color_option.add_item(color_label)
	color_option.item_selected.connect(_on_ship_color_selected)
	$CenterContainer/SelectionPanel/Content/PilotRow/PilotPrevious.pressed.connect(_step_pilot.bind(-1))
	$CenterContainer/SelectionPanel/Content/PilotRow/PilotNext.pressed.connect(_step_pilot.bind(1))
	confirm_button.pressed.connect(_confirm_selection)
	_connect_ui_sounds(self)

	if SHIP_IDS.has(RunState.selected_ship_id):
		_ship_id = RunState.selected_ship_id
	if PILOT_IDS.has(RunState.selected_pilot_id):
		_pilot_index = PILOT_IDS.find(RunState.selected_pilot_id)
	var selected_color_index: int = RunState.SHIP_COLOR_IDS.find(GameSettings.selected_ship_color_id)
	color_option.select(maxi(selected_color_index, 0))
	_select_ship(_ship_id)
	_update_pilot()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		SceneRouter.show_main_menu()
		get_viewport().set_input_as_handled()


func _select_ship(ship_id: StringName) -> void:
	var definition: ShipDefinition = RunState.get_ship(ship_id)
	if definition == null:
		Log.error("Ship selection references a missing YARD definition", ship_id)
		return
	_ship_id = ship_id
	ship_name.text = definition.display_name
	ship_description.text = definition.role_description
	preview.texture = RunState.get_ship_color_texture(GameSettings.selected_ship_color_id)
	preview.region_enabled = definition.hull_texture != null
	preview.region_rect = definition.hull_region
	for index in range(SHIP_IDS.size()):
		_ship_buttons[index].button_pressed = SHIP_IDS[index] == ship_id


func _step_pilot(direction: int) -> void:
	_pilot_index = posmod(_pilot_index + direction, PILOT_IDS.size())
	_update_pilot()


func _on_ship_color_selected(index: int) -> void:
	if index < 0 or index >= RunState.SHIP_COLOR_IDS.size():
		return
	GameSettings.set_selected_ship_color(RunState.SHIP_COLOR_IDS[index])
	preview.texture = RunState.get_ship_color_texture(GameSettings.selected_ship_color_id)


func _update_pilot() -> void:
	var pilot: PilotDefinition = RunState.get_pilot(PILOT_IDS[_pilot_index])
	if pilot == null:
		Log.error("Pilot selection references a missing YARD definition", PILOT_IDS[_pilot_index])
		return
	pilot_name.text = pilot.display_name
	ability_icon.texture = pilot.ability_icon
	RunState.selected_pilot_id = PILOT_IDS[_pilot_index]


func _confirm_selection() -> void:
	RunState.selected_ship_id = _ship_id
	RunState.selected_pilot_id = PILOT_IDS[_pilot_index]
	RunState.start_new_campaign()
	SceneRouter.show_game()


func _connect_ui_sounds(parent: Node) -> void:
	for child: Node in parent.get_children():
		if child is BaseButton and not child.button_down.is_connected(_play_ui_select):
			child.button_down.connect(_play_ui_select)
		_connect_ui_sounds(child)


func _play_ui_select() -> void:
	if EventAudio.instance != null:
		EventAudio.instance.play_2d("ui_select", null, "Menu")
