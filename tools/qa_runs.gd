## QA tool: plays many full 60-day runs through the real GameManager (scene changes, EventBus, saves) with an
## autoplayer and checks invariants. Backs up and restores the player's user:// save files.
##   godot --headless --path . --script res://tools/qa_runs.gd 2>&1 | tail -40
## Any "ERROR" / "SCRIPT ERROR" line in the output is a defect.
extends SceneTree

var _fails: int = 0
var _day_us: Array[int] = []
var _gm_day_us: Array[int] = []
var _save_us: Array[int] = []
var _runs: int = 0
var _game_overs: int = 0
var _high_score_entries: int = 0
var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_main.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("FAIL ", what)


func _main() -> void:
	var bak_profile: Variant = _read("user://profile.json")
	var bak_run: Variant = _read("user://run.json")
	var gm: Node = root.get_node("GameManager")
	var sm: Node = root.get_node("SaveManager")
	var mem0: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	var objs0: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))

	# CSV parse time (fresh parse, not the cached default).
	var t0 := Time.get_ticks_usec()
	var h := HistoryData.from_file(HistoryData.DEFAULT_PATH)
	var parse_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	print("csv parse: %.1f ms, %d rows" % [parse_ms, h.row_count()])

	var seed_value := 100
	for ch: CharacterDef in ContentDb.characters():
		for diff in range(1, 6):
			for margin in [false, true]:
				seed_value += 7
				await _play(gm, sm, ch, diff, margin, seed_value)
	for s_i in 12:   # plus a spread of seeds (different windows) with the default setup
		seed_value += 13
		await _play(gm, sm, ContentDb.characters()[0], 1 + s_i % 5, s_i % 2 == 0, seed_value)

	await process_frame
	await process_frame
	var objs1: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var mem1: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	print("runs: %d  game-over screens: %d  fails: %d" % [_runs, _game_overs, _fails])
	print("session.next_day(): mean %.2f ms  max %.2f ms  (n=%d)" % [_mean(_day_us) / 1000.0, _max(_day_us) / 1000.0, _day_us.size()])
	print("GameManager.next_day() incl. signals + UI + save: mean %.2f ms  max %.2f ms" % [_mean(_gm_day_us) / 1000.0, _max(_gm_day_us) / 1000.0])
	print("to_dict+save to disk: mean %.2f ms  max %.2f ms" % [_mean(_save_us) / 1000.0, _max(_save_us) / 1000.0])
	print("objects before/after: %d / %d   static mem: %.1f MB -> %.1f MB" % [objs0, objs1, mem0 / 1048576.0, mem1 / 1048576.0])
	_write("user://profile.json", bak_profile)
	_write("user://run.json", bak_run)
	quit(1 if _fails > 0 else 0)


