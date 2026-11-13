shader_type canvas_item;
// A diamond checkerboard (dark and light squares turned 45 degrees) that scrolls from the top-left to the bottom-right.
// The checkerboard follows the background of fusion-pixel-font.takwolf.com: a 96 px cell, 96 px of travel every 4 seconds.
// Every square (dark or light) carries ONE icon in its middle: coin, up arrow, down arrow or plus, taken from the four
// 48 px quarters of `tile` and picked at random for each square. `rect_size` is set by animated_background.gd.

uniform sampler2D tile : filter_nearest, repeat_enable;
uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform vec2 tile_size = vec2(96.0, 96.0);
uniform float speed = 24.0; // pixels per second, along both axes
uniform vec4 dark : source_color = vec4(0.169, 0.129, 0.314, 1.0);
uniform vec4 light : source_color = vec4(0.215, 0.165, 0.376, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 pixel = floor(UV * rect_size - vec2(1.0, 1.0) * TIME * speed);
	float cell = tile_size.x;
	float half_cell = cell * 0.5;
	// Inside one cell (x, y from 0 to 96) the dark part is the diamond |x - y| <= 48 and 48 <= x + y <= 144;
	// the four corners around it are light and join the neighbouring cells' corners into light diamonds.
	vec2 q = mod(pixel, cell);
	bool is_light = abs(q.x - q.y) > half_cell || abs(q.x + q.y - cell) > half_cell;
	// The middle of the square this pixel is in: the cell's centre for a dark one, a cell corner for a light one.
	vec2 centre = is_light ? floor(pixel / cell + 0.5) * cell : floor(pixel / cell) * cell + vec2(half_cell);
	vec2 local = pixel - centre;    // -48 .. 48 around the middle
	vec3 colour = is_light ? light.rgb : dark.rgb;
	if (abs(local.x) < 24.0 && abs(local.y) < 24.0) {
		int id = int(floor(hash(centre / half_cell + (is_light ? vec2(0.5) : vec2(0.0))) * 4.0));
		vec2 quarter = vec2(float(id % 2), float(id / 2)) * 48.0;
		ivec2 texel = ivec2(quarter + local + vec2(24.0));
		vec4 icon = texelFetch(tile, texel, 0);
		float is_icon = step(0.04, distance(icon.rgb, dark.rgb)) * icon.a;
		colour = mix(colour, icon.rgb, is_icon);
	}
	COLOR = vec4(colour, 1.0);
}
