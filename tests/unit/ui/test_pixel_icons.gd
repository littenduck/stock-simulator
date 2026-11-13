extends TestCase

const COMPANY_ICONS := ["chip", "window", "fruit", "magnifier", "people", "eye", "rocket", "box", "car", "play", "cart", "coffee", "soda", "bank", "card", "coin", "ticket", "blocks", "satellite", "game", "moon", "disk", "bear"]


func test_every_company_icon_exists() -> void:
	for n in COMPANY_ICONS:
		assert_true(PixelIcons.has_icon(n), "bitmap for " + n)
	assert_true(PixelIcons.has_icon(PixelIcons.FALLBACK), "fallback bitmap")
	assert_eq(PixelIcons.names().size(), COMPANY_ICONS.size() + 1, "23 company icons + fallback")


func test_bitmaps_are_16x16_and_use_known_colours() -> void:
	for n in PixelIcons.names():
		var rows: Array = PixelIcons.rows_of(n)
		assert_eq(rows.size(), PixelIcons.SIZE, n + " row count")
		for row: String in rows:
			assert_eq(row.length(), PixelIcons.SIZE, n + " row width")
			for ch in row:
				assert_true(ch == "." or PixelIcons.PALETTE.has(ch), "%s uses unknown colour '%s'" % [n, ch])
		assert_true(PixelIcons.TILE.has(n), n + " has a tile colour")


func test_textures_are_nonempty_and_sized() -> void:
	for n in PixelIcons.names():
		var tex: ImageTexture = PixelIcons.texture(n)
		assert_not_null(tex, n)
		assert_eq(tex.get_width(), PixelIcons.SIZE, n + " width")
		assert_eq(tex.get_height(), PixelIcons.SIZE, n + " height")
		var img: Image = PixelIcons.image(n)
		var opaque: int = 0
		for y in PixelIcons.SIZE:
			for x in PixelIcons.SIZE:
				if img.get_pixel(x, y).a > 0.5:
					opaque += 1
		assert_true(opaque >= 20, "%s has visible pixels (%d)" % [n, opaque])
		var badge: ImageTexture = PixelIcons.badge_texture(n)
		assert_eq(badge.get_width(), PixelIcons.BADGE_SIZE, n + " badge width")


func test_generation_is_deterministic() -> void:
	for n in PixelIcons.names():
		var a: Image = PixelIcons._build(n)
		var b: Image = PixelIcons._build(n)
		assert_true(a.get_data() == b.get_data(), n + " identical bytes")
		assert_true(PixelIcons.image(n).get_data() == a.get_data(), n + " cache equals fresh build")
		assert_true(PixelIcons.badge_image(n).get_data() == PixelIcons.badge_image(n).get_data(), n + " badge identical")


func test_unknown_name_falls_back() -> void:
	assert_eq(PixelIcons.resolve("nope"), PixelIcons.FALLBACK)
	assert_eq(PixelIcons.resolve(""), PixelIcons.FALLBACK)
	assert_true(PixelIcons.texture("nope") == PixelIcons.texture(PixelIcons.FALLBACK), "same fallback texture")


func test_every_content_icon_has_a_bitmap() -> void:
	for c in ContentDb.companies():
		assert_true(PixelIcons.has_icon(c.icon), "company icon " + c.icon)
	for e in ContentDb.news():
		if e.icon != "":
			assert_true(PixelIcons.has_icon(e.icon), "news icon " + e.icon)
