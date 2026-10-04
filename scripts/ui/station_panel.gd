extends PanelContainer
## Paused station shop with module inventories, drag sorting, sales, and hull repair.

@export var slot_scene: PackedScene

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
@onready var unequipped_grid: GridContainer = $MarginContainer/VBoxContainer/InventoryRow/UnequippedPanel/MarginContainer/VBoxContainer/Grid
@onready var equipped_grid: GridContainer = $MarginContainer/VBoxContainer/InventoryRow/EquippedPanel/MarginContainer/VBoxContainer/Grid
@onready var sell_zone: ModuleSellDropZone = $MarginContainer/VBoxContainer/SellZone
@onready var drag_preview: ModuleDragPreview = $DragPreview

var player: PlayerShip = null
var offers: Array[ModuleDefinition] = []


func _ready() -> void:
	add_to_group("station_panel")
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	hide()
	drag_preview.hide()

	for i in range(offer_buttons.size()):
		offer_buttons[i].pressed.connect(_buy_offer.bind(i))

	repair_button.pressed.connect(_repair)
	close_button.pressed.connect(close_panel)
	sell_zone.module_dropped.connect(_sell_module_by_drop)
	if not RunState.credits_changed.is_connected(_on_credits_changed):
		RunState.credits_changed.connect(_on_credits_changed)


## Roll this visit's offers, bind the player, then pause the world while the panel is open.
func open_for(target_player: PlayerShip) -> void:
	if player != target_player and is_instance_valid(player):
		if player.modules_changed.is_connected(_on_modules_changed):
			player.modules_changed.disconnect(_on_modules_changed)

	player = target_player
	if is_instance_valid(player) and not player.modules_changed.is_connected(_on_modules_changed):
		player.modules_changed.connect(_on_modules_changed)

	_roll_offers()
	_refresh()

	show()
	get_tree().paused = true


## Hide the station interface and resume the scene tree.
func close_panel() -> void:
	end_module_drag()
	hide()
	get_tree().paused = false


## Show the saved module icon preview above station inventory while dragging.
func begin_module_drag(module: ModuleDefinition) -> void:
	drag_preview.configure(module)
	drag_preview.global_position = get_global_mouse_position() - drag_preview.size * 0.5
	drag_preview.show()


## Hide the temporary saved-scene preview after a drop or canceled drag.
func end_module_drag() -> void:
	if is_instance_valid(drag_preview):
		drag_preview.hide()


func _process(_delta: float) -> void:
	if drag_preview.visible:
		drag_preview.global_position = get_global_mouse_position() - drag_preview.size * 0.5


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
	else:
		hull_label.text = "Hull: -- / --"

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
	_refresh_inventories()


func _refresh_inventories() -> void:
	_clear_grid(unequipped_grid)
	_clear_grid(equipped_grid)
	if not is_instance_valid(player):
		return
	for index in range(BaseShip.UNEQUIPPED_MODULE_CAPACITY):
		var module: ModuleDefinition = player.unequipped_modules[index] if index < player.unequipped_modules.size() else null
		_add_module_slot(unequipped_grid, module, index, false)
	for index in range(player.module_slots):
		var module: ModuleDefinition = player.installed_modules[index] if index < player.installed_modules.size() else null
		_add_module_slot(equipped_grid, module, index, true)


func _add_module_slot(grid: GridContainer, module: ModuleDefinition, index: int, equipped: bool) -> void:
	if slot_scene == null:
		Log.error("StationPanel scene is missing its saved module slot scene", get_path())
		return
	var slot := slot_scene.instantiate() as ModuleInventorySlot
	slot.custom_minimum_size = Vector2(72, 72)
	slot.configure(module, index, equipped, self, player.module_slots)
	grid.add_child(slot)


func _clear_grid(grid: GridContainer) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()


func _on_modules_changed() -> void:
	call_deferred("_refresh")


func _on_credits_changed(_credits: int) -> void:
	call_deferred("_refresh")


