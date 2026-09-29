shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D cloud_noise : repeat_enable, filter_linear_mipmap;
uniform vec4 color_a : source_color = vec4(0.18, 0.06, 0.42, 1.0);
uniform vec4 color_b : source_color = vec4(0.08, 0.34, 0.52, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.82;
uniform float drift_speed : hint_range(0.0, 0.02) = 0.0018;

void fragment() {
	// Sample seamless broad and fine noise at different rates for organic structure.
	vec2 drift = TIME * vec2(drift_speed, drift_speed * 0.63);
	float broad = texture(cloud_noise, UV + drift).r;
	float detail = texture(cloud_noise, UV * 2.0 - drift * 0.7).r;
	// Warp an asymmetric superellipse so the main cloud has a changing, non-circular outline.
	vec2 warp_noise = vec2(
		texture(cloud_noise, UV * 0.85 + vec2(0.17, 0.43) + drift * 0.20).r,
		texture(cloud_noise, UV * 0.85 + vec2(0.61, 0.09) - drift * 0.20).r
	);
	vec2 warped_uv = UV + (warp_noise - vec2(0.5)) * 0.035;
	vec2 centered = (warped_uv - vec2(0.49, 0.48)) * 2.0;
	float contour_distance = pow(
		pow(abs(centered.x) * 1.05, 1.65) + pow(abs(centered.y) * 1.18, 1.65),
		0.6060606
	);

	// Noise moves both contours; only the narrow threshold smooths their edges for antialiasing.
	float boundary_noise = texture(cloud_noise, UV * 0.65 + drift * 0.25).r;
	float extent = 0.68 + (boundary_noise - 0.5) * 0.32 + (broad - 0.5) * 0.08;
	float main_mask = smoothstep(-0.035, 0.035, extent - contour_distance);
	float outer_extent = min(extent + 0.14, 0.86);
	float outer_mask = smoothstep(-0.045, 0.045, outer_extent - contour_distance);
	float rim = clamp(outer_mask - main_mask, 0.0, 1.0);

	// Keep one dense body, with smaller noise-shaped lobes trailing from its perimeter.
	float interior_density = 0.62 + smoothstep(0.30, 0.70, broad) * 0.22;
	float main_cloud = main_mask * (interior_density + smoothstep(0.56, 0.80, detail) * 0.10);
	float satellites = rim * smoothstep(0.55, 0.76, detail) * 0.58;
	float wisps = rim * smoothstep(0.40, 0.62, broad) * 0.20;
	float cloud_alpha = clamp(main_cloud + satellites + wisps, 0.0, 0.92);
	float alpha = cloud_alpha * opacity;

	vec3 cloud_color = mix(color_a.rgb, color_b.rgb, smoothstep(0.40, 0.76, detail));
	COLOR = vec4(cloud_color, alpha);
}
