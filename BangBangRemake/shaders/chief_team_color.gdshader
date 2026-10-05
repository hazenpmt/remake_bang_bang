shader_type canvas_item;

// The dump contains one original tuzhu04 sheet. The source client applies
// relation colour at runtime, so keep the sheet untouched and remap only its
// red team-painted pixels when this chief is friendly to the local viewer.
uniform bool friendly_to_viewer = true;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	if (
		friendly_to_viewer
		&& source.a > 0.0
		&& source.r > source.g * 1.12
		&& source.r > source.b * 1.12
	) {
		float value = source.r;
		float shade = min(source.g, source.b);
		source.rgb = vec3(shade * 0.55, max(source.g, value * 0.62), value);
	}
	COLOR = source;
}
