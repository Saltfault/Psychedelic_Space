extends Resource
## Authored pilot identity and active-ability tuning.
class_name PilotDefinition

# Ability identifiers are stable enum values stored with each pilot Resource.
enum ActiveAbility {
	DASH,
}

@export var display_name: String = "Prototype Pilot"
# These values are consumed by the pilot ability controller.
@export var ability: ActiveAbility = ActiveAbility.DASH
# Time until the ability can be activated again, in seconds.
@export var cooldown: float = 5.0
# Forward impulse added to the ship when Dash is activated.
@export var dash_impulse: float = 900.0
