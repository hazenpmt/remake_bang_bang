shader_type canvas_item;
render_mode unshaded;


void fragment() {
	vec4 sampled = texture(TEXTURE, UV);
	float pattern_mask = clamp(sampled.a * 7.5, 0.0, 1.0);
	vec3 base_color = vec3(0.31, 0.69, 0.87);
	COLOR = vec4(
		mix(base_color, sampled.rgb, pattern_mask * 0.13),
		1.0
	);
}
