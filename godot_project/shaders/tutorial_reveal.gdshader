shader_type canvas_item;

uniform float reveal_percent : hint_range(0.0, 1.0) = 0.166;

void fragment() {
	// get texture color
	vec4 tex_color = texture(TEXTURE, UV);

	// clip based on reveal percent from left to right
	if (UV.x > reveal_percent) {
		tex_color.a = 0.0;  // make transparent
	}

	COLOR = tex_color;
}
