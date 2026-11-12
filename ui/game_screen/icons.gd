## Small vector icons drawn at runtime. The default Godot font has no arrow, check, cross or star
## glyphs, and web exports have no system fallback font, so text glyphs would show as boxes.
class_name GameIcons
extends RefCounted

const SIZE := 48
const SUPERSAMPLE := 3

static var _cache: Dictionary = {}


## White icon on a transparent background; tint it with modulate. Names: up, down, flat, check, cross, star.
static func tex(icon_name: String) -> ImageTexture:
	if not _cache.has(icon_name):
		_cache[icon_name] = _make(icon_name)
	return _cache[icon_name]


static func _make(icon_name: String) -> ImageTexture:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var star := _star_points()
	for y in SIZE:
		for x in SIZE:
			var hits: int = 0
			for sy in SUPERSAMPLE:
				for sx in SUPERSAMPLE:
					var p := Vector2((x + (sx + 0.5) / SUPERSAMPLE) / SIZE, (y + (sy + 0.5) / SUPERSAMPLE) / SIZE)
					if _inside(icon_name, p, star):
						hits += 1
			img.set_pixel(x, y, Color(1, 1, 1, float(hits) / (SUPERSAMPLE * SUPERSAMPLE)))
	return ImageTexture.create_from_image(img)


static func _inside(icon_name: String, p: Vector2, star: PackedVector2Array) -> bool:
	match icon_name:
		"up":
			return Geometry2D.is_point_in_polygon(p, PackedVector2Array([Vector2(0.5, 0.12), Vector2(0.94, 0.86), Vector2(0.06, 0.86)]))
		"down":
			return Geometry2D.is_point_in_polygon(p, PackedVector2Array([Vector2(0.5, 0.88), Vector2(0.94, 0.14), Vector2(0.06, 0.14)]))
		"flat":
			return p.x > 0.12 and p.x < 0.88 and p.y > 0.42 and p.y < 0.58
		"check":
			return _near(p, Vector2(0.14, 0.56), Vector2(0.4, 0.82)) or _near(p, Vector2(0.4, 0.82), Vector2(0.88, 0.2))
		"cross":
			return _near(p, Vector2(0.2, 0.2), Vector2(0.8, 0.8)) or _near(p, Vector2(0.8, 0.2), Vector2(0.2, 0.8))
		"star":
			return Geometry2D.is_point_in_polygon(p, star)
	return false


static func _near(p: Vector2, a: Vector2, b: Vector2) -> bool:
	return Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < 0.075


static func _star_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var radius: float = 0.48 if i % 2 == 0 else 0.2
		var angle: float = -PI / 2.0 + i * PI / 5.0
		pts.append(Vector2(0.5 + cos(angle) * radius, 0.54 + sin(angle) * radius))
	return pts
