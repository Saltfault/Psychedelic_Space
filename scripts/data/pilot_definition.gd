extends Resource
## Authored pilot identity and active-ability tuning.
class_name PilotDefinition

## Ability identifiers stored by pilot resources and handled by PlayerShip.
enum ActiveAbility {
	DASH,
	RAM_SHIELD,
}

## Display name shown in the pilot information UI.
@export var display_name: String = "Prototype Pilot"
## Ability applied by the player controller.
@export var ability: ActiveAbility = ActiveAbility.DASH
## HUD portrait/ability image used by the selection screen and cooldown tracker.
@export var ability_icon: Texture2D
## Minimum seconds between successful ability activations.
@export var cooldown: float = 5.0
## Target forward speed during the short Dash burst, in world units per second.
@export var dash_speed: float = 900.0
## Duration of the temporary speed limit that preserves the Dash burst.
@export_range(0.05, 1.0, 0.05) var dash_duration: float = 0.22
@export_group("Ram Shield")
## Ram field durability shown in the pilot ability meter.
@export_range(1.0, 500.0, 1.0) var ram_shield_health: float = 90.0
## Minimum remaining shield durability required to activate Ram.
@export_range(1.0, 250.0, 1.0) var ram_activation_cost: float = 20.0
## Contact damage dealt while the forward shield is active.
@export_range(1.0, 500.0, 1.0) var ram_contact_damage: float = 45.0
## Time the forward shield remains active per ability press; Ram does not alter ship velocity.
@export_range(0.1, 3.0, 0.05) var ram_shield_duration: float = 0.9
## Shield points restored per second after the recharge delay.
@export_range(0.0, 200.0, 1.0) var ram_recharge_rate: float = 35.0
## Delay after depletion before the Ram shield starts recharging.
@export_range(0.0, 15.0, 0.1) var ram_recharge_delay: float = 2.0
