extends GdUnitTestSuite


func test_module_slot_is_square_and_has_visual_module_icon() -> void:
	var packed: PackedScene = load("res://scenes/ui/module_inventory_slot.tscn") as PackedScene
	var slot: ModuleInventorySlot = packed.instantiate() as ModuleInventorySlot
	add_child(slot)
	await get_tree().process_frame
	var size: Vector2 = slot.custom_minimum_size
	assert_that(size.x).is_equal(size.y)
	assert_that(slot.get_node("Icon")).is_not_null()
	assert_that(slot.get_node("Label")).is_not_null()
	slot.queue_free()


func test_module_hover_text_includes_description_and_stat_delta() -> void:
	var packed: PackedScene = load("res://scenes/ui/module_inventory_slot.tscn") as PackedScene
	var slot: ModuleInventorySlot = packed.instantiate() as ModuleInventorySlot
	add_child(slot)
	await get_tree().process_frame
	var module: ModuleDefinition = load("res://assets/data/modules/long_range_scanner.tres") as ModuleDefinition
	var drop_target: Control = Control.new()
	slot.configure(module, 0, false, drop_target, 3)
	assert_that(slot.tooltip_text).contains(module.description)
	assert_that(slot.tooltip_text).contains("Stat change:")
	assert_that((slot.get_node("Icon") as TextureRect).texture).is_not_null()
	slot.queue_free()
	drop_target.free()


func test_station_has_both_inventories_and_a_sell_drop_zone() -> void:
	var station_scene: PackedScene = load("res://scenes/ui/station_panel.tscn") as PackedScene
	var station: Node = station_scene.instantiate()
	assert_that(station.get_node_or_null("MarginContainer/VBoxContainer/InventoryRow/UnequippedPanel/MarginContainer/VBoxContainer/Grid")).is_not_null()
	assert_that(station.get_node_or_null("MarginContainer/VBoxContainer/InventoryRow/EquippedPanel/MarginContainer/VBoxContainer/Grid")).is_not_null()
	assert_that(station.get_node_or_null("MarginContainer/VBoxContainer/SellZone")).is_not_null()
	station.free()


func test_hud_has_adjacent_inventory_and_stats_controls() -> void:
	var hud_scene: PackedScene = load("res://scenes/ui/hud.tscn") as PackedScene
	var hud: Node = hud_scene.instantiate()
	assert_that(hud.get_node_or_null("Root/ModuleInventoryButton")).is_not_null()
	assert_that(hud.get_node_or_null("Root/ShipStatsButton")).is_not_null()
	assert_that(hud.get_node_or_null("Root/StatsScreen")).is_not_null()
	hud.free()
