## The card that pops up every time a rumor is dealt: a tall playing card with the stock, what is going to happen,
## how likely it is, and three big choices that say what they cost and what they can win.
## Today's rumor and the quarter's Boss rumor use the same card. Q / W / E choose, Esc decides later (that means PASS).
class_name RumorCard
extends Control

signal closed(boss: bool)

const SIDE_COLORS := {RumorTier.Side.BELIEVE: Color("#3fb950"), RumorTier.Side.BULLSHIT: Color("#e5484d"), RumorTier.Side.PASS: Color("#8b949e")}
const PAPER := Color("#f6edd9")
const INK := Color("#2b2540")

var _boss: bool = false
var _panel: PanelContainer
var _body: VBoxContainer
var _type_tween: Tween
var _open: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(390, 0)
	var card := StyleBoxFlat.new()
	card.bg_color = PAPER
	card.border_color = INK
	card.set_border_width_all(5)
	card.set_corner_radius_all(18)
	card.shadow_color = Color(0, 0, 0, 0.45)
	card.shadow_size = 14
	card.content_margin_left = 16
	card.content_margin_right = 16
	card.content_margin_top = 14
	card.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", card)
	_panel.set_meta("no_fx", true)
	center.add_child(_panel)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	_panel.add_child(_body)
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


## The card is dealt onto the table: it spins in from small and a bit tilted, and overshoots.
func _pop_in() -> void:
	await get_tree().process_frame
	if not _open:
		return
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.1, 0.1)
	_panel.rotation = -0.5
	_panel.modulate.a = 0.0
	var tw := _panel.create_tween().set_parallel(true)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.12)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build(t: TableSession, rumor: TableRumor) -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	var seat := t.human()
	var blind := seat.has_flag(&"goldfish")
	# Ribbon across the top.
	var ribbon := PanelContainer.new()
	ribbon.set_meta("no_fx", true)
	var rb := StyleBoxFlat.new()
	rb.bg_color = Color("#cf534f") if _boss else Color("#e3b341")
	rb.set_corner_radius_all(8)
	rb.content_margin_top = 4
	rb.content_margin_bottom = 4
	ribbon.add_theme_stylebox_override("panel", rb)
	var title := (tr("TABLE_BOSS_TITLE") % maxi(rumor.resolve_day - t.day, 1)) if _boss else (tr("TABLE_CARD_TODAY") % t.day)
	var ribbon_label := GameFmt.label(title, Color.WHITE if _boss else INK, 15)
	ribbon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ribbon.add_child(ribbon_label)
	_body.add_child(ribbon)
	_body.add_child(_hero(t, rumor))
	_body.add_child(_rule())
	var headline := TableUi.wrapped(rumor.headline(tr, t.market), INK, 20)
	headline.custom_minimum_size = Vector2(0, 84)
	_body.add_child(headline)
	if _type_tween != null and _type_tween.is_valid():
		_type_tween.kill()
	headline.visible_ratio = 0.0
	_type_tween = create_tween()
	_type_tween.tween_property(headline, "visible_ratio", 1.0, clampf(headline.text.length() * 0.012, 0.35, 0.9))
	_body.add_child(_rule())
	_body.add_child(_chance(rumor, blind))
	var stake := t.premium_for(0, _boss)
	var current := int(t.boss_calls.get(0, RumorTier.Side.PASS)) if _boss else t.call_of(0)
	var chosen := t.boss_calls.has(0) if _boss else t.calls.has(0)
	for side in [RumorTier.Side.BELIEVE, RumorTier.Side.BULLSHIT, RumorTier.Side.PASS]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("no_fx", false)
		b.text = _option_text(t, rumor, side, stake, blind)
		b.custom_minimum_size = Vector2(0, 66)
		b.toggle_mode = true
		b.set_pressed_no_signal(current == side and chosen)
		_style_option(b, SIDE_COLORS[side])
		b.pressed.connect(_choose.bind(side))
		_body.add_child(b)
	var rate := TableSession.BOSS_RATE if _boss else TableSession.DAILY_RATE
	var note := tr("TABLE_STAKE_NONE") if stake <= 0.0 else tr("TABLE_STAKE") % [GameFmt.money(stake, 0), roundi(rate * 100.0)]
	var note_label := GameFmt.label(note, Color("#6b6578"), 12)
	note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(note_label)
	if seat.has_flag(&"copilot") and not _boss:
		var copy_label := GameFmt.label(tr("TABLE_CARD_COPY"), Color("#a06a00"), 13)
		copy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_body.add_child(copy_label)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		for other in t.seats:
			if other.id == 0 or not other.alive:
				continue
			var cb := GameFmt.button(TableUi.seat_name(other, self))
			cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cb.toggle_mode = true
			cb.set_pressed_no_signal(int(t.copy_targets.get(0, -1)) == other.id)
			cb.pressed.connect(_copy.bind(other.id))
			row.add_child(cb)
		_body.add_child(row)
	var hint := GameFmt.label(tr("TABLE_CARD_HINT"), Color("#6b6578"), 11)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(hint)


