extends Resource
## A complete, editor-authored primary weapon profile used by ships and drops.
class_name WeaponDefinition

## Quality tier controls the matching weapon pickup sprite color.
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

## Stable ID matching the weapon YARD registry entry.
@export var weapon_id: StringName
## Name displayed in the HUD and pickup notification.
@export var display_name: String = "Pulse Cannon"
## Icon used by authored HUD and map/UI scenes.
@export var icon: Texture2D
## Drop quality used to select the weapon pickup sprite tint.
@export var rarity: Rarity = Rarity.COMMON
## Projectile scene; its root must implement Projectile.
@export var projectile_scene: PackedScene
## Per-projectile damage before target defenses.
@export_range(0.1, 500.0, 0.1) var damage: float = 10.0
## Projectile speed in world units per second.
@export_range(1.0, 5000.0, 1.0) var projectile_speed: float = 1000.0
## Delay between volleys.
@export_range(0.03, 10.0, 0.01) var cooldown: float = 0.18
## Number of projectiles emitted in each volley.
@export_range(1, 9, 1) var projectile_count: int = 1
## Total angle covered by a multi-projectile volley, in degrees.
@export_range(0.0, 90.0, 0.5) var spread_degrees: float = 0.0
## Relative chance used by the enemy weapon-drop roll.
@export_range(0.0, 100.0, 0.1) var drop_weight: float = 1.0
