shader_type canvas_item;
// Scrolls a seamless tile diagonally (up and to the right). `rect_size` is set by animated_background.gd.

uniform sampler2D tile : filter_nearest, repeat_enable;
uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform vec2 tile_size = vec2(96.0, 96.0);
uniform float speed = 24.0; // pixels per second

void fragment() {
	vec2 pixel = UV * rect_size;
	pixel += vec2(-1.0, 1.0) * TIME * speed;
	COLOR = texture(tile, pixel / tile_size);
}
