extends Resource
## Editable baseline movement, defense, weapon, sensor, and module-slot stats for a ship.
class_name ShipDefinition

# Name shown in ship-selection and inspection UI.
@export var display_name: String = "Prototype Ship"

# Movement is applied by BaseShip in world units and degrees per second.
@export_group("Movement")
@export var max_speed: float = 520.0
@export var thrust_acceleration: float = 700.0
@export var linear_drag: float = 40.0
@export var turn_speed_degrees: float = 220.0

@export_group("Defense")
# Hull is persistent damage; shields regenerate after the delay.
@export var max_hull: float = 100.0
@export var max_shield: float = 60.0
@export var shield_regen_per_second: float = 9.0
@export var shield_regen_delay: float = 2.5

@export_group("Weapon")
# Weapon values are copied into the ship when its YARD entry is loaded.
@export var weapon_cooldown: float = 0.18
@export var projectile_speed: float = 1000.0
@export var projectile_damage: float = 10.0

@export_group("Sensors")
@export var sensor_range: float = 1900.0

@export_group("Modules")
# Installed modules cannot exceed this capacity.
@export var module_slots: int = 4
