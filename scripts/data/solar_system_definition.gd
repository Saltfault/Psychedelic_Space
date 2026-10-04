extends Resource
## One authored solar-system theme and its procedural-content weights.
class_name SolarSystemDefinition

## Stable ID matching the solar-system registry.
@export var system_id: StringName
## Display name used by maps and transition notices.
@export var display_name: String = "Uncharted System"
## System star icon for the route map.
@export var map_icon: Texture2D
## Planet definitions eligible for deterministic assignment to generated sectors.
@export var planets: Array[PlanetDefinition] = []
## Enemy scene choices used by sector generation; empty uses project defaults.
@export var enemy_scenes: Array[PackedScene] = []
## Number of asteroid clusters generated in an ordinary sector.
@export_range(0, 12, 1) var asteroid_clusters: int = 3
## Chance to add a nebula effect in this system.
@export_range(0.0, 1.0, 0.01) var nebula_chance: float = 0.2
## Optional one-line system flavor shown on the map.
@export var map_subtitle: String = ""
