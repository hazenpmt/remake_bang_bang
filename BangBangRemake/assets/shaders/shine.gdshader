shader_type canvas_item;

uniform float shine_progress : hint_range(0.0, 1.0) = 0.0;
uniform float shine_size : hint_range(0.01, 1.0) = 0.1;
uniform float shine_angle : hint_range(0.0, 360.0) = 45.0;
uniform vec4 shine_color : source_color = vec4(1.0, 1.0, 1.0, 0.5);

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    
    // Calculate rotated UV for the angled shine
    float angle = radians(shine_angle);
    mat2 rot = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle)));
    vec2 rotated_uv = rot * (UV - vec2(0.5)) + vec2(0.5);
    
    // Create the shine band
    float current_shine = step(rotated_uv.x, shine_progress + shine_size) - step(rotated_uv.x, shine_progress);
    
    // Add shine on top of the original image, ignoring transparent pixels
    vec4 final_color = color + (shine_color * current_shine * color.a);
    
    COLOR = final_color;
}
