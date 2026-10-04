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


func test_planet_registry_uses_shared_renderers_and_distinct_map_icons() -> void:
	var planet_paths: PackedStringArray = [
		"res://assets/data/planets/terran.tres",
		"res://assets/data/planets/desert.tres",
		"res://assets/data/planets/gas_giant.tres",
		"res://assets/data/planets/ice.tres",
		"res://assets/data/planets/lava.tres",
		"res://assets/data/planets/moon.tres",
		"res://assets/data/planets/star.tres",
		"res://assets/data/planets/water_world.tres",
	]
	var icon_paths: Array[String] = []
	for path in planet_paths:
		var planet: PlanetDefinition = load(path) as PlanetDefinition
		assert_that(planet).is_not_null()
		assert_that(planet.map_icon).is_not_null()
		icon_paths.append(planet.map_icon.resource_path)
	var unique_icons: Dictionary = {}
	for resource_path in icon_paths:
		unique_icons[resource_path] = true
	assert_that(unique_icons.size()).is_equal(planet_paths.size())
	assert_that(icon_paths.has("res://assets/ui/map_icons/planet_pack/GasGiant.png")).is_true()
	assert_that(PlanetDefinition.BODY_DIAMETER).is_equal(2800.0)


func test_celestial_body_scene_has_visuals_but_no_collision_nodes() -> void:
	var body_scene: PackedScene = load("res://scenes/world/planet_body.tscn") as PackedScene
	var body: PlanetBody = body_scene.instantiate() as PlanetBody
	assert_that(body).is_not_null()
	assert_that(body.get_node_or_null("Visual/PixelPlanetView")).is_not_null()
	assert_that(body.get_node_or_null("Visual/StarView")).is_not_null()
	assert_that(body.find_children("*", "CollisionShape2D", true, false).size()).is_equal(0)
	assert_that(body.find_children("*", "Area2D", true, false).size()).is_equal(0)
	body.free()


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


func test_shield_pickups_use_blue_source_sprites_without_recolor_shaders() -> void:
	var expected_textures: Dictionary = {
		"res://scenes/pickups/shield_booster.tscn": "res://assets/sprites/pickups/shield_small_blue.png",
		"res://scenes/pickups/large_shield_booster.tscn": "res://assets/sprites/pickups/shield_large_blue.png",
	}
	for path: String in expected_textures:
		var pickup_scene: PackedScene = load(path) as PackedScene
		var pickup: Area2D = pickup_scene.instantiate() as Area2D
		var icon: Sprite2D = pickup.get_node("Icon") as Sprite2D
		assert_that(icon.texture.resource_path).is_equal(expected_textures[path])
		assert_that(icon.material).is_null()
		pickup.free()


func test_every_authored_ship_definition_has_a_distinct_engine_profile() -> void:
	var definition_paths: Array[String] = [
		"res://assets/data/ships/prototype_ship.tres",
		"res://assets/data/ships/corsair.tres",
		"res://assets/data/ships/security.tres",
	]
	var profiles: Dictionary = {}
	for path in definition_paths:
		var definition: ShipDefinition = load(path) as ShipDefinition
		assert_that(definition).is_not_null()
		assert_that(definition.engine_loop).is_not_null()
		var profile: String = "%s|%.2f" % [definition.engine_loop.resource_path, definition.engine_pitch_scale]
		profiles[profile] = true
	assert_that(profiles.size()).is_equal(definition_paths.size())


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
	assert_that(map.generic_icon.resource_path).not_contains("Galaxy")
	assert_that(map.gate_icon.resource_path).not_contains("Galaxy")
	assert_that(SectorGenerator.ASTEROID_RING_CLUSTER_MINIMUM).is_greater(10)
	assert_that(SectorGenerator.ASTEROID_RING_ROCKS_PER_CLUSTER_MINIMUM).is_greater(4)
	map.queue_free()
