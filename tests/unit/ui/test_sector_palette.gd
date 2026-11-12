extends TestCase

const SECTORS := ["tech", "space", "consumer", "finance"]


func test_every_company_sector_has_its_own_colours() -> void:
	var seen := {}
	for c in ContentDb.companies():
		assert_true(c.sector in SECTORS, "known sector " + c.symbol)
	for s in SECTORS:
		var main: Color = UiPalette.sector_color(s)
		assert_false(seen.has(main.to_html()), "distinct main colour for " + s)
		seen[main.to_html()] = true
		assert_false(main.is_equal_approx(UiPalette.SECTOR_NEUTRAL), "not the fallback grey: " + s)
		assert_true(UiPalette.sector_soft(s).get_luminance() > 0.8, "soft tint is light: " + s)
		assert_true(UiPalette.sector_deep(s).get_luminance() < main.get_luminance(), "deep is darker than main: " + s)


func test_sector_colours_do_not_clash_with_signals() -> void:
	var signals: Array[Color] = [UiPalette.INK_UP, UiPalette.INK_DOWN, UiPalette.RARITY_RARE, UiPalette.RARITY_LEGENDARY]
	for s in SECTORS:
		var main: Color = UiPalette.sector_color(s)
		for sig in signals:
			assert_true(absf(main.h - sig.h) > 0.04 or absf(main.s - sig.s) > 0.25 or absf(main.v - sig.v) > 0.25, "%s too close to a signal colour" % s)


func test_unknown_sector_falls_back_to_neutral() -> void:
	assert_eq(UiPalette.sector_color("energy"), UiPalette.SECTOR_NEUTRAL)
	assert_eq(UiPalette.sector_soft(""), UiPalette.SECTOR_NEUTRAL_SOFT)
