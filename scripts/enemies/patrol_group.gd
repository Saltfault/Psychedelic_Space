extends Node2D
## Coordinates shared alert state for a group of independently controlled EnemyShips.
class_name PatrolGroup

## Whether members drift along the configured heading while unaware.
@export var drifting: bool = false
## Shared idle travel direction when drifting is enabled.
@export var drift_heading: Vector2 = Vector2.RIGHT
## Thrust fraction assigned to members while they are unaware.
@export_range(0.0, 1.0) var drift_thrust: float = 0.25


func _ready() -> void:
	for child in get_children():
		if child is EnemyShip:
			if drifting:
				child.unaware_heading = drift_heading.normalized()
				child.unaware_thrust = drift_thrust
			else:
				child.unaware_thrust = 0.0


## Alert every living group member, optionally sharing the source's last confirmed position.
func alert_all(_source: EnemyShip = null) -> void:
	for child in get_children():
		if child is EnemyShip:
			if is_instance_valid(_source):
				child.force_aggro(_source.last_known_player_position)
			else:
				child.force_aggro()
