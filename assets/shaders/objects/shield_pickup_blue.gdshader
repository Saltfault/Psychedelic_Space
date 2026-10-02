shader_type canvas_item;
render_mode unshaded;

uniform vec4 shield_blue : source_color = vec4(0.12, 0.58, 1.0, 1.0);

void fragment() {
	vec4 texel = texture(TEXTURE, UV) * COLOR;
	float luminance = dot(texel.rgb, vec3(0.2126, 0.7152, 0.0722));
	float preserved_shading = mix(0.35, 1.0, luminance);
	COLOR = vec4(shield_blue.rgb * preserved_shading, texel.a * shield_blue.a);
}
