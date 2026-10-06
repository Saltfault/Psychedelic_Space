extends Area2D
## Collectible that restores a fixed amount of the player's current shield.
## Remains in the world while the touching ship still has maximum shields.

## Shield points restored to a PlayerShip when this pickup is collected.
@export var shield_amount: float = 12.0

## The PlayerShip currently overlapping this pickup, if any. body_entered only
## fires once while the hull remains inside, so the pickup is re-checked each
## physics tick until the shields drop below the cap.
var _overlapping_player: PlayerShip = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body is PlayerShip:
		_overlapping_player = body


func _on_body_exited(body: Node) -> void:
	if body == _overlapping_player:
		_overlapping_player = null


func _physics_process(_delta: float) -> void:
	if _overlapping_player == null:
		return
	# At full shield the pickup is not a reward: leave it for later.
	if _overlapping_player.shield >= _overlapping_player.max_shield:
		return
	_overlapping_player.restore_shield(shield_amount)
	Juicee.preset_pickup(self)
	queue_free()
