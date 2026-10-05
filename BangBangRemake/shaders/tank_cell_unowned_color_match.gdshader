shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float neutral = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float solid_region = step(0.18, source.a);
	float matched_alpha = mix(
		source.a,
		min(source.a * 4.0, 1.0),
		solid_region
	);
	float bright_border = smoothstep(0.78, 1.0, source.a);
	float matched_gray = mix(neutral * 0.92, neutral, bright_border);
	COLOR = vec4(vec3(matched_gray), matched_alpha);
}
