extends Node
## Maintains the owning ship's range-limited contact list, including nebula attenuation.
class_name SensorComponent

## Seconds between complete contact-list refreshes.
@export var refresh_interval: float = 0.20

var contacts: Array[Node2D] = []
var refresh_time_left: float = 0.0
var nebula_sensor_multiplier: float = 1.0
var nebula_signature_multiplier: float = 1.0


func _process(delta: float) -> void:
	refresh_time_left -= delta

	if refresh_time_left <= 0.0:
		refresh_time_left = refresh_interval
		refresh_contacts()


## Rebuild contacts from currently eligible actors; stale contacts are removed immediately.
func refresh_contacts() -> void:
	contacts.clear()

	var ship := get_parent() as BaseShip
	if ship == null:
		return

	for node in get_tree().get_nodes_in_group("sensor_contact"):
		if node == ship:
			continue

		if not node is Node2D:
			continue

		var distance := SectorSpace.wrapped_distance(ship.global_position, node.global_position)

		var target_signature_multiplier: float = 1.0
		if node is BaseShip:
			var target_sensor := node.get_node_or_null("SensorComponent") as SensorComponent
			if target_sensor != null:
				target_signature_multiplier = target_sensor.nebula_signature_multiplier

		var contact_multiplier: float = minf(nebula_sensor_multiplier, target_signature_multiplier)
		var effective_range: float = ship.sensor_range * contact_multiplier

		if distance <= effective_range:
			contacts.append(node)

			if node.is_in_group("caravan"):
				RunState.reveal_caravan_here()


func has_contact(node: Node) -> bool:
	return node in contacts
