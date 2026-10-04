extends Node2D
## Presents an authored 3D shader scene as a transparent texture in the 2D sector.

@onready var viewport: SubViewport = $SubViewport
@onready var visual: Sprite2D = $Visual


func _ready() -> void:
	# The viewport remains a saved scene child; only its render target is bridged to 2D.
	visual.texture = viewport.get_texture()

