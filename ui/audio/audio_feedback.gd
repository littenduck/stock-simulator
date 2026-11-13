## Plays sound effects in reaction to EventBus signals. Instanced once inside game_screen.tscn.
## Does not decide anything about the game; a missing audio file is silently skipped.
## Web note: browsers keep the audio context suspended until the first user input. Godot's web
## runtime resumes it on the first click/key, and the player always clicks before any sound
## is triggered (menu -> run setup -> game), so no extra unlock code is needed. See tools/release/web-audio.md.
extends Node

const IFACE := "res://audio/kenney_interface-sounds/Audio/"
const IMPACT := "res://audio/kenney_impact-sounds/Audio/"
## Event -> file. All effects come from Kenney "Interface Sounds" so the style stays consistent.
## The other Kenney packs in audio/ are bundled unused for now (see CREDITS.md).
const SFX: Dictionary = {
	&"buy": IFACE + "confirmation_001.ogg",
	&"sell": IFACE + "drop_001.ogg",
	&"next_day": IFACE + "toggle_001.ogg",
	&"perk": IFACE + "maximize_001.ogg",
	&"perk_picked": IFACE + "pluck_001.ogg",
	&"margin_call": IFACE + "glitch_001.ogg",
	&"error": IFACE + "error_001.ogg",
	&"win": IFACE + "glass_001.ogg",
	&"lose": IFACE + "scratch_001.ogg",
	&"order_placed": IFACE + "open_001.ogg",
	&"order_cancelled": IFACE + "close_001.ogg",
	&"rumor_posted": IFACE + "question_001.ogg",
	&"rumor_resolved": IFACE + "bong_001.ogg",
	&"reveal_tick": IFACE + "click_003.ogg",
	&"stamp": IFACE + "drop_003.ogg",
	&"slot_tick": IFACE + "tick_001.ogg",
	&"slot_land": IFACE + "confirmation_002.ogg",
	&"chart_tick": IFACE + "tick_002.ogg",
	&"board_drop": IMPACT + "impactPlank_medium_000.ogg",
	&"board_fill": IFACE + "scroll_001.ogg",
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
		var path: String = SFX[key]
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
	bus.connect("order_placed", _on_order_placed)
	bus.connect("order_cancelled", _on_order_cancelled)
	bus.connect("rumor_posted", _on_rumor_posted)
	bus.connect("rumor_resolved", _on_rumor_resolved)
	bus.connect("perks_changed", _on_perks_changed)
	bus.connect("sfx_requested", play)


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
