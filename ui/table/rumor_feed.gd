## The right column: the rumor feed, like the classic screen's rumor window. Newest first: the Boss rumor (pinned while
## it is open), today's rumor with the call you made, then every rumor that has resolved with its stamp and your result.
class_name TableFeed
extends PanelContainer

const SHOWN := 30
const CARD_BG := Color("#e9e1cb")

var _list: VBoxContainer


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


## A feed card with a coloured edge; returns the column inside it.
func _card(accent: Color) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.set_meta("no_fx", true)
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD_BG
	sb.border_color = accent
	sb.border_width_left = 4
	sb.set_corner_radius_all(6)
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


func _today_entry(t: TableSession) -> Control:
	var rumor := t.today_rumor
	var col := _card(GameColors.GOLD)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(GameFmt.label(tr("TABLE_FEED_TODAY") % t.day, GameColors.GOLD, 13))
	head.add_child(GameFmt.label(tr("TABLE_FEED_RESOLVES"), GameColors.MUTED, 12))
	col.add_child(head)
	col.add_child(TableUi.wrapped(rumor.headline(tr, t.market), Color.WHITE, 14))
	col.add_child(_tier_line(t, rumor))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var copying := t.copy_targets.has(0)
	var side := t.call_of(0)
	var text := ""
	var color := GameColors.MUTED
	if copying:
		text = tr("TABLE_COPYING") % TableUi.seat_name(t.seats[int(t.copy_targets[0])], self)
		color = GameColors.GOLD
	elif side == RumorTier.Side.PASS and not t.calls.has(0):
		text = tr("TABLE_FEED_NO_CALL")
	else:
		text = tr("TABLE_FEED_CALL") % _call_text(t, side)
		color = TableUi.side_color(side)
	var label := TableUi.wrapped(text, color, 14)
	row.add_child(label)
	if t.phase == TableSession.Phase.ACTION and t.human().alive:
		var change := GameFmt.button(tr("TABLE_FEED_CHANGE") if t.calls.has(0) or copying else tr("TABLE_FEED_CHOOSE"))
		change.pressed.connect(func() -> void: EventBus.rumor_card_requested.emit(false))
		row.add_child(change)
	col.add_child(row)
	return _panel_of(col)


func _boss_entry(t: TableSession) -> Control:
	var boss := t.boss_rumor
	var col := _card(Color("#e3b341"))
	col.add_child(GameFmt.label(tr("TABLE_BOSS_TITLE") % maxi(boss.resolve_day - t.day, 1), GameColors.GOLD, 13))
	col.add_child(TableUi.wrapped(boss.headline(tr, t.market), Color.WHITE, 14))
	col.add_child(_tier_line(t, boss))
	var placed := t.boss_bet_of(0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	if placed != null:
		row.add_child(TableUi.wrapped(tr("TABLE_BOSS_BET") % [tr(TableUi.side_key(placed.side)), GameFmt.money(placed.premium, 0)], TableUi.side_color(placed.side), 14))
	else:
		var chosen := int(t.boss_calls.get(0, RumorTier.Side.PASS))
		var text := tr("TABLE_FEED_CALL") % _call_text(t, chosen) if t.boss_calls.has(0) else tr("TABLE_FEED_NO_CALL")
		row.add_child(TableUi.wrapped(text, TableUi.side_color(chosen) if t.boss_calls.has(0) else GameColors.MUTED, 14))
		if t.phase == TableSession.Phase.ACTION and t.human().alive:
			var open := GameFmt.button(tr("TABLE_FEED_OPEN"))
			open.pressed.connect(func() -> void: EventBus.rumor_card_requested.emit(true))
			row.add_child(open)
	col.add_child(row)
	return _panel_of(col)


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
