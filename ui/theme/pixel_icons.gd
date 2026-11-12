## Code-drawn 16x16 pixel-art icons (one per company, plus a fallback). Each icon is a string array
## (one character per pixel, '.' = transparent) and is rendered to a nearest-neighbour ImageTexture, so
## no binary assets or fonts are needed (web exports have no fallback font). Scale them up with
## texture_filter NEAREST (CompanyBadge does that). Pure data and no autoloads: safe in unit tests.
class_name PixelIcons
extends RefCounted

const SIZE := 16
const BADGE_SIZE := 22
const FALLBACK := "chart"

## Shared palette: one character per colour. Icons only use the characters they need.
const PALETTE := {
	"k": "#2b2540", "w": "#ffffff", "g": "#9aa3b5", "G": "#5d6270",
	"r": "#e5484d", "R": "#a82a30", "o": "#f5963a", "y": "#ffd23f", "Y": "#c99a1d",
	"l": "#8ee05a", "n": "#2f9e44", "N": "#1d6b2d", "b": "#4aa3ff", "B": "#2a6fdb",
	"c": "#8eeef2", "p": "#b57bee", "P": "#7a45c0", "m": "#ff7eb6",
	"t": "#d79a5b", "T": "#8a5a2b", "s": "#ffd9b3",
}

## Tile colour behind each icon (CompanyBadge), chosen so the icon reads on it.
const TILE := {
	"chip": "#3f8f4f", "window": "#2f3b52", "fruit": "#6b3a5b", "magnifier": "#f2c94c",
	"people": "#2d3a5a", "eye": "#3a2f4a", "rocket": "#1f2a4d", "box": "#232f3e",
	"car": "#d8d8e0", "play": "#1b1b1f", "cart": "#f0e2c0", "coffee": "#3b2a22",
	"soda": "#0b2a5b", "bank": "#1d3557", "card": "#e9e4d6", "coin": "#1a56db",
	"chart": "#5d6270",
	"ticket": "#7a1f2b", "blocks": "#2b2f45", "satellite": "#1c2340", "game": "#3b2f6b", "moon": "#241c4a", "disk": "#2a2f3a", "bear": "#6fb7e6",
	"sun": "#274c77", "star": "#5b3b8c", "bolt": "#2a3358", "shield": "#233a2f", "clover": "#3a2a52", "gem": "#1f2a4d",
}

