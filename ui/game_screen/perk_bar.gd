## Strip showing the perks owned this run. Hover a chip for its description.
class_name GamePerkBar
extends PanelContainer

var _row: HBoxContainer


func _ready() -> void:
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 8)
	add_child(_row)
	EventBus.perks_changed.connect(_on_perks_changed)
	_refresh()


func _refresh() -> void:
	if _row == null:
		return
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	_row.add_child(GameFmt.label(tr("UI_GAME_PERKS"), GameColors.MUTED, 14))
	var s: GameSession = GameManager.session
	if s == null or s.owned_perks.is_empty():
		_row.add_child(GameFmt.label(tr("UI_GAME_NO_PERKS"), GameColors.MUTED, 14))
		return
	for perk in s.owned_perks:
		_row.add_child(_chip(perk))


func _chip(perk: PerkDef) -> Control:
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	var accent: Color = [Color("#8b949e"), Color("#58a6ff"), GameColors.GOLD][perk.rarity]
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.15)
	style.border_color = accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", style)
	chip.tooltip_text = tr(perk.description_key)
	chip.add_child(GameFmt.label(tr(perk.title_key), Color.WHITE, 14))
	return chip


func _on_perks_changed() -> void:
	_refresh()
