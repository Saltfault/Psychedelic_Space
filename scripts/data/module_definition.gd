extends Resource
## A single YARD-authored equipment upgrade and its target stat effect.
class_name ModuleDefinition

# Each enum case maps to one explicit branch in BaseShip._rebuild_stats().
enum Effect {
	MAX_HULL_ADD,
	MAX_SHIELD_ADD,
	FIRE_COOLDOWN_MULTIPLY,
	PROJECTILE_DAMAGE_MULTIPLY,
	THRUST_MULTIPLY,
	SENSOR_RANGE_MULTIPLY,
}

@export var display_name: String
@export_multiline var description: String

# Indexed by the module registry to support fast category filtering.
@export_group("Shop / Query Data")
@export_enum("offense", "defense", "mobility", "sensor", "utility") var category: String = "utility"
@export var price: int = 40

@export_group("Effect")
# Multipliers use 1.0 as neutral; additive effects use their natural stat units.
@export var effect: Effect
@export var value: float = 1.0
