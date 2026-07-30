shader_type canvas_item;

uniform vec3 colors[16]: source_color;

int get_index(float value) {
	// divide colors by 20%
	return int(round(value * 16.));
}
void fragment() {
	COLOR.rgb = colors[get_index(COLOR.r)];
}