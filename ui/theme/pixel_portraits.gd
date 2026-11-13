## Code-drawn pixel portraits of the six table characters: 14x15 busts, one character per pixel ('.' = transparent),
## rendered to nearest-neighbour textures like PixelIcons, so there are no image assets. Original artwork.
## Draw them with texture_filter NEAREST and a whole-number scale (PortraitView does).
class_name PixelPortraits
extends RefCounted

const WIDTH := 14
const HEIGHT := 15

const PALETTE := {
	"k": "#2b2540",
	"s": "#ffd9b3",
	"w": "#ffffff",
	"g": "#9aa3b5",
	"G": "#5d6270",
	"r": "#e5484d",
	"R": "#a82a30",
	"o": "#f5963a",
	"y": "#ffd23f",
	"Y": "#c99a1d",
	"n": "#2f9e44",
	"N": "#1d6b2d",
	"b": "#4aa3ff",
	"B": "#2a6fdb",
	"c": "#8eeef2",
	"p": "#b57bee",
	"m": "#ff7eb6",
	"M": "#d9548f",
	"t": "#d79a5b",
	"T": "#8a5a2b",
	"h": "#3b2a22",
}

const PORTRAITS := {
	"insider_inu": [
		"....kkkkkk....",
		"...kGGGGGGk...",
		"...kGGGGGGk...",
		"..kGGGGGGGGk..",
		"..kTssssssTk..",
		"..kTssssssTk..",
		"..kTkkkkkkTk..",
		"...kssTTssk...",
		"...kssssssk...",
		"..kkkksskkkk..",
		".kttTTwwTTttk.",
		".kttttwwttttk.",
		".kttttttttttk.",
		".kttttttttttk.",
		"..kkkkkkkkkk..",
	],
	"copilot_cody": [
		"....kkkkkk....",
		"...kBBBBBBk...",
		"...kBBBBBBk...",
		"..kBYcYYcYBk..",
		"..kBssssssBk..",
		"..kGssssssGk..",
		"..kGskssksGk..",
		"...kssrrssk...",
		"...kssssssk...",
		"..kkkksskkkk..",
		".kyBBBwwBBByk.",
		".kyBBBBBBBByk.",
		".kBByyBBBBBBk.",
		".kBBBBBBBBBBk.",
		"..kkkkkkkkkk..",
	],
	"double_dan": [
		"....kkkkkk....",
		"...kkkkkkkk...",
		"...kkkkkkkk...",
		"..knnnnnnnnk..",
		"..kNNNNNNNNk..",
		"...kssssssk...",
		"...kskssksk...",
		"...ksskkssk...",
		"...kssssssk...",
		"..kkkksskkkk..",
		".kkkkrRRrkkkk.",
		".kkkkwwwwkkkk.",
		".kkkkwwwwkkkk.",
		".kkkkwwwwkkkk.",
		"..kkkkkkkkkk..",
	],
	"saving_son": [
		"....kkkkkk....",
		"...kTTTTTTk...",
		"...kTTTTTTk...",
		"..kTssssssTk..",
		"..kTssssssTk..",
		"...kssssssk...",
		"...kmksskmk...",
		"...kssrrssk...",
		"...kssssssk...",
		"..kkkksskkkk..",
		".kooowoowommk.",
		".kooooomkkmmk.",
		".kooooommmmkk.",
		".kooooommmmmk.",
		"..kkkkkkkkkk..",
	],
	"goldfish_gus": [
		"....kkkkkk....",
		"...kcccccck...",
		"..kcwkkkkkck..",
		".kcwssssssock.",
		".kwkssssssork.",
		".kckswsswskck.",
		".kcksksskskck.",
		".kcksskksskck.",
		"..kcssssssck..",
		"..kkcksskckk..",
		".kyyyyyyyyyyk.",
		".kyyryyyyyryk.",
		".kyyyyyyryyyk.",
		".kyyyyyyyyyyk.",
		"..kkkkkkkkkk..",
	],
	"hodl_hana": [
		"....kkkkkk....",
		"...kwwwwwwk...",
		"...kwwwwwwk...",
		"..kwwwwwwwwk..",
		"..kwwsssswwk..",
		"..kwwsssswwk..",
		"..kgwksskwgk..",
		"..kwwsrrswwk..",
		"..kgwsssswgk..",
		"..kwwksskwwk..",
		".kGGGGyyGGGGk.",
		".kGGGGccGGGGk.",
		".kGGGGbbGGGGk.",
		".kGGGGGGGGGGk.",
		"..kkkkkkkkkk..",
	],
}

static var _images: Dictionary = {}
static var _textures: Dictionary = {}


## Character ids that have a portrait.
static func ids() -> Array[String]:
	var out: Array[String] = []
	for k: String in PORTRAITS:
		out.append(k)
	return out


static func has_portrait(character_id: String) -> bool:
	return PORTRAITS.has(character_id)


static func rows_of(character_id: String) -> Array:
	return PORTRAITS.get(character_id, [])


## WIDTH x HEIGHT RGBA image, cached. Unknown ids give a fully transparent image.
static func image(character_id: String) -> Image:
	if not _images.has(character_id):
		_images[character_id] = _build(character_id)
	return _images[character_id]


static func texture(character_id: String) -> ImageTexture:
	if not _textures.has(character_id):
		_textures[character_id] = ImageTexture.create_from_image(image(character_id))
	return _textures[character_id]


static func _build(character_id: String) -> Image:
	var img := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	var rows: Array = PORTRAITS.get(character_id, [])
	for y in mini(rows.size(), HEIGHT):
		var row: String = rows[y]
		for x in mini(row.length(), WIDTH):
			var ch: String = row[x]
			if ch != "." and PALETTE.has(ch):
				img.set_pixel(x, y, Color(PALETTE[ch]))
	return img
