## Perk draft pop-up. Shows EventBus.draft_offered options as three rarity-styled cards inside a framed
## panel: the backdrop fades in, the panel pops in, the cards fly in one after another. Picking a card
## (click, 1-4, or Enter/Space on the focused card) plays a selection animation (the chosen card grows,
## the others fade) and then hands the perk to GameManager.choose_perk().
## Starts hidden. Arrows move the focus. There is no cancel: a draft must be answered.
extends Control

const INPUT_LOCK := 0.45
const PICK_HOLD := 0.62

var _options: Array[PerkDef] = []
var _cards: Array[PerkCard] = []
var _slots: Array[Control] = []
var _busy: bool = false
var _open_time: float = 0.0
var _tween: Tween

@onready var _dim: ColorRect = $Dim
@onready var _panel: Control = $Center/Panel
@onready var _title_label: Label = $Center/Panel/Column/TitleLabel
@onready var _cards_row: HBoxContainer = %Cards
@onready var _hint_label: Label = %HintLabel


func _ready() -> void:
	hide()
	EventBus.draft_offered.connect(_on_draft_offered)
	EventBus.state_changed.connect(_on_state_changed)


func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	var index := key.keycode - KEY_1
	if key.keycode >= KEY_KP_1 and key.keycode <= KEY_KP_4:
		index = key.keycode - KEY_KP_1
	if index >= 0 and index < _options.size():
		get_viewport().set_input_as_handled()
		select_index(index)
		return
	if key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		get_viewport().set_input_as_handled()
		var focused := get_viewport().gui_get_focus_owner()
		if focused is PerkCard:
			select_index((focused as PerkCard).index)
		return
	if key.keycode in [KEY_LEFT, KEY_RIGHT]:
		get_viewport().set_input_as_handled()
		_move_focus(-1 if key.keycode == KEY_LEFT else 1)
		return
	# While the draft is open nothing underneath (space = next day, 1-6 = stock) may react.
	if key.keycode in [KEY_B, KEY_S, KEY_ESCAPE]:
		get_viewport().set_input_as_handled()


## Cards currently shown (for tests and dev shots).
func cards() -> Array[PerkCard]:
	return _cards


func is_busy() -> bool:
	return _busy


## The draft was answered elsewhere (a dev tool, or the run ended): close without animation.
func _on_state_changed(state: int) -> void:
	if visible and not _busy and state != GameManager.State.DRAFTING:
		hide()
		_options.clear()


func _on_draft_offered(options: Array) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_options.clear()
	for o in options:
		_options.append(o as PerkDef)
	_busy = false
	_rebuild_cards()
	_hint_label.text = tr("UI_FLOW_DRAFT_HINT") % _options.size()
	show()
	_open_time = Time.get_ticks_msec() / 1000.0
	_play_intro()


func _rebuild_cards() -> void:
	for child in _cards_row.get_children():
		_cards_row.remove_child(child)
		child.queue_free()
	_cards.clear()
	_slots.clear()
	for i in _options.size():
		var perk: PerkDef = _options[i]
		var card := PerkCard.new()
		card.setup(perk, i, tr(perk.title_key), tr(perk.description_key), tr(UiPalette.rarity_key(perk.rarity)))
		card.pressed.connect(_on_card_pressed.bind(card))
		card.focus_entered.connect(card.set_focus_lift.bind(true))
		card.focus_exited.connect(card.set_focus_lift.bind(false))
		card.appear = 0.0
		var slot := Control.new()
		slot.custom_minimum_size = PerkCard.CARD_SIZE
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(card)
		_cards_row.add_child(slot)
		_cards.append(card)
		_slots.append(slot)
	_link_focus()


## Backdrop, panel pop, title, then each card flies in.
func _play_intro() -> void:
	_dim.color.a = 0.0
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.78, 0.78)
	_title_label.modulate.a = 0.0
	_hint_label.modulate.a = 0.0
	for card in _cards:
		card.appear = 0.0
		card.interactive = false
	# The panel's size is only known after the first layout pass.
	await get_tree().process_frame
	if not is_inside_tree() or _busy:
		return
	_panel.pivot_offset = _panel.size * 0.5
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_dim, "color:a", 0.66, 0.28)
	_tween.tween_property(_panel, "modulate:a", 1.0, 0.18)
	_tween.tween_property(_panel, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_title_label, "modulate:a", 1.0, 0.25).set_delay(0.18)
	_tween.tween_property(_hint_label, "modulate:a", 1.0, 0.3).set_delay(0.55)
	for i in _cards.size():
		_tween.tween_property(_cards[i], "appear", 1.0, 0.55).set_delay(0.30 + 0.13 * i).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var ready_at: float = 0.30 + 0.13 * _cards.size() + 0.35
	get_tree().create_timer(minf(ready_at, 0.9)).timeout.connect(_unlock)


func _unlock() -> void:
	if _busy:
		return
	for card in _cards:
		if is_instance_valid(card):
			card.interactive = true


func _move_focus(step: int) -> void:
	if _cards.is_empty() or _busy:
		return
	var focused := get_viewport().gui_get_focus_owner()
	var at: int = (focused as PerkCard).index if focused is PerkCard else (-1 if step > 0 else 0)
	_cards[posmod(at + step, _cards.size())].grab_focus()


func _on_card_pressed(card: PerkCard) -> void:
	if card.interactive:
		select_index(card.index)


## Picks card `index`: selection animation, then GameManager.choose_perk().
func select_index(index: int) -> void:
	if _busy or index < 0 or index >= _cards.size():
		return
	if Time.get_ticks_msec() / 1000.0 - _open_time < INPUT_LOCK:
		return
	_busy = true
	var perk: PerkDef = _options[index]
	if _tween != null and _tween.is_valid():
		_tween.kill()
	for card in _cards:
		card.interactive = false
		card.appear = 1.0
	_tween = create_tween().set_parallel(true)
	var chosen := _cards[index]
	_tween.tween_property(chosen, "chosen", 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(chosen, "burst", 1.0, 0.55).from(0.0)
	for card in _cards:
		if card != chosen:
			_tween.tween_property(card, "dim", 1.0, 0.3)
	_tween.tween_property(_hint_label, "modulate:a", 0.0, 0.2)
	_tween.tween_property(_title_label, "modulate:a", 0.0, 0.25).set_delay(0.2)
	# Close: panel and backdrop fade after the chosen card had its moment.
	var close := create_tween().set_parallel(true)
	close.tween_interval(PICK_HOLD)
	close.chain().tween_property(_panel, "modulate:a", 0.0, 0.22)
	close.tween_property(_panel, "scale", Vector2(1.06, 1.06), 0.22)
	close.tween_property(_dim, "color:a", 0.0, 0.25)
	close.chain().tween_callback(_finish_pick.bind(perk))


func _finish_pick(perk: PerkDef) -> void:
	hide()
	_options.clear()
	_busy = false
	GameManager.choose_perk(perk)


## Left/right wrap around inside the card row.
func _link_focus() -> void:
	var count := _cards.size()
	for i in count:
		var card := _cards[i]
		card.focus_neighbor_left = card.get_path_to(_cards[(i - 1 + count) % count])
		card.focus_neighbor_right = card.get_path_to(_cards[(i + 1) % count])
		card.focus_neighbor_top = card.get_path_to(card)
		card.focus_neighbor_bottom = card.get_path_to(card)
