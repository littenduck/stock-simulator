## The heart of the table screen: today's rumor, the BELIEVE / BULLSHIT / PASS buttons, the Boss rumor
## and the skill of your character. Calls stay hidden from the others until the reveal.
class_name TableHud
extends PanelContainer

var _headline: Label
var _tier_line: Label
var _know_line: Label
var _buttons: Dictionary = {}     ## side -> Button
var _stake_line: Label
var _boss_box: VBoxContainer
var _boss_title: Label
var _boss_headline: Label
var _boss_tier: Label
var _boss_buttons: Dictionary = {}
var _boss_stake: Label
var _skill_box: VBoxContainer


func _ready() -> void:
	var box := TableUi.column(self, 6)
	box.add_child(GameFmt.label(tr("TABLE_RUMOR_TODAY"), GameColors.MUTED, 13))
	_headline = TableUi.wrapped("", Color.WHITE, 18)
	box.add_child(_headline)
	_tier_line = GameFmt.label("", Color.WHITE, 15)
	box.add_child(_tier_line)
	_know_line = TableUi.wrapped("", GameColors.GOLD, 14)
	box.add_child(_know_line)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for side in [RumorTier.Side.BELIEVE, RumorTier.Side.BULLSHIT, RumorTier.Side.PASS]:
		var b := GameFmt.button("")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 58)
		b.toggle_mode = true
		b.pressed.connect(_choose.bind(side, false))
		row.add_child(b)
		_buttons[side] = b
	box.add_child(row)
	_stake_line = TableUi.wrapped("", GameColors.MUTED, 13)
	box.add_child(_stake_line)
	box.add_child(TableUi.wrapped(tr("TABLE_KEYS_HINT"), GameColors.MUTED, 11))
	_boss_box = VBoxContainer.new()
	_boss_box.add_theme_constant_override("separation", 4)
	box.add_child(_boss_box)
	_build_boss()
	_skill_box = VBoxContainer.new()
	_skill_box.add_theme_constant_override("separation", 4)
	box.add_child(_skill_box)
	EventBus.table_changed.connect(_refresh)
	EventBus.day_advanced.connect(func(_d: int) -> void: _refresh())
	EventBus.portfolio_changed.connect(_refresh)
	EventBus.table_revealed.connect(func(_e: Array) -> void: _refresh())
	_refresh()


func _build_boss() -> void:
	var rule := ColorRect.new()
	rule.color = Color(1, 1, 1, 0.12)
	rule.custom_minimum_size = Vector2(0, 2)
	_boss_box.add_child(rule)
	_boss_title = GameFmt.label("", GameColors.GOLD, 14)
	_boss_box.add_child(_boss_title)
	_boss_headline = TableUi.wrapped("", Color.WHITE, 16)
	_boss_box.add_child(_boss_headline)
	_boss_tier = GameFmt.label("", Color.WHITE, 14)
	_boss_box.add_child(_boss_tier)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for side in [RumorTier.Side.BELIEVE, RumorTier.Side.BULLSHIT, RumorTier.Side.PASS]:
		var b := GameFmt.button("")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.pressed.connect(_choose.bind(side, true))
		row.add_child(b)
		_boss_buttons[side] = b
	_boss_box.add_child(row)
	_boss_stake = TableUi.wrapped("", GameColors.MUTED, 13)
	_boss_box.add_child(_boss_stake)


func _unhandled_key_input(event: InputEvent) -> void:
	var t := TableUi.session()
	if t == null or t.phase != TableSession.Phase.ACTION or GameManager.state != GameManager.State.PLAYING:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var side := -1
	match (event as InputEventKey).keycode:
		KEY_Q:
			side = RumorTier.Side.BELIEVE
		KEY_W:
			side = RumorTier.Side.BULLSHIT
		KEY_E:
			side = RumorTier.Side.PASS
	if side >= 0:
		_choose(side, false)
		get_viewport().set_input_as_handled()


func _choose(side: int, boss: bool) -> void:
	var t := TableUi.session()
	if t == null:
		return
	if boss:
		t.set_boss_call(side)
	else:
		t.set_call(side)
	GameManager.table_refresh()


func _refresh() -> void:
	var t := TableUi.session()
	if t == null or t.today_rumor == null or _headline == null:
		return
	var seat := t.human()
	var rumor := t.today_rumor
	var blind := seat.has_flag(&"goldfish")
	var open := t.phase == TableSession.Phase.ACTION and seat.alive and not t.is_finished()
	_headline.text = rumor.headline(tr, t.market)
	var stock := "%s  %s" % [rumor.primary_symbol(), GameFmt.money(t.market.price_of(rumor.primary_symbol()))]
	_tier_line.text = stock + "   ·   " + (tr("TABLE_CRED_HIDDEN") if blind else tr("TABLE_CRED") % TableUi.tier_text(rumor.tier, self))
	GameFmt.tint(_tier_line, Color.WHITE if blind else TableUi.tier_color(rumor.tier))
	_know_line.text = ""
	if seat.knowledge.has(rumor.id):
		_know_line.text = tr("TABLE_KNOW_TRUE") if bool(seat.knowledge[rumor.id]) else tr("TABLE_KNOW_FALSE")
	var copying := t.copy_targets.has(0)
	var current := t.call_of(0)
	for side in _buttons:
		var b: Button = _buttons[side]
		b.disabled = not open or copying
		b.set_pressed_no_signal(current == side and not copying)
		b.text = _button_text(side, rumor, blind, t, seat, "Q" if side == RumorTier.Side.BELIEVE else ("W" if side == RumorTier.Side.BULLSHIT else "E"))
	var stake := t.premium_for(0)
	if copying:
		var target := t.seats[int(t.copy_targets[0])]
		_stake_line.text = tr("TABLE_COPYING") % TableUi.seat_name(target, self)
	elif stake <= 0.0:
		_stake_line.text = tr("TABLE_STAKE_NONE")
	else:
		_stake_line.text = tr("TABLE_STAKE") % [GameFmt.money(stake, 0), roundi(TableSession.DAILY_RATE * 100.0)]
	_refresh_boss(t, open, blind)
	_refresh_skills(t, open)