const ICONS := {
	"chip": [
		"................",
		"....g.g.g.g.....",
		"....g.g.g.g.....",
		"..gkkkkkkkkkkg..",
		"...kbbbbbbbbk...",
		"..gkbkkkkkkbkg..",
		"...kbkcccckbk...",
		"..gkbkcccckbkg..",
		"...kbkcccckbk...",
		"..gkbkkkkkkbkg..",
		"...kbbbbbbbbk...",
		"..gkkkkkkkkkkg..",
		"....g.g.g.g.....",
		"....g.g.g.g.....",
		"................",
		"................",
	],
	"window": [
		"................",
		"................",
		"..rrrrrr.nnnnnn.",
		"..rrrrrr.nnnnnn.",
		"..rrrrrr.nnnnnn.",
		"..rrrrrr.nnnnnn.",
		"..rrrrrr.nnnnnn.",
		"..rrrrrr.nnnnnn.",
		"................",
		"..bbbbbb.yyyyyy.",
		"..bbbbbb.yyyyyy.",
		"..bbbbbb.yyyyyy.",
		"..bbbbbb.yyyyyy.",
		"..bbbbbb.yyyyyy.",
		"..bbbbbb.yyyyyy.",
		"................",
	],
	"fruit": [
		"........tt......",
		".......t..lll...",
		".......llll.....",
		"......lllll.....",
		"......lwlll.....",
		".....lwllll.....",
		"....lllllllll...",
		"...llllllllll...",
		"..lwllllllllll..",
		"..lwllllllllll..",
		"..llllllllllll..",
		"..llllllllllll..",
		"...llllllllll...",
		"....llllllll....",
		".....nnnnnn.....",
		"................",
	],
	"magnifier": [
		"................",
		"....BBBBB.......",
		"...BcccccB......",
		"..BcwwcccccB....",
		"..BcwccccccB....",
		"..BccccccccB....",
		"..BccccccccB....",
		"...BcccccB......",
		"....BBBBBT......",
		".........TT.....",
		"..........TT....",
		"...........TT...",
		"............TT..",
		".............TT.",
		"................",
		"................",
	],
	"people": [
		"................",
		".....ssss.......",
		"....ssssss..ss..",
		"....ssssss.ssss.",
		"....ssssss.ssss.",
		".....ssss...ss..",
		"..bbbbbbbb.mmmm.",
		".bbbbbbbbbmmmmm.",
		".bbbbbbbbbmmmmm.",
		".bbbbbbbbbmmmmm.",
		".bbbbbbbbbmmmmm.",
		".bbbbbbbbbmmmmm.",
		"................",
		"................",
		"................",
		"................",
	],
	"eye": [
		"................",
		"................",
		"................",
		".....kkkkkk.....",
		"...kkwwwwwwkk...",
		"..kwwwwwwwwwwk..",
		".kwwwoooooowwwk.",
		".kwwwookkoowwwk.",
		".kwwwookkoowwwk.",
		".kwwwoooooowwwk.",
		"..kwwwwooowwwk..",
		"...kkwwwwwwkk...",
		".....kkkkkk.....",
		"................",
		"................",
		"................",
	],
	"rocket": [
		".......rr.......",
		"......rrrr......",
		".....wwwwww.....",
		".....wwwwww.....",
		".....wwbbww.....",
		".....wwbbww.....",
		".....wwwwww.....",
		".....wwwwww.....",
		"....rwwwwwwr....",
		"...rrwwwwwwrr...",
		"...rr.wwww.rr...",
		"......gggg......",
		".....yyyyyy.....",
		"......oyyo......",
		".......oo.......",
		"................",
	],
	"box": [
		"................",
		"................",
		"..TTTTTTTTTTTT..",
		"..tttttyyttttt..",
		"..tttttyyttttt..",
		"..tttttyyttttt..",
		"..tttttyyttttt..",
		"..tttttyyttttt..",
		"..tttttyyttttt..",
		"..twwwtyyttttt..",
		"..twwwtyyttttt..",
		"..tttttyyttttt..",
		"..tttttyyttttt..",
		"..TTTTTTTTTTTT..",
		"................",
		"................",
	],
	"car": [
		"................",
		"................",
		"................",
		"................",
		"......rrrrrr....",
		".....rwwwrwwwr..",
		"..rrrrrrrrrrrrr.",
		".rrrrrrrrrrrrrrr",
		".rrrrrrrrrrrrrrr",
		".rrrkkkrrrrkkkrr",
		"..rkkgkkrrkkgkk.",
		"..rkkkkkrrkkkkk.",
		"...kkkkk..kkkkk.",
		"................",
		"................",
		"................",
	],
	"play": [
		"................",
		"................",
		"................",
		".kkkkkkkkkkkkkk.",
		".krrwwrrrrrrrrk.",
		".krrwwwrrrrrrrk.",
		".krrwwwwwrrrrrk.",
		".krrwwwwwwrrrrk.",
		".krrwwwwwwrrrrk.",
		".krrwwwwwrrrrrk.",
		".krrwwwrrrrrrrk.",
		".krrwwrrrrrrrrk.",
		".kkkkkkkkkkkkkk.",
		"................",
		"................",
		"................",
	],
	"cart": [
		"................",
		"................",
		"................",
		"gg..............",
		".g.bbbbbbbbbbb..",
		".g.bwbbbbbbbbb..",
		".g..bbbbbbbbbb..",
		".g...bbbbbbbb...",
		".ggggggggggg....",
		"..........g.....",
		".....kk....kk...",
		".....kk....kk...",
		"................",
		"................",
		"................",
		"................",
	],
	"coffee": [
		".......g..g.....",
		"......g..g......",
		"..TTTTTTTTTTTT..",
		"...wwwwwwwwww...",
		"...wwwwwwwwww...",
		"...nnnnnnnnnn...",
		"...nnnnwwnnnn...",
		"...nnnwwwwnnn...",
		"...nnnnwwnnnn...",
		"...nnnnnnnnnn...",
		"....wwwwwwww....",
		"....wwwwwwww....",
		".....wwwwww.....",
		"................",
		"................",
		"................",
	],
	"soda": [
		"................",
		"................",
		".....kkkkkk.....",
		"...kkrrrrrrkk...",
		"..krrrrrrrrrrk..",
		".krrrrrrrrrrrrk.",
		".krrrrrrrrrrrrk.",
		".kwwwwwwwwwwwwk.",
		".kbbbbbbbbbbbbk.",
		".kbbbbbbbbbbbbk.",
		".kbbbbbbbbbbbbk.",
		"..kbbbbbbbbbbk..",
		"...kkbbbbbbkk...",
		".....kkkkkk.....",
		"................",
		"................",
	],
	"bank": [
		"................",
		".......ww.......",
		"......wwww......",
		".....wwwwww.....",
		"....wwwwwwww....",
		"...wwwwwwwwww...",
		"..gggggggggggg..",
		"...ww.ww.ww.ww..",
		"...ww.ww.ww.ww..",
		"...ww.ww.ww.ww..",
		"...ww.ww.ww.ww..",
		"...ww.ww.ww.ww..",
		"..yyyyyyyyyyyy..",
		".yyyyyyyyyyyyyy.",
		"................",
		"................",
	],
	"card": [
		"................",
		"................",
		"................",
		".kkkkkkkkkkkkkk.",
		".kbbbbbbbbbbbbk.",
		".kbbbbbbbbbbbbk.",
		".kyyyybbbbbbbbk.",
		".kyyyybbbbbbbbk.",
		".kbbbbbbbbbbbbk.",
		".kwwwwwwwwwwbbk.",
		".kbbbbbbbbbbbbk.",
		".kbbbbbbbbbbbbk.",
		".kkkkkkkkkkkkkk.",
		"................",
		"................",
		"................",
	],
	"coin": [
		"................",
		"................",
		".....kkkkkk.....",
		"...kkyyyyyykk...",
		"..kyyyyyyyyyyk..",
		".kyyYYYYYYYYyyk.",
		".kyYyyyyyyyyYyk.",
		".kyYyywwyyyyYyk.",
		".kyYyywyyyyyYyk.",
		".kyYyyyyyyyyYyk.",
		".kyyYYYYYYYYyyk.",
		"..kyyyyyyyyyyk..",
		"...kkyyyyyykk...",
		".....kkkkkk.....",
		"................",
		"................",
	],
	"ticket": [
		"................",
		"................",
		"..kkkkkkkkkkkk..",
		".kyyyyyyyYyyyyk.",
		".kyyrrrryYywwyk.",
		".kyyrrrryYyyyyk.",
		".kyyyrryyYywwyk.",
		".yyyyyyyyYyyyyy.",
		".yyyyyyyyYyyyyy.",
		".kyyyrryyYywwyk.",
		".kyyrrrryYyyyyk.",
		".kyyrrrryYywwyk.",
		".kyyyyyyyYyyyyk.",
		"..kkkkkkkkkkkk..",
		"................",
		"................",
	],
	"blocks": [
		"................",
		"................",
		"....kkkkkk......",
		"....krrrrk......",
		"....krwrrk......",
		"....krrrrk......",
		"....kkkkkk......",
		"..kkkkkkkkkkk...",
		"..kbbbbknnnnk...",
		"..kbwbbknwnnk...",
		"..kbbbbknnnnk...",
		"..kbbbbknnnnk...",
		"..kkkkkkkkkkk...",
		"................",
		"................",
		"................",
	],
	"satellite": [
		"................",
		"..........kk....",
		"..........kggk..",
		"..bbbb...kkgk...",
		".kbBBbk.kgk.....",
		".kbBBbkkgk......",
		".kbbbbkgk.......",
		"..kkkkkkkk......",
		"......kGgGk.....",
		".kbbbbkGGGk.....",
		".kbBBbkkkkk.....",
		".kbBBbk.........",
		".kbbbbk.........",
		"..kkkk..........",
		"................",
		"................",
	],
	"game": [
		"................",
		"................",
		"................",
		"..kkkkkkkkkkkk..",
		".kggggggggggggk.",
		".kgkgggggggroggk",
		".kkkkkgggggggrgk",
		".kgkgggggoggggyk",
		".kgggggggggbgggk",
		".kggggggggggggk.",
		".kgggkkkkkkgggk.",
		"..kgkk....kkgk..",
		"...kk......kk...",
		"................",
		"................",
		"................",
	],
	"moon": [
		"................",
		".....kkkkk......",
		"...kkyyyyk......",
		"..kyyyyyk.......",
		".kyyyYyyk.......",
		".kyyyyyyk.......",
		".kyYyyyyyk......",
		".kyyyyyyyyk.....",
		".kyyyyyyyyyk.k..",
		"..kyyyyyyyykyk..",
		"..kyyYyyyyyyk...",
		"...kyyyyyyyk....",
		"....kkyyykk.....",
		".......kkk......",
		"................",
		"................",
	],
	"disk": [
		"................",
		"..kkkkkkkkkkkk..",
		".kbbkgggggkbbbk.",
		".kbbkgGGGgkbbbk.",
		".kbbkgggggkbbbk.",
		".kbbbkkkkkbbbbk.",
		".kbbbbbbbbbbbbk.",
		".kbwwwwwwwwwwbk.",
		".kbwkkkkkkkkwbk.",
		".kbwwwwwwwwwwbk.",
		".kbwkkkkkkwwwbk.",
		".kbwwwwwwwwwwbk.",
		".kbbbbbbbbbbbbk.",
		"..kkkkkkkkkkkk..",
		"................",
		"................",
	],
	"bear": [
		"................",
		"..kkk......kkk..",
		".kwwwk.kk.kwwwk.",
		".kwmwkkwwkkwmwk.",
		"..kwwwwwwwwwwk..",
		"..kwwwwwwwwwwk..",
		".kwwkwwwwwwkwwk.",
		".kwwwwwwwwwwwwk.",
		".kwwwwwkkwwwwwk.",
		".kwwwwkkkkwwwwk.",
		".kwwwwwkkwwwwwk.",
		"..kwwwkwwkwwwk..",
		"...kwwwwwwwwk...",
		"....kkkkkkkk....",
		"................",
		"................",
	],
	"star": [
		"................",
		"................",
		".......kk.......",
		"......kyyk......",
		"......kyyk......",
		".kkkkkywyykkkkk.",
		"kyyyyywwyyyYYYYk",
		".kkyyyyyyyyYYkk.",
		"...kyyyyyyyYk...",
		"....kyyyyyYk....",
		"....kyyyyYYk....",
		"....kyyyYYYk....",
		"...kyyykkYYYk...",
		"...kykk..kkYk...",
		"....k......k....",
		"................",
	],
	"bolt": [
		"..........k.....",
		".........kyk....",
		"........kwyk....",
		".......kwyk.....",
		"......kyyyk.....",
		".....kyyykkkk...",
		".....kyyyyyyok..",
		"....kyyyyyyok...",
		"...kyyyyyyok....",
		"....kkkyyok.....",
		"......kyok......",
		"......kok.......",
		".....kook.......",
		".....kok........",
		"....kok.........",
		".....k..........",
	],
	"shield": [
		"..kkkkkkkkkkkk..",
		".kbbbbbbBBBBBBk.",
		".kbbbbbbBBBBBBk.",
		".kbbbbbwwBBBBBk.",
		".kbbbbbwwBBBBBk.",
		".kbbbbbwwBBBBBk.",
		".kbbbwwwwwwBBBk.",
		".kbbbbbwwBBBBBk.",
		".kbbbbbwwBBBBBk.",
		"..kbbbbwwBBBBk..",
		"...kbbbbBBBBk...",
		"....kbbbBBBk....",
		".....kbbBBk.....",
		".....kbbBBk.....",
		"......kbBk......",
		".......kk.......",
	],
	"clover": [
		"................",
		"...kkkk..kkkk...",
		"..kllllkkllllk..",
		".klllwllllllllk.",
		".kllwllllwllllk.",
		".klllllllllllnk.",
		"..klllllllllnk..",
		"...klllkkllnk...",
		"..klllllllnnnk..",
		".klllllllnnnnnk.",
		".kllllllnnnnnnk.",
		".klllllnTnnnnnk.",
		"..klllnkTnnnnk..",
		"...kkkkkTkkkk...",
		"......kTTk......",
		"......kTTk......",
	],
	"gem": [
		"................",
		"...kkkkkkkkkk...",
		"..kcccccbbbbbk..",
		".kccwwccbbbbbbk.",
		".kcccwccbbbbbbk.",
		"kcccccccbbbbbbbk",
		"kBBBBBBBBBBBBBBk",
		".kccccccbbbbbbk.",
		"..kcccccbbbbbk..",
		"...kccccbbbbk...",
		"...kccccbbbbk...",
		"....kcccbbbk....",
		".....kccbbk.....",
		"......kcbk......",
		"......kcbk......",
		".......kk.......",
	],
	"sun": [
		"................",
		".......oo.......",
		"..o....oo....o..",
		"...o........o...",
		"......yyyy......",
		".....yyyyyy.....",
		"....yywyyyyy....",
		"oo..yyyyyyyy..oo",
		"oo..yyyyyyyy..oo",
		"....yyyyyyyy....",
		".....yyyyyy.....",
		"......yyyy......",
		"...o........o...",
		"..o....oo....o..",
		".......oo.......",
		"................",
	],
	"chart": [
		"................",
		"................",
		"................",
		"................",
		"..........nnn...",
		"..........nnn...",
		"..........nnn...",
		"......nnn.nnn...",
		"......nnn.nnn...",
		"......nnn.nnn...",
		"..nnn.nnn.nnn...",
		"..nnn.nnn.nnn...",
		"..nnn.nnn.nnn...",
		"..gggggggggggg..",
		"................",
		"................",
	],
}

