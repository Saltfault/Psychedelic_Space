shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec4 shield_color : source_color = vec4(0.15, 0.8, 1.0, 1.0);

void fragment() {
	vec2 p = UV - vec2 (0.5);
	float radius = length(p);
	
	float edge = 1.0 - smoothstep(0.025, 0.07, abs(radius - 0.43));
	float inner_glow = (1.0 - smoothstep(0.18, 0.48, radius)) * 0.12;
	
	float pulse = 0.75 + 0.25 * sin(TIME * 3.0);
	float alpha = (edge * pulse + inner_glow) * strength;
	
	COLOR = vec4(shield_color.rgb * alpha * 2.0, alpha);
}