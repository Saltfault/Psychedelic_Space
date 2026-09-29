extends Sprite2D
## Plays a horizontal sprite strip once, then frees the effect node.
# Plays a horizontal sprite strip once, then removes its scene instance.
class_name OneShotStrip

@export_range(1.0, 60.0, 1.0) var frames_per_second: float = 15.0
var elapsed: float = 0.0


func _ready() -> void:
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
