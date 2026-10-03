extends Area2D
## A ground weapon that replaces the player's active primary and drops the displaced one.
class_name WeaponPickup

const RARITY_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/pickups/weapon_common_green.png"),
	preload("res://assets/sprites/pickups/weapon_uncommon_blue.png"),
	preload("res://assets/sprites/pickups/weapon_rare_violet.png"),
	preload("res://assets/sprites/pickups/weapon_epic_yellow.png"),
	preload("res://assets/sprites/pickups/weapon_legendary_red.png"),
]

@export var weapon: WeaponDefinition
@onready var icon: Sprite2D = $Icon


func _ready() -> void:
	add_to_group("weapon_pickup")
	# Reassert the player layer on the saved Area2D so scene edits cannot silently disable pickup.
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = true
	var pickup_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if pickup_shape == null or pickup_shape.shape == null:
		Log.error("Weapon pickup requires an enabled CollisionShape2D", get_path())
	else:
		pickup_shape.disabled = false
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	_refresh_visual()


func _refresh_visual() -> void:
	if weapon == null:
		Log.error("Weapon pickup has no WeaponDefinition", get_path())
		return
	icon.texture = RARITY_TEXTURES[clampi(int(weapon.rarity), 0, RARITY_TEXTURES.size() - 1)]
	set_meta("weapon_id", weapon.weapon_id)
	set_meta("contact_type", "weapon")


func _on_body_entered(body: Node2D) -> void:
	var player: PlayerShip = body as PlayerShip
	if player == null or weapon == null:
		return
	var previous_weapon: WeaponDefinition = player.weapon_definition
	if not player.equip_weapon(weapon.weapon_id):
		Log.warn("Weapon pickup could not equip its registered definition", weapon.weapon_id)
		return
	Juicee.preset_pickup(self)
	if previous_weapon != null:
		weapon = previous_weapon
		_refresh_visual()
		# Move the swapped weapon clear of the pickup overlap before restoring monitoring.
		global_position += Vector2.RIGHT.rotated(player.rotation + PI) * 120.0
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		_reenable_after_swap()
	else:
		queue_free()
	Log.info("Weapon pickup swapped", player.name, player.weapon_definition.display_name)


func _reenable_after_swap() -> void:
	await get_tree().create_timer(0.35).timeout
	if is_inside_tree():
		set_deferred("monitoring", true)
		set_deferred("monitorable", true)
