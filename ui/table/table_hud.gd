## Today's rumor and the BELIEVE / BULLSHIT / PASS buttons (it replaces the old order form).
## Calls stay hidden from the others until the reveal. Boss rumor, skills and the log are separate widgets.
class_name TableHud
extends PanelContainer

var _headline: Label
var _tier_line: Label
var _know_line: Label
var _buttons: Dictionary = {}     ## side -> Button
var _stake_line: Label
var _last_rumor_id: int = -1
var _type_tween: Tween


func _ready() -> void:
	var box := TableUi.column(self, 5)
	box.add_child(GameFmt.label(tr("TABLE_RUMOR_TODAY"), GameColors.MUTED, 13))
	_headline = TableUi.wrapped("", Color.WHITE, 16)
	box.add_child(_headline)
	_tier_line = GameFmt.label("", Color.WHITE, 14)
	box.add_child(_tier_line)
	_know_line = TableUi.wrapped("", GameColors.GOLD, 13)
	box.add_child(_know_line)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for side in [RumorTier.Side.BELIEVE, RumorTier.Side.BULLSHIT, RumorTier.Side.PASS]:
		var b := GameFmt.button("")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 54)
		b.toggle_mode = true
		b.pressed.connect(_choose.bind(side))
		row.add_child(b)
		_buttons[side] = b
	box.add_child(row)
	_stake_line = TableUi.wrapped("", GameColors.MUTED, 12)
	box.add_child(_stake_line)
	EventBus.table_changed.connect(_refresh)
	EventBus.day_advanced.connect(func(_d: int) -> void: _refresh())
	EventBus.portfolio_changed.connect(_refresh)
	EventBus.table_revealed.connect(func(_e: Array) -> void: _refresh())
	_refresh()


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
		_choose(side)
		get_viewport().set_input_as_handled()


func _choose(side: int) -> void:
	var t := TableUi.session()
	if t == null:
		return
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
	if rumor.id != _last_rumor_id:
		_announce(_last_rumor_id >= 0)
		_last_rumor_id = rumor.id
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
		b.text = _button_text(side, rumor, blind, t, seat)
	var stake := t.premium_for(0)
	if copying:
		var target := t.seats[int(t.copy_targets[0])]
		_stake_line.text = tr("TABLE_COPYING") % TableUi.seat_name(target, self)
	elif stake <= 0.0:
		_stake_line.text = tr("TABLE_STAKE_NONE")
	else:
		_stake_line.text = tr("TABLE_STAKE") % [GameFmt.money(stake, 0), roundi(TableSession.DAILY_RATE * 100.0)] + "   " + tr("TABLE_KEYS_SHORT")


## A new rumor types itself out and the credibility line fades in behind it.
func _announce(with_sound: bool) -> void:
	if _type_tween != null and _type_tween.is_valid():
		_type_tween.kill()
	_headline.visible_ratio = 0.0
	_tier_line.modulate.a = 0.0
	_type_tween = create_tween()
	_type_tween.tween_property(_headline, "visible_ratio", 1.0, clampf(_headline.text.length() * 0.014, 0.4, 0.95))
	_type_tween.tween_property(_tier_line, "modulate:a", 1.0, 0.25)
	if with_sound:
		TableFx.sfx(&"rumor_posted")


func _button_text(side: int, rumor: TableRumor, blind: bool, t: TableSession, seat: Seat) -> String:
	var title := tr(TableUi.side_key(side))
	if side == RumorTier.Side.PASS:
		return title + "\n" + tr("TABLE_PASS_SUB")
	var kind := tr("TABLE_CALL") if side == RumorTier.Side.BELIEVE else tr("TABLE_PUT")
	if blind:
		return title + "\n" + kind
	return "%s\n%s x%.2f" % [title, kind, t.odds_for(seat, rumor, side)]