static var _images: Dictionary = {}
static var _textures: Dictionary = {}


## All icon names that have a bitmap (including the fallback).
static func names() -> Array[String]:
	var out: Array[String] = []
	for k: String in ICONS:
		out.append(k)
	return out


## Pixel icon of a perk (by PerkDef.id). Unknown perks get a star.
const PERK_ICONS := {
	"low_fees": "coin", "savings_account": "bank", "early_bird": "bolt", "fact_checker": "magnifier",
	"stop_guard": "shield", "sector_fan": "clover", "margin_account": "rocket", "cheap_borrow": "card",
	"diversifier": "people", "dividend_hunter": "sun", "second_opinion": "eye", "insider_friend": "star",
	"iron_hands": "shield", "compounder": "gem", "market_maker": "chip",
}


static func perk_icon(perk_id: String) -> String:
	return String(PERK_ICONS.get(perk_id, "star"))


static func has_icon(icon_name: String) -> bool:
	return ICONS.has(icon_name)


## Resolves unknown or empty names to the fallback icon.
static func resolve(icon_name: String) -> String:
	return icon_name if ICONS.has(icon_name) else FALLBACK


static func rows_of(icon_name: String) -> Array:
	return ICONS[resolve(icon_name)]


## 16x16 RGBA image, cached. Deterministic: depends only on the bitmap and the palette.
static func image(icon_name: String) -> Image:
	var key: String = resolve(icon_name)
	if not _images.has(key):
		_images[key] = _build(key)
	return _images[key]


