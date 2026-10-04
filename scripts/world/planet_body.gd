extends Node2D
## Non-colliding celestial body with scene-authored planet and star renderers.
class_name PlanetBody

@onready var visual: Node2D = $Visual
@onready var pixel_planet: PixelPlanetView = $Visual/PixelPlanetView
@onready var star_visual: Node2D = $Visual/StarView

var definition: PlanetDefinition
var visual_seed: int = 0

func configure(planet: PlanetDefinition, variation_seed: int = 0) -> void:
	definition = planet
	visual_seed = variation_seed
	if is_node_ready():
		_apply_definition()

func _ready() -> void:
	add_to_group("sensor_contact")
	add_to_group("planet")
	_apply_definition()

func _apply_definition() -> void:
	if definition == null:
		Log.error("PlanetBody requires a PlanetDefinition before entering the tree", get_path())
		return
	# Both renderers and their textures/materials are saved in planet_body.tscn.
	var is_star: bool = definition.body_kind == PlanetDefinition.BodyKind.STAR
	pixel_planet.visible = not is_star
	star_visual.visible = is_star
	pixel_planet.scale = Vector2.ONE * (PlanetDefinition.BODY_DIAMETER / 512.0)
	star_visual.scale = Vector2.ONE * (PlanetDefinition.BODY_DIAMETER / 512.0)
	if not is_star:
		pixel_planet.configure(definition, visual_seed)
	set_meta("planet_id", definition.planet_id)
	set_meta("contact_type", "planet")
	set_meta("sensor_signature", definition.sensor_signature)
	Log.info("Shader planet configured", definition.planet_id, definition.display_name)
