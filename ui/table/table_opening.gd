## The opening of a new table run, about 20 seconds (the rival roll before it is on the character screen, RivalRoll).
## Space skips all of it. The bars at the top and bottom are always there; the screen is built board by board:
##   1 The four players, 3 seconds each: a live 3D character makes a move, then its two skills are stuck on.
##   2 The left board drops in; the arcade pick runs over the 30 companies and the six land in its list.
##   3 The middle board (chart and trade, one board) drops in; the first stock's 30 days are drawn bar by bar.
##   4 The right board drops in, empty; the screen then plays the first news, which is pasted onto it.
## Until its scene the board is hidden: prepare() hides the parts, play() drops them one by one.
class_name TableOpening
extends Control

signal finished

const BG := Color("#14111f")
const GOLD := Color("#e3b341")
const INTRO_TIME := 3.0
const STOCK_TIMES := [0.7, 0.6, 0.5, 0.5, 0.45, 0.45]
const CHART_TIME := 3.6

var _parts: Dictionary = {}
var _skipped: bool = false
var _done: bool = false
var _bg: ColorRect
var _stage: Control
var _hint: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_meta("no_fx", true)
	_hint = GameFmt.label(tr("TABLE_SKIP_HINT"), Color(1, 1, 1, 0.55), 13)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 14)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.z_index = 50
	add_child(_hint)


## Hides what the opening will reveal. `parts`: stock_list, chart_card, chart, trade, feed, the three boards, body.
func prepare(parts: Dictionary) -> void:
	_parts = parts
	TableUi.modal_open = true
	for key in ["board_left", "board_center", "board_right"]:
		(parts[key] as Control).modulate.a = 0.0
	for key in ["chart_card", "trade"]:
		(parts[key] as Control).modulate.a = 0.0
	(parts["chart"] as GamePriceChart).reveal = 0.0
	(parts["stock_list"] as GameStockList).set_rows_hidden(true)
	(parts["feed"] as TableFeed).hide_content()


func _unhandled_input(event: InputEvent) -> void:
	if not _done and event.is_action_pressed("next_day"):
		_skipped = true
		get_viewport().set_input_as_handled()


func _wait(sec: float) -> void:
	var left := sec
	while left > 0.0 and not _skipped:
		await get_tree().process_frame
		left -= get_process_delta_time()


func _is_skipped() -> bool:
	return _skipped


func play() -> void:
	var t := TableUi.session()
	if t == null:
		_finish()
		return
	# The stage covers only the middle of the screen: the top and bottom bars stay in view. (Wait for the layout.)
	await get_tree().process_frame
	await get_tree().process_frame
	var body: Control = _parts["body"]
	_bg = ColorRect.new()
	_bg.color = Color(BG.r, BG.g, BG.b, 0.97)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	move_child(_bg, 0)
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	move_child(_stage, 1)
	for c: Control in [_bg, _stage]:
		c.set_anchors_preset(Control.PRESET_TOP_LEFT)
		c.global_position = body.global_position
		c.size = body.size
	for i in t.seats.size():
		if _skipped:
			break
		await _scene_player(t, i)
	if not _skipped:
		await _fade_out(_bg, 0.3)
	_stage.queue_free()
	_bg.visible = false
	if not _skipped:
		await _scene_stocks(t)
	if not _skipped:
		await _scene_chart()
	if not _skipped:
		await _scene_feed()
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	if _bg != null:
		_bg.queue_free()
	if _stage != null and is_instance_valid(_stage):
		_stage.queue_free()
	for key in ["board_left", "board_center", "board_right", "chart_card", "trade"]:
		if _parts.has(key):
			var c: Control = _parts[key]
			c.modulate.a = 1.0
	if _parts.has("chart"):
		(_parts["chart"] as GamePriceChart).reveal = 1.0
	if _parts.has("stock_list"):
		(_parts["stock_list"] as GameStockList).set_rows_hidden(false)
	for child in get_children():
		if child != _hint:
			child.queue_free()
	_hint.visible = false
	TableUi.modal_open = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A board still in the air is put back by the container.
	(_parts["body"] as Control).queue_sort()
	finished.emit()


