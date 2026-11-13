extends TestCase

const CHARACTERS: Array[StringName] = [&"insider_inu", &"copilot_cody", &"double_dan", &"saving_son", &"goldfish_gus", &"hodl_hana"]


func _session(char_id: StringName, seed_value: int) -> TableSession:
	var cfg := RunConfig.make_table(ContentDb.character_by_id(char_id), seed_value)
	var s := TableSession.new(cfg, ContentDb.companies(), ContentDb.perks(), ContentDb.news())
	s.start()
	return s


## A scripted human: rotates the call, trades a little, uses the skills when they are available.
func _play(s: TableSession) -> void:
	var guard := 0
	var symbols := s.market.symbols()
	while not s.is_finished() and guard < 40:
		var sides := [RumorTier.Side.BELIEVE, RumorTier.Side.BULLSHIT, RumorTier.Side.PASS]
		s.set_call(sides[s.day % 3])
		if s.day % 4 == 0:
			s.buy_fraction(0, symbols[s.day % symbols.size()], 0.25)
		if s.day % 5 == 3:
			s.sell_fraction(0, symbols[(s.day + 1) % symbols.size()], 0.5)
		if s.boss_rumor != null:
			s.set_boss_call(RumorTier.Side.BELIEVE)
		if s.can_flip(0):
			s.arm_flip(true)
		if s.seats[0].has_flag(&"copilot"):
			s.set_copy_target(1 + s.day % 3)
		s.reveal()
		if s.can_double(0):
			s.double_down(0)
		s.advance()
		guard += 1


func test_every_character_can_play_a_whole_run() -> void:
	for id in CHARACTERS:
		for seed_value in [3, 17]:
			var s := _session(id, seed_value)
			_play(s)
			assert_true(s.is_finished(), "%s seed %d finished" % [id, seed_value])
			assert_true(s.day <= 30)
			assert_true(is_finite(s.net_worth()), "net worth is a number")
			assert_true(s.net_worth() > 0.0, "%s still has money" % id)
			assert_eq(s.standings().size(), 4)
			for entry in s.standings():
				assert_true(is_finite(float(entry["net_worth"])))


func test_ranks_are_ordered_and_unique() -> void:
	var s := _session(&"saving_son", 8)
	_play(s)
	var ranks: Array[int] = []
	for e in s.standings():
		ranks.append(int(e["rank"]))
	assert_eq(ranks, [1, 2, 3, 4])
	var alive_nw: Array[float] = []
	for e in s.standings():
		if (e["seat"] as Seat).alive:
			alive_nw.append(float(e["net_worth"]))
	for i in range(1, alive_nw.size()):
		assert_true(alive_nw[i - 1] >= alive_nw[i], "living seats are sorted by net worth")


func test_no_bet_ever_costs_more_than_cash() -> void:
	var s := _session(&"double_dan", 4)
	for seat in s.seats:
		assert_true(seat.portfolio.cash >= 0.0)
	var guard := 0
	while not s.is_finished() and guard < 40:
		s.set_call(RumorTier.Side.BELIEVE)
		s.next_day()
		for seat in s.seats:
			assert_true(seat.portfolio.cash >= -0.01, "cash never negative without margin")
		guard += 1


func test_a_run_is_reproducible() -> void:
	var a := _session(&"copilot_cody", 21)
	var b := _session(&"copilot_cody", 21)
	_play(a)
	_play(b)
	assert_almost(a.net_worth(), b.net_worth(), 0.001)
	assert_eq(a.day, b.day)
	for i in 4:
		assert_almost(a.seats[i].portfolio.cash, b.seats[i].portfolio.cash, 0.001)


func test_hodl_hana_head_start_is_capped() -> void:
	for seed_value in range(1, 9):
		var s := _session(&"hodl_hana", seed_value)
		assert_true(s.net_worth() <= 10000.0 * (1.0 + 0.5 * (TableSession.HODL_MAX_GAIN - 1.0)) + 5.0, "head start is capped (seed %d)" % seed_value)
		assert_true(s.net_worth() >= 9990.0)
