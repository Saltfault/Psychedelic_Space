extends Node2D
## Scene-authored visual for one selectable system-map destination.
class_name SystemMapNodeVisual

@onready var icon: Sprite2D = $Icon
@onready var selection_ring: Sprite2D = $SelectionRing
@onready var caption: Label = $Caption
@onready var objective_icon: Sprite2D = $ObjectiveIcon


## Assign map data to the Sprite2D, ring, and label already authored in the scene.
func configure(
	icon_texture: Texture2D,
	selected: bool,
	reachable: bool,
	label_text: String,
	has_outpost: bool = false,
) -> void:
	icon.texture = icon_texture
	if icon_texture != null:
		# These source icons are already 16x16; render them at native size on the route map.
		icon.scale = Vector2.ONE
	icon.modulate.a = 1.0 if reachable else 0.82
	selection_ring.visible = selected
	caption.visible = not label_text.is_empty()
	caption.text = label_text
	objective_icon.visible = has_outpost
