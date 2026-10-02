extends Control
## Paused read-only panel that reports the active ship's effective run statistics.
class_name ShipStatsPanel

signal closed

@onready var stats_text: Label = $Panel/MarginContainer/VBoxContainer/Stats
@onready var back_button: Button = $Panel/MarginContainer/VBoxContainer/Header/BackButton

var player: PlayerShip


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	back_button.pressed.connect(close_panel)
	hide()


## Bind the active ship and refresh its currently derived values.
func configure(target_player: PlayerShip) -> void:
	player = target_player
	_refresh()


func _refresh() -> void:
	if not is_instance_valid(player) or player.definition == null:
		stats_text.text = "No active ship is available."
		return

	var weapon_name: String = "None"
	var weapon_count: int = 0
	var weapon_spread: float = 0.0
	if player.weapon_definition != null:
		weapon_name = player.weapon_definition.display_name
		weapon_count = player.weapon_definition.projectile_count
		weapon_spread = player.weapon_definition.spread_degrees
	var rows: PackedStringArray = [
		"SHIP  %s" % player.definition.display_name,
		"HULL  %d / %d" % [roundi(player.hull), roundi(player.max_hull)],
		"SHIELDS  %d / %d" % [roundi(player.shield), roundi(player.max_shield)],
		"SHIELD REGENERATION  %.1f per second" % player.shield_regen_per_second,
		"SHIELD REGENERATION DELAY  %.1f seconds" % player.shield_regen_delay,
		"SPEED  %.1f / %.1f" % [player.velocity.length(), player.max_speed],
		"THRUST ACCELERATION  %.1f" % player.thrust_acceleration,
		"LINEAR DRAG  %.2f" % player.linear_drag,
		"TURN RATE  %.1f degrees per second" % rad_to_deg(player.turn_speed),
		"WEAPON  %s" % weapon_name,
		"DAMAGE PER PROJECTILE  %.1f" % player.projectile_damage,
		"FIRE RATE  %.2f shots per second" % (1.0 / maxf(player.weapon_cooldown, 0.001)),
		"PROJECTILE SPEED  %.1f" % player.projectile_speed,
		"PROJECTILES PER VOLLEY  %d" % weapon_count,
		"WEAPON SPREAD  %.1f degrees" % weapon_spread,
		"SENSOR CONTACT RANGE  %.0f" % player.sensor_range,
		"MODULE SLOTS  %d / %d" % [player.installed_modules.size(), player.module_slots],
		"UNEQUIPPED MODULES  %d / %d" % [player.unequipped_modules.size(), BaseShip.UNEQUIPPED_MODULE_CAPACITY],
	]
	if player.pilot == null:
		rows.append("PILOT / ABILITY  None")
	else:
		rows.append("PILOT  %s   |   ABILITY  %s" % [player.pilot.display_name, _pilot_ability_name()])
		rows.append("ABILITY COOLDOWN  %.1f seconds" % player.pilot.cooldown)
		if player.pilot.ability == PilotDefinition.ActiveAbility.DASH:
			rows.append("DASH SPEED  %.1f" % player.pilot.dash_speed)
			rows.append("DASH BURST DURATION  %.2f seconds" % player.pilot.dash_duration)
		elif player.pilot.ability == PilotDefinition.ActiveAbility.RAM_SHIELD:
			rows.append("RAM SHIELD DURABILITY  %.0f" % player.pilot.ram_shield_health)
			rows.append("RAM ACTIVATION COST  %.0f" % player.pilot.ram_activation_cost)
			rows.append("RAM CONTACT DAMAGE  %.0f" % player.pilot.ram_contact_damage)
			rows.append("RAM SHIELD DURATION  %.2f seconds" % player.pilot.ram_shield_duration)
			rows.append("RAM RECHARGE  %.1f per second after %.1f seconds" % [
				player.pilot.ram_recharge_rate,
				player.pilot.ram_recharge_delay,
			])
	stats_text.text = "\n".join(rows)


func _pilot_ability_name() -> String:
	match player.pilot.ability:
		PilotDefinition.ActiveAbility.DASH:
			return "Dash"
		PilotDefinition.ActiveAbility.RAM_SHIELD:
			return "Ram Shield"
	return "Unknown"


## Close the stats panel and notify the HUD to unpause the run.
func close_panel() -> void:
	hide()
	closed.emit()
