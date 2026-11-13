## Plays sound effects in reaction to EventBus signals. Instanced once inside game_screen.tscn.
## Does not decide anything about the game; a missing audio file is silently skipped.
## Web note: browsers keep the audio context suspended until the first user input. Godot's web
## runtime resumes it on the first click/key, and the player always clicks before any sound
## is triggered (menu -> run setup -> game), so no extra unlock code is needed. See tools/release/web-audio.md.
extends Node

const IFACE := "res://audio/kenney_interface-sounds/Audio/"
const UIA := "res://audio/kenney_ui-audio/Audio/"
const DIGI := "res://audio/kenney_digital-audio/Audio/"
const IMPACT := "res://audio/kenney_impact-sounds/Audio/"
## Event -> the files it may play. Each play picks one of them (never the same twice in a row) and bends the pitch a
## little, so the same event never sounds the same twice. Every file is from the four Kenney packs in audio/.
var SFX: Dictionary = _build_table()
## Events whose pitch varies more than the default (the arcade ticks climb and fall).
const JITTER := {&"slot_tick": 0.1, &"chart_tick": 0.08, &"reveal_tick": 0.06}
const POLYPHONY := 6

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _last_pick: Dictionary = {}
## Counts plays per effect; tests read it (also works with a headless audio driver).
var played: Dictionary = {}


## `dir` + prefix + number (001..) for the given numbers: ("confirmation_", [1, 2, 3, 4]) -> confirmation_001.ogg ...
static func _seq(dir: String, prefix: String, numbers: Array, digits: int = 3, ext: String = ".ogg") -> Array:
	var out: Array = []
	for n: int in numbers:
		out.append(dir + prefix + str(n).pad_zeros(digits) + ext)
	return out


static func _build_table() -> Dictionary:
	var t := {}
	# The things you do.
	t[&"buy"] = _seq(IFACE, "confirmation_", [1, 2, 3, 4])
	t[&"sell"] = _seq(IFACE, "drop_", [1, 2, 4])
	t[&"error"] = _seq(IFACE, "error_", [1, 2, 3, 5])
	t[&"order_placed"] = _seq(IFACE, "open_", [1, 2, 3, 4])
	t[&"order_cancelled"] = _seq(IFACE, "close_", [1, 2, 3, 4])
	t[&"perk"] = _seq(IFACE, "maximize_", [1, 2, 3])
	t[&"perk_picked"] = _seq(IFACE, "pluck_", [1, 2])
	t[&"margin_call"] = _seq(IFACE, "glitch_", [1, 2, 3, 4])
	# The day.
	t[&"next_day"] = _seq(IFACE, "toggle_", [1, 2, 3, 4])
	t[&"rumor_posted"] = _seq(IFACE, "question_", [1, 2, 3, 4])
	t[&"rumor_resolved"] = [IFACE + "bong_001.ogg"] + _seq(IMPACT, "impactBell_heavy_", [0, 1, 2], 3)
	t[&"win"] = _seq(IFACE, "glass_", [1, 2, 3, 4, 5, 6]) + [DIGI + "powerUp3.ogg", DIGI + "powerUp7.ogg"]
	t[&"lose"] = _seq(IFACE, "scratch_", [1, 2, 3, 4, 5]) + [DIGI + "lowDown.ogg"]
	t[&"reveal_tick"] = _seq(IFACE, "click_", [1, 2, 3, 4, 5]) + _seq(UIA, "click", [1, 2, 3, 4, 5], 1)
	t[&"stamp"] = _seq(IFACE, "drop_", [3, 4]) + _seq(IMPACT, "impactPlate_heavy_", [0, 1, 2], 3) + _seq(IMPACT, "impactWood_heavy_", [0, 1], 3)
	# The arcade picks and the boards.
	t[&"slot_tick"] = _seq(IFACE, "tick_", [1, 2, 4]) + _seq(UIA, "rollover", [1, 2, 3, 4, 5], 1)
	t[&"slot_land"] = _seq(IFACE, "confirmation_", [2, 3, 4]) + _seq(DIGI, "pepSound", [1, 2, 3, 4, 5], 1)
	t[&"chart_tick"] = _seq(IFACE, "select_", [1, 2, 3, 4, 5, 6, 7, 8])
	t[&"board_drop"] = _seq(IMPACT, "impactPlank_medium_", [0, 1, 2, 3, 4], 3) + _seq(IMPACT, "impactWood_heavy_", [2, 3, 4], 3)
	t[&"board_fill"] = _seq(IFACE, "scroll_", [1, 2, 3, 4, 5])
	# The banners of the day.
	t[&"banner_dawn"] = [DIGI + "highUp.ogg"] + _seq(DIGI, "phaserUp", [1, 2, 3], 1)
	t[&"banner_day"] = _seq(IFACE, "maximize_", [4, 5, 6, 7])
	t[&"banner_night"] = [DIGI + "lowDown.ogg"] + _seq(DIGI, "phaserDown", [1, 2, 3], 1)
	t[&"night_card"] = _seq(IMPACT, "impactSoft_medium_", [0, 1, 2, 3, 4], 3)
	t[&"swap_up"] = _seq(DIGI, "phaserUp", [4, 5, 6, 7], 1)
	t[&"swap_down"] = _seq(DIGI, "phaserDown", [1, 2, 3], 1)
	t[&"fanfare"] = _seq(DIGI, "powerUp", [5, 8, 9, 10, 11, 12], 1)
	# One sound family for each skill.
	t[&"skill_tip"] = _seq(DIGI, "phaseJump", [1, 2, 3], 1) + [DIGI + "zapThreeToneUp.ogg"]
	t[&"skill_hodl"] = _seq(DIGI, "powerUp", [1, 2, 4, 6], 1)
	t[&"skill_copy"] = [DIGI + "zap1.ogg", DIGI + "zap2.ogg", DIGI + "zapTwoTone.ogg", DIGI + "zapTwoTone2.ogg"]
	t[&"skill_double"] = _seq(IMPACT, "impactPunch_heavy_", [0, 1, 2, 3, 4], 3)
	t[&"skill_interest"] = _seq(IFACE, "pluck_", [1, 2]) + [DIGI + "twoTone1.ogg", DIGI + "twoTone2.ogg"]
	t[&"skill_bubble"] = _seq(UIA, "rollover", [1, 2, 3, 4, 5], 1)
	t[&"skill_sparkle"] = [DIGI + "threeTone1.ogg", DIGI + "threeTone2.ogg", DIGI + "tone1.ogg"]
	return t