## Company badge and name on the left, price and what the rumor claims on the right.
func _hero(t: TableSession, rumor: TableRumor) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var company := t.market.company_of(rumor.primary_symbol())
	var badge := CompanyBadge.make("star" if _boss else (company.icon if company != null else ""), 56, "" if _boss else (company.sector if company != null else ""))
	row.add_child(badge)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _boss:
		col.add_child(GameFmt.label(tr("TABLE_CARD_BOSS_HEAD"), INK, 22))
		col.add_child(GameFmt.label(tr("TABLE_CARD_AFFECTS") % ", ".join(rumor.symbols.slice(0, 4)), Color("#6b6578"), 13))
	else:
		col.add_child(GameFmt.label(rumor.primary_symbol(), INK, 22))
		col.add_child(GameFmt.label(tr(company.display_name) if company != null else "", Color("#6b6578"), 13))
		var claim := tr("TABLE_CARD_CLAIM_UP") if rumor.claim_dir > 0 else tr("TABLE_CARD_CLAIM_DOWN")
		col.add_child(GameFmt.label("%s  ·  %s" % [GameFmt.money(t.market.price_of(rumor.primary_symbol())), claim], INK, 14))
	row.add_child(col)
	return row


func _rule() -> Control:
	var rule := ColorRect.new()
	rule.color = Color(0.17, 0.15, 0.25, 0.25)
	rule.custom_minimum_size = Vector2(0, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


## A big percentage with the bar filling up under it.
func _chance(rumor: TableRumor, blind: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	if blind:
		var unknown := GameFmt.label(tr("TABLE_CRED_HIDDEN"), Color("#6b6578"), 18)
		unknown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(unknown)
		return box
	var chance := RumorTier.truth_chance(rumor.tier)
	var color := TableUi.tier_color(rumor.tier)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 10)
	var big := GameFmt.label("0%", color, 44)
	head.add_child(big)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 0)
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	side.add_child(GameFmt.label(tr("TABLE_CARD_CHANCE_SHORT"), Color("#6b6578"), 13))
	side.add_child(GameFmt.label(TableUi.tier_text(rumor.tier, self), color, 16))
	head.add_child(side)
	box.add_child(head)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 0.0
	bar.custom_minimum_size = Vector2(0, 14)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(6)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.15)
	back.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	box.add_child(bar)
	var tw := bar.create_tween().set_parallel(true)
	tw.tween_property(bar, "value", chance * 100.0, 0.8).set_delay(0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: big.text = "%d%%" % roundi(v), 0.0, chance * 100.0, 0.8).set_delay(0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return box


## "BELIEVE" and under it what it is: the option, its odds, what you pay now and what you get if you are right.
func _option_text(t: TableSession, rumor: TableRumor, side: int, stake: float, blind: bool) -> String:
	var title := tr(TableUi.side_key(side))
	if side == RumorTier.Side.PASS:
		return title + "\n" + tr("TABLE_CARD_PASS_OPTION")
	var kind := tr("TABLE_BUY_CALL") if side == RumorTier.Side.BELIEVE else tr("TABLE_BUY_PUT")
	if blind:
		return title + "\n" + tr("TABLE_CARD_OPTION_BLIND") % [kind, GameFmt.money(stake, 0)]
	var odds := t.odds_for(t.human(), rumor, side)
	return title + "\n" + tr("TABLE_CARD_OPTION") % [kind, odds, GameFmt.money(stake, 0), GameFmt.money(stake * odds, 0)]


func _style_option(b: Button, color: Color) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		if state == "focus":
			b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
			continue
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		if state == "pressed" or state == "hover_pressed":
			sb.bg_color = color.darkened(0.12)
			sb.border_color = Color.WHITE
			sb.set_border_width_all(4)
		else:
			sb.bg_color = color.lightened(0.1) if state == "hover" else color
			sb.border_color = color.darkened(0.4)
			sb.border_width_bottom = 5
		b.add_theme_stylebox_override(state, sb)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, Color.WHITE)
	b.add_theme_font_size_override("font_size", 15)


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
	tw.tween_property(_panel, "modulate:a", 0.0, 0.16)
	tw.tween_property(_panel, "scale", Vector2(0.8, 0.8), 0.16)
	tw.tween_property(_panel, "rotation", 0.12, 0.16)
	await tw.finished
	hide()
	GameManager.table_refresh()
	closed.emit(_boss)


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("next_day"):
		get_viewport().set_input_as_handled()
		TableFx.jolt(_panel, 1.05)     # first choose, then reveal
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
