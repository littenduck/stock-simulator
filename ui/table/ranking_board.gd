## The board at the end of a quarter, in the manner of a party game: the four players sit in last quarter's order, their
## net worth rolls to the new value, and then they swap places one pair at a time, the climber hopping up as the other
## drops down. A new leader gets the crown. Space (or a click) closes it.
class_name RankingBoard
extends Control

signal finished

const ROW_H := 82.0
const ROW_W := 560.0
const MEDALS := [Color("#ffd23f"), Color("#c9d1d9"), Color("#d08a4a"), Color("#8d8a94")]

var _session: TableSession
## Last quarter's standings: [{"seat": id, "net": float}] in rank order.
var _prev: Array = []
var _quarter: int = 1
var _rows: Dictionary = {}
var _order: Array[int] = []
var _frame: PanelContainer
var _track: Control
var _skipped: bool = false
var _age: float = 0.0
var _crown: Control


## Plays the board and returns when it is closed. `prev` is the standings of the quarter before (see _prev).
static func play(host: Control, session: TableSession, prev: Array, quarter: int) -> void:
	var board := RankingBoard.new()
	board._session = session
	board._prev = prev
	board._quarter = quarter
	host.add_child(board)
	await board.finished
	board.queue_free()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_meta("no_fx", true)
	z_index = 55
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	create_tween().tween_property(dim, "color:a", 0.62, 0.3)
	_frame = PanelContainer.new()
	_frame.set_meta("no_fx", true)
	_frame.set_anchors_preset(Control.PRESET_CENTER)
	_frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_frame.grow_vertical = Control.GROW_DIRECTION_BOTH
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#1b1830")
	sb.border_color = Color("#f4efe0")
	sb.set_border_width_all(4)
	_frame.add_theme_stylebox_override("panel", sb)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	_frame.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)
	var title := GameFmt.label(tr("TABLE_BOARD_TITLE") % _quarter, Color("#e3b341"), 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_track = Control.new()
	_track.custom_minimum_size = Vector2(ROW_W, ROW_H * 4.0)
	_track.clip_contents = false
	col.add_child(_track)
	var hint := GameFmt.label(" ", Color(1, 1, 1, 0.8), 15)
	hint.name = "Hint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)
	add_child(_frame)
	_frame.modulate.a = 0.0
	_run()


func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = event.is_action_pressed("next_day") or event.is_action_pressed("ui_accept") \
			or (event is InputEventMouseButton and event.pressed)
	if pressed:
		_skipped = true
		get_viewport().set_input_as_handled()


func _wait(sec: float) -> void:
	var left := sec
	while left > 0.0 and not _skipped:
		await get_tree().process_frame
		left -= get_process_delta_time()


func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_frame.pivot_offset = _frame.size * 0.5
	_frame.scale = Vector2(0.6, 0.6)
	var pop := create_tween().set_parallel(true)
	pop.tween_property(_frame, "modulate:a", 1.0, 0.15)
	pop.tween_property(_frame, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	TableFx.sfx(&"order_placed")
	# The four rows drop in, in last quarter's order.
	var new_net: Dictionary = {}
	for e in _session.standings():
		new_net[(e["seat"] as Seat).id] = float(e["net_worth"])
	var prev_net: Dictionary = {}
	if _prev.is_empty():
		for e in _session.standings():
			_prev.append({"seat": (e["seat"] as Seat).id, "net": float(e["net_worth"])})
	for p in _prev:
		prev_net[int(p["seat"])] = float(p["net"])
		_order.append(int(p["seat"]))
	for i in _order.size():
		var id: int = _order[i]
		var row := _make_row(id, i, float(prev_net[id]))
		_track.add_child(row)
		_rows[id] = row
		row.position = Vector2(0, i * ROW_H - 260.0)
		row.modulate.a = 0.0
		var drop := row.create_tween().set_parallel(true)
		drop.tween_property(row, "position:y", i * ROW_H, 0.4).set_delay(0.12 * i).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		drop.tween_property(row, "modulate:a", 1.0, 0.1).set_delay(0.12 * i)
		get_tree().create_timer(0.12 * i + 0.2).timeout.connect(func() -> void: TableFx.sfx(&"board_drop"))
	await _wait(0.12 * 3 + 0.6)
	# The net worth rolls to its new value, with what changed beside it.
	for id in _order:
		var row: Control = _rows[id]
		var net: Label = row.find_child("Net", true, false)
		var delta: Label = row.find_child("Delta", true, false)
		var from := float(prev_net[id])
		var to := float(new_net.get(id, from))
		var roll := create_tween()
		roll.tween_method(func(v: float) -> void: net.text = GameFmt.money(v, 0), from, to, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		delta.text = ("+" if to >= from else "-") + GameFmt.money(absf(to - from), 0)
		GameFmt.tint(delta, GameColors.UP if to >= from else GameColors.DOWN)
		delta.modulate.a = 0.0
		delta.create_tween().tween_property(delta, "modulate:a", 1.0, 0.3).set_delay(0.9)
	TableFx.sfx(&"reveal_tick")
	await _wait(1.5)
	# Then they change places, one pair at a time.
	var target: Array[int] = []
	for e in _session.standings():
		target.append((e["seat"] as Seat).id)
	var old_leader := _order[0]
	for i in target.size():
		while _order[i] != target[i]:
			var j := _order.find(target[i])
			await _swap(j - 1, j)
			if _skipped:
				break
		if _skipped:
			break
	_settle_positions()
	await _wait(0.2)
	if _order[0] != old_leader:
		_crown_the_leader()
	var hint: Label = _frame.find_child("Hint", true, false)
	hint.text = tr("TABLE_SKILL_CONTINUE")
	_skipped = false
	var waited := 0.0
	while not _skipped:
		await get_tree().process_frame
		waited += get_process_delta_time()
		hint.modulate.a = 0.55 + 0.45 * absf(sin(waited * 4.0))
		if waited < 0.5:
			_skipped = false
	var out := create_tween().set_parallel(true)
	out.tween_property(_frame, "modulate:a", 0.0, 0.25)
	await out.finished
	finished.emit()


func _make_row(seat_id: int, slot: int, net_worth: float) -> Control:
	var seat := _session.seats[seat_id]
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"DialogPanel"
	panel.custom_minimum_size = Vector2(ROW_W, ROW_H - 8.0)
	panel.size = Vector2(ROW_W, ROW_H - 8.0)
	panel.set_meta("no_fx", true)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var rank := GameFmt.label("%d" % (slot + 1), MEDALS[mini(slot, 3)], 40)
	rank.name = "Rank"
	rank.custom_minimum_size = Vector2(40, 0)
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(rank)
	row.add_child(PortraitView.make(String(seat.character.id), 3.5))
	var name_label := GameFmt.label(TableUi.seat_name(seat, self) + ("  (" + tr("TABLE_YOU") + ")" if seat.is_human else ""), Color("#2b2540"), 18)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var col := VBoxContainer.new()
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	var net := GameFmt.label(GameFmt.money(net_worth, 0), Color("#2b2540"), 22)
	net.name = "Net"
	net.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	net.custom_minimum_size = Vector2(130, 0)
	col.add_child(net)
	var delta := GameFmt.label(" ", GameColors.MUTED, 15)
	delta.name = "Delta"
	delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(delta)
	return panel


## Two neighbours change places: the one below climbs (a hop and a rising chime), the one above drops.
func _swap(upper: int, lower: int) -> void:
	var climber: Control = _rows[_order[lower]]
	var faller: Control = _rows[_order[upper]]
	var tmp := _order[upper]
	_order[upper] = _order[lower]
	_order[lower] = tmp
	climber.z_index = 3
	var up := climber.create_tween().set_parallel(true)
	up.tween_property(climber, "position:y", upper * ROW_H, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	up.tween_property(climber, "scale", Vector2(1.06, 1.06), 0.2)
	up.chain().tween_property(climber, "scale", Vector2.ONE, 0.2)
	var down := faller.create_tween()
	down.tween_property(faller, "position:y", lower * ROW_H, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	TableFx.sfx(&"swap_up")
	get_tree().create_timer(0.2).timeout.connect(func() -> void: TableFx.sfx(&"swap_down"))
	_refresh_ranks()
	await _wait(0.55)
	climber.z_index = 0


func _refresh_ranks() -> void:
	for i in _order.size():
		var label: Label = (_rows[_order[i]] as Control).find_child("Rank", true, false)
		label.text = "%d" % (i + 1)
		GameFmt.tint(label, MEDALS[mini(i, 3)])


func _settle_positions() -> void:
	for i in _order.size():
		var row: Control = _rows[_order[i]]
		row.position = Vector2(0, i * ROW_H)
		row.scale = Vector2.ONE
		row.modulate.a = 1.0
		var net: Label = row.find_child("Net", true, false)
		net.text = GameFmt.money(_net_of(_order[i]), 0)
		var delta: Label = row.find_child("Delta", true, false)
		delta.modulate.a = 1.0
	_refresh_ranks()


func _net_of(seat_id: int) -> float:
	for e in _session.standings():
		if (e["seat"] as Seat).id == seat_id:
			return float(e["net_worth"])
	return 0.0


## A crown drops onto the new leader, with confetti and a fanfare.
func _crown_the_leader() -> void:
	var row: Control = _rows[_order[0]]
	_crown = _PixelCrown.new()
	_crown.custom_minimum_size = Vector2(64, 40)
	_crown.size = Vector2(64, 40)
	_track.add_child(_crown)
	_crown.position = Vector2(ROW_W - 90.0, -90.0)
	var tw := _crown.create_tween()
	tw.tween_property(_crown, "position:y", -34.0, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	TableFx.sfx(&"fanfare")
	TableFx.confetti(self, _track.global_position + Vector2(ROW_W * 0.5, 40.0), 80, 0.0)
	TableFx.jolt(row, 1.08)


class _PixelCrown extends Control:
	func _draw() -> void:
		var gold := Color("#ffd23f")
		var dark := Color("#b8860b")
		draw_rect(Rect2(4, 20, 56, 16), gold)
		for x in [4, 26, 48]:
			draw_rect(Rect2(x, 4, 12, 20), gold)
		draw_rect(Rect2(4, 30, 56, 6), dark)
		for x in [10, 32, 54]:
			draw_rect(Rect2(x - 2, 0, 6, 6), Color("#e3524f"))
