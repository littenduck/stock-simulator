## The pick of your rivals, played on the character screen after you press Start and before the game opens: a frame runs
## over the six characters like an arcade pick, fast and then slower, and lands on the three rivals one after another.
## You are already seated. Space skips it.
class_name RivalRoll
extends Control

const ROSTER := ["saving_son", "double_dan", "hodl_hana", "goldfish_gus", "copilot_cody", "insider_inu"]
const BG := Color("#14111f")
const GOLD := Color("#e3b341")
const YOU_GREEN := Color("#3fb950")
const RIVAL_TIMES := [1.0, 0.8, 0.7]

signal finished

var _skipped: bool = false
var _stage: Control
var _session: TableSession


## Plays the roll for the rivals of `session` on top of `host`, and returns when it is over.
static func play(host: Control, session: TableSession) -> void:
	var roll := RivalRoll.new()
	roll._session = session
	host.add_child(roll)
	await roll.finished
	roll.queue_free()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_meta("no_fx", true)
	z_index = 40
	# This screen has no sound player of its own.
	add_child((load("res://ui/audio/audio_feedback.tscn") as PackedScene).instantiate())
	var bg := ColorRect.new()
	bg.color = Color(BG.r, BG.g, BG.b, 0.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	create_tween().tween_property(bg, "color:a", 0.97, 0.3)
	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	var hint := GameFmt.label(tr("TABLE_SKIP_HINT"), Color(1, 1, 1, 0.55), 13)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 14)
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(hint)
	_run()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("next_day") or event.is_action_pressed("ui_accept"):
		_skipped = true
		get_viewport().set_input_as_handled()


func _wait(sec: float) -> void:
	var left := sec
	while left > 0.0 and not _skipped:
		await get_tree().process_frame
		left -= get_process_delta_time()


func _is_skipped() -> bool:
	return _skipped


func _run() -> void:
	await _roll()
	await _wait(0.5)
	finished.emit()


func _character_card(id: String, number: int) -> PanelContainer:
	var def := ContentDb.character_by_id(StringName(id))
	var card := PanelContainer.new()
	card.theme_type_variation = &"DialogPanel"
	card.custom_minimum_size = Vector2(150, 200)
	var box := TableUi.column(card, 4, 8)
	var no := GameFmt.label("%02d" % number, Color("#5d5870"), 14)
	no.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(no)
	var portrait := PortraitView.make(id, 6)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(portrait)
	var name_label := GameFmt.label(tr(def.title_key), Color("#2b2540"), 15)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	var tag := GameFmt.label(" ", GOLD, 15)
	tag.name = "Tag"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tag)
	return card


func _roll() -> void:
	var t := _session
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 26)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(column)
	var title := GameFmt.label(tr("TABLE_INTRO_RIVALS"), GOLD, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	var cards: Array = []
	for i in ROSTER.size():
		var card := _character_card(ROSTER[i], i + 1)
		card.modulate.a = 0.0
		row.add_child(card)
		cards.append(card)
	await get_tree().process_frame
	await get_tree().process_frame
	for i in cards.size():
		if _skipped:
			break
		var card: Control = cards[i]
		card.modulate.a = 1.0
		TableFx.pop(card, 0.6, 0.0)
		TableFx.sfx(&"reveal_tick")
		await _wait(0.06)
	for card: Control in cards:
		card.modulate.a = 1.0
	var you_index: int = ROSTER.find(String(t.seats[0].character.id))
	_mark(cards[you_index], tr("TABLE_INTRO_YOU"), YOU_GREEN, true)
	var open: Array = []
	for i in cards.size():
		if i != you_index:
			open.append(i)
	await _wait(0.25)
	var roller := SlotPick.make_frame(Color.WHITE, 6)
	_stage.add_child(roller)
	roller.visible = false
	for n in range(1, 4):
		var target: int = ROSTER.find(String(t.seats[n].character.id))
		await SlotPick.run(self, roller, cards, open, target, RIVAL_TIMES[n - 1], _is_skipped)
		open.erase(target)
		_mark(cards[target], tr("TABLE_INTRO_RIVAL") % n, GOLD, false)
		TableFx.pop(cards[target], 1.18, 0.0)
		await _wait(0.15)
	roller.visible = false
	for i in open:
		(cards[i] as Control).modulate = Color(0.45, 0.45, 0.5, 1.0)


## A solid frame and a tag under the card: who sits there.
func _mark(card: Control, text: String, color: Color, mine: bool) -> void:
	var tag: Label = card.find_child("Tag", true, false)
	tag.text = text
	GameFmt.tint(tag, color if not mine else Color("#2f9e44"))
	var frame := SlotPick.make_frame(color, 5)
	_stage.add_child(frame)
	frame.global_position = card.global_position - Vector2(5, 5)
	frame.size = card.size + Vector2(10, 10)
