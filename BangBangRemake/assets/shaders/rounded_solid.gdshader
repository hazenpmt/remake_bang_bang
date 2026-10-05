shader_type canvas_item;

uniform vec4 fill_color : source_color = vec4(0.94, 0.975, 0.99, 1.0);
uniform vec2 rect_size = vec2(100.0, 100.0);
uniform float radius = 8.0;

void fragment() {
	vec2 pixel_position = UV * rect_size;
	vec2 half_size = rect_size * 0.5;
	vec2 corner_distance = abs(pixel_position - half_size)
		- (half_size - vec2(radius));
	float signed_distance = length(max(corner_distance, vec2(0.0)))
		+ min(max(corner_distance.x, corner_distance.y), 0.0)
		- radius;
	float edge_alpha = 1.0 - smoothstep(-1.0, 1.0, signed_distance);
	COLOR = vec4(fill_color.rgb, fill_color.a * edge_alpha);
}
