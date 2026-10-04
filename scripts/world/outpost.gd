extends StaticBody2D
## Three-phase outpost mini-boss that completes the existing main objective on defeat.
class_name Outpost

signal hull_changed(current: float, maximum: float, phase: int)
signal shield_changed(current: float, maximum: float, phase: int)

@export_range(1.0, 5000.0, 1.0) var max_hull: float = 1200.0
## Shield capacity restored whenever the outpost enters a new phase.
@export_range(1.0, 5000.0, 1.0) var max_shield: float = 360.0
@export var projectile_scene: PackedScene
@export_range(100.0, 2500.0, 25.0) var projectile_speed: float = 850.0
@export_range(1.0, 150.0, 1.0) var projectile_damage: float = 16.0
@export_range(100.0, 5000.0, 50.0) var attack_range: float = 2200.0

@onready var muzzle_top: Marker2D = $MuzzleTop
@onready var muzzle_right: Marker2D = $MuzzleRight
@onready var muzzle_bottom: Marker2D = $MuzzleBottom
@onready var muzzle_left: Marker2D = $MuzzleLeft
@onready var fire_timer: Timer = $FireTimer
@onready var visual: Sprite2D = $Visual
@onready var boss_hud: CanvasLayer = $BossHUD
@onready var boss_name: Label = $BossHUD/Panel/Content/BossName
@onready var phase_label: Label = $BossHUD/Panel/Content/PhaseLabel
@onready var shield_bar: ProgressBar = $BossHUD/Panel/Content/ShieldBar
@onready var health_bar: ProgressBar = $BossHUD/Panel/Content/HealthBar

var team: int = 1
var hull: float
var shield: float
var phase: int = 1
var player: Node2D
var difficulty_multiplier: float = 1.0


func _ready() -> void:
	difficulty_multiplier = RunState.enemy_difficulty_multiplier()
	max_hull *= difficulty_multiplier
	max_shield *= difficulty_multiplier
	projectile_damage *= difficulty_multiplier
	projectile_speed *= difficulty_multiplier
	hull = max_hull
	shield = max_shield
	add_to_group("sensor_contact")
	add_to_group("main_objective")
	set_meta("contact_type", "outpost")
	set_meta("sensor_signature", 1.0)
	SectorSpace.register_wrap_visual(self, visual)
	boss_name.text = "ENEMY OUTPOST"
	shield_bar.max_value = max_shield
	shield_bar.value = shield
	health_bar.max_value = max_hull
	health_bar.value = hull
	boss_hud.visible = RunState.outpost_alerted
	fire_timer.timeout.connect(_try_fire)
	fire_timer.wait_time = 1.15
	fire_timer.start()
	hull_changed.emit(hull, max_hull, phase)
	shield_changed.emit(shield, max_shield, phase)


func _exit_tree() -> void:
	SectorSpace.unregister_wrap_visual(self)


func _process(delta: float) -> void:
	if boss_hud.visible != RunState.outpost_alerted:
		boss_hud.visible = RunState.outpost_alerted


## Apply damage, update phase thresholds, and preserve the existing objective contract.
func take_damage(amount: float) -> void:
	if amount <= 0.0 or hull <= 0.0:
		return
	# The current phase's shield absorbs damage before the persistent hull does.
	var remaining_damage: float = amount
	var absorbed_damage: float = minf(shield, remaining_damage)
	shield -= absorbed_damage
	remaining_damage -= absorbed_damage
	if remaining_damage > 0.0:
		hull = maxf(hull - remaining_damage, 0.0)
	if GameSettings.screen_shake_strength > 0.0:
		Juicee.shake_camera(self, 1.4 * GameSettings.screen_shake_strength, 0.08, 26.0)
	var next_phase: int = 1 if hull > max_hull * 0.66 else (2 if hull > max_hull * 0.33 else 3)
	if next_phase != phase:
		phase = next_phase
		# A phase transition starts with a fresh shield instead of carrying damage forward.
		shield = max_shield
		var base_fire_interval: float = 1.15 if phase == 1 else (0.82 if phase == 2 else 0.58)
		fire_timer.wait_time = base_fire_interval / difficulty_multiplier
		if is_instance_valid(visual):
			Juicee.flash(visual, Color(1.0, 0.35, 0.2), 0.22)
		if EventAudio.instance != null:
			EventAudio.instance.play_2d("boss_phase", self, "SFX")
		Log.info("Outpost boss phase changed", phase, hull)
	shield_bar.value = shield
	health_bar.value = hull
	phase_label.text = "PHASE %d / 3" % phase
	hull_changed.emit(hull, max_hull, phase)
	shield_changed.emit(shield, max_shield, phase)
	if hull <= 0.0:
		RunState.complete_main_objective()
		if GameSettings.screen_shake_strength > 0.0:
			Juicee.shake_camera(self, 8.0 * GameSettings.screen_shake_strength, 0.36, 18.0)
		Log.info("Outpost destroyed", global_position)
		queue_free()


func _try_fire() -> void:
	if projectile_scene == null:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player_ship") as Node2D
	if not is_instance_valid(player):
		return
	var to_player: Vector2 = SectorSpace.shortest_delta(global_position, player.global_position)
	if to_player.length() > attack_range:
		return
	var muzzle: Marker2D = _muzzle_on_player_side(to_player)
	var shot_count: int = 1 if phase == 1 else (3 if phase == 2 else 5)
	var spread: float = deg_to_rad(0.0 if phase == 1 else (18.0 if phase == 2 else 34.0))
	for shot_index in range(shot_count):
		var offset: float = 0.0
		if shot_count > 1:
			offset = lerpf(-spread * 0.5, spread * 0.5, float(shot_index) / float(shot_count - 1))
		var direction: Vector2 = to_player.normalized().rotated(offset)
		var projectile: Projectile = projectile_scene.instantiate() as Projectile
		if projectile == null:
			Log.error("Outpost projectile scene root must use Projectile.gd")
			return
		projectile.rotation = direction.angle()
		projectile.velocity = direction * projectile_speed
		projectile.damage = projectile_damage
		projectile.team = team
		projectile.source = self
		SectorSpace.spawn_owned(projectile, muzzle.global_position)
	if EventAudio.instance != null:
		EventAudio.instance.play_2d("enemy_fire", self, "SFX")


func _muzzle_on_player_side(to_player: Vector2) -> Marker2D:
	# Use the dominant axis so each volley starts from the closest authored side.
	if absf(to_player.x) >= absf(to_player.y):
		return muzzle_right if to_player.x >= 0.0 else muzzle_left
	return muzzle_bottom if to_player.y >= 0.0 else muzzle_top
