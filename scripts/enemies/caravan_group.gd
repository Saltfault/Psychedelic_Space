extends PatrolGroup


func _ready() -> void:
	add_to_group("sensor_contact")
	add_to_group("caravan")
	set_meta("contact_type", "caravan")
	super._ready()
