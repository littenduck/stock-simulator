## Rounded coloured tile with a company's pixel icon. Set `icon_name` (see PixelIcons) and give it a
## square minimum size. The icon is scaled by a whole factor so the pixels stay crisp.
class_name CompanyBadge
extends Control

var icon_name: String = "":
	set(value):
		icon_name = value
		queue_redraw()

## CompanyDef.sector; its UiPalette colour frames the tile ("" = neutral frame derived from the tile).
var sector: String = "":
	set(value):
		sector = value
		queue_redraw()

## Extra scale used by bounce() (pop effect on selection).
var _pop: float = 0.0


static func make(icon: String, px: int = 36, p_sector: String = "") -> CompanyBadge:
	var b := CompanyBadge.new()
	b.icon_name = icon
	b.sector = p_sector
	b.custom_minimum_size = Vector2(px, px)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	resized.connect(_update_pivot)
	_update_pivot()


func _update_pivot() -> void:
	pivot_offset = size * 0.5


## Quick pop animation (used when a row is selected).
func bounce() -> void:
	if not is_inside_tree():
		return
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.18, 1.18), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var tile: Color = PixelIcons.tile_color(icon_name)
	var radius: int = maxi(int(minf(size.x, size.y) * 0.22), 3)
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0, 0, 0, 0.22)
	shadow.set_corner_radius_all(radius)
	draw_style_box(shadow, Rect2(Vector2(0, 2), size - Vector2(0, 2)))
	var body := StyleBoxFlat.new()
	body.bg_color = tile
	body.border_color = UiPalette.sector_color(sector) if sector != "" else tile.darkened(0.45)
	body.set_border_width_all(3 if sector != "" and size.x >= 30.0 else 2)
	body.set_corner_radius_all(radius)
	draw_style_box(body, Rect2(Vector2.ZERO, size - Vector2(0, 2)))
	# Soft top highlight.
	var gloss := StyleBoxFlat.new()
	gloss.bg_color = Color(1, 1, 1, 0.14)
	gloss.corner_radius_top_left = radius - 1
	gloss.corner_radius_top_right = radius - 1
	draw_style_box(gloss, Rect2(Vector2(2, 2), Vector2(size.x - 4, (size.y - 2) * 0.4)))
	var inner: float = minf(size.x, size.y - 2.0) - 2.0
	var factor: int = maxi(int(inner / PixelIcons.SIZE), 1)
	var side: float = float(PixelIcons.SIZE * factor)
	var pos := Vector2((size.x - side) * 0.5, (size.y - 2.0 - side) * 0.5).floor()
	draw_texture_rect(PixelIcons.texture(icon_name), Rect2(pos, Vector2(side, side)), false)
