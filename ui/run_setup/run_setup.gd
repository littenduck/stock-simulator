## Pick character and difficulty, then GameManager.start_run().
## Locked characters / difficulties are shown but cannot be selected.
extends Control

## Dev seam: when non-empty, used instead of ContentDb.characters().
var characters_override: Array[CharacterDef] = []

var _character: CharacterDef
var _difficulty: int = 1
var _character_group := ButtonGroup.new()
var _difficulty_group := ButtonGroup.new()

@onready var _character_row: HBoxContainer = %CharacterRow
@onready var _difficulty_row: HBoxContainer = %DifficultyRow
@onready var _difficulty_label: Label = %DifficultyLabel
@onready var _margin_label: Label = %MarginLabel
@onready var _back_button: Button = %BackButton
@onready var _start_button: Button = %StartButton


func _ready() -> void:
	UiFx.install(get_tree())
	PanelFx.decorate_tree($Center)
	_animate_in()
	_back_button.pressed.connect(_on_back_button_pressed)
	_start_button.pressed.connect(_on_start_button_pressed)
	_build_characters()
	_build_difficulties()
	_update_difficulty_text()
	# Read-only: the margin switch lives in Settings and is fixed for the whole run.
	_margin_label.text = tr("UI_FLOW_SETUP_MARGIN_ON" if GameSettings.margin_enabled() else "UI_FLOW_SETUP_MARGIN_OFF")
	_start_button.disabled = _character == null
	var selected := _character_group.get_pressed_button()
	if selected != null:
		selected.grab_focus()
	else:
		_back_button.grab_focus()


## Sections of the panel fade and pop in one after another (waits a frame so the layout is known).
func _animate_in() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	UiFx.stagger_in($Center/Panel/Column, 0.07)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.go_to_menu()


func _characters() -> Array[CharacterDef]:
	return characters_override if not characters_override.is_empty() else ContentDb.characters()


func _build_characters() -> void:
	var profile := SaveManager.profile
	for def in _characters():
		var unlocked := profile.is_unlocked(def.unlock_id)
		var card := Button.new()
		card.theme_type_variation = &"SelectCard"
		card.toggle_mode = true
		card.button_group = _character_group
		card.disabled = not unlocked
		card.custom_minimum_size = Vector2(300, 190)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_child(_character_card_body(def, unlocked))
		card.toggled.connect(_on_character_card_toggled.bind(def))
		_character_row.add_child(card)
		if unlocked and _character == null:
			card.button_pressed = true  # also fires toggled -> _character


func _character_card_body(def: CharacterDef, unlocked: bool) -> Control:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	box.add_child(_label(tr(def.title_key), &"HeaderLabel"))
	box.add_child(_label(tr("UI_FLOW_START_CASH") % UiFormat.money(def.start_cash), &"PositiveLabel"))
	var desc := _label(tr(def.description_key), &"")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(desc)
	if not unlocked:
		var locked := _label(tr("UI_FLOW_LOCKED") + ": " + _unlock_hint(def), &"RarityLegendaryLabel")
		locked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(locked)
		box.modulate = Color(1, 1, 1, 0.7)
	return margin


func _unlock_hint(def: CharacterDef) -> String:
	var key := "UI_FLOW_UNLOCK_HINT_" + String(def.id).to_upper()
	var text := tr(key)
	return tr("UI_FLOW_LOCKED_GENERIC") if text == key else text


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if variation != &"":
		label.theme_type_variation = variation
	return label


func _build_difficulties() -> void:
	for level in range(1, Difficulty.MAX_LEVEL + 1):
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = _difficulty_group
		button.text = tr("UI_FLOW_DIFFICULTY_LEVEL") % level
		button.custom_minimum_size = Vector2(120, 0)
		var unlocked := level == 1 or SaveManager.profile.is_unlocked(StringName("difficulty_%d" % level))
		button.disabled = not unlocked
		if not unlocked:
			button.text += "  (" + tr("UI_FLOW_LOCKED") + ")"
			button.custom_minimum_size = Vector2(190, 0)
			button.add_theme_constant_override("outline_size", 0)
		button.toggled.connect(_on_difficulty_button_toggled.bind(level))
		_difficulty_row.add_child(button)
		if level == 1:
			button.button_pressed = true


func _update_difficulty_text() -> void:
	var text := tr("UI_FLOW_DIFFICULTY_%d" % _difficulty)
	if _difficulty > 1:
		text += "  " + tr("UI_FLOW_DIFFICULTY_NOTE")
	_difficulty_label.text = text


func _on_character_card_toggled(pressed: bool, def: CharacterDef) -> void:
	if pressed:
		_character = def
		_start_button.disabled = false


func _on_difficulty_button_toggled(pressed: bool, level: int) -> void:
	if pressed:
		_difficulty = level
		_update_difficulty_text()


func _on_start_button_pressed() -> void:
	if _character == null:
		return
	GameManager.start_run(RunConfig.make(_character, _difficulty, 0, GameSettings.margin_enabled()))


func _on_back_button_pressed() -> void:
	GameManager.go_to_menu()
