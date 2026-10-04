extends Node2D
## Scene-authored route line and arrowhead for one legal forward map edge.
class_name SystemMapRouteVisual

@onready var route_line: Line2D = $RouteLine
@onready var arrow_upper: Line2D = $ArrowUpper
@onready var arrow_lower: Line2D = $ArrowLower


## Set the points and tint on the three Line2D nodes authored in this scene.
func configure(from_point: Vector2, to_point: Vector2, tint: Color) -> void:
	route_line.points = PackedVector2Array([from_point, to_point])
	var direction: Vector2 = (to_point - from_point).normalized()
	var perpendicular: Vector2 = direction.orthogonal()
	var tip: Vector2 = to_point - direction * 13.0
	route_line.default_color = tint
	arrow_upper.default_color = tint
	arrow_lower.default_color = tint
	arrow_upper.points = PackedVector2Array([tip, tip - direction * 10.0 + perpendicular * 6.0])
	arrow_lower.points = PackedVector2Array([tip, tip - direction * 10.0 - perpendicular * 6.0])
