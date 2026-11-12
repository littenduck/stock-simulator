## Dev tool: builds derived art from the Kenney Pixel UI Pack (CC0).
##  - ui/theme/assets/ui_2x/*.png : 9-slice panels / buttons scaled 2x with nearest filtering
##  - ui/theme/assets/bg_tile.png : seamless 96x96 tile for the scrolling menu background
## Run: godot --headless --path . --script res://ui/theme/dev/build_assets.gd
extends SceneTree

const PACK := "res://ui/theme/assets/kenney_pixel-ui-pack/"
const OUT := "res://ui/theme/assets/"
const SLICES: Array[String] = [
	"Colored/blue", "Colored/blue_pressed", "Colored/green", "Colored/green_pressed",
	"Colored/red", "Colored/red_pressed", "Colored/grey", "Colored/grey_pressed",
	"Ancient/tan",
	"Outline/blue", "Outline/green", "Outline/yellow",
]
const COIN: Array[String] = ["..yyyy..", ".yooooy.", "yoyyyyoy", "yoyooyoy", "yoyooyoy", "yoyyyyoy", ".yooooy.", "..yyyy.."]
const PLUS: Array[String] = ["...bb...", "...bb...", ".bbbbbb.", ".bbbbbb.", ".bbbbbb.", ".bbbbbb.", "...bb...", "...bb..."]
## Lighter, calmer background: sprites are only slightly different from it, so panels stand out.
const BG := Color("#2d5a4c")
const SPRITE_BLEND := 0.35  ## 0 = invisible (BG colour), 1 = full sprite colour


func _init() -> void:
	_scale_slices()
	_build_tile()
	quit()


func _load(path: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(path))


func _save(img: Image, path: String) -> void:
	img.save_png(ProjectSettings.globalize_path(path))


func _scale_slices() -> void:
	for s in SLICES:
		var img := _load(PACK + "9-Slice/%s.png" % s)
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		_save(img, OUT + "ui_2x/%s.png" % s.replace("/", "_").to_lower())


func _arrow(sheet: Image, col: int, row: int) -> Image:
	return sheet.get_region(Rect2i(col * 18, row * 18, 16, 16))


func _pixmap(rows: Array[String], palette: Dictionary) -> Image:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			var c := rows[y][x]
			if c != ".":
				img.set_pixel(x, y, palette[c])
	img.resize(16, 16, Image.INTERPOLATE_NEAREST)
	return img


func _blit(dst: Image, src: Image, at: Vector2i) -> void:
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x, y)
			if c.a > 0.0:
				dst.set_pixel(at.x + x, at.y + y, BG.lerp(Color(c.r, c.g, c.b, 1.0), SPRITE_BLEND))


## Native tile is 48px (sprites are 16px); stored 2x so it matches the 2x UI art at 1280x720.
func _build_tile() -> void:
	var sheet := _load(PACK + "Spritesheet/UIpackSheet_transparent.png")
	var coin := _pixmap(COIN, {"y": Color("#ffd34e"), "o": Color("#d98a1f")})
	var plus := _pixmap(PLUS, {"b": Color("#5aa9ff")})
	var tile := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	tile.fill(BG)
	_blit(tile, coin, Vector2i(4, 4))
	_blit(tile, _arrow(sheet, 22, 23), Vector2i(28, 4))    # green up
	_blit(tile, _arrow(sheet, 17, 25), Vector2i(4, 28))    # orange down
	_blit(tile, plus, Vector2i(28, 28))
	tile.resize(96, 96, Image.INTERPOLATE_NEAREST)
	_save(tile, OUT + "bg_tile.png")
