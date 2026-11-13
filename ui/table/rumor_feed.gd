## The right column: the rumor feed, like the classic screen's rumor window. Newest first: the Boss rumor (pinned while
## it is open), today's rumor with the call you made, then every rumor that has resolved with its stamp and your result.
class_name TableFeed
extends PanelContainer

const SHOWN := 30
const CARD_BG := Color("#e9e1cb")

var _list: VBoxContainer
## True while the board is only a frame (the opening): the first rumor is pasted on with reveal_content().
var content_hidden: bool = false


func _ready() -> void:
	var box := TableUi.column(self, 4)
	box.add_child(GameFmt.label(tr("TABLE_FEED_TITLE"), GameColors.MUTED, 13))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	EventBus.table_resolved.connect(func(_r: TableReport) -> void: _refresh())
	EventBus.table_changed.connect(_refresh)
	EventBus.table_revealed.connect(func(_e: Array) -> void: _refresh())
	EventBus.day_advanced.connect(func(_d: int) -> void: _refresh())
	_refresh()


func _refresh() -> void:
	var t := TableUi.session()
	if t == null or _list == null:
		return
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	if t.boss_rumor != null:
		_list.add_child(_boss_entry(t))
	if t.today_rumor != null and not t.is_finished():
		_list.add_child(_today_entry(t))
	var count := 0
	for i in range(t.history.size() - 1, -1, -1):
		_list.add_child(_history_entry(t, t.history[i]))
		count += 1
		if count >= SHOWN:
			break
	if t.history.is_empty() and t.today_rumor == null:
		_list.add_child(TableUi.wrapped(tr("TABLE_LOG_EMPTY"), GameColors.MUTED, 13))


## The board arrives empty; the contents are hidden until reveal_content().
func hide_content() -> void:
	content_hidden = true
	if get_child_count() > 0:
		(get_child(0) as CanvasItem).modulate.a = 0.0


## The first rumor is pasted onto the board: its card slaps down and the title appears.
func reveal_content() -> void:
	if not content_hidden:
		return
	content_hidden = false
	if get_child_count() > 0:
		(get_child(0) as CanvasItem).modulate.a = 1.0
	if _list != null and _list.get_child_count() > 0:
		var entry := _list.get_child(0) as Control
		entry.pivot_offset = entry.size * 0.5
		entry.scale = Vector2(1.35, 1.35)
		var tw := entry.create_tween()
		tw.tween_property(entry, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	TableFx.sfx(&"stamp")


## A feed card with a coloured edge; returns the column inside it.
func _card(accent: Color) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.set_meta("no_fx", true)
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD_BG
	sb.border_color = accent
	sb.border_width_left = 4
	sb.content_margin_left = 10
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	panel.add_child(col)
	col.set_meta("panel", panel)
	return col


func _panel_of(col: VBoxContainer) -> Control:
	return col.get_meta("panel") as Control


func _call_text(_t: TableSession, side: int) -> String:
	return tr(TableUi.side_key(side))


## Today's rumor: click the card, or the blue Choose button under it, to open the choice card.
func _today_entry(t: TableSession) -> Control:
	var rumor := t.today_rumor
	var decided := t.calls.has(0) or t.copy_targets.has(0)
	var col := _card(GameColors.GOLD)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	if not decided:
		head.add_child(GameFmt.label(tr("TABLE_FEED_NEW"), Color("#cf534f"), 13))
	head.add_child(GameFmt.label(tr("TABLE_FEED_TODAY") % t.day, GameColors.GOLD, 13))
	head.add_child(GameFmt.label(tr("TABLE_FEED_RESOLVES"), GameColors.MUTED, 12))
	col.add_child(head)
	col.add_child(TableUi.wrapped(rumor.headline(tr, t.market), Color.WHITE, 14))
	col.add_child(_tier_line(t, rumor))
	var side := t.call_of(0)
	var text := ""
	var color := GameColors.MUTED
	if t.copy_targets.has(0):
		text = tr("TABLE_COPYING") % TableUi.seat_name(t.seats[int(t.copy_targets[0])], self)
		color = GameColors.GOLD
	elif not t.calls.has(0):
		text = tr("TABLE_FEED_NO_CALL")
	else:
		text = tr("TABLE_FEED_CALL") % _call_text(t, side)
		color = TableUi.side_color(side)
	col.add_child(TableUi.wrapped(text, color, 14))
	var panel := _panel_of(col)
	if t.phase == TableSession.Phase.ACTION and TableUi.current_step == 1 and t.human().alive:
		col.add_child(_blue_button(tr("TABLE_FEED_CHANGE") if decided else tr("TABLE_FEED_CHOOSE"), false))
		_make_clickable(panel, false)
	return panel


func _boss_entry(t: TableSession) -> Control:
	var boss := t.boss_rumor
	var col := _card(Color("#e3b341"))
	col.add_child(GameFmt.label(tr("TABLE_BOSS_TITLE") % maxi(boss.resolve_day - t.day, 1), GameColors.GOLD, 13))
	col.add_child(TableUi.wrapped(boss.headline(tr, t.market), Color.WHITE, 14))
	col.add_child(_tier_line(t, boss))
	var placed := t.boss_bet_of(0)
	var panel := _panel_of(col)
	if placed != null:
		col.add_child(TableUi.wrapped(tr("TABLE_BOSS_BET") % [tr(TableUi.side_key(placed.side)), GameFmt.money(placed.premium, 0)], TableUi.side_color(placed.side), 14))
		return panel
	var chosen := t.boss_calls.has(0)
	var side := int(t.boss_calls.get(0, RumorTier.Side.PASS))
	col.add_child(TableUi.wrapped(tr("TABLE_FEED_CALL") % _call_text(t, side) if chosen else tr("TABLE_FEED_NO_CALL"), TableUi.side_color(side) if chosen else GameColors.MUTED, 14))
	if t.phase == TableSession.Phase.ACTION and TableUi.current_step == 1 and t.human().alive:
		col.add_child(_blue_button(tr("TABLE_FEED_CHANGE") if chosen else tr("TABLE_FEED_CHOOSE"), true))
		_make_clickable(panel, true)
	return panel


## A big blue button across the card: the thing to press.
func _blue_button(text: String, boss: bool) -> Button:
	var b := GameFmt.button(text)
	b.custom_minimum_size = Vector2(0, 40)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(func() -> void: EventBus.rumor_card_requested.emit(boss))
	return b


func _make_clickable(panel: Control, boss: bool) -> void:
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			EventBus.rumor_card_requested.emit(boss))


