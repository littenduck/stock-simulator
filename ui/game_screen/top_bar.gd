## Day, cash, net worth, return, Next Day and Menu buttons. Read-only apart from the two commands.
class_name GameTopBar
extends PanelContainer

signal menu_requested

var _day: Label
var _cash: Label
var _net_worth: Label
var _return: Label
var _alert: Label
var _next_day: Button
var _alert_day: int = -1


func _ready() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	add_child(row)

	_day = GameFmt.label("", Color.WHITE, 24)
	row.add_child(_day)
	_cash = _stat(row, "UI_GAME_CASH")
	_net_worth = _stat(row, "UI_GAME_NET_WORTH")
	_return = _stat(row, "UI_GAME_RETURN")

	_alert = GameFmt.label("", GameColors.DOWN, 18)
	_alert.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_alert.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_alert)

	_next_day = GameFmt.button(tr("UI_GAME_NEXT_DAY") + "  [Space]")
	_next_day.name = "NextDayButton"
	_next_day.custom_minimum_size = Vector2(170, 44)
	_next_day.pressed.connect(_on_next_day_pressed)
	row.add_child(_next_day)
	var menu := GameFmt.button(tr("UI_GAME_MENU") + "  [Esc]")
	menu.custom_minimum_size = Vector2(110, 44)
	menu.pressed.connect(func() -> void: menu_requested.emit())
	row.add_child(menu)

	EventBus.day_advanced.connect(_on_day_advanced)
	EventBus.prices_updated.connect(_on_prices_updated)
	EventBus.portfolio_changed.connect(_on_portfolio_changed)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.margin_called.connect(_on_margin_called)
	_refresh()


## Caption above a big value; returns the value label.
func _stat(parent: Control, caption_key: String) -> Label:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.add_child(GameFmt.label(tr(caption_key), GameColors.MUTED, 13))
	var value := GameFmt.label("", Color.WHITE, 22)
	box.add_child(value)
	parent.add_child(box)
	return value


func _refresh() -> void:
	var s: GameSession = GameManager.session
	if s == null:
		return
	_day.text = "%s %d / %d" % [tr("UI_GAME_DAY"), s.day, RunConfig.TRADING_DAYS]
	_cash.text = GameFmt.money(s.portfolio.cash)
	_cash.add_theme_color_override("font_color", GameColors.DOWN if s.portfolio.cash < 0.0 else Color.WHITE)
	var nw: float = s.net_worth()
	_net_worth.text = GameFmt.money(nw)
	var start: float = s.config.character.start_cash if s.config != null and s.config.character != null else nw
	var ret: float = nw / start - 1.0 if start > 0.0 else 0.0
	_return.text = GameColors.pct_text(ret)
	_return.add_theme_color_override("font_color", GameColors.for_change(ret))
	if s.day != _alert_day:
		_alert.text = ""
	var blocked: bool = GameManager.state == GameManager.State.DRAFTING or GameManager.state == GameManager.State.GAME_OVER
	_next_day.disabled = blocked or s.is_finished()
	_next_day.text = (tr("UI_GAME_FINAL_DAY") if s.day == RunConfig.TRADING_DAYS - 1 else tr("UI_GAME_NEXT_DAY")) + "  [Space]"


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
