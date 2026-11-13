extends TestCase


func _order() -> Array:
	var script: GDScript = load("res://ui/run_setup/run_setup.gd")
	return script.get_script_constant_map()["ROSTER_ORDER"]


func test_picker_numbers_the_six_characters() -> void:
	assert_eq(_order(), ["saving_son", "double_dan", "hodl_hana", "goldfish_gus", "copilot_cody", "insider_inu"])


func test_every_table_character_has_exactly_one_number() -> void:
	var order := _order()
	var seen := {}
	for c in ContentDb.characters():
		if c.table_role:
			assert_true(String(c.id) in order, "%s is in the picker" % c.id)
			seen[String(c.id)] = true
	assert_eq(seen.size(), order.size())
	for id in order:
		assert_true(seen.has(id), "%s is a table character" % id)


func test_characters_carry_no_difficulty_tag() -> void:
	for c in ContentDb.characters():
		assert_false("difficulty_tag" in c, "the easy / hard tag is gone")