func _button_text(side: int, rumor: TableRumor, blind: bool, t: TableSession, seat: Seat, key: String) -> String:
	var title := tr(TableUi.side_key(side))
	if side == RumorTier.Side.PASS:
		return title + "\n" + tr("TABLE_PASS_SUB")
	var kind := tr("TABLE_CALL") if side == RumorTier.Side.BELIEVE else tr("TABLE_PUT")
	if blind:
		return title + "\n" + kind
	return "%s\n%s x%.2f" % [title, kind, t.odds_for(seat, rumor, side)]


func _refresh_boss(t: TableSession, open: bool, blind: bool) -> void:
	var boss := t.boss_rumor
	_boss_box.visible = boss != null
	if boss == null:
		return
	var seat := t.human()
	_boss_title.text = tr("TABLE_BOSS_TITLE") % maxi(boss.resolve_day - t.day, 1)
	_boss_headline.text = boss.headline(tr, t.market)
	_boss_tier.text = tr("TABLE_CRED_HIDDEN") if blind else tr("TABLE_CRED") % TableUi.tier_text(boss.tier, self)
	GameFmt.tint(_boss_tier, Color.WHITE if blind else TableUi.tier_color(boss.tier))
	var placed := t.boss_bet_of(0)
	var chosen := int(t.boss_calls.get(0, RumorTier.Side.PASS))
	for side in _boss_buttons:
		var b: Button = _boss_buttons[side]
		b.disabled = not open or placed != null
		b.set_pressed_no_signal((placed.side if placed != null else chosen) == side)
		var text := tr(TableUi.side_key(side))
		if side != RumorTier.Side.PASS and not blind:
			text += "  x%.2f" % t.odds_for(seat, boss, side)
		b.text = text
	if placed != null:
		_boss_stake.text = tr("TABLE_BOSS_BET") % [tr(TableUi.side_key(placed.side)), GameFmt.money(placed.premium, 0)]
	else:
		_boss_stake.text = tr("TABLE_BOSS_STAKE") % [GameFmt.money(t.premium_for(0, true), 0), roundi(TableSession.BOSS_RATE * 100.0)]


func _refresh_skills(t: TableSession, open: bool) -> void:
	for child in _skill_box.get_children():
		_skill_box.remove_child(child)
		child.queue_free()
	var seat := t.human()
	if seat.has_flag(&"copilot"):
		_skill_box.add_child(GameFmt.label(tr("TABLE_COPILOT"), GameColors.GOLD, 14))
		var pick := OptionButton.new()
		pick.focus_mode = Control.FOCUS_NONE
		pick.disabled = not open
		pick.add_item(tr("TABLE_COPY_NONE"))
		pick.set_item_metadata(0, -1)
		var selected := 0
		for other in t.seats:
			if other.id == 0 or not other.alive:
				continue
			pick.add_item(TableUi.seat_name(other, self))
			pick.set_item_metadata(pick.item_count - 1, other.id)
			if int(t.copy_targets.get(0, -1)) == other.id:
				selected = pick.item_count - 1
		pick.select(selected)
		pick.item_selected.connect(func(index: int) -> void:
			t.set_copy_target(int(pick.get_item_metadata(index)))
			GameManager.table_refresh())
		_skill_box.add_child(pick)
	elif seat.has_flag(&"insider"):
		var hint := t.insider_hint()
		if hint != null:
			_skill_box.add_child(GameFmt.label(tr("TABLE_INSIDER_HINT"), GameColors.GOLD, 14))
			_skill_box.add_child(TableUi.wrapped(hint.headline(tr, t.market), Color.WHITE, 15))
			var flip := CheckButton.new()
			flip.text = tr("TABLE_FLIP")
			flip.focus_mode = Control.FOCUS_NONE
			flip.disabled = not open
			flip.button_pressed = bool(t.flip_armed.get(0, false))
			flip.toggled.connect(func(on: bool) -> void:
				t.arm_flip(on)
				GameManager.table_refresh())
			_skill_box.add_child(flip)
			_skill_box.add_child(TableUi.wrapped(tr("TABLE_FLIP_HINT"), GameColors.MUTED, 12))
		else:
			var used := seat.skill_used
			_skill_box.add_child(TableUi.wrapped(tr("TABLE_FLIP_USED") if used else tr("TABLE_NO_HINT"), GameColors.MUTED, 13))
	elif seat.has_flag(&"double_down"):
		var state := tr("TABLE_DAN_USED") if seat.skill_used else tr("TABLE_DAN_HINT")
		_skill_box.add_child(TableUi.wrapped(state, GameColors.GOLD, 13))
