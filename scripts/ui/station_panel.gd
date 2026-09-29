extends PanelContainer

@onready var credits_label: Label = $MarginContainer/VBoxContainer/Credits
@onready var hull_label: Label = $MarginContainer/VBoxContainer/Hull

@onready var offer_buttons: Array[Button] = [
	$MarginContainer/VBoxContainer/Offer1,
	$MarginContainer/VBoxContainer/Offer2,
	$MarginContainer/VBoxContainer/Offer3,
]

@onready var repair_button: Button = $MarginContainer/VBoxContainer/Repair
@onready var status_label: Label = $MarginContainer/VBoxContainer/Status
@onready var close_button: Button = $MarginContainer/VBoxContainer/Close

var player: PlayerShip = null
var offers: Array[ModuleDefinition] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	hide()

	for i in range(offer_buttons.size()):
		offer_buttons[i].pressed.connect(_buy_offer.bind(i))

	repair_button.pressed.connect(_repair)
	close_button.pressed.connect(close_panel)


func open_for(target_player: PlayerShip) -> void:
	player = target_player

	_roll_offers()
	_refresh()

	show()
	get_tree().paused = true


func close_panel() -> void:
	hide()
	get_tree().paused = false


func _roll_offers() -> void:
	offers.clear()

	var categories: Array[String] = ["offense", "defense", "mobility", "sensor"]

	categories.shuffle()

	for category in categories:
		var candidates := RunState.get_modules_by_category(category)

		if candidates.is_empty():
			continue

		offers.append(candidates.pick_random())

		if offers.size() >= 3:
			break

	if offers.size() < 3:
		var fallback := RunState.get_all_modules()
		fallback.shuffle()

		for module in fallback:
			if module in offers:
				continue

			offers.append(module)

			if offers.size() >= 3:
				break


func _refresh() -> void:
	credits_label.text = "Credits: %d" % RunState.credits

	if player != null:
		hull_label.text = (
			"Hull: %d / %d  |  Modules: %d / %d"
			% [
				roundi(player.hull),
				roundi(player.max_hull),
				player.installed_modules.size(),
				player.module_slots,
			]
		)

	for i in range(offer_buttons.size()):
		if i < offers.size():
			var module := offers[i]

			offer_buttons[i].text = (
				"%s - %d cr\n%s" % [module.display_name, module.price, module.description]
			)

			offer_buttons[i].disabled = false
		else:
			offer_buttons[i].text = "Sold Out"
			offer_buttons[i].disabled = true

	repair_button.text = "Repair 10 Hull - 10 cr"


func _buy_offer(index: int) -> void:
	if player == null:
		return

	if index < 0 or index >= offers.size():
		return

	var module := offers[index]

	if player.installed_modules.size() >= player.module_slots:
		status_label.text = "No empty module slots."
		Log.warn("Module purchase denied: insufficient credits", module.display_name, module.price)
		return

	if not player.install_module(module):
		RunState.add_credits(module.price)
		status_label.text = "Module installation failed."
		Log.error("Module purchase rolled back after install failure", module.display_name)
		return

	status_label.text = "Installed %s." % module.display_name
	Log.info("Module purchased", module.display_name, module.price)
	offers.remove_at(index)

	_refresh()


func _repair() -> void:
	if player == null:
		return

	if player.hull >= player.max_hull:
		status_label.text = "Hull already fully repaired."
		return

	if not RunState.spend_credits(10):
		status_label.text = "Not enough credits."
		Log.warn("Repair denied: insufficient credits", RunState.credits)
		return

	player.repair_hull(10.0)

	status_label.text = "Hull repaired."
	Log.info("Hull repaired at station", player.hull, player.max_hull)
	_refresh()
