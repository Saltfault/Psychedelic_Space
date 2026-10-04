extends Node2D
## Saved 2D presentation for the texture-free Pixel Planet shader.
class_name PixelPlanetView

## Apply a registry definition to this scene's unique shader material.
func configure(definition: PlanetDefinition, variation_seed: int = 0) -> void:
	var planet_surface: ColorRect = get_node("Surface") as ColorRect
	var shader_material: ShaderMaterial = planet_surface.material as ShaderMaterial
	shader_material.set_shader_parameter("planet_type", int(definition.planet_type))
	shader_material.set_shader_parameter("sea_level", definition.sea_level)
	var resolved_seed: int = variation_seed if variation_seed != 0 else hash(definition.planet_id)
	shader_material.set_shader_parameter("seed", float(posmod(resolved_seed, 10000)) / 100.0)
