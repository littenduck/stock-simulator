shader_type canvas_item;
// A diamond checkerboard (dark and light squares turned 45 degrees) that scrolls from the top-left to the bottom-right,
// with the small coin / plus / arrow icons of `tile` drawn over it and scrolling with it. The checkerboard follows the
// background of fusion-pixel-font.takwolf.com: a 96 px cell, 96 px of travel every 4 seconds. `rect_size` is set by
// animated_background.gd.

uniform sampler2D tile : filter_nearest, repeat_enable;
uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform vec2 tile_size = vec2(96.0, 96.0);
uniform float speed = 24.0; // pixels per second, along both axes
uniform vec4 dark : source_color = vec4(0.169, 0.129, 0.314, 1.0);
uniform vec4 light : source_color = vec4(0.215, 0.165, 0.376, 1.0);

void fragment() {
	vec2 pixel = UV * rect_size - vec2(1.0, 1.0) * TIME * speed;
	// Inside one cell (x, y from 0 to 96) the dark part is the diamond |x - y| <= 48 and 48 <= x + y <= 144;
	// the four corners around it are light and join the neighbouring cells' corners into light diamonds.
	vec2 q = mod(floor(pixel), tile_size.x);
	bool is_light = abs(q.x - q.y) > 48.0 || abs(q.x + q.y - 96.0) > 48.0;
	vec4 base = is_light ? light : dark;
	// The icons: the tile's own background colour is not drawn, only what is painted on it.
	vec4 icon = texture(tile, pixel / tile_size);
	float is_icon = step(0.04, distance(icon.rgb, dark.rgb)) * icon.a;
	COLOR = vec4(mix(base.rgb, icon.rgb, is_icon), 1.0);
}
