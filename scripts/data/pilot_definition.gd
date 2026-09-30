extends Resource
## Authored pilot identity and active-ability tuning.
class_name PilotDefinition

## Ability identifiers stored by pilot resources and handled by PlayerShip.
enum ActiveAbility {
	DASH,
}

## Display name shown in the pilot information UI.
@export var display_name: String = "Prototype Pilot"
## Ability applied by the player controller.
@export var ability: ActiveAbility = ActiveAbility.DASH
## Minimum seconds between successful ability activations.
@export var cooldown: float = 5.0
## Target forward speed during the short Dash burst, in world units per second.
@export var dash_speed: float = 900.0
## Duration of the temporary speed limit that preserves the Dash burst.
@export_range(0.05, 1.0, 0.05) var dash_duration: float = 0.22
