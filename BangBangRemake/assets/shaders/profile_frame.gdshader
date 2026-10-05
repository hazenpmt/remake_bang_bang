shader_type canvas_item;
render_mode unshaded;


void fragment() {
	vec4 sampled = texture(TEXTURE, UV);
	if (sampled.a < 0.02) {
		discard;
	}
	COLOR = vec4(sampled.rgb, 1.0);
}
