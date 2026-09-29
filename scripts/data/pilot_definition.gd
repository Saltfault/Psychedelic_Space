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
## Forward impulse added to the ship when Dash activates.
@export var dash_impulse: float = 900.0
