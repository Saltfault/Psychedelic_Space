extends Control
## Scene-authored marker used for nearby sensor contacts on the circular minimap.
class_name MinimapMarker

@onready var icon: TextureRect = $Icon
@onready var dot: TextureRect = $Dot


## Configure the saved icon/dot visuals; this does not create UI nodes.
func configure(texture: Texture2D, tint: Color, diameter: float) -> void:
	var marker_size: Vector2 = Vector2.ONE * diameter
	if size != marker_size:
		custom_minimum_size = marker_size
		size = marker_size
	icon.texture = texture
	icon.modulate = tint
	icon.visible = texture != null
	dot.modulate = tint
	dot.visible = texture == null
