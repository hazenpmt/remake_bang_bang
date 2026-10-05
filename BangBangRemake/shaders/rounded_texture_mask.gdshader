shader_type canvas_item;

uniform float corner_radius : hint_range(0.0, 0.5, 0.01) = 0.12;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	vec2 corner = abs(UV - vec2(0.5)) - vec2(0.5 - corner_radius);
	float signed_distance = length(max(corner, vec2(0.0))) - corner_radius;
	float feather = max(fwidth(signed_distance), 0.0001);
	color.a *= 1.0 - smoothstep(-feather, feather, signed_distance);
	COLOR = color;
}
