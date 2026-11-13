extends TestCase


func test_every_table_character_has_a_3d_model_with_its_intro_move() -> void:
	for c in ContentDb.characters():
		if not c.table_role:
			continue
		var id := String(c.id)
		assert_true(CharacterModel.has_model(id), "model for %s" % id)
		var model := CharacterModel.make(id)
		assert_true(model != null, "%s loads" % id)
		if model == null:
			continue
		var anim: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
		assert_true(anim != null, "%s has an animation player" % id)
		if anim != null:
			assert_true(anim.has_animation("idle"), "%s idles" % id)
			assert_true(anim.has_animation(CharacterModel.INTRO_MOVE[id]), "%s has its intro move" % id)
		model.free()


func test_the_roster_order_matches_the_character_picker() -> void:
	var ids := {}
	for id in RivalRoll.ROSTER:
		ids[id] = true
		assert_true(ContentDb.character_by_id(StringName(id)) != null, "%s exists" % id)
	for c in ContentDb.characters():
		if c.table_role:
			assert_true(ids.has(String(c.id)), "%s is in the opening roster" % c.id)


func test_the_opening_is_on_by_default() -> void:
	GameSettings.path = "user://test_opening_settings.cfg"
	GameSettings.reload()
	assert_true(GameSettings.opening_enabled())
	GameSettings.set_opening_enabled(false)
	assert_false(GameSettings.opening_enabled())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.path))
	GameSettings.path = GameSettings.PATH
	GameSettings.reload()
