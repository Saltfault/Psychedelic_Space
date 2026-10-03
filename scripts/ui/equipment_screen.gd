extends Control
## Combined module-storage and ship-loadout screen with drag-and-drop transfers.
class_name EquipmentScreen

signal closed

const SLOT_SCENE: PackedScene = preload("res://scenes/ui/module_inventory_slot.tscn")
const WEAPON_SLOT_SCENE: PackedScene = preload("res://scenes/ui/weapon_loadout_slot.tscn")

@onready var _unequipped_grid: GridContainer = $Panel/MarginContainer/VBoxContainer/ContentRow/UnequippedPanel/MarginContainer/VBoxContainer/Grid
@onready var _equipped_grid: GridContainer = $Panel/MarginContainer/VBoxContainer/ContentRow/EquippedPanel/MarginContainer/VBoxContainer/Grid
@onready var _equipped_heading: Label = $Panel/MarginContainer/VBoxContainer/ContentRow/EquippedPanel/MarginContainer/VBoxContainer/Heading
@onready var _status: Label = $Panel/MarginContainer/VBoxContainer/Status
@onready var _credits: Label = $Panel/MarginContainer/VBoxContainer/Header/Credits
@onready var _back_button: Button = $Panel/MarginContainer/VBoxContainer/Header/BackButton
@onready var _weapon_row: HBoxContainer = $Panel/MarginContainer/VBoxContainer/WeaponRow

var player: PlayerShip


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_back_button.pressed.connect(_close)
	hide()


## Bind the screen to the active ship whose module stores it displays.
func configure(target_player: PlayerShip) -> void:
	if is_instance_valid(player) and player.modules_changed.is_connected(_on_modules_changed):
		player.modules_changed.disconnect(_on_modules_changed)
	if is_instance_valid(player) and player.weapon_changed.is_connected(_on_weapon_changed):
		player.weapon_changed.disconnect(_on_weapon_changed)
	player = target_player
	if is_instance_valid(player) and not player.modules_changed.is_connected(_on_modules_changed):
		player.modules_changed.connect(_on_modules_changed)
	if is_instance_valid(player) and not player.weapon_changed.is_connected(_on_weapon_changed):
		player.weapon_changed.connect(_on_weapon_changed)
	_refresh()


## Open both module inventories together; the game remains paused by the HUD.
func open_inventory() -> void:
	_refresh()
	show()


## Decide whether a module can be reordered, equipped, or returned to reserve.
func can_accept_drop(
	source_equipped: bool,
	source_index: int,
	target_equipped: bool,
	target_index: int,
) -> bool:
	if not is_instance_valid(player):
		return false
	var source_inventory: Array[ModuleDefinition] = (
		player.installed_modules if source_equipped else player.unequipped_modules
	)
	var target_inventory: Array[ModuleDefinition] = (
		player.installed_modules if target_equipped else player.unequipped_modules
	)
	if source_index < 0 or source_index >= source_inventory.size():
		return false
	if source_equipped == target_equipped:
		var capacity: int = player.module_slots if target_equipped else BaseShip.UNEQUIPPED_MODULE_CAPACITY
		return (
			target_index >= 0
			and target_index < capacity
			and target_index != source_index
			and (target_index < target_inventory.size() or target_index == target_inventory.size())
		)
	if source_equipped:
		return (
			target_index >= player.unequipped_modules.size()
			and target_index < BaseShip.UNEQUIPPED_MODULE_CAPACITY
			and player.unequipped_modules.size() < BaseShip.UNEQUIPPED_MODULE_CAPACITY
		)
	return (
		target_index == player.installed_modules.size()
		and player.installed_modules.size() < player.module_slots
	)


## Apply a validated drag transfer and refresh the serialized slot-scene instances.
func move_module_by_drop(
	source_equipped: bool,
	source_index: int,
	target_equipped: bool,
	target_index: int,
) -> bool:
	if not can_accept_drop(source_equipped, source_index, target_equipped, target_index):
		return false
	if source_equipped == target_equipped:
		var inventory: Array[ModuleDefinition] = (
			player.installed_modules if source_equipped else player.unequipped_modules
		)
		if target_index < inventory.size():
			var displaced: ModuleDefinition = inventory[target_index]
			inventory[target_index] = inventory[source_index]
			inventory[source_index] = displaced
		else:
			var moved: ModuleDefinition = inventory[source_index]
			inventory.remove_at(source_index)
			inventory.append(moved)
		player.modules_changed.emit()
		_status.text = "Module order updated."
		call_deferred("_refresh")
		return true
	var succeeded: bool = (
		player.unequip_module(source_index)
		if source_equipped
		else player.equip_module(source_index)
	)
	if succeeded:
		_status.text = "Module moved between inventories."
		call_deferred("_refresh")
	return succeeded


## Replace the mandatory primary weapon while refusing unknown/unregistered weapon resources.
func equip_weapon_definition(weapon: WeaponDefinition) -> bool:
	if not is_instance_valid(player) or weapon == null:
		return false
	var registered: WeaponDefinition = RunState.get_weapon(weapon.weapon_id)
	if registered == null or registered.weapon_id != weapon.weapon_id:
		return false
	var equipped: bool = player.equip_weapon(weapon.weapon_id)
	if equipped:
		_status.text = "%s equipped." % weapon.display_name
		_refresh_weapon_slot()
	return equipped


func _refresh() -> void:
	_clear_grid(_unequipped_grid)
	_clear_grid(_equipped_grid)
	if not is_instance_valid(player):
		_status.text = "No player ship is available."
		_credits.text = "CREDITS  0"
		return

	_credits.text = "CREDITS  %d" % RunState.credits
	_refresh_weapon_slot()
	for index in range(25):
		var module: ModuleDefinition = (
			player.unequipped_modules[index]
			if index < player.unequipped_modules.size()
			else null
		)
		_add_slot(_unequipped_grid, module, index, false, Vector2(72, 72))
	_equipped_heading.text = "EQUIPPED MODULES  %d / %d SLOTS" % [
		player.installed_modules.size(),
		player.module_slots,
	]
	for index in range(player.module_slots):
		var module: ModuleDefinition = (
			player.installed_modules[index]
			if index < player.installed_modules.size()
			else null
		)
		_add_slot(_equipped_grid, module, index, true, Vector2(72, 72))
	_status.text = "Drag to sort, equip, or return modules to reserve. Hover for details."


func _add_slot(
	grid: GridContainer,
	module: ModuleDefinition,
	index: int,
	equipped: bool,
	slot_size: Vector2,
) -> void:
	var slot := SLOT_SCENE.instantiate() as ModuleInventorySlot
	slot.custom_minimum_size = slot_size
	slot.configure(module, index, equipped, self, player.module_slots)
	grid.add_child(slot)


func _clear_grid(grid: GridContainer) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()


func _refresh_weapon_slot() -> void:
	for child in _weapon_row.get_children():
		_weapon_row.remove_child(child)
		child.queue_free()
	if not is_instance_valid(player):
		return
	var weapon_slot: WeaponLoadoutSlot = WEAPON_SLOT_SCENE.instantiate() as WeaponLoadoutSlot
	_weapon_row.add_child(weapon_slot)
	weapon_slot.configure(player.weapon_definition, self)


func _on_weapon_changed(_weapon: WeaponDefinition) -> void:
	call_deferred("_refresh_weapon_slot")


func _on_modules_changed() -> void:
	call_deferred("_refresh")


func _close() -> void:
	close_screen()


## Close the inventory screen and notify the HUD to resume gameplay.
func close_screen() -> void:
	hide()
	closed.emit()
