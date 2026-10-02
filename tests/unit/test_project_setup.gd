extends GdUnitTestSuite


func test_default_audio_layout_has_separate_game_buses() -> void:
	var layout: AudioBusLayout = load("res://assets/audio/default_bus_layout.tres") as AudioBusLayout
	assert_that(layout).is_not_null()
	assert_that(layout.get_bus_count()).is_equal(4)
	assert_that(layout.get_bus_name(1)).is_equal(&"Music")
	assert_that(layout.get_bus_name(2)).is_equal(&"SFX")
	assert_that(layout.get_bus_name(3)).is_equal(&"Menu")
	assert_that(ProjectSettings.get_setting("audio/buses/default_bus_layout")).is_equal(
		"res://assets/audio/default_bus_layout.tres"
	)


func test_planet_registry_uses_distinct_shader_views_and_map_icons() -> void:
	var planet_paths: PackedStringArray = [
		"res://assets/data/planets/terran.tres",
		"res://assets/data/planets/gas_giant.tres",
		"res://assets/data/planets/ice.tres",
		"res://assets/data/planets/lava.tres",
		"res://assets/data/planets/moon.tres",
		"res://assets/data/planets/star.tres",
	]
	var view_paths: Array[String] = []
	var icon_paths: Array[String] = []
	for path in planet_paths:
		var planet: PlanetDefinition = load(path) as PlanetDefinition
		assert_that(planet).is_not_null()
		assert_that(planet.planet_view_scene).is_not_null()
		assert_that(planet.map_icon).is_not_null()
		view_paths.append(planet.planet_view_scene.resource_path)
		icon_paths.append(planet.map_icon.resource_path)
	var unique_views: Dictionary = {}
	var unique_icons: Dictionary = {}
	for resource_path in view_paths:
		unique_views[resource_path] = true
	for resource_path in icon_paths:
		unique_icons[resource_path] = true
	assert_that(unique_views.size()).is_equal(6)
	assert_that(unique_icons.size()).is_equal(6)
	assert_that(view_paths.has("res://scenes/world/planet_views/planet_lava.tscn")).is_true()
	assert_that(icon_paths.has("res://assets/ui/map_icons/planet_pack/GasGiant.png")).is_true()


func test_main_menu_background_uses_saved_star_shader_material() -> void:
	var menu_scene: PackedScene = load("res://scenes/ui/main_menu.tscn") as PackedScene
	var menu: Control = menu_scene.instantiate() as Control
	var background: ColorRect = menu.get_node("SpaceBackground") as ColorRect
	var material: ShaderMaterial = background.material as ShaderMaterial
	assert_that(material).is_not_null()
	assert_that(material.shader.resource_path).is_equal(
		"res://assets/shaders/backgrounds/starfield.gdshader"
	)
	menu.free()


func test_shield_pickups_share_the_blue_shader() -> void:
	for path in [
		"res://scenes/pickups/shield_booster.tscn",
		"res://scenes/pickups/large_shield_booster.tscn",
	]:
		var pickup_scene: PackedScene = load(path) as PackedScene
		var pickup: Area2D = pickup_scene.instantiate() as Area2D
		var icon: Sprite2D = pickup.get_node("Icon") as Sprite2D
		var material: ShaderMaterial = icon.material as ShaderMaterial
		assert_that(material).is_not_null()
		assert_that(material.shader.resource_path).is_equal(
			"res://assets/shaders/objects/shield_pickup_blue.gdshader"
		)
		pickup.free()


func test_generated_route_contains_a_labeled_asteroid_ring() -> void:
	var map_scene: PackedScene = load("res://scenes/ui/system_map.tscn") as PackedScene
	var map: SystemMap = map_scene.instantiate() as SystemMap
	add_child(map)
	await get_tree().process_frame
	map.generate_new_map(73519)
	var ring_found: bool = false
	for node_id in map.node_order:
		var node_data: Dictionary = map.get_node_data(node_id)
		if String(node_data.get("role", "")) == "asteroid_ring":
			ring_found = true
			break
	assert_that(ring_found).is_true()
	assert_that(SystemMap.ICON_GENERIC.resource_path).not_contains("Galaxy")
	assert_that(SystemMap.ICON_GATE.resource_path).not_contains("Galaxy")
	assert_that(SectorGenerator.ASTEROID_RING_CLUSTER_MINIMUM).is_greater(10)
	assert_that(SectorGenerator.ASTEROID_RING_ROCKS_PER_CLUSTER_MINIMUM).is_greater(4)
	map.queue_free()
