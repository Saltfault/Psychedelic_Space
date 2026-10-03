extends PanelContainer
## Scene-authored, permanent primary-weapon slot; weapons can replace but never leave it empty.
class_name WeaponLoadoutSlot

@onready var weapon_icon: TextureRect = $MarginContainer/Content/WeaponIcon
@onready var weapon_name: Label = $MarginContainer/Content/WeaponName
@onready var weapon_hint: Label = $MarginContainer/Content/WeaponHint

var equipment_screen: Control


## Display the ship's currently equipped weapon in this non-removable slot.
func configure(weapon: WeaponDefinition, screen: Control) -> void:
	equipment_screen = screen
	if weapon == null:
		weapon_name.text = "WEAPON UNAVAILABLE"
		weapon_hint.text = "A primary weapon is required"
		weapon_icon.texture = null
		return
	weapon_icon.texture = weapon.icon
	weapon_name.text = weapon.display_name
	weapon_hint.text = "PRIMARY WEAPON  |  DROP A WEAPON HERE TO REPLACE"
	tooltip_text = weapon.display_name


## Accept only typed weapon payloads; module payloads and empty-slot drops are rejected.
func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or equipment_screen == null:
		return false
	var incoming: Variant = data.get("weapon")
	return incoming is WeaponDefinition


func _drop_data(_position: Vector2, data: Variant) -> void:
	if not data is Dictionary or equipment_screen == null:
		return
	var incoming: Variant = data.get("weapon")
	if incoming is WeaponDefinition:
		equipment_screen.call("equip_weapon_definition", incoming as WeaponDefinition)
