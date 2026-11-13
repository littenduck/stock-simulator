## Pick character and difficulty, then GameManager.start_run().
## Locked characters / difficulties are shown but cannot be selected.
extends Control

## Dev seam: when non-empty, used instead of ContentDb.characters().
var characters_override: Array[CharacterDef] = []

var _character: CharacterDef
var _difficulty: int = 1
var _character_group := ButtonGroup.new()
var _difficulty_group := ButtonGroup.new()

@onready var _character_row: Container = %CharacterRow
@onready var _difficulty_row: HBoxContainer = %DifficultyRow
## Shows the passive and active skill of the selected character.
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
	# Table mode has no difficulty levels yet: the row is hidden, the label below the cards describes the skills.
	_difficulty_row.get_parent().get_node("DifficultyHeader").visible = false
	_difficulty_row.visible = false
	_build_characters()
	_margin_label.text = tr("TABLE_SETUP_FEES_ON" if GameSettings.fees_enabled() else "TABLE_SETUP_FEES_OFF")
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


const ROSTER_ORDER := ["insider_inu", "copilot_cody", "double_dan", "saving_son", "goldfish_gus", "hodl_hana"]


func _characters() -> Array[CharacterDef]:
	if not characters_override.is_empty():
		return characters_override
	var out: Array[CharacterDef] = []
	for id in ROSTER_ORDER:
		var def := ContentDb.character_by_id(StringName(id))
		if def != null:
			out.append(def)
	return out


func _build_characters() -> void:
	var profile := SaveManager.profile
	for def in _characters():
		var unlocked := profile.is_unlocked(def.unlock_id)
		var card := Button.new()
		card.theme_type_variation = &"SelectCard"
		card.toggle_mode = true
		card.button_group = _character_group
		card.disabled = not unlocked
		card.custom_minimum_size = Vector2(300, 150)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.focus_mode = Control.FOCUS_ALL
		_style_card(card, unlocked)
		card.add_child(_character_card_body(def, unlocked))
		card.toggled.connect(_on_character_card_toggled.bind(def))
		_character_row.add_child(card)
		if unlocked and _character == null:
			card.button_pressed = true  # also fires toggled -> _character


const AVATARS := {"rookie": "star", "day_trader": "bolt", "value_investor": "bank", "insider_inu": "eye", "copilot_cody": "people", "double_dan": "coin", "saving_son": "bank", "goldfish_gus": "clover", "hodl_hana": "gem"}


## Same cream card for every state: unselected is dimmer with a grey frame, selected has a green frame and glow.
func _style_card(card: Button, unlocked: bool) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(10)
		sb.bg_color = Color("#f6edd9")
		var selected: bool = state in ["pressed", "hover_pressed"]
		sb.set_border_width_all(4 if selected else 3)
		sb.border_color = Color("#4fb83a") if selected else Color("#8d8a94")
		if selected:
			sb.shadow_color = Color(0.3, 0.85, 0.25, 0.55)
			sb.shadow_size = 14
		elif state == "hover":
			sb.border_color = Color("#b9b5c2")
			sb.bg_color = Color("#fbf4e3")
		card.add_theme_stylebox_override(state, StyleBoxEmpty.new() if state == "focus" else sb)
	card.set_meta("fx_off", true)
	card.pivot_offset_ratio = Vector2(0.5, 0.5)
	card.toggled.connect(func(on: bool) -> void: _restyle_card(card, on, unlocked))
	_restyle_card(card, false, unlocked, false)


func _restyle_card(card: Button, on: bool, unlocked: bool, animate: bool = true) -> void:
	var dim: float = 1.0 if on else (0.62 if not unlocked else 0.8)
	card.self_modulate = Color(1, 1, 1, 1)
	for child in card.get_children():
		if child is Control:
			(child as Control).modulate = Color(dim, dim, dim, 1.0)
	if on and animate and card.is_inside_tree():
		var t := card.create_tween()
		t.tween_property(card, "scale", Vector2(1.04, 1.04), 0.10)
		t.tween_property(card, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 12)
	head.add_child(CompanyBadge.make(String(AVATARS.get(String(def.id), "star")), 64))
	var names := VBoxContainer.new()
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.add_child(_label(tr(def.title_key), &"HeaderLabel"))
	var tag_key := "TABLE_ADVANCED" if def.difficulty_tag == "advanced" else "TABLE_EASY"
	names.add_child(_label(tr(tag_key), &"RarityLegendaryLabel" if def.difficulty_tag == "advanced" else &"PositiveLabel"))
	head.add_child(names)
	box.add_child(head)
	var rule := ColorRect.new()
	rule.color = Color(0.55, 0.54, 0.58, 0.5)
	rule.custom_minimum_size = Vector2(0, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rule)
	var desc := _label(tr(def.description_key), &"")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(desc)
	if not unlocked:
		var locked := _label(tr("UI_FLOW_LOCKED") + ": " + _unlock_hint(def), &"RarityLegendaryLabel")
		locked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(locked)
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
		var key := String(def.id).to_upper()
		_difficulty_label.text = "%s: %s\n%s: %s" % [tr("TABLE_PASSIVE"), tr("CHAR_%s_PASSIVE" % key), tr("TABLE_ACTIVE"), tr("CHAR_%s_ACTIVE" % key)]


func _on_difficulty_button_toggled(pressed: bool, level: int) -> void:
	if pressed:
		_difficulty = level
		_update_difficulty_text()


func _on_start_button_pressed() -> void:
	if _character == null:
		return
	GameManager.start_run(RunConfig.make_table(_character, 0, GameSettings.fees_enabled()))


func _on_back_button_pressed() -> void:
	GameManager.go_to_menu()
