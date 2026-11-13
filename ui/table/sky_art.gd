## Pixel-style sky pieces for the step banners and the day transition: gradient skies, a sun, a moon, stars. Every
## function draws onto the CanvasItem it is given and must be called from that item's _draw().
class_name SkyArt
extends RefCounted

const CELL := 4.0
## Sky colours (top, bottom) for pre-market (dawn), market open (daytime) and after-market (night).
const SKY_TOP := [Color("#2b2250"), Color("#2f80e0"), Color("#0e1230")]
const SKY_BOTTOM := [Color("#f2906b"), Color("#8fd0ff"), Color("#2c3068")]
const SUN := Color("#ffd84a")
const SUN_DAWN := Color("#ffb347")
const MOON := Color("#f4efd8")


## Vertical gradient in bands of a few pixels.
static func sky(c: CanvasItem, rect: Rect2, top: Color, bottom: Color) -> void:
	var bands := maxi(1, int(rect.size.y / 6.0))
	for i in bands:
		var y0 := rect.position.y + rect.size.y * float(i) / float(bands)
		var y1 := rect.position.y + rect.size.y * float(i + 1) / float(bands)
		c.draw_rect(Rect2(rect.position.x, y0, rect.size.x, y1 - y0 + 0.5), top.lerp(bottom, float(i) / float(maxi(bands - 1, 1))))


## A disc made of square cells, clipped to `clip` (so a sun can set below the horizon).
static func disc(c: CanvasItem, center: Vector2, radius: float, color: Color, clip: Rect2, hole_center: Vector2 = Vector2.INF, hole_radius: float = 0.0) -> void:
	var n := int(ceil(radius / CELL))
	for gy in range(-n, n + 1):
		for gx in range(-n, n + 1):
			var p := center + Vector2(gx, gy) * CELL
			if p.distance_to(center) > radius:
				continue
			if hole_center != Vector2.INF and p.distance_to(hole_center) < hole_radius:
				continue
			var r := Rect2(p - Vector2(CELL, CELL) * 0.5, Vector2(CELL, CELL)).intersection(clip)
			if r.size.x > 0.0 and r.size.y > 0.0:
				c.draw_rect(r, color)


## The sun with rays; `spin` turns the rays (0..1 is a quarter turn).
static func sun(c: CanvasItem, center: Vector2, radius: float, clip: Rect2, color: Color = SUN, spin: float = 0.0) -> void:
	for i in 8:
		var a := (float(i) + spin * 2.0) * TAU / 8.0
		for k in range(1, 4):
			var p := center + Vector2(cos(a), sin(a)) * (radius + 6.0 + float(k) * CELL * 1.6)
			var r := Rect2(p - Vector2(CELL, CELL) * 0.5, Vector2(CELL, CELL)).intersection(clip)
			if r.size.x > 0.0 and r.size.y > 0.0:
				c.draw_rect(r, Color(color.r, color.g, color.b, 0.9 - 0.2 * float(k)))
	disc(c, center, radius, color, clip)
	disc(c, center + Vector2(-radius * 0.25, -radius * 0.25), radius * 0.55, color.lightened(0.35), clip, center, 0.0)


## A crescent: the disc with a bite taken out of it.
static func moon(c: CanvasItem, center: Vector2, radius: float, clip: Rect2) -> void:
	disc(c, center, radius, MOON, clip, center + Vector2(radius * 0.5, -radius * 0.25), radius * 0.85)


## Little plus-shaped stars at fixed spots, blinking with `t`.
static func stars(c: CanvasItem, rect: Rect2, count: int, t: float, seed_value: int = 7) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in count:
		var p := rect.position + Vector2(rng.randf() * rect.size.x, rng.randf() * rect.size.y * 0.8)
		var blink := 0.35 + 0.65 * absf(sin(t * 3.0 + float(i)))
		p = (p / CELL).floor() * CELL
		var col := Color(1, 1, 0.9, blink)
		c.draw_rect(Rect2(p, Vector2(CELL, CELL)), col)
		if i % 3 == 0:
			c.draw_rect(Rect2(p + Vector2(-CELL, 0), Vector2(CELL, CELL)), Color(col.r, col.g, col.b, col.a * 0.6))
			c.draw_rect(Rect2(p + Vector2(CELL, 0), Vector2(CELL, CELL)), Color(col.r, col.g, col.b, col.a * 0.6))
			c.draw_rect(Rect2(p + Vector2(0, -CELL), Vector2(CELL, CELL)), Color(col.r, col.g, col.b, col.a * 0.6))
			c.draw_rect(Rect2(p + Vector2(0, CELL), Vector2(CELL, CELL)), Color(col.r, col.g, col.b, col.a * 0.6))


## A band of dark ground along the bottom: the horizon.
static func ground(c: CanvasItem, rect: Rect2, color: Color, height: float = 14.0) -> void:
	c.draw_rect(Rect2(rect.position.x, rect.end.y - height, rect.size.x, height), color)
