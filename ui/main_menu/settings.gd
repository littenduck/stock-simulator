## Settings: a few switches stored by GameSettings. Margin trading is the only rule switch
## (off by default); buying and selling are core mechanics and are never listed here.
extends Control

@onready var _margin_row: HBoxContainer = %MarginRow
@onready var _auto_row: HBoxContainer = %AutoRevealRow
@onready var _fees_row: HBoxContainer = %FeesRow
@onready var _volume_row: HBoxContainer = %VolumeRow
@onready var _display_section: VBoxContainer = %DisplaySection
@onready var _fullscreen_row: HBoxContainer = %FullscreenRow
@onready var _back_button: Button = %BackButton

var _volume_label: Label
var _volume_down: Button
var _volume_up: Button


func _ready() -> void:
	_back_button.pressed.connect(_on_back_button_pressed)
	_build_switch(_margin_row, GameSettings.margin_enabled(), _on_margin_chosen)
	_build_switch(_auto_row, GameSettings.auto_reveal(), func(value: bool) -> void: GameSettings.set_auto_reveal(value))
	_build_switch(_fees_row, GameSettings.fees_enabled(), func(value: bool) -> void: GameSettings.set_fees_enabled(value))
	_build_volume()
	_display_section.visible = not OS.has_feature("web")
	_build_switch(_fullscreen_row, GameSettings.fullscreen(), _on_fullscreen_chosen)
	(_margin_row.get_child(1) as Button).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.go_to_menu()


## Two exclusive toggle buttons (Off | On); the same look as the difficulty row.
func _build_switch(row: HBoxContainer, is_on: bool, on_chosen: Callable) -> void:
	var group := ButtonGroup.new()
	var title := Label.new()
	title.text = tr(String(row.get_meta("title_key")))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	for value in [false, true]:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.text = tr("UI_FLOW_SETTINGS_ON") if value else tr("UI_FLOW_SETTINGS_OFF")
		button.custom_minimum_size = Vector2(110, 0)
		button.button_pressed = value == is_on
		button.toggled.connect(func(pressed: bool) -> void:
			if pressed:
				on_chosen.call(value))
		row.add_child(button)


func _build_volume() -> void:
	var title := Label.new()
	title.text = tr("UI_FLOW_SETTINGS_VOLUME")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_volume_row.add_child(title)
	_volume_down = _step_button("-", -GameSettings.VOLUME_STEP)
	_volume_label = Label.new()
	_volume_label.custom_minimum_size = Vector2(110, 0)
	_volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_volume_up = _step_button("+", GameSettings.VOLUME_STEP)
	_volume_row.add_child(_volume_down)
	_volume_row.add_child(_volume_label)
	_volume_row.add_child(_volume_up)
	_update_volume_text()


func _step_button(text: String, delta: float) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(56, 0)
	button.pressed.connect(func() -> void:
		GameSettings.set_volume(GameSettings.volume() + delta)
		_update_volume_text())
	return button


func _update_volume_text() -> void:
	var v := GameSettings.volume()
	_volume_label.text = tr("UI_FLOW_SETTINGS_MUTED") if v <= 0.0 else "%d%%" % roundi(v * 100.0)
	_volume_down.disabled = v <= 0.0
	_volume_up.disabled = v >= 1.0


func _on_margin_chosen(value: bool) -> void:
	GameSettings.set_margin_enabled(value)


func _on_fullscreen_chosen(value: bool) -> void:
	GameSettings.set_fullscreen(value)


func _on_back_button_pressed() -> void:
	GameManager.go_to_menu()