## Validate a station-inventory drop before it changes the player's module arrays.
func can_accept_drop(source_equipped: bool, source_index: int, target_equipped: bool, target_index: int) -> bool:
	if not is_instance_valid(player):
		return false
	var source: Array[ModuleDefinition]
	var target: Array[ModuleDefinition]
	if source_equipped:
		source = player.installed_modules
	else:
		source = player.unequipped_modules
	if target_equipped:
		target = player.installed_modules
	else:
		target = player.unequipped_modules
	if source_index < 0 or source_index >= source.size():
		return false
	if source_equipped == target_equipped:
		var capacity: int
		if target_equipped:
			capacity = player.module_slots
		else:
			capacity = BaseShip.UNEQUIPPED_MODULE_CAPACITY
		return target_index >= 0 and target_index < capacity and target_index != source_index
	if source_equipped:
		return (
			target_index >= 0
			and target_index < BaseShip.UNEQUIPPED_MODULE_CAPACITY
			and (target_index < target.size() or target.size() < BaseShip.UNEQUIPPED_MODULE_CAPACITY)
		)
	return (
		target_index >= 0
		and target_index < player.module_slots
		and (target_index < target.size() or target.size() < player.module_slots)
	)


## Sort, equip, or unequip modules through the same saved slot scenes used by the HUD.
func move_module_by_drop(source_equipped: bool, source_index: int, target_equipped: bool, target_index: int) -> bool:
	if not can_accept_drop(source_equipped, source_index, target_equipped, target_index):
		return false
	if source_equipped == target_equipped:
		var inventory: Array[ModuleDefinition]
		if source_equipped:
			inventory = player.installed_modules
		else:
			inventory = player.unequipped_modules
		if target_index < inventory.size():
			var displaced: ModuleDefinition = inventory[target_index]
			inventory[target_index] = inventory[source_index]
			inventory[source_index] = displaced
		else:
			var moved: ModuleDefinition = inventory[source_index]
			inventory.remove_at(source_index)
			inventory.insert(mini(target_index, inventory.size()), moved)
		player.modules_changed.emit()
		return true
	var target_inventory: Array[ModuleDefinition]
	if target_equipped:
		target_inventory = player.installed_modules
	else:
		target_inventory = player.unequipped_modules
	var target_is_occupied: bool = target_index < target_inventory.size()
	if target_is_occupied:
		if source_equipped:
			return player.swap_equipped_with_reserve(source_index, target_index)
		return player.swap_equipped_with_reserve(target_index, source_index)
	if source_equipped:
		return player.unequip_module(source_index)
	return player.equip_module(source_index, target_index)


## Provide a double-click alternative to dragging in the station inventory.
func quick_move_module(source_equipped: bool, source_index: int) -> bool:
	if not is_instance_valid(player):
		return false
	var succeeded: bool
	if source_equipped:
		succeeded = player.unequip_module(source_index)
	else:
		succeeded = player.equip_module(source_index)
	if succeeded:
		status_label.text = "Module moved to reserve." if source_equipped else "Module equipped."
	else:
		status_label.text = "Could not move module; check available inventory slots."
	return succeeded


func _sell_module_by_drop(payload: Variant) -> void:
	if not is_instance_valid(player) or not payload is Dictionary:
		return
	var source_equipped: bool = bool(payload.get("source_equipped", false))
	var source_index: int = int(payload.get("source_index", -1))
	var module: ModuleDefinition = payload.get("module") as ModuleDefinition
	if module == null:
		return
	var source: Array[ModuleDefinition] = player.installed_modules if source_equipped else player.unequipped_modules
	if source_index < 0 or source_index >= source.size() or source[source_index] != module:
		return
	if source_equipped and not player.unequip_module(source_index):
		status_label.text = "Could not move the equipped module into reserve."
		return
	var inventory_index: int = player.unequipped_modules.find(module)
	if inventory_index < 0:
		return
	player.unequipped_modules.remove_at(inventory_index)
	var sale_price: int = maxi(1, floori(float(module.price) * 0.5))
	RunState.add_credits(sale_price)
	player.modules_changed.emit()
	status_label.text = "Sold %s for %d credits." % [module.display_name, sale_price]
	Log.info("Module sold at station", module.display_name, sale_price)
	call_deferred("_refresh")


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
