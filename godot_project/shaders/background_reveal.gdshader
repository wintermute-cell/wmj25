shader_type canvas_item;

uniform sampler2D ghost_texture : source_color, filter_nearest;
uniform sampler2D normal_texture : source_color, filter_nearest;

// screen tex captured by BackBufferCopy with white brush strokes
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

void fragment() {
	vec4 ghost_color = texture(ghost_texture, UV);
	vec4 normal_color = texture(normal_texture, UV);

	vec4 mask_color = texture(SCREEN_TEXTURE, SCREEN_UV);

	float mask_value = 1.0 - mask_color.r;

	COLOR = mix(ghost_color, normal_color, mask_value);
}
