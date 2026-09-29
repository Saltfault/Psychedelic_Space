extends Node

const GENERATED_SECTOR_SCENE: PackedScene = preload("res://scenes/sectors/generated_sector.tscn")

@onready var sector_container: Node2D = $SectorContainer
@onready var player: PlayerShip = $PlayerShip
@onready var hud: GameHUD = $HUD
@onready var system_map: SystemMap = $HUD/Root/SystemMap

var active_sector: SectorRoot = null
var run_finished: bool = false


func _ready() -> void:
	RunState.reset_run()

	hud.configure(player)
	system_map.travel_requested.connect(_on_travel_requested)
	player.died.connect(_on_player_died)

	system_map.generate_new_map(RunState.run_seed)
	_load_map_node(sytem_map.get_node_data(system_map.start_node_id))


func _process(delta: float) -> void:
	if run_finished:
		return

	if Input.is_action_just_pressed("system_map"):
		if active_sector != null and active_sector.sector_id == "warp":
			return
