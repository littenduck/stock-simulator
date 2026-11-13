## Shows the final score on EventBus.run_finished: score, rank in the local top 10, new unlocks.
## Starts hidden. Enter / Esc / button -> GameManager.go_to_menu().
## Rank and unlocks are read from SaveManager.profile, so the profile must already contain this
## run when run_finished is emitted. New unlocks = ids that were not unlocked when this screen loaded.
extends Control

var _unlocked_at_start: Dictionary = {}

@onready var _run_info_label: Label = %RunInfoLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _rank_label: Label = %RankLabel
@onready var _unlocks_box: VBoxContainer = %UnlocksBox
@onready var _menu_button: Button = %MenuButton


func _ready() -> void:
	hide()
	_unlocked_at_start = SaveManager.profile.unlocked.duplicate()
	_menu_button.pressed.connect(_on_menu_button_pressed)
	EventBus.run_finished.connect(_on_run_finished)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_on_menu_button_pressed()
	elif event is InputEventKey and event.is_pressed():
		# Keep the game screen underneath quiet (space = next day, B / S, 1-6).
		get_viewport().set_input_as_handled()


func _on_run_finished(score: float) -> void:
	_score_label.text = UiFormat.money(0.0)
	_run_info_label.text = _run_info()
	_rank_label.text = _rank_text(score)
	_fill_unlocks()
	show()
	_menu_button.grab_focus()
	_animate_in(score)


## Dim fades in, the panel pops up, the score counts up from zero.
func _animate_in(score: float) -> void:
	UiFx.install(get_tree())
	PanelFx.decorate_tree($Center)
	var dim: CanvasItem = $Dim
	dim.modulate.a = 0.0
	dim.create_tween().tween_property(dim, "modulate:a", 1.0, 0.35)
	await get_tree().process_frame
	var panel: Control = $Center/Panel
	UiFx.bounce_in(panel, 0.1)
	_score_label.remove_meta("fx_value")
	UiFx.count_label(_score_label, 0.0, UiFormat.money)
	await get_tree().create_timer(0.5).timeout
	UiFx.count_label(_score_label, score, UiFormat.money, Color.WHITE, 1.2)


func _run_info() -> String:
	var session := GameManager.session
	if session == null or session.config == null or session.config.character == null:
		return ""
	var config := session.config
	return tr("UI_FLOW_RUN_INFO") % [tr(config.character.title_key), config.difficulty]


func _rank_text(score: float) -> String:
	var scores: Array[Dictionary] = SaveManager.profile.top_scores
	for i in scores.size():
		if is_equal_approx(float(scores[i].get("score", -1.0)), score):
			return tr("UI_FLOW_RANK") % [i + 1, Profile.MAX_SCORES]
	return tr("UI_FLOW_RANK_NONE") % Profile.MAX_SCORES


func _fill_unlocks() -> void:
	for child in _unlocks_box.get_children():
		_unlocks_box.remove_child(child)
		child.queue_free()
	var lines: Array[String] = []
	for id: StringName in SaveManager.profile.unlocked:
		if _unlocked_at_start.has(id):
			continue
		var character := _character_for_unlock(id)
		if character != null:
			lines.append(tr("UI_FLOW_UNLOCK_CHARACTER") % tr(character.title_key))
		else:
			lines.append(tr("UI_FLOW_UNLOCK_OTHER") % String(id).capitalize())
	_unlocks_box.visible = not lines.is_empty()
	if lines.is_empty():
		return
	var header := Label.new()
	header.text = tr("UI_FLOW_NEW_UNLOCKS")
	header.theme_type_variation = &"SubtleLabel"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unlocks_box.add_child(header)
	for line in lines:
		var label := Label.new()
		label.text = line
		label.theme_type_variation = &"RarityLegendaryLabel"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_unlocks_box.add_child(label)
	# Remember them so a second run_finished (never expected) does not repeat the list.
	_unlocked_at_start = SaveManager.profile.unlocked.duplicate()


func _character_for_unlock(id: StringName) -> CharacterDef:
	for c in ContentDb.characters():
		if c.unlock_id == id:
			return c
	return null


func _on_menu_button_pressed() -> void:
	hide()
	GameManager.go_to_menu()
