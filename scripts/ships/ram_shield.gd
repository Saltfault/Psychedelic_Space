extends Area2D
## Forward-facing Ram shield that absorbs hostile shots and rams nearby enemy ships.
class_name RamShield

signal health_changed(current: float, maximum: float)

@onready var visual: Sprite2D = $ShieldVisual

var pilot: PilotDefinition
var max_health: float = 90.0
var current_health: float = 90.0
var active: bool = false
var active_time_left: float = 0.0
var recharge_wait: float = 0.0
var _contact_cooldowns: Dictionary = {}


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	monitoring = false
	monitorable = false
	visual.visible = false


func configure(definition: PilotDefinition) -> void:
	pilot = definition
	max_health = definition.ram_shield_health
	current_health = max_health
	health_changed.emit(current_health, max_health)


func activate(definition: PilotDefinition) -> bool:
	if current_health < definition.ram_activation_cost or active:
		return false
	pilot = definition
	# Spend charge on use so the HUD meter reflects activations as well as blocked shots.
	current_health = maxf(current_health - definition.ram_activation_cost, 0.0)
	recharge_wait = definition.ram_recharge_delay
	health_changed.emit(current_health, max_health)
	active = true
	active_time_left = definition.ram_shield_duration
	_contact_cooldowns.clear()
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	visual.visible = true
	return true


func _physics_process(delta: float) -> void:
	for key: Variant in _contact_cooldowns.keys():
		_contact_cooldowns[key] = maxf(float(_contact_cooldowns[key]) - delta, 0.0)
		if float(_contact_cooldowns[key]) <= 0.0:
			_contact_cooldowns.erase(key)
	if active:
		active_time_left = maxf(active_time_left - delta, 0.0)
		if active_time_left <= 0.0:
			_deactivate()
	elif recharge_wait > 0.0:
		recharge_wait = maxf(recharge_wait - delta, 0.0)
	elif pilot != null and current_health < max_health:
		current_health = minf(current_health + pilot.ram_recharge_rate * delta, max_health)
		health_changed.emit(current_health, max_health)


func get_charge_ratio() -> float:
	return clampf(current_health / maxf(max_health, 1.0), 0.0, 1.0)


func _on_area_entered(area: Area2D) -> void:
	if not active or not area is Projectile:
		return
	var projectile: Projectile = area as Projectile
	if projectile.team == 0 or projectile.has_impacted:
		return
	_damage_shield(projectile.damage)
	projectile.absorb()
	if GameSettings.screen_shake_strength > 0.0:
		Juicee.shake_camera(get_parent(), 1.2 * GameSettings.screen_shake_strength, 0.06, 30.0)
	if EventAudio.instance != null:
		EventAudio.instance.play_2d("shield_block", get_parent() as Node2D, "SFX")


func _on_body_entered(body: Node2D) -> void:
	if not active or not body.is_in_group("enemy_ship") or pilot == null:
		return
	var body_id: int = body.get_instance_id()
	if _contact_cooldowns.has(body_id):
		return
	_contact_cooldowns[body_id] = 0.35
	if body.has_method("take_damage"):
		body.call("take_damage", pilot.ram_contact_damage)
	if GameSettings.screen_shake_strength > 0.0:
		Juicee.shake_camera(get_parent(), 2.2 * GameSettings.screen_shake_strength, 0.09, 24.0)
	if EventAudio.instance != null:
		EventAudio.instance.play_2d("ram_hit", get_parent() as Node2D, "SFX")
	if InputHelper != null and GameSettings.controller_vibration:
		InputHelper.rumble_medium()


func _damage_shield(amount: float) -> void:
	current_health = maxf(current_health - maxf(amount, 0.0), 0.0)
	recharge_wait = pilot.ram_recharge_delay if pilot != null else 2.0
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		_deactivate()


func _deactivate() -> void:
	# A completed Ram burst must recharge too, even if nothing hit the shield.
	if active and pilot != null:
		recharge_wait = pilot.ram_recharge_delay
	active = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	visual.visible = false
