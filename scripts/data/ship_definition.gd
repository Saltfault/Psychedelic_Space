extends Resource
## Editable baseline movement, defense, weapon, sensor, and module-slot stats for a ship.
class_name ShipDefinition

## Name shown in ship-selection and inspection UI.
@export var display_name: String = "Prototype Ship"

@export_group("Movement")
## Maximum linear speed in world units per second.
@export var max_speed: float = 520.0
## Acceleration applied while thrust is commanded.
@export var thrust_acceleration: float = 700.0
## Linear velocity lost per second when thrust is not applied.
@export var linear_drag: float = 40.0
## Maximum hull rotation rate in degrees per second.
@export var turn_speed_degrees: float = 220.0

@export_group("Defense")
## Hull capacity; hull damage persists between sectors.
@export var max_hull: float = 100.0
## Shield capacity; shields regenerate during combat after the delay.
@export var max_shield: float = 60.0
## Shield points restored per second after regeneration resumes.
@export var shield_regen_per_second: float = 9.0
## Delay after damage before shield regeneration starts, in seconds.
@export var shield_regen_delay: float = 2.5

@export_group("Weapon")
## Time between shots, in seconds.
@export var weapon_cooldown: float = 0.18
## Projectile travel speed in world units per second.
@export var projectile_speed: float = 1000.0
## Damage dealt by each projectile before target defenses.
@export var projectile_damage: float = 10.0

@export_group("Sensors")
## Maximum contact range before nebula and target-signature modifiers.
@export var sensor_range: float = 1900.0

@export_group("Modules")
## Maximum number of module slots available to this hull.
@export var module_slots: int = 4