func _ready() -> void:
	for i in POLYPHONY:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for key: StringName in SFX:
		var list: Array = []
		for path: String in SFX[key]:
			if ResourceLoader.exists(path):
				list.append(load(path))
		if not list.is_empty():
			_streams[key] = list
	if is_inside_tree():
		bind_bus(get_node_or_null("/root/EventBus"))


## Connects to an EventBus-shaped node. _ready() passes the autoload; tests pass their own instance.
## Autoloads are looked up by path so this script also compiles outside a running game.
func bind_bus(bus: Node) -> void:
	if bus == null:
		return
	bus.connect("order_filled", _on_order_filled)
	bus.connect("day_advanced", _on_day_advanced)
	bus.connect("draft_offered", _on_draft_offered)
	bus.connect("margin_called", _on_margin_called)
	bus.connect("run_finished", _on_run_finished)
	bus.connect("trade_failed", _on_trade_failed)
	bus.connect("order_placed", _on_order_placed)
	bus.connect("order_cancelled", _on_order_cancelled)
	bus.connect("rumor_posted", _on_rumor_posted)
	bus.connect("rumor_resolved", _on_rumor_resolved)
	bus.connect("perks_changed", _on_perks_changed)
	bus.connect("sfx_requested", play)


## Plays an effect by name. Unknown names and missing files are ignored.
func play(sfx: StringName) -> void:
	played[sfx] = int(played.get(sfx, 0)) + 1
	var list: Array = _streams.get(sfx, [])
	if list.is_empty() or _players.is_empty():
		return
	var index := randi() % list.size()
	if list.size() > 1 and index == int(_last_pick.get(sfx, -1)):
		index = (index + 1 + randi() % (list.size() - 1)) % list.size()
	_last_pick[sfx] = index
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = list[index]
	var jitter: float = float(JITTER.get(sfx, 0.04))
	p.pitch_scale = 1.0 + randf_range(-jitter, jitter)
	p.play()


func _on_order_filled(order: Order, result: TradeResult) -> void:
	if result != null and not result.ok:
		return
	play(&"buy" if order != null and order.side == Order.Dir.BUY else &"sell")


func _on_day_advanced(_day: int) -> void:
	play(&"next_day")


func _on_draft_offered(_options: Array) -> void:
	play(&"perk")


func _on_margin_called() -> void:
	play(&"margin_call")


func _on_run_finished(score: float) -> void:
	var start_cash := 10000.0
	var manager := get_node_or_null("/root/GameManager")
	var session: GameSession = manager.get("session") if manager != null else null
	if session != null and session.config != null and session.config.character != null:
		start_cash = session.config.character.start_cash
	play(&"win" if score >= start_cash else &"lose")


func _on_trade_failed(_reason: String) -> void:
	play(&"error")


func _on_order_placed(_order: Order) -> void:
	play(&"order_placed")


func _on_order_cancelled(_order_id: int) -> void:
	play(&"order_cancelled")


func _on_rumor_posted(_rumor: Rumor) -> void:
	play(&"rumor_posted")


func _on_rumor_resolved(_rumor: Rumor) -> void:
	play(&"rumor_resolved")


func _on_perks_changed() -> void:
	play(&"perk_picked")
