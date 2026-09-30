extends Sprite2D
## Plays a horizontal sprite strip once, then frees the effect node.

## Playback rate used by all visual variants.
@export_range(1.0, 60.0, 1.0) var frames_per_second: float = 15.0
## Same-layout strips selected randomly so repeated impacts do not look identical.
@export var texture_variants: Array[Texture2D] = []
## Horizontal frame count shared by every texture in texture_variants.
@export_range(1, 60, 1) var variant_hframes: int = 10
var elapsed: float = 0.0


func _ready() -> void:
	# Each entry must use the same horizontal frame layout for a safe texture swap.
	if not texture_variants.is_empty():
		var variant_index: int = randi_range(0, texture_variants.size() - 1)
		texture = texture_variants[variant_index]
		hframes = variant_hframes

	# Always begin on the first atlas frame.
	frame = 0


func _process(delta: float) -> void:
	# Reject invalid playback settings instead of dividing by zero.
	if frames_per_second <= 0.0 or hframes <= 1:
		queue_free()
		return

	var frame_duration: float = 1.0 / frames_per_second
	elapsed += delta

	# Consume every elapsed frame interval to keep playback FPS-independent.
	while elapsed >= frame_duration:
		elapsed -= frame_duration

		if frame >= hframes - 1:
			queue_free()
			return

		frame += 1
