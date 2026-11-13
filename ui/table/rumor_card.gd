## The card that pops up every time a rumor is dealt: what is going to happen, how likely it is, and the three choices.
## Today's rumor and the quarter's Boss rumor use the same card. Q / W / E choose, Esc decides later (that means PASS).
class_name RumorCard
extends Control

signal closed(boss: bool)

var _boss: bool = false
var _panel: PanelContainer
var _body: VBoxContainer
var _type_tween: Tween
var _open: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"DialogPanel"
	_panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(_panel)
	_body = TableUi.column(_panel, 10, 14)
	hide()
	EventBus.rumor_card_requested.connect(open)


func is_open() -> bool:
	return _open


## Shows the card for today's rumor, or for the Boss rumor.
func open(boss: bool = false) -> void:
	var t := TableUi.session()
	if t == null or t.phase != TableSession.Phase.ACTION or t.is_finished() or not t.human().alive:
		return
	var rumor := t.boss_rumor if boss else t.today_rumor
	if rumor == null or (boss and t.boss_bet_of(0) != null):
		return
	_boss = boss
	_build(t, rumor)
	_open = true
	show()
	TableFx.sfx(&"rumor_posted")
	_pop_in()


func _pop_in() -> void:
	await get_tree().process_frame
	if not _open:
		return
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.25, 0.25)
	_panel.rotation = -0.2
	_panel.modulate.a = 0.0
	var tw := _panel.create_tween().set_parallel(true)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.15)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "rotation", 0.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build(t: TableSession, rumor: TableRumor) -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	var seat := t.human()
	var blind := seat.has_flag(&"goldfish")
	var title := (tr("TABLE_BOSS_TITLE") % maxi(rumor.resolve_day - t.day, 1)) if _boss else (tr("TABLE_CARD_TODAY") % t.day)
	_body.add_child(GameFmt.label(title, GameColors.GOLD, 15))
	var headline := TableUi.wrapped(rumor.headline(tr, t.market), Color.WHITE, 22)
	_body.add_child(headline)
	if _type_tween != null and _type_tween.is_valid():
		_type_tween.kill()
	headline.visible_ratio = 0.0
	_type_tween = create_tween()
	_type_tween.tween_property(headline, "visible_ratio", 1.0, clampf(headline.text.length() * 0.012, 0.35, 0.9))
	_body.add_child(GameFmt.label(_about(t, rumor), GameColors.MUTED, 14))
	_body.add_child(_chance_row(rumor, blind))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	var current := int(t.boss_calls.get(0, RumorTier.Side.PASS)) if _boss else t.call_of(0)
	for side in [RumorTier.Side.BELIEVE, RumorTier.Side.BULLSHIT, RumorTier.Side.PASS]:
		var b := GameFmt.button(_button_text(t, rumor, side, blind))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 80)
		b.toggle_mode = true
		b.set_pressed_no_signal(current == side and (t.calls.has(0) or t.boss_calls.has(0)))
		b.pressed.connect(_choose.bind(side))
		buttons.add_child(b)
	_body.add_child(buttons)
	var stake := t.premium_for(0, _boss)
	var rate := TableSession.BOSS_RATE if _boss else TableSession.DAILY_RATE
	_body.add_child(GameFmt.label(tr("TABLE_STAKE_NONE") if stake <= 0.0 else tr("TABLE_STAKE") % [GameFmt.money(stake, 0), roundi(rate * 100.0)], GameColors.MUTED, 13))
	if seat.has_flag(&"copilot") and not _boss:
		_body.add_child(GameFmt.label(tr("TABLE_CARD_COPY"), GameColors.GOLD, 13))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		for other in t.seats:
			if other.id == 0 or not other.alive:
				continue
			var cb := GameFmt.button(TableUi.seat_name(other, self))
			cb.toggle_mode = true
			cb.set_pressed_no_signal(int(t.copy_targets.get(0, -1)) == other.id)
			cb.pressed.connect(_copy.bind(other.id))
			row.add_child(cb)
		_body.add_child(row)
	_body.add_child(GameFmt.label(tr("TABLE_CARD_HINT"), GameColors.MUTED, 12))


func _about(t: TableSession, rumor: TableRumor) -> String:
	if _boss:
		return tr("TABLE_CARD_AFFECTS") % ", ".join(rumor.symbols.slice(0, 5))
	var company := t.market.company_of(rumor.primary_symbol())
	var company_name := tr(company.display_name) if company != null else ""
	return "%s  %s   ·   %s   %s" % [rumor.primary_symbol(), company_name, GameFmt.money(t.market.price_of(rumor.primary_symbol())), _arrow(t, rumor)]


func _arrow(_t: TableSession, rumor: TableRumor) -> String:
	return tr("TABLE_CARD_CLAIM_UP") if rumor.claim_dir > 0 else tr("TABLE_CARD_CLAIM_DOWN")


func _chance_row(rumor: TableRumor, blind: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	if blind:
		row.add_child(GameFmt.label(tr("TABLE_CRED_HIDDEN"), GameColors.MUTED, 15))
		return row
	var chance := RumorTier.truth_chance(rumor.tier)
	var color := TableUi.tier_color(rumor.tier)
	row.add_child(GameFmt.label(tr("TABLE_CARD_CHANCE") % roundi(chance * 100.0), color, 16))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 0.0
	bar.custom_minimum_size = Vector2(200, 16)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.18)
	back.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	row.add_child(bar)
	row.add_child(GameFmt.label(TableUi.tier_text(rumor.tier, self), color, 14))
	bar.create_tween().tween_property(bar, "value", chance * 100.0, 0.7).set_delay(0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return row


func _button_text(t: TableSession, rumor: TableRumor, side: int, blind: bool) -> String:
	var title := tr(TableUi.side_key(side))
	if side == RumorTier.Side.PASS:
		return title + "\n" + tr("TABLE_PASS_SUB")
	var kind := tr("TABLE_CALL") if side == RumorTier.Side.BELIEVE else tr("TABLE_PUT")
	if blind:
		return title + "\n" + kind
	return "%s\n%s x%.2f" % [title, kind, t.odds_for(t.human(), rumor, side)]


func _choose(side: int) -> void:
	var t := TableUi.session()
	if t == null:
		return
	if _boss:
		t.set_boss_call(side)
	else:
		t.set_call(side)
	TableFx.sfx(&"reveal_tick")
	close()


func _copy(seat_id: int) -> void:
	var t := TableUi.session()
	if t != null:
		t.set_copy_target(seat_id)
	TableFx.sfx(&"reveal_tick")
	close()


func close() -> void:
	if not _open:
		return
	_open = false
	var tw := _panel.create_tween().set_parallel(true)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.14)
	tw.tween_property(_panel, "scale", Vector2(0.88, 0.88), 0.14)
	await tw.finished
	hide()
	GameManager.table_refresh()
	closed.emit(_boss)


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("next_day"):
		get_viewport().set_input_as_handled()
		TableFx.jolt(_panel, 1.03)     # first choose, then reveal
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var side := -1
		match (event as InputEventKey).keycode:
			KEY_Q:
				side = RumorTier.Side.BELIEVE
			KEY_W:
				side = RumorTier.Side.BULLSHIT
			KEY_E:
				side = RumorTier.Side.PASS
		if side >= 0:
			get_viewport().set_input_as_handled()
			_choose(side)