func _play(gm: Node, sm: Node, ch: CharacterDef, diff: int, margin: bool, seed_value: int) -> void:
	_runs += 1
	_rng.seed = seed_value
	var tag := "%s d%d m%d s%d" % [ch.id, diff, int(margin), seed_value]
	var scores_before: int = sm.profile.top_scores.size()
	gm.start_run(RunConfig.make(ch, diff, seed_value, margin))
	await process_frame
	await process_frame
	await process_frame
	var guard := 0
	var did_roundtrip := false
	while gm.state != gm.State.GAME_OVER and guard < 400:
		guard += 1
		var s: GameSession = gm.session
		if gm.state == gm.State.DRAFTING:
			gm.choose_perk(s.pending_draft[_rng.randi() % s.pending_draft.size()])
			continue
		_autoplay(gm, s, margin)
		_invariants(s, tag)
		var t := Time.get_ticks_usec()
		gm.next_day()
		var dt := Time.get_ticks_usec() - t
		_gm_day_us.append(dt)
		if dt > 40000 and OS.get_cmdline_user_args().has("--slow"):
			print("slow day %d: %.1f ms  %s (drafting=%s)" % [s.day, dt / 1000.0, tag, gm.state == gm.State.DRAFTING])
		await process_frame
		if gm.session != null and not did_roundtrip and gm.session.day == 25 and gm.state == gm.State.PLAYING:
			did_roundtrip = true
			_roundtrip(gm, s, tag)
	_check(gm.state == gm.State.GAME_OVER, tag + ": reaches game over")
	await process_frame
	await process_frame
	var screen: Node = current_scene
	var over: Node = screen.find_child("GameOverDialog", true, false) if screen != null else null
	if over != null and over.visible:
		_game_overs += 1
	else:
		_check(false, tag + ": game over dialog visible (found=%s)" % str(over != null))
	_check(gm.session.day == RunConfig.TRADING_DAYS, tag + ": 60 days")
	_check(is_finite(gm.session.score()), tag + ": score finite")
	_check(sm.profile.top_scores.size() >= mini(scores_before + 1, Profile.MAX_SCORES), tag + ": high score recorded")
	_check(not sm.has_run(), tag + ": run save deleted on finish")
	if OS.get_cmdline_user_args().has("--leaks"):
		print("leak %s: objects %d nodes %d orphans %d static %.1f MB" % [tag, Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
	# Per-day pure-session timing for this seed (separate session, no UI): replay the same seed quickly.
	var ps := GameSession.new(RunConfig.make(ch, diff, seed_value, margin), ContentDb.companies(), ContentDb.perks(), ContentDb.news())
	ps.start()
	for i in 80:
		if ps.is_finished():
			break
		var t2 := Time.get_ticks_usec()
		ps.next_day()
		_day_us.append(Time.get_ticks_usec() - t2)
		if not ps.pending_draft.is_empty():
			ps.choose_perk(ps.pending_draft[0])


## Buys and sells a bit of everything, including limit orders and (margin) shorts.
func _autoplay(gm: Node, s: GameSession, margin: bool) -> void:
	var syms: Array[String] = s.market.symbols()
	for k in 3:
		var sym: String = syms[_rng.randi() % syms.size()]
		var price: float = s.market.price_of(sym)
		var roll := _rng.randf()
		var n := 1 + _rng.randi() % 6
		var order: Order
		if roll < 0.45:
			order = Order.market(Order.Dir.BUY, sym, n)
		elif roll < 0.65 and s.portfolio.shares_of(sym) > 0:
			order = Order.market(Order.Dir.SELL, sym, mini(n, s.portfolio.shares_of(sym)))
		elif roll < 0.75:
			order = Order.limit(Order.Dir.BUY, sym, n, price * 0.97)
		elif roll < 0.82 and s.portfolio.shares_of(sym) > 0:
			order = Order.stop(Order.Dir.SELL, sym, 1, price * 0.95)
		elif margin and roll < 0.95:
			order = Order.market(Order.Dir.SELL, sym, n * 3)   # short / leverage pressure to provoke margin calls
		else:
			order = Order.market(Order.Dir.BUY, sym, n * (4 if margin else 1))
		gm.submit_order(order)


func _invariants(s: GameSession, tag: String) -> void:
	_check(is_finite(s.net_worth()), tag + ": net worth finite day %d" % s.day)
	for sym in s.market.symbols():
		var p: float = s.market.price_of(sym)
		_check(p > 0.0 and is_finite(p), "%s: price > 0 (%s day %d = %f)" % [tag, sym, s.day, p])
		var c: Dictionary = s.market.candles_of(sym)
		var cl: PackedFloat32Array = c["close"]
		var n := cl.size()
		_check((c["open"] as PackedFloat32Array).size() == n and (c["high"] as PackedFloat32Array).size() == n and (c["low"] as PackedFloat32Array).size() == n, tag + ": candle arrays aligned " + sym)
		var i := n - 1
		var hi: float = (c["high"] as PackedFloat32Array)[i]
		var lo: float = (c["low"] as PackedFloat32Array)[i]
		var op: float = (c["open"] as PackedFloat32Array)[i]
		_check(lo <= minf(op, cl[i]) + 0.0001 and hi >= maxf(op, cl[i]) - 0.0001, "%s: candle ordering %s day %d" % [tag, sym, s.day])
		_check(n == s.market.lookback_of(sym) + 1 + s.day, "%s: history length %s day %d (n=%d lb=%d)" % [tag, sym, s.day, n, s.market.lookback_of(sym)])
	_check(s.date_of_day(s.day) != "", tag + ": date_of_day")


## Save mid-run, rebuild from the dictionary, and run both for 8 days with identical (deterministic) play.
func _roundtrip(gm: Node, s: GameSession, tag: String) -> void:
	var t := Time.get_ticks_usec()
	var data: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	_save_us.append(Time.get_ticks_usec() - t)
	var cfg := GameSession.config_from_dict(data)
	var l := GameSession.from_dict(data, cfg, ContentDb.companies(), ContentDb.perks(), ContentDb.news())
	_check(l != null, tag + ": load ok")
	if l == null:
		return
	_check(l.day == s.day and l.window_start == s.window_start, tag + ": day/window restored")
	_check(absf(l.net_worth() - s.net_worth()) < 0.01, tag + ": net worth restored")
	_check(l.date_of_day(0) == s.date_of_day(0), tag + ": start date restored")
	for sym in s.market.symbols():
		var a: Dictionary = s.market.candles_of(sym)
		var b: Dictionary = l.market.candles_of(sym)
		for k in ["open", "high", "low", "close"]:
			_check((a[k] as PackedFloat32Array) == (b[k] as PackedFloat32Array), "%s: %s %s restored" % [tag, sym, k])
		_check(s.market.lookback_of(sym) == l.market.lookback_of(sym), tag + ": lookback restored")
	for i in 8:
		if s.is_finished() or l.is_finished():
			break
		s.next_day()
		l.next_day()
		if not s.pending_draft.is_empty():
			s.choose_perk(s.pending_draft[0])
		if not l.pending_draft.is_empty():
			l.choose_perk(l.pending_draft[0])
	_check(absf(l.net_worth() - s.net_worth()) < 0.01, tag + ": loaded run stays in lockstep with the original (%.2f vs %.2f)" % [l.net_worth(), s.net_worth()])
	# Disk path used by Continue.
	gm.get_node("/root/SaveManager").save_run(gm.session)
	var d2: Dictionary = gm.get_node("/root/SaveManager").load_run_data()
	_check(not d2.is_empty() and int(d2["day"]) == gm.session.day, tag + ": disk roundtrip")


func _mean(a: Array[int]) -> float:
	var t := 0.0
	for v in a:
		t += v
	return t / maxf(a.size(), 1)


func _max(a: Array[int]) -> float:
	var m := 0
	for v in a:
		m = maxi(m, v)
	return float(m)


func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return FileAccess.get_file_as_string(path)


func _write(path: String, content: Variant) -> void:
	if content == null:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(String(content))
	f.close()
