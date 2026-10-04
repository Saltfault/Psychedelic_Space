extends Resource
## A single YARD-authored equipment upgrade and its target stat effect.
class_name ModuleDefinition

## Quality tier controls the matching pickup sprite color.
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

## Stat operation applied by BaseShip when this module is installed.
enum Effect {
	MAX_HULL_ADD,
	MAX_SHIELD_ADD,
	FIRE_COOLDOWN_MULTIPLY,
	PROJECTILE_DAMAGE_MULTIPLY,
	THRUST_MULTIPLY,
	SENSOR_RANGE_MULTIPLY,
}

## Player-facing module name.
@export var display_name: String
## Shop description explaining the effect to the player.
@export_multiline var description: String

@export_group("Shop / Query Data")
## Drop quality used to select the module pickup sprite tint.
@export var rarity: Rarity = Rarity.COMMON
## Indexed module family used by YARD store queries.
@export_enum("offense", "defense", "mobility", "sensor", "utility") var category: String = "utility"
## Credit cost charged by the station shop.
@export var price: int = 40

@export_group("Effect")
## Operation selected from Effect; additive effects use stat units and multipliers use 1.0 as neutral.
@export var effect: Effect
## Amount added or multiplier applied according to effect.
@export var value: float = 1.0
