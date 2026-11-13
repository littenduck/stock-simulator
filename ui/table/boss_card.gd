## The Boss rumor of the quarter (bet window: the three days before the quarter ends), as one compact row:
## the rumor on the left, its three buttons on the right. Hidden when there is none.
class_name BossCard
extends PanelContainer

var _title: Label
var _headline: Label
var _buttons: Dictionary = {}


func _ready() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	_title = TableUi.wrapped("", GameColors.GOLD, 13)
	left.add_child(_title)
	_headline = TableUi.wrapped("", Color.WHITE, 14)
	left.add_child(_headline)
	for side in [RumorTier.Side.BELIEVE, RumorTier.Side.BULLSHIT, RumorTier.Side.PASS]:
		var b := GameFmt.button("")
		b.toggle_mode = true
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(_choose.bind(side))
		row.add_child(b)
		_buttons[side] = b
	EventBus.table_changed.connect(_refresh)
	EventBus.day_advanced.connect(func(_d: int) -> void: _refresh())
	EventBus.portfolio_changed.connect(_refresh)
	EventBus.table_revealed.connect(func(_e: Array) -> void: _refresh())
	_refresh()


func _choose(side: int) -> void:
	var t := TableUi.session()
	if t != null:
		t.set_boss_call(side)
		GameManager.table_refresh()


func _refresh() -> void:
	var t := TableUi.session()
	if t == null or _title == null:
		return
	var boss := t.boss_rumor
	var was_visible := visible
	visible = boss != null
	if boss == null:
		return
	if not was_visible:
		UiFx.bounce_in(self)
		TableFx.flash(get_tree().current_scene, GameColors.GOLD, 0.16, 0.5)
		TableFx.sfx(&"perk")
	var seat := t.human()
	var blind := seat.has_flag(&"goldfish")
	var open := t.phase == TableSession.Phase.ACTION and seat.alive and not t.is_finished()
	var tier := tr("TABLE_CRED_HIDDEN") if blind else tr("TABLE_CRED") % TableUi.tier_text(boss.tier, self)
	var placed := t.boss_bet_of(0)
	var stake := (tr("TABLE_BOSS_BET") % [tr(TableUi.side_key(placed.side)), GameFmt.money(placed.premium, 0)]) if placed != null \
			else (tr("TABLE_BOSS_STAKE") % [GameFmt.money(t.premium_for(0, true), 0), roundi(TableSession.BOSS_RATE * 100.0)])
	_title.text = (tr("TABLE_BOSS_TITLE") % maxi(boss.resolve_day - t.day, 1)) + "   ·   " + tier + "   ·   " + stake
	_headline.text = boss.headline(tr, t.market)
	var chosen := int(t.boss_calls.get(0, RumorTier.Side.PASS))
	for side in _buttons:
		var b: Button = _buttons[side]
		b.disabled = not open or placed != null
		b.set_pressed_no_signal((placed.side if placed != null else chosen) == side)
		var text := tr(TableUi.side_key(side))
		if side != RumorTier.Side.PASS and not blind:
			text += "\nx%.2f" % t.odds_for(seat, boss, side)
		b.text = text