## Nearest-neighbour texture, cached. Draw it with texture_filter = NEAREST for crisp scaling.
static func texture(icon_name: String) -> ImageTexture:
	var key: String = resolve(icon_name)
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(image(key))
	return _textures[key]


## Background colour of the badge tile of an icon.
static func tile_color(icon_name: String) -> Color:
	return Color(TILE[resolve(icon_name)])


## Icon on its coloured rounded tile, baked into one small texture (BADGE_SIZE px) for places that only take
## a Texture2D (Tree items, buttons). Cached; same determinism as image().
static func badge_texture(icon_name: String, sector: String = "") -> ImageTexture:
	var key: String = "badge:%s:%s" % [resolve(icon_name), sector]
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(badge_image(icon_name, sector))
	return _textures[key]


static func badge_image(icon_name: String, sector: String = "") -> Image:
	var key: String = resolve(icon_name)
	var size: int = BADGE_SIZE
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var tile: Color = tile_color(key)
	var edge: Color = UiPalette.sector_color(sector) if sector != "" else tile.darkened(0.45)
	for y in size:
		for x in size:
			var cx: int = mini(x, size - 1 - x)
			var cy: int = mini(y, size - 1 - y)
			if cx + cy < 2:
				continue  # cut corner
			var border: bool = cx == 0 or cy == 0
			img.set_pixel(x, y, edge if border else tile)
	img.blend_rect(image(key), Rect2i(0, 0, SIZE, SIZE), Vector2i((size - SIZE) / 2, (size - SIZE) / 2))
	return img


static func _build(key: String) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var rows: Array = ICONS[key]
	for y in mini(rows.size(), SIZE):
		var row: String = rows[y]
		for x in mini(row.length(), SIZE):
			var ch: String = row[x]
			if ch != "." and PALETTE.has(ch):
				img.set_pixel(x, y, Color(PALETTE[ch]))
	return img
