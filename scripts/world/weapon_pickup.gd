extends Area2D
## A ground weapon that replaces the player's active primary when collected.
class_name WeaponPickup

@export var weapon: WeaponDefinition
@export var rarity_textures: Array[Texture2D] = []
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
	if rarity_textures.size() < 5:
		Log.error("WeaponPickup scene is missing its rarity textures", get_path())
		return
	icon.texture = rarity_textures[clampi(int(weapon.rarity), 0, rarity_textures.size() - 1)]
	set_meta("weapon_id", weapon.weapon_id)
	set_meta("contact_type", "weapon")


func _on_body_entered(body: Node2D) -> void:
	var player: PlayerShip = body as PlayerShip
	if player == null or weapon == null:
		return
	if not player.equip_weapon(weapon.weapon_id):
		Log.warn("Weapon pickup could not equip its registered definition", weapon.weapon_id)
		return
	Juicee.preset_pickup(self)
	# The pickup replaces the active weapon; consuming it avoids making the newly
	# equipped weapon appear to jump away as the old weapon is respawned nearby.
	queue_free()
	Log.info("Weapon pickup swapped", player.name, player.weapon_definition.display_name)
