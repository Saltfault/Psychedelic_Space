shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec2 camera_world_position = vec2(0.0);
// NEW CODE STARTS HERE
uniform vec2 camera_velocity = vec2(0.0);
uniform float trail_strength : hint_range(0.0, 1.0) = 0.2;
// NEW CODE ENDS HERE
uniform float parallax = 0.00008;
uniform float star_scale : hint_range(20.0, 220.0) = 110.0;
uniform float star_size : hint_range(0.1, 1.5) = 0.6;
uniform float brightness : hint_range(0.0, 4.0) = 1.6;

uniform vec4 color_a : source_color = vec4(0.55, 0.9, 1.0, 1.0);
uniform vec4 color_b : source_color = vec4(1.0, 0.45, 0.85, 1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
	float n = hash21(p);
	return vec2(n, hash21(p + n + 17.17));
}

void fragment() {
	vec2 world_uv = UV + camera_world_position * parallax;
	vec2 grid = world_uv * star_scale;
	
	vec2 cell = floor(grid);
	vec2 local = fract(grid) - 0.5;
	
	float existence = hash21(cell);
	vec2 offset = (hash22(cell + 3.1) - 0.5) * 0.65;
	
	float radius = mix(
		0.025,
		0.06,
		hash21(cell + vec2(8.4, 2.7))
	) * star_size;
	
	float distance_to_star = length(local - offset);
	float edge_width = max(fwidth(distance_to_star) * 0.25, 0.002);
	float star_core = 1.0 - smoothstep(radius - edge_width, radius + edge_width, distance_to_star);

	// NEW CODE STARTS HERE
	// A short tapered streak extends opposite the stars' apparent screen travel.
	float normalized_speed = clamp(length(camera_velocity), 0.0, 1.0);
	float trail = 0.0;
	if (normalized_speed > 0.001) {
		vec2 trail_direction = normalize(camera_velocity);
		float x_edge_distance = 1e6;
		float y_edge_distance = 1e6;
		if (trail_direction.x > 0.0001) {
			x_edge_distance = (0.5 - offset.x) / trail_direction.x;
		} else if (trail_direction.x < -0.0001) {
			x_edge_distance = (-0.5 - offset.x) / trail_direction.x;
		}
		if (trail_direction.y > 0.0001) {
			y_edge_distance = (0.5 - offset.y) / trail_direction.y;
		} else if (trail_direction.y < -0.0001) {
			y_edge_distance = (-0.5 - offset.y) / trail_direction.y;
		}

		float available_length = max(min(x_edge_distance, y_edge_distance), 0.0);
		float trail_length = min(trail_strength * normalized_speed, available_length);
		if (trail_length > radius * 1.5) {
			vec2 relative = local - offset;
			float along = dot(relative, trail_direction);
			float across = abs(relative.x * trail_direction.y - relative.y * trail_direction.x);
			float trail_width = max(radius * 0.55, 0.022);
			float trail_edge = max(fwidth(across) * 0.25, 0.0015);
			float width_mask = 1.0 - smoothstep(trail_width - trail_edge, trail_width + trail_edge, across);
			float start_mask = smoothstep(radius * 0.35, radius * 1.3, along);
			float end_fade = 1.0 - smoothstep(trail_length * 0.6, trail_length, along);
			trail = width_mask * start_mask * end_fade * normalized_speed;
		}
	}
	float star = max(star_core, trail * 0.55);
	// NEW CODE ENDS HERE
	
	star *= step(0.94, existence);
	
	float color_mix = hash21(cell + vec2(20.0, 91.0));
	vec3 star_color = mix(color_a.rgb, color_b.rgb, color_mix);
	
	COLOR = vec4(star_color * star * brightness, star);
}
