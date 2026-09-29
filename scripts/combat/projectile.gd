extends Area2D
class_name Projectile

var velocity: Vector2 = Vector2.ZERO
var damage: float = 10.0
var team: int = -1
var source: Node = null
var lifetime: float = 4.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# NEW CODE STARTS HERE
	# Render a matching projectile copy across the seam while keeping one hitbox.
	var projectile_visual := get_node_or_null("Sprite2D") as Node2D
	if projectile_visual != null:
		SectorSpace.register_wrap_visual(self, projectile_visual)
	# NEW CODE ENDS HERE


func _physics_process(delta: float) -> void:
	# NEW CODE STARTS HERE
	# Keep the projectile transform canonical and suppress interpolation across the seam.
	var raw_position: Vector2 = global_position + velocity * delta
	var wrapped_position: Vector2 = SectorSpace.wrap_position(raw_position)
	if raw_position.distance_squared_to(wrapped_position) > 0.0001:
		global_position = wrapped_position
		reset_physics_interpolation()
	else:
		global_position = raw_position
	# NEW CODE ENDS HERE

	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


# NEW CODE STARTS HERE
func _exit_tree() -> void:
	# Remove any visual-only copies when this projectile expires or hits something.
	SectorSpace.unregister_wrap_visual(self)
# NEW CODE ENDS HERE


func _on_body_entered(body: Node) -> void:
	if body == source:
		return

	# Physics bodies may not expose a team property, so keep get()'s nullable Variant explicit.
	var body_team: Variant = body.get("team")
	if body_team != null and int(body_team) == team:
		return

	if body.has_method("take_damage"):
		body.take_damage(damage)
		Log.debug("Projectile hit a damageable body", body.name, damage, team)

	queue_free()
