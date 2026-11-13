## Day, cash, net worth, return, Next Day and Menu buttons. Read-only apart from the two commands.
class_name GameTopBar
extends PanelContainer

signal menu_requested

## Font size of the net worth value (hero numbers in the Robinhood-style skins).
@export var hero_size: int = 22
@export var value_size: int = 22

var _day: Label
var _cash: Label
var _net_worth: Label
var _return: GameDelta
var _alert: Label
var _next_day: Button
var _alert_day: int = -1


func _ready() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	add_child(row)

	_day = GameFmt.label("", Color.WHITE, 24)
	_day.custom_minimum_size = Vector2(250, 0)
	_day.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_day)
	_cash = _stat(row, "UI_GAME_CASH", value_size) as Label
	_net_worth = _stat(row, "UI_GAME_NET_WORTH", hero_size) as Label
	_return = _stat(row, "UI_GAME_RETURN", value_size, true) as GameDelta

	_alert = GameFmt.label("", GameColors.DOWN, 16)
	# Wraps instead of widening the bar: a long alert used to push the whole screen out of the window.
	_alert.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_alert.custom_minimum_size = Vector2(60, 0)
	_alert.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_alert.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_alert)

	_next_day = GameFmt.button(tr("UI_GAME_NEXT_DAY") + "  [Space]")
	_next_day.name = "NextDayButton"
	_next_day.theme_type_variation = &"PrimaryButton"
	_next_day.custom_minimum_size = Vector2(170, 44)
	_next_day.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_next_day.pressed.connect(_on_next_day_pressed)
	row.add_child(_next_day)
	var menu := GameFmt.button(tr("UI_GAME_MENU") + "  [Esc]")
	menu.custom_minimum_size = Vector2(110, 44)
	menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	menu.pressed.connect(func() -> void: menu_requested.emit())
	row.add_child(menu)

	EventBus.day_advanced.connect(_on_day_advanced)
	EventBus.prices_updated.connect(_on_prices_updated)
	EventBus.portfolio_changed.connect(_on_portfolio_changed)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.margin_called.connect(_on_margin_called)
	_refresh()


## Caption above a big value; returns the value label.
func _stat(parent: Control, caption_key: String, size: int, delta: bool = false) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.add_child(GameFmt.label(tr(caption_key), GameColors.MUTED, 13))
	var value: Control = GameDelta.new(size) if delta else GameFmt.label("", Color.WHITE, size)
	box.add_child(value)
	parent.add_child(box)
	return value


func _refresh() -> void:
	var s: GameSession = GameManager.session
	if s == null:
		return
	var date: String = ChartMath.long_date(s.date_of_day(s.day))
	if date != "":
		_day.text = tr("UI_GAME_DAY_DATE") % [s.day, RunConfig.TRADING_DAYS, date]
	else:
		_day.text = tr("UI_GAME_DAY_ONLY") % [s.day, RunConfig.TRADING_DAYS]
	UiFx.count_label(_cash, s.portfolio.cash, _money, GameColors.DOWN if s.portfolio.cash < 0.0 else Color.WHITE)
	var nw: float = s.net_worth()
	UiFx.count_label(_net_worth, nw, _money)
	var start: float = s.config.character.start_cash if s.config != null and s.config.character != null else nw
	var ret: float = nw / start - 1.0 if start > 0.0 else 0.0
	_return.show_change(ret)
	if s.day != _alert_day:
		_alert.text = ""
	var blocked: bool = GameManager.state == GameManager.State.DRAFTING or GameManager.state == GameManager.State.GAME_OVER
	_next_day.disabled = blocked or s.is_finished()
	_next_day.text = (tr("UI_GAME_FINAL_DAY") if s.day == RunConfig.TRADING_DAYS - 1 else tr("UI_GAME_NEXT_DAY")) + "  [Space]"


func _money(value: float) -> String:
	return GameFmt.money(value)


func _on_next_day_pressed() -> void:
	GameCommands.next_day()


func _on_day_advanced(_day_number: int) -> void:
	_refresh()


func _on_prices_updated() -> void:
	_refresh()


func _on_portfolio_changed() -> void:
	_refresh()


func _on_state_changed(_state: int) -> void:
	_refresh()


func _on_margin_called() -> void:
	var s: GameSession = GameManager.session
	_alert_day = s.day if s != null else -1
	_alert.text = tr("UI_GAME_MARGIN_CALL")
