## Local top 10 from SaveManager.profile.top_scores.
extends Control

const COLUMN_KEYS: Array[String] = [
	"UI_FLOW_COL_RANK", "UI_FLOW_COL_SCORE", "UI_FLOW_COL_CHARACTER",
	"UI_FLOW_COL_DIFFICULTY", "UI_FLOW_COL_DATE",
]

@onready var _grid: GridContainer = %ScoreGrid
@onready var _empty_label: Label = %EmptyLabel
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_back_button.pressed.connect(_on_back_button_pressed)
	_build_rows()
	_back_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_go_back()


func _build_rows() -> void:
	for child in _grid.get_children():
		child.queue_free()
	var scores: Array[Dictionary] = SaveManager.profile.top_scores
	_empty_label.visible = scores.is_empty()
	_grid.visible = not scores.is_empty()
	if scores.is_empty():
		return
	for key in COLUMN_KEYS:
		_grid.add_child(_cell(tr(key), &"SubtleLabel"))
	for i in scores.size():
		var entry: Dictionary = scores[i]
		var rank := _cell("%d" % (i + 1), &"RarityLegendaryLabel" if i == 0 else &"")
		rank.add_theme_font_size_override("font_size", 16)
		_grid.add_child(rank)
		_grid.add_child(_cell(UiFormat.money(float(entry.get("score", 0.0))), &"PositiveLabel"))
		_grid.add_child(_cell(_character_name(entry.get("character", "")), &""))
		_grid.add_child(_cell(str(int(entry.get("difficulty", 1))), &""))
		_grid.add_child(_cell(_date_text(entry.get("date", "")), &"SubtleLabel"))


func _cell(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if variation != &"":
		label.theme_type_variation = variation
	return label


func _character_name(id: Variant) -> String:
	var def := ContentDb.character_by_id(StringName(str(id)))
	return tr(def.title_key) if def != null else str(id)


func _date_text(value: Variant) -> String:
	if value is int or value is float:
		return Time.get_date_string_from_unix_time(int(value))
	return str(value).substr(0, 10)


func _go_back() -> void:
	GameManager.go_to_menu()


func _on_back_button_pressed() -> void:
	_go_back()
