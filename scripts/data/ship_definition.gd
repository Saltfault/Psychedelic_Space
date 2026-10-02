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

@export_group("Destruction Effects")
## Fixed explosion artwork used when this hull is destroyed.
@export var explosion_visual: Texture2D

@export_group("Sensors")
## Maximum contact range before nebula and target-signature modifiers.
@export var sensor_range: float = 1900.0

@export_group("Modules")
## Maximum number of module slots available to this hull.
@export var module_slots: int = 4

@export_group("Ship Visuals")
## Sprite atlas used by the existing Visuals/Hull Sprite2D.
@export var hull_texture: Texture2D
## 64x64 atlas cell rectangle; use an empty rect for a standalone texture.
@export var hull_region: Rect2 = Rect2(0, 0, 64, 64)
## Optional short role description shown in ship selection.
@export_multiline var role_description: String = ""

@export_group("Audio")
## Loop used while this hull is actively thrusting; each YARD ship entry can choose its own engine tone.
@export var engine_loop: AudioStream
## Per-hull pitch tuning keeps shared source loops distinctive across ship classes.
@export_range(0.5, 2.0, 0.01) var engine_pitch_scale: float = 1.0
