extends RigidBody2D
## Lightweight physics rock: collisions nudge it and cause small contact damage to ships.
class_name Asteroid

const BUMP_DAMAGE: float = 3.0
const DAMAGE_REPEAT_DELAY: float = 0.75
const KNOCKBACK_IMPULSE: float = 520.0

var _damage_cooldowns: Dictionary = {}


func _ready() -> void:
	# Rocks begin asleep and weightless; only a real collision should set them moving.
	gravity_scale = 0.0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	sleeping = true
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	for body_id: Variant in _damage_cooldowns.keys():
		var time_left: float = maxf(float(_damage_cooldowns[body_id]) - delta, 0.0)
		if time_left <= 0.0:
			_damage_cooldowns.erase(body_id)
		else:
			_damage_cooldowns[body_id] = time_left


func _on_body_entered(body: Node) -> void:
	var ship: BaseShip = body as BaseShip
	if ship == null or ship.is_dead:
		return
	var body_id: int = ship.get_instance_id()
	if _damage_cooldowns.has(body_id):
		return
	_damage_cooldowns[body_id] = DAMAGE_REPEAT_DELAY
	ship.take_damage(BUMP_DAMAGE)

	# CharacterBody2D ships do not impart enough impulse on every contact, so add a gentle push.
	var push_direction: Vector2 = global_position - ship.global_position
	if push_direction.length_squared() < 0.001:
		push_direction = Vector2.RIGHT
	apply_central_impulse(push_direction.normalized() * KNOCKBACK_IMPULSE)
	apply_torque_impulse(randf_range(-24.0, 24.0))
