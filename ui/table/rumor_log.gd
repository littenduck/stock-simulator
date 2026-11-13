## Every rumor that has resolved, newest first: day, verdict stamp, the headline and what it did to you.
## This is the rumor window of the old screen, back at the bottom right.
class_name RumorLog
extends PanelContainer

const SHOWN := 30

var _list: VBoxContainer


func _ready() -> void:
	var box := TableUi.column(self, 4)
	box.add_child(GameFmt.label(tr("TABLE_LOG_TITLE"), GameColors.MUTED, 13))
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
	_refresh()


func _refresh() -> void:
	var t := TableUi.session()
	if t == null or _list == null:
		return
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	if t.history.is_empty():
		_list.add_child(TableUi.wrapped(tr("TABLE_LOG_EMPTY"), GameColors.MUTED, 13))
		return
	var count := 0
	for i in range(t.history.size() - 1, -1, -1):
		_list.add_child(_entry(t, t.history[i]))
		count += 1
		if count >= SHOWN:
			break


func _entry(t: TableSession, h: Dictionary) -> Control:
	var rumor := TableRumor.from_dict(h["rumor"])
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(GameFmt.label(tr("TABLE_LOG_DAY") % rumor.visible_day, GameColors.MUTED, 12))
	head.add_child(GameFmt.label(tr("TABLE_CONFIRMED") if rumor.came_true else tr("TABLE_DEBUNKED"), GameColors.UP if rumor.came_true else GameColors.DOWN, 13))
	if rumor.planted:
		head.add_child(GameFmt.label(tr("TABLE_PLANTED"), Color("#b57bee"), 12))
	if rumor.is_boss():
		head.add_child(GameFmt.label(tr("TABLE_BOSS_TAG"), GameColors.GOLD, 12))
	box.add_child(head)
	box.add_child(TableUi.wrapped(rumor.headline(tr, t.market), Color.WHITE, 13))
	var net := float(h["net"])
	var side := int(h["side"])
	var result := tr("TABLE_NO_BET")
	var result_color := GameColors.MUTED
	if side != RumorTier.Side.PASS:
		result = (tr("TABLE_YOU_WON") if net > 0.0 else tr("TABLE_YOU_LOST")) % GameFmt.money(absf(net), 0)
		result_color = GameColors.UP if net > 0.0 else GameColors.DOWN
	var blind := t.human().has_flag(&"goldfish")
	var tier := "" if blind else RumorTier.label(rumor.tier, tr) + "  ·  "
	box.add_child(GameFmt.label(tier + result, result_color, 12))
	return box
