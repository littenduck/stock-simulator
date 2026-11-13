## A character portrait: the Kenney Mini Characters bust (ui/theme/portraits/<id>.png, CC0) when there is one,
## otherwise the pixel bust of PixelPortraits. `scale` sets the size: a bust is scale x 16 pixels wide.
class_name PortraitView
extends TextureRect

const FOLDER := "res://ui/theme/portraits/"
const UNIT := 16

static var _cache: Dictionary = {}


static func has_art(character_id: String) -> bool:
	return ResourceLoader.exists(FOLDER + character_id + ".png")


## The bust as a texture with mipmaps (so the big picture stays smooth when it is shown small).
static func bust_texture(character_id: String) -> Texture2D:
	if not has_art(character_id):
		return PixelPortraits.texture(character_id)
	if not _cache.has(character_id):
		var source: Texture2D = load(FOLDER + character_id + ".png")
		var img := source.get_image()
		if img.is_compressed():
			img.decompress()
		img.generate_mipmaps()
		_cache[character_id] = ImageTexture.create_from_image(img)
	return _cache[character_id]


static func make(character_id: String, scale: float = 4.0) -> PortraitView:
	var v := PortraitView.new()
	v.texture = bust_texture(character_id)
	var art := has_art(character_id)
	v.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if art else CanvasItem.TEXTURE_FILTER_NEAREST
	v.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.custom_minimum_size = (Vector2(UNIT * scale, UNIT * scale) if art else Vector2(PixelPortraits.WIDTH * scale, PixelPortraits.HEIGHT * scale)).round()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v
