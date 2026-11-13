## Share quantity entry: [-] [ text box ] [+] plus quick chips (+1, +10, 25%, 50%, Max) and an inline
## validation message. The text box value is committed live: shares() always reads the current text, so a
## Buy click right after typing "10" (no Enter) orders 10. No autoloads, usable in unit tests.
class_name SharesInput
extends VBoxContainer

signal changed
## B / S typed inside the box switch the order side instead of typing a letter (dir is an Order.Dir).
signal side_key(dir: int)
signal submit_requested

var line_edit: LineEdit
var max_shares: int = -1:
	set(value):
		max_shares = value
		_update_message()
var hard_limit: bool = true:
	set(value):
		hard_limit = value
		_update_message()

var _minus: Button
var _plus: Button
var _chips: Dictionary = {}
var _message: Label


func _init() -> void:
	add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	_minus = _chip_button("-", 34)
	_minus.name = "MinusButton"
	_minus.pressed.connect(func() -> void: set_shares(OrderEntry.stepped(line_edit.text, -1)))
	row.add_child(_minus)
	line_edit = LineEdit.new()
	line_edit.name = "SharesEdit"
	line_edit.text = "1"
	line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	line_edit.select_all_on_focus = true
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.custom_minimum_size = Vector2(0, 34)
	line_edit.max_length = 12
	line_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	line_edit.text_changed.connect(_on_text_changed)
	line_edit.text_submitted.connect(func(_t: String) -> void: submit_requested.emit())
	line_edit.gui_input.connect(_on_edit_gui_input)
	row.add_child(line_edit)
	_plus = _chip_button("+", 34)
	_plus.name = "PlusButton"
	_plus.pressed.connect(func() -> void: set_shares(OrderEntry.stepped(line_edit.text, 1)))
	row.add_child(_plus)

	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 4)
	add_child(chips)
	for spec in [["plus1", "+1"], ["plus10", "+10"], ["pct25", "25%"], ["pct50", "50%"], ["max", ""]]:
		var b := _chip_button(String(spec[1]), 0)
		b.name = "Chip_" + String(spec[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_chip.bind(String(spec[0])))
		chips.add_child(b)
		_chips[String(spec[0])] = b
	(_chips["max"] as Button).text = tr("UI_GAME_MAX")
	(_chips["max"] as Button).tooltip_text = tr("UI_GAME_MAX_TIP")

	_message = Label.new()
	_message.name = "ErrorLabel"
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_font_size_override("font_size", 12)
	_message.custom_minimum_size = Vector2(0, 18)
	add_child(_message)


static func _chip_button(text: String, min_w: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(min_w, 28)
	b.add_theme_font_size_override("font_size", 13)
	return b


## Whole shares in the box right now, or -1 if the text is not a number.
func shares() -> int:
	return OrderEntry.parse(line_edit.text)


func status() -> OrderEntry.Status:
	return OrderEntry.status(line_edit.text, max_shares, hard_limit)


func is_submittable() -> bool:
	return OrderEntry.is_submittable(status(), hard_limit)


func set_shares(n: int) -> void:
	line_edit.text = str(n)
	line_edit.caret_column = line_edit.text.length()
	_on_text_changed(line_edit.text)


## Typed or programmatic text change (tests call this after setting line_edit.text).
func _on_text_changed(_text: String) -> void:
	_update_message()
	changed.emit()


func _on_chip(kind: String) -> void:
	match kind:
		"plus1":
			set_shares(OrderEntry.stepped(line_edit.text, 1))
		"plus10":
			set_shares(OrderEntry.stepped(line_edit.text, 10))
		"pct25":
			set_shares(OrderEntry.fraction_of(max_shares, 0.25))
		"pct50":
			set_shares(OrderEntry.fraction_of(max_shares, 0.5))
		"max":
			set_shares(OrderEntry.fraction_of(max_shares, 1.0))


func _on_edit_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	if key.ctrl_pressed or key.meta_pressed or key.alt_pressed:
		return
	if key.keycode == KEY_B or key.keycode == KEY_S:
		line_edit.accept_event()
		side_key.emit(0 if key.keycode == KEY_B else 1)
	elif key.keycode == KEY_ESCAPE:
		line_edit.accept_event()
		line_edit.release_focus()
	elif key.keycode == KEY_SPACE:
		# A space is never part of a quantity. Swallow it (it must not type, and must not advance the day
		# while the player is entering a number).
		line_edit.accept_event()


func _update_message() -> void:
	if _message == null:
		return
	var st := status()
	var key: String = OrderEntry.message_key(st, hard_limit)
	var text: String = tr(key) if key != "" else ""
	if text != "" and "%d" in text:
		text = text % max_shares
	_message.text = text
	var warn: bool = st == OrderEntry.Status.OVER_MAX and not hard_limit
	_message.add_theme_color_override("font_color", Color("#c77d0a") if warn else UiPalette.INK_DOWN)
	var bad: bool = st != OrderEntry.Status.OK and not warn
	line_edit.add_theme_color_override("font_color", UiPalette.INK_DOWN if bad else UiPalette.INK)
	line_edit.add_theme_color_override("font_uneditable_color", UiPalette.INK)
