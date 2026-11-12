## Sanity checks of the shared foundation (lead-owned): content formats load, modifiers work.
extends TestCase


func test_sample_content_loads() -> void:
	assert_eq(ContentDb.companies().size() >= 1, true, "companies")
	assert_eq(ContentDb.news().size() >= 1, true, "news")
	assert_eq(ContentDb.perks().size() >= 1, true, "perks")
	assert_eq(ContentDb.characters().size() >= 1, true, "characters")


func test_perk_effect_multiplies_fee() -> void:
	var perk := ContentDb.perk_by_id(&"low_fees")
	assert_not_null(perk, "low_fees perk")
	var mods := RunModifiers.new()
	mods.apply(perk)
	assert_almost(mods.fee_mult, 0.5)
	assert_almost(mods.effective_fee_rate(), 0.0005)


func test_flags() -> void:
	var mods := RunModifiers.new()
	assert_false(mods.has_flag(&"iron_hands"))
	mods.set_flag(&"iron_hands")
	assert_true(mods.has_flag(&"iron_hands"))


func test_session_can_be_constructed() -> void:
	var config := RunConfig.make(ContentDb.character_by_id(&"rookie"), 1, 123)
	var s := GameSession.new(config, ContentDb.companies(), ContentDb.perks(), ContentDb.news())
	assert_eq(s.day, 0)
	assert_eq(s.market.has_symbol("NOVA"), true)


func test_all_scenes_load() -> void:
	for path in _scenes("res://ui"):
		var scene := load(path) as PackedScene
		assert_not_null(scene, "cannot load %s" % path)


func _scenes(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir_path):
		if f.ends_with(".tscn"):
			out.append(dir_path.path_join(f))
	for d in DirAccess.get_directories_at(dir_path):
		out.append_array(_scenes(dir_path.path_join(d)))
	return out