## A board is thrown down from behind the top bar: it bounces once on the screen, with a thud and a jolt.
func _drop(board: Control) -> void:
	var rest := board.position
	board.position = Vector2(rest.x, rest.y - board.size.y - 180.0)
	board.modulate.a = 1.0
	var tw := board.create_tween()
	tw.tween_property(board, "position:y", rest.y, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.22).timeout
	TableFx.sfx(&"board_drop")
	var scene := get_tree().current_scene as Control
	if scene != null and not _skipped:
		TableFx.shake(scene, 7.0, 0.3)
	await _wait(0.4)
	if tw.is_running():
		tw.kill()
	board.position = rest


func _fade_out(c: CanvasItem, sec: float) -> void:
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 0.0, sec)
	await tw.finished


func _fade_in(c: CanvasItem, sec: float) -> void:
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, sec)
	await tw.finished


# ---- Scene 1: the four players ----------------------------------------------------------------------------------

func _scene_player(t: TableSession, index: int) -> void:
	for child in _stage.get_children():
		child.queue_free()
	var seat: Seat = t.seats[index]
	var id := String(seat.character.id)
	var key := id.to_upper()
	var column := HBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 30)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(column)
	# Left: the live 3D character.
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.custom_minimum_size = Vector2(340, 420)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(holder)
	var model := CharacterModel.make(id)
	if model != null:
		holder.add_child(CharacterModel.make_viewport(model, Vector2i(340, 420)))
	else:
		holder.add_child(PortraitView.make(id, 14))
	# Right: who it is, then the two skills.
	var text := VBoxContainer.new()
	text.custom_minimum_size = Vector2(500, 0)
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", 12)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(text)
	var who := tr("TABLE_INTRO_PLAYER") % [index + 1, t.seats.size()]
	if index == 0:
		who += "  ·  " + tr("TABLE_INTRO_YOU")
	var tag := GameFmt.label(who, GOLD, 16)
	tag.modulate.a = 0.0
	text.add_child(tag)
	var name_label := GameFmt.label(TableUi.seat_name(seat, self), Color("#f4efe0"), 38)
	name_label.modulate.a = 0.0
	text.add_child(name_label)
	var passive := _skill_panel(tr("TABLE_PASSIVE"), tr("CHAR_%s_PASSIVE" % key))
	var active := _skill_panel(tr("TABLE_ACTIVE"), tr("CHAR_%s_ACTIVE" % key))
	text.add_child(passive)
	text.add_child(active)
	await get_tree().process_frame
	await get_tree().process_frame
	if _skipped:
		return
	# 0.0 the character steps in, 0.45 the name, 1.0 and 1.8 the skills are stuck on, then it holds until 3 seconds.
	holder.pivot_offset = holder.size * 0.5
	holder.scale = Vector2(0.5, 0.5)
	var pop := holder.create_tween()
	pop.tween_property(holder, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	TableFx.sfx(&"slot_land")
	if model != null:
		CharacterModel.introduce(model, id)
	await _wait(0.45)
	if _skipped:
		return
	tag.modulate.a = 1.0
	name_label.modulate.a = 1.0
	TableFx.pop(name_label, 1.5, 0.0)
	await _wait(0.55)
	if _skipped:
		return
	_stick(passive)
	await _wait(0.8)
	if _skipped:
		return
	_stick(active)
	await _wait(INTRO_TIME - 1.8)


func _skill_panel(head: String, body: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"DialogPanel"
	panel.custom_minimum_size = Vector2(500, 0)
	panel.modulate.a = 0.0
	var box := TableUi.column(panel, 2, 10)
	box.add_child(GameFmt.label(head.to_upper(), Color("#c77d0a"), 14))
	box.add_child(TableUi.wrapped(body, Color("#2b2540"), 16))
	return panel


## The skill slaps onto the screen: big and tilted, then it lands.
func _stick(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(1.5, 1.5)
	c.rotation = 0.08
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(c, "rotation", 0.0, 0.2)
	tw.tween_property(c, "modulate:a", 1.0, 0.08)
	TableFx.sfx(&"stamp")


# ---- Scene 2: the stocks ------------------------------------------------------------------------------------------

func _scene_stocks(t: TableSession) -> void:
	var list: GameStockList = _parts["stock_list"]
	await _drop(_parts["board_left"])
	var companies: Array = ContentDb.companies()
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"DialogPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.modulate.a = 0.0
	add_child(panel)
	var box := TableUi.column(panel, 8, 12)
	var head := GameFmt.label(tr("TABLE_INTRO_STOCKS"), Color("#2b2540"), 18)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	var cells: Array = []
	for c: CompanyDef in companies:
		var badge := CompanyBadge.make(c.icon, 46, c.sector)
		grid.add_child(badge)
		cells.append(badge)
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_in(panel, 0.25)
	var roller := SlotPick.make_frame(Color("#e3524f"), 5)
	add_child(roller)
	roller.visible = false
	var open: Array = range(cells.size())
	var symbols: Array[String] = t.market.symbols()
	for n in symbols.size():
		if _skipped:
			break
		var target := -1
		for i in companies.size():
			if (companies[i] as CompanyDef).symbol == symbols[n]:
				target = i
		if target < 0:
			continue
		await SlotPick.run(self, roller, cells, open, target, STOCK_TIMES[mini(n, STOCK_TIMES.size() - 1)], _is_skipped)
		open.erase(target)
		(cells[target] as Control).modulate = Color(0.35, 0.35, 0.4, 1.0)
		_fly_to_list(cells[target], companies[target], list, symbols[n])
		await _wait(0.1)
	roller.visible = false
	await _wait(0.45)
	if is_instance_valid(panel):
		await _fade_out(panel, 0.25)
		panel.queue_free()
	roller.queue_free()


## A copy of the badge flies from the pick into its row, which then lights up.
func _fly_to_list(cell: Control, company: CompanyDef, list: GameStockList, symbol: String) -> void:
	var clone := CompanyBadge.make(company.icon, 46, company.sector)
	clone.size = cell.size
	add_child(clone)
	clone.global_position = cell.global_position
	var row := list.row_button(symbol)
	var target := row.global_position + Vector2(8, (row.size.y - 46.0) * 0.5)
	var tw := clone.create_tween()
	tw.tween_property(clone, "global_position", target, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		clone.queue_free()
		list.reveal_row(symbol)
		TableFx.sfx(&"stamp"))


# ---- Scenes 3 and 4: chart, feed ------------------------------------------------------------------------------

func _scene_chart() -> void:
	var chart: GamePriceChart = _parts["chart"]
	var card: Control = _parts["chart_card"]
	await _drop(_parts["board_center"])
	TableFx.sfx(&"board_fill")
	await _fade_in(card, 0.25)
	var bars: int = maxi(1, TableUi.session().market.history_of(chart.symbol).size())
	var last := [0]
	var tw := chart.create_tween()
	tw.tween_method(func(v: float) -> void:
		chart.reveal = v
		var step := int(v * float(bars) / 2.0)
		if step != last[0]:
			last[0] = step
			TableFx.sfx(&"chart_tick"), 0.0, 1.0, CHART_TIME).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	while tw.is_running() and not _skipped:
		await get_tree().process_frame
	tw.kill()
	chart.reveal = 1.0
	TableFx.sfx(&"slot_land")
	_fade_in(_parts["trade"], 0.3)
	await _wait(0.35)


## The right board is thrown down empty; the screen then plays the first news and pastes it on.
func _scene_feed() -> void:
	await _drop(_parts["board_right"])
