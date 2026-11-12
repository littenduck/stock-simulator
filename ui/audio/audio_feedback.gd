## Plays sound effects in reaction to EventBus signals. Instanced once inside game_screen.tscn.
## Does not decide anything about the game; a missing audio file is silently skipped.
## Web note: browsers keep the audio context suspended until the first user input. Godot's web
## runtime resumes it on the first click/key, and the player always clicks before any sound
## is triggered (menu -> run setup -> game), so no extra unlock code is needed. See docs/release/web-audio.md.
extends Node

const SFX_DIR := "res://audio/"
const SFX: Dictionary = {
	&"buy": "buy.wav",
	&"sell": "sell.wav",
	&"next_day": "next_day.wav",
	&"perk": "perk.wav",
	&"margin_call": "margin_call.wav",
	&"error": "error.wav",
	&"win": "win.wav",
	&"lose": "lose.wav",
}
const POLYPHONY := 4

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
## Counts plays per effect; tests read it (also works with a headless audio driver).
var played: Dictionary = {}


func _ready() -> void:
	for i in POLYPHONY:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for key: StringName in SFX:
		var path: String = SFX_DIR + String(SFX[key])
		if ResourceLoader.exists(path):
			_streams[key] = load(path)
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


## Plays an effect by name. Unknown names and missing files are ignored.
func play(sfx: StringName) -> void:
	played[sfx] = int(played.get(sfx, 0)) + 1
	var stream: AudioStream = _streams.get(sfx)
	if stream == null or _players.is_empty():
		return
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = stream
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
