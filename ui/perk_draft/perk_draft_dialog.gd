## Shows EventBus.draft_offered options as cards; the pick goes to GameManager.choose_perk().
## Starts hidden. Keys: 1-4 pick, arrows move focus, Enter/Space confirm the focused card.
## There is no cancel: a draft must be answered.
extends Control

const CARD_SIZE := Vector2(260, 280)

var _options: Array[PerkDef] = []

@onready var _cards: HBoxContainer = %Cards
@onready var _hint_label: Label = %HintLabel


func _ready() -> void:
	hide()
	EventBus.draft_offered.connect(_on_draft_offered)


func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	var index := key.keycode - KEY_1
	if key.keycode >= KEY_KP_1 and key.keycode <= KEY_KP_4:
		index = key.keycode - KEY_KP_1
	if index >= 0 and index < _options.size():
		get_viewport().set_input_as_handled()
		_pick(_options[index])
		return
	# While the draft is open nothing underneath (space = next day, 1-6 = stock) may react.
	if key.keycode in [KEY_SPACE, KEY_B, KEY_S, KEY_ESCAPE]:
		get_viewport().set_input_as_handled()


func _on_draft_offered(options: Array) -> void:
	_options.clear()
	for o in options:
		_options.append(o as PerkDef)
	_rebuild_cards()
	_hint_label.text = tr("UI_FLOW_DRAFT_HINT") % _options.size()
	show()
	if _cards.get_child_count() > 0:
		(_cards.get_child(0) as Control).grab_focus()


func _rebuild_cards() -> void:
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for i in _options.size():
		var card := _make_card(_options[i], i)
		_cards.add_child(card)
	_link_focus()


func _make_card(perk: PerkDef, index: int) -> Button:
	var card := Button.new()
	card.theme_type_variation = _card_variation(perk.rarity)
	card.custom_minimum_size = CARD_SIZE
	card.focus_mode = Control.FOCUS_ALL
	card.pressed.connect(_on_card_pressed.bind(perk))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var number := Label.new()
	number.text = "[%d]" % (index + 1)
	number.theme_type_variation = &"SubtleLabel"
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(number)

	if perk.icon != null:
		var icon := TextureRect.new()
		icon.texture = perk.icon
		icon.custom_minimum_size = Vector2(48, 48)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)

	var title := Label.new()
	title.text = tr(perk.title_key)
	title.theme_type_variation = &"HeaderLabel"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)

	var rarity := Label.new()
	rarity.text = tr(UiPalette.rarity_key(perk.rarity)).to_upper()
	rarity.add_theme_color_override("font_color", UiPalette.rarity_color(perk.rarity))
	rarity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rarity)

	var desc := Label.new()
	desc.text = tr(perk.description_key)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(desc)
	return card


func _card_variation(rarity: int) -> StringName:
	match rarity:
		PerkDef.Rarity.RARE:
			return &"PerkCardRare"
		PerkDef.Rarity.LEGENDARY:
			return &"PerkCardLegendary"
		_:
			return &"PerkCardCommon"


## Left/right wrap around inside the card row.
func _link_focus() -> void:
	var count := _cards.get_child_count()
	for i in count:
		var card := _cards.get_child(i) as Control
		var left := _cards.get_child((i - 1 + count) % count) as Control
		var right := _cards.get_child((i + 1) % count) as Control
		card.focus_neighbor_left = card.get_path_to(left)
		card.focus_neighbor_right = card.get_path_to(right)
		card.focus_neighbor_top = card.get_path_to(card)
		card.focus_neighbor_bottom = card.get_path_to(card)


func _pick(perk: PerkDef) -> void:
	hide()
	_options.clear()
	GameManager.choose_perk(perk)


func _on_card_pressed(perk: PerkDef) -> void:
	_pick(perk)
