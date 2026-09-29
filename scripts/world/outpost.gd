extends StaticBody2D
class_name Outpost

@export var max_hull: float = 260.0
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 700.0
@export var projectile_damage: float = 13.0
@export var attack_range: float = 1350.0

@onready var muzzle: Marker2D = $Muzzle
@onready var fire_timer: Timer = $FireTimer

var team: int = 1
var hull: float
var player: Node2D = null


func _ready() -> void:
	hull = max_hull

	add_to_group("sensor_contact")
	add_to_group("main_objective")
	set_meta("contact_type", "outpost")

	fire_timer.wait_time = 1.1
	fire_timer.timeout.connect(_try_fire)
	fire_timer.start()


func take_damage(amount: float) -> void:
	if amount <= 0.0 or hull <= 0.0:
		return

	hull = max(hull - amount, 0.0)
	Log.debug("Outpost took damage", amount, hull)

	if hull <= 0.0:
		RunState.complete_main_objective()
		Log.info("Outpost destroyed", global_position)
		queue_free()


func _try_fire() -> void:
	if projectile_scene == null:
		return

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player_ship") as Node2D

	if not is_instance_valid(player):
		return

	var delta_to_player := SectorSpace.shortest_delta(global_position, player.global_position)

	if delta_to_player.length() > attack_range:
		return

	var projectile = projectile_scene.instantiate()
	var direction := delta_to_player.normalized()

	projectile.rotation = direction.angle()
	projectile.velocity = direction * projectile_speed
	projectile.damage = projectile_damage
	projectile.team = team
	projectile.source = self

	SectorSpace.spawn_owned(projectile, muzzle.global_position)
