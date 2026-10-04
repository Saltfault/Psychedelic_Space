extends Resource
## A generated celestial body's type, map icon, and sensor signature.
class_name PlanetDefinition

## Kind assigned by a route-map planetary role.
enum BodyKind { PLANET, MOON, STAR }

## Surface preset understood by the downloaded Pixel Planet shader.
enum PlanetType { TERRAN, DESERT, ICE, LAVA, GAS_GIANT, MOON }

## All planets, moons, and stars share this world-space body radius.
const BODY_RADIUS: float = 1400.0
const BODY_DIAMETER: float = BODY_RADIUS * 2.0

## Stable ID matching the planet YARD registry.
@export var planet_id: StringName
## Name shown in inspection text.
@export var display_name: String = "Barren World"
## Terrain preset passed to the Pixel Planet shader; values match PlanetType.
@export var planet_type: PlanetType = PlanetType.TERRAN
## Surface water fraction; set near 1.0 for a water world.
@export_range(0.0, 1.0, 0.01) var sea_level: float = 0.5
## Kind used to match this definition to generated planet, moon, or star nodes.
@export var body_kind: BodyKind = BodyKind.PLANET
## Icon shared by the system map and local sensor map.
@export var map_icon: Texture2D
## Target signature multiplier; lower values are harder to contact.
@export_range(0.1, 2.0, 0.05) var sensor_signature: float = 0.7
