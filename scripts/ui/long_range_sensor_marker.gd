extends Node2D
## Saved-scene blip art shared by station, outpost, and warp-gate sensor contacts.
class_name LongRangeSensorMarker

@onready var station_icon: Sprite2D = $StationIcon
@onready var outpost_icon: Sprite2D = $OutpostIcon
@onready var warp_gate_icon: Sprite2D = $WarpGateIcon


## Select an editor-authored contact icon while preserving its directional arrow.
func configure(contact_type: StringName) -> void:
	station_icon.visible = contact_type == &"station"
	outpost_icon.visible = contact_type == &"outpost"
	warp_gate_icon.visible = contact_type == &"warp_gate"