func _tier_line(t: TableSession, rumor: TableRumor) -> Control:
	if t.human().has_flag(&"goldfish"):
		return GameFmt.label(tr("TABLE_CRED_HIDDEN"), GameColors.MUTED, 12)
	return GameFmt.label(tr("TABLE_CRED") % TableUi.tier_text(rumor.tier, self), TableUi.tier_color(rumor.tier), 12)


func _history_entry(t: TableSession, h: Dictionary) -> Control:
	var rumor := TableRumor.from_dict(h["rumor"])
	var accent := GameColors.UP if rumor.came_true else GameColors.DOWN
	var col := _card(accent)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(GameFmt.label(tr("TABLE_LOG_DAY") % rumor.visible_day, GameColors.MUTED, 12))
	head.add_child(GameFmt.label(tr("TABLE_CONFIRMED") if rumor.came_true else tr("TABLE_DEBUNKED"), accent, 13))
	if rumor.planted:
		head.add_child(GameFmt.label(tr("TABLE_PLANTED"), TableFx.PLANTED_COLOR, 12))
	if rumor.is_boss():
		head.add_child(GameFmt.label(tr("TABLE_BOSS_TAG"), GameColors.GOLD, 12))
	col.add_child(head)
	col.add_child(TableUi.wrapped(rumor.headline(tr, t.market), Color.WHITE, 13))
	var net := float(h["net"])
	var side := int(h["side"])
	var result := tr("TABLE_NO_BET")
	var result_color := GameColors.MUTED
	if side != RumorTier.Side.PASS:
		result = "%s  ·  %s" % [tr(TableUi.side_key(side)), (tr("TABLE_YOU_WON") if net > 0.0 else tr("TABLE_YOU_LOST")) % GameFmt.money(absf(net), 0)]
		result_color = GameColors.UP if net > 0.0 else GameColors.DOWN
	var blind := t.human().has_flag(&"goldfish")
	var tier := "" if blind else RumorTier.label(rumor.tier, tr) + "  ·  "
	col.add_child(GameFmt.label(tier + result, result_color, 12))
	return _panel_of(col)
