extends TestCase


func _cfg(character_id: StringName = &"rookie", difficulty: int = 1, seed_value: int = 7) -> RunConfig:
	return RunConfig.make(ContentDb.character_by_id(character_id), difficulty, seed_value)


func test_top_scores_sorted_and_capped() -> void:
	var p := Profile.new()
	for s in [5000.0, 12000.0, 9000.0, 1.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]:
		p.record_run(s, _cfg())
	assert_eq(p.total_runs, 12)
	assert_eq(p.top_scores.size(), 10)
	assert_eq(p.top_scores[0]["score"], 12000.0)
	assert_eq(p.top_scores[1]["score"], 9000.0)
	for i in range(1, p.top_scores.size()):
		assert_true(p.top_scores[i - 1]["score"] >= p.top_scores[i]["score"], "sorted")
	assert_eq(p.top_scores[9]["score"], 4.0)


func test_entry_fields_and_ties() -> void:
	var p := Profile.new()
	p.record_run(1000.0, _cfg(&"rookie", 1, 111))
	p.record_run(1000.0, _cfg(&"rookie", 1, 222))
	assert_eq(p.top_scores[0]["seed"], 111, "earlier run stays first on ties")
	for key in ["score", "character", "difficulty", "seed", "date"]:
		assert_true(p.top_scores[0].has(key), key)
	assert_eq(p.top_scores[0]["character"], "rookie")


func test_first_run_unlocks_day_trader_and_difficulty_2() -> void:
	var p := Profile.new()
	assert_false(p.is_unlocked(Profile.UNLOCK_CHAR_DAY_TRADER))
	var gained := p.record_run(100.0, _cfg())
	assert_true(Profile.UNLOCK_CHAR_DAY_TRADER in gained)
	assert_true(Profile.UNLOCK_DIFFICULTY_2 in gained)
	assert_false(Profile.UNLOCK_CHAR_VALUE_INVESTOR in gained)
	assert_true(p.is_unlocked(Profile.UNLOCK_CHAR_DAY_TRADER))
	assert_true(p.is_unlocked(&""), "empty id always unlocked")
	assert_eq(p.record_run(100.0, _cfg()).size(), 0, "nothing new the second time")


func test_value_investor_needs_20000() -> void:
	var p := Profile.new()
	p.record_run(19999.0, _cfg())
	assert_false(p.is_unlocked(Profile.UNLOCK_CHAR_VALUE_INVESTOR))
	var gained := p.record_run(20000.0, _cfg())
	assert_true(Profile.UNLOCK_CHAR_VALUE_INVESTOR in gained)


func test_difficulty_chain_unlocks_next_level_only() -> void:
	var p := Profile.new()
	p.record_run(1.0, _cfg(&"rookie", 3))
	assert_true(p.is_unlocked(&"difficulty_4"))
	assert_false(p.is_unlocked(&"difficulty_3"))
	p.record_run(1.0, _cfg(&"rookie", Difficulty.MAX_LEVEL))
	assert_false(p.is_unlocked(&"difficulty_6"))
	assert_eq(Profile.difficulty_unlock_id(1), &"")
	assert_eq(Profile.difficulty_unlock_id(2), Profile.UNLOCK_DIFFICULTY_2)


func test_company_unlocks() -> void:
	var p := Profile.new()
	p.record_run(16000.0, _cfg())
	assert_true(p.is_unlocked(Profile.UNLOCK_COMPANY_OLDE))
	assert_false(p.is_unlocked(Profile.UNLOCK_COMPANY_MOON))
	p.record_run(1.0, _cfg())
	var gained := p.record_run(1.0, _cfg())
	assert_true(Profile.UNLOCK_COMPANY_MOON in gained, "3rd run")


func test_dict_round_trip() -> void:
	var p := Profile.new()
	p.record_run(25000.0, _cfg())
	var q := Profile.new()
	q.load_dict(p.to_dict())
	assert_eq(q.total_runs, 1)
	assert_eq(q.top_scores.size(), 1)
	assert_eq(q.unlocked.keys().size(), p.unlocked.keys().size())
	assert_true(q.is_unlocked(Profile.UNLOCK_COMPANY_EXTRA_3))
