extends TestCase


func test_every_table_character_has_a_portrait() -> void:
	for c in ContentDb.characters():
		if c.table_role:
			assert_true(PixelPortraits.has_portrait(String(c.id)), "portrait for %s" % c.id)


func test_portraits_are_14_by_15_and_use_known_colours() -> void:
	for id in PixelPortraits.ids():
		var rows := PixelPortraits.rows_of(id)
		assert_eq(rows.size(), PixelPortraits.HEIGHT, "%s rows" % id)
		for row in rows:
			assert_eq((row as String).length(), PixelPortraits.WIDTH, "%s row width" % id)
			for ch in (row as String):
				assert_true(ch == "." or PixelPortraits.PALETTE.has(ch), "%s uses colour '%s'" % [id, ch])
		var img := PixelPortraits.image(id)
		assert_eq(img.get_width(), PixelPortraits.WIDTH)
		assert_eq(img.get_height(), PixelPortraits.HEIGHT)
		assert_true(img.get_pixel(PixelPortraits.WIDTH / 2, PixelPortraits.HEIGHT - 1).a > 0.0, "%s stands on the bottom edge" % id)


func test_portraits_are_all_different() -> void:
	var seen := {}
	for id in PixelPortraits.ids():
		seen[str(PixelPortraits.rows_of(id))] = true
	assert_eq(seen.size(), PixelPortraits.ids().size())


func test_unknown_character_is_transparent() -> void:
	var img := PixelPortraits.image("nobody")
	assert_eq(img.get_pixel(5, 5).a, 0.0)


func test_every_table_character_has_kenney_art() -> void:
	for c in ContentDb.characters():
		if c.table_role:
			assert_true(PortraitView.has_art(String(c.id)), "Kenney bust for %s" % c.id)
			var tex := PortraitView.bust_texture(String(c.id))
			assert_true(tex.get_width() >= 128 and tex.get_height() >= 128, "%s bust is big enough" % c.id)
			var img := tex.get_image()
			assert_true(img.get_pixel(img.get_width() / 2, img.get_height() / 2).a > 0.5, "%s bust is not empty" % c.id)
