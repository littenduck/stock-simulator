## The opening of a new table run, in five short scenes (about 25 seconds, Space skips all of it):
##   1 The rivals: a frame runs over the six characters like an arcade pick and lands on three of them.
##   2 The four players, 3 seconds each: a live 3D character makes a move, then its two skills are stuck on.
##   3 The stocks: the same pick over all 30 companies; each of the six lands in the left list.
##   4 The chart: the first stock's last 30 days are drawn bar by bar, fast and then slower.
##   5 The feed and the turn bar appear, and the first news comes in (the screen plays that itself afterwards).
## Until its scene the screen is kept hidden: prepare() hides the parts, play() reveals them one by one.
class_name TableOpening
extends Control

signal finished

const ROSTER := ["saving_son", "double_dan", "hodl_hana", "goldfish_gus", "copilot_cody", "insider_inu"]
const BG := Color("#14111f")
const GOLD := Color("#e3b341")
const YOU_GREEN := Color("#3fb950")
const INTRO_TIME := 3.0
const RIVAL_TIMES := [0.9, 0.7, 0.6]
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


## Hides what the opening will reveal. `parts`: stock_list, chart_card, chart, trade, feed, turn_bar.
func prepare(parts: Dictionary) -> void:
	_parts = parts
	TableUi.modal_open = true
	for key in ["chart_card", "trade", "feed", "turn_bar"]:
		(parts[key] as Control).modulate.a = 0.0
	(parts["chart"] as GamePriceChart).reveal = 0.0
	(parts["stock_list"] as GameStockList).set_rows_hidden(true)


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
	_bg = ColorRect.new()
	_bg.color = Color(BG.r, BG.g, BG.b, 0.97)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	move_child(_bg, 0)
	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	move_child(_stage, 1)
	await _scene_rivals(t)
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
	for key in ["chart_card", "trade", "feed", "turn_bar"]:
		if _parts.has(key):
			(_parts[key] as Control).modulate.a = 1.0
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
	finished.emit()


func _fade_out(c: CanvasItem, sec: float) -> void:
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 0.0, sec)
	await tw.finished


func _fade_in(c: CanvasItem, sec: float) -> void:
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, sec)
	await tw.finished


# ---- Scene 1: the rivals --------------------------------------------------------------------------------------

func _character_card(id: String, number: int) -> PanelContainer:
	var def := ContentDb.character_by_id(StringName(id))
	var card := PanelContainer.new()
	card.theme_type_variation = &"DialogPanel"
	card.custom_minimum_size = Vector2(150, 200)
	var box := TableUi.column(card, 4, 8)
	var no := GameFmt.label("%02d" % number, Color("#5d5870"), 14)
	no.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(no)
	var portrait := PortraitView.make(id, 6)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(portrait)
	var name_label := GameFmt.label(tr(def.title_key), Color("#2b2540"), 15)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	var tag := GameFmt.label(" ", GOLD, 15)
	tag.name = "Tag"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tag)
	return card


func _scene_rivals(t: TableSession) -> void:
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 26)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(column)
	var title := GameFmt.label(tr("TABLE_INTRO_RIVALS"), GOLD, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	var cards: Array = []
	for i in ROSTER.size():
		var card := _character_card(ROSTER[i], i + 1)
		card.modulate.a = 0.0
		row.add_child(card)
		cards.append(card)
	await get_tree().process_frame
	await get_tree().process_frame
	for i in cards.size():
		if _skipped:
			return
		var card: Control = cards[i]
		card.modulate.a = 1.0
		TableFx.pop(card, 0.6, 0.0)
		TableFx.sfx(&"reveal_tick")
		await _wait(0.06)
	# You are already seated.
	var you_index: int = ROSTER.find(String(t.seats[0].character.id))
	_mark(cards[you_index], tr("TABLE_INTRO_YOU"), YOU_GREEN, true)
	var open: Array = []
	for i in cards.size():
		if i != you_index:
			open.append(i)
	await _wait(0.2)
	var roller := SlotPick.make_frame(Color.WHITE, 6)
	_stage.add_child(roller)
	roller.visible = false
	for n in range(1, 4):
		if _skipped:
			return
		var target: int = ROSTER.find(String(t.seats[n].character.id))
		await SlotPick.run(self, roller, cards, open, target, RIVAL_TIMES[n - 1], _is_skipped)
		open.erase(target)
		_mark(cards[target], tr("TABLE_INTRO_RIVAL") % n, GOLD, false)
		TableFx.pop(cards[target], 1.18, 0.0)
		await _wait(0.12)
	roller.visible = false
	for i in open:
		(cards[i] as Control).modulate = Color(0.45, 0.45, 0.5, 1.0)
	await _wait(0.35)


## A solid frame and a tag under the card: who sits there.
func _mark(card: Control, text: String, color: Color, mine: bool) -> void:
	var tag: Label = card.find_child("Tag", true, false)
	tag.text = text
	GameFmt.tint(tag, color if not mine else Color("#2f9e44"))
	var frame := SlotPick.make_frame(color, 5)
	_stage.add_child(frame)
	frame.global_position = card.global_position - Vector2(5, 5)
	frame.size = card.size + Vector2(10, 10)


# ---- Scene 2: the four players ----------------------------------------------------------------------------------

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


# ---- Scene 3: the stocks ------------------------------------------------------------------------------------------

func _scene_stocks(t: TableSession) -> void:
	var list: GameStockList = _parts["stock_list"]
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


# ---- Scenes 4 and 5: chart, feed ------------------------------------------------------------------------------

func _scene_chart() -> void:
	var chart: GamePriceChart = _parts["chart"]
	var card: Control = _parts["chart_card"]
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


func _scene_feed() -> void:
	_fade_in(_parts["turn_bar"], 0.3)
	await _fade_in(_parts["feed"], 0.3)
