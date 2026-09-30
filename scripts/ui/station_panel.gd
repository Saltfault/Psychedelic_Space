extends PanelContainer
## Paused station interface for module purchases and paid hull repairs.

@onready var credits_label: Label = $MarginContainer/VBoxContainer/Credits
@onready var hull_label: Label = $MarginContainer/VBoxContainer/Hull
@onready var equipped_heading: Label = $MarginContainer/VBoxContainer/InventoryColumns/EquippedColumn/EquippedHeading
@onready var unequipped_heading: Label = $MarginContainer/VBoxContainer/InventoryColumns/UnequippedColumn/UnequippedHeading
@onready var equipped_list: ItemList = $MarginContainer/VBoxContainer/InventoryColumns/EquippedColumn/EquippedList
@onready var unequipped_list: ItemList = $MarginContainer/VBoxContainer/InventoryColumns/UnequippedColumn/UnequippedList
@onready var equip_button: Button = $MarginContainer/VBoxContainer/InventoryColumns/UnequippedColumn/EquipButton
@onready var unequip_button: Button = $MarginContainer/VBoxContainer/InventoryColumns/EquippedColumn/UnequipButton

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
	add_to_group("station_panel")
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	hide()

	for i in range(offer_buttons.size()):
		offer_buttons[i].pressed.connect(_buy_offer.bind(i))

	equip_button.pressed.connect(_equip_selected)
	unequip_button.pressed.connect(_unequip_selected)
	equipped_list.item_selected.connect(_refresh_inventory_controls)
	unequipped_list.item_selected.connect(_refresh_inventory_controls)
	repair_button.pressed.connect(_repair)
	close_button.pressed.connect(close_panel)


## Roll this visit's offers, bind the player, then pause the world while the panel is open.
func open_for(target_player: PlayerShip) -> void:
	if player != target_player and is_instance_valid(player):
		if player.modules_changed.is_connected(_refresh):
			player.modules_changed.disconnect(_refresh)

	player = target_player
	if is_instance_valid(player) and not player.modules_changed.is_connected(_refresh):
		player.modules_changed.connect(_refresh)

	_roll_offers()
	_refresh()

	show()
	get_tree().paused = true


## Hide the station interface and resume the scene tree.
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

	if is_instance_valid(player):
		hull_label.text = "Hull: %d / %d" % [roundi(player.hull), roundi(player.max_hull)]
		_refresh_module_inventories()
	else:
		hull_label.text = "Hull: -- / --"
		equipped_list.clear()
		unequipped_list.clear()
		_refresh_inventory_controls()

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


func _refresh_module_inventories() -> void:
	equipped_list.clear()
	unequipped_list.clear()

	if not is_instance_valid(player):
		_refresh_inventory_controls()
		return

	equipped_heading.text = "EQUIPPED  %d / %d" % [
		player.installed_modules.size(),
		player.module_slots,
	]
	unequipped_heading.text = "UNEQUIPPED  %d" % player.unequipped_modules.size()

	for module in player.installed_modules:
		equipped_list.add_item("%s [%s]\n%s" % [
			module.display_name,
			module.category,
			module.description,
		])

	for module in player.unequipped_modules:
		unequipped_list.add_item("%s [%s]\n%s" % [
			module.display_name,
			module.category,
			module.description,
		])

	_refresh_inventory_controls()


func _refresh_inventory_controls(_selected_index: int = -1) -> void:
	var equipped_selection: PackedInt32Array = equipped_list.get_selected_items()
	var reserve_selection: PackedInt32Array = unequipped_list.get_selected_items()
	unequip_button.disabled = equipped_selection.is_empty()
	equip_button.disabled = (
		reserve_selection.is_empty()
		or not is_instance_valid(player)
		or player.installed_modules.size() >= player.module_slots
	)


func _equip_selected() -> void:
	if not is_instance_valid(player):
		return
	var selected: PackedInt32Array = unequipped_list.get_selected_items()
	if selected.is_empty():
		status_label.text = "Select an unequipped module first."
		return
	if not player.equip_module(selected[0]):
		status_label.text = "No empty equipped module slots."
		return

	status_label.text = "Equipped module."
	_refresh()


func _unequip_selected() -> void:
	if not is_instance_valid(player):
		return
	var selected: PackedInt32Array = equipped_list.get_selected_items()
	if selected.is_empty():
		status_label.text = "Select an equipped module first."
		return
	if not player.unequip_module(selected[0]):
		status_label.text = "Could not move that module to reserve."
		return

	status_label.text = "Moved module to unequipped inventory."
	_refresh()


func _buy_offer(index: int) -> void:
	if not is_instance_valid(player):
		return

	if index < 0 or index >= offers.size():
		return

	var module := offers[index]

	if not RunState.spend_credits(module.price):
		status_label.text = "Not enough credits."
		Log.warn("Module purchase denied: insufficient credits", module.display_name, module.price)
		return

	if not player.store_module(module):
		RunState.add_credits(module.price)
		status_label.text = "Module storage failed; purchase refunded."
		Log.error("Module purchase rolled back after storage failure", module.display_name)
		return

	status_label.text = "Added %s to unequipped modules." % module.display_name
	Log.info("Module purchased into unequipped inventory", module.display_name, module.price)
	offers.remove_at(index)

	_refresh()


func _repair() -> void:
	if not is_instance_valid(player):
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
