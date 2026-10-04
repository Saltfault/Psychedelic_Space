extends Area2D
## A team-filtered projectile that applies damage to compatible actors on contact.
class_name Projectile

var velocity: Vector2 = Vector2.ZERO
var damage: float = 10.0
var team: int = -1
var source: Node = null
var lifetime: float = 4.0
var has_impacted: bool = false

## Optional artwork override chosen by the firing ship's YARD definition.
var visual_override: Texture2D
## Default projectile artwork options kept for scene-authored non-YARD weapons.
@export var projectile_visuals: Array[Texture2D] = []
## Effect scene spawned at the point where this projectile contacts an object.
@export var hit_effect_scene: PackedScene


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# A YARD override keeps this ship's shots visually consistent; otherwise use the scene default.
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		if visual_override != null:
			sprite.texture = visual_override
		elif not projectile_visuals.is_empty():
			sprite.texture = projectile_visuals[0]

	# Render a matching projectile copy across the seam while keeping one hitbox.
	var projectile_visual := get_node_or_null("Sprite2D") as Node2D
	if projectile_visual != null:
		SectorSpace.register_wrap_visual(self, projectile_visual)


func _physics_process(delta: float) -> void:
	# Keep the projectile transform canonical and suppress interpolation across the seam.
	var raw_position: Vector2 = global_position + velocity * delta
	var wrapped_position: Vector2 = SectorSpace.wrap_position(raw_position)
	if raw_position.distance_squared_to(wrapped_position) > 0.0001:
		global_position = wrapped_position
		reset_physics_interpolation()
	else:
		global_position = raw_position

	lifetime -= delta
	if lifetime <= 0.0:
		_retire()


func _exit_tree() -> void:
	# Remove any visual-only copies when this projectile expires or hits something.
	SectorSpace.unregister_wrap_visual(self)


func _on_body_entered(body: Node) -> void:
	# A single projectile can overlap more than one body in the same physics flush.
	if has_impacted:
		return
	if body == source:
		return

	# Physics bodies may not expose a team property, so keep get()'s nullable Variant explicit.
	var body_team: Variant = body.get("team")
	if body_team != null and int(body_team) == team:
		return
	has_impacted = true

	# Spawn the effect via SectorSpace so it lands inside the active sector and
	# survives this projectile's queue_free() (attach itself happens deferred).
	if hit_effect_scene != null:
		var hit_effect: Node2D = hit_effect_scene.instantiate() as Node2D
		if hit_effect != null:
			SectorSpace.spawn_owned(hit_effect, global_position)

	if body.has_method("take_damage"):
		body.take_damage(damage)
		Log.debug("Projectile hit a damageable body", body.name, damage, team)

	_retire()


## Consume this projectile at a shield without applying its damage to the ship.
func absorb() -> void:
	if has_impacted:
		return
	has_impacted = true
	_retire()


func _retire() -> void:
	# Hide the real sprite and wrap copies immediately; queue_free alone renders through frame end.
	var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.hide()
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	SectorSpace.unregister_wrap_visual(self)
	queue_free()
