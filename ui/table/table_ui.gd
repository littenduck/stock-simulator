## Small helpers shared by the table-mode widgets.
class_name TableUi
extends RefCounted

const BELIEVE_COLOR := Color("#3fb950")
const BULLSHIT_COLOR := Color("#f85149")
const PASS_COLOR := Color("#8b949e")


static func session() -> TableSession:
	return GameManager.session as TableSession


static func side_key(side: int) -> String:
	match side:
		RumorTier.Side.BELIEVE:
			return "TABLE_BELIEVE"
		RumorTier.Side.BULLSHIT:
			return "TABLE_BULLSHIT"
	return "TABLE_PASS"


static func side_color(side: int) -> Color:
	match side:
		RumorTier.Side.BELIEVE:
			return BELIEVE_COLOR
		RumorTier.Side.BULLSHIT:
			return BULLSHIT_COLOR
	return PASS_COLOR


static func tier_color(tier: int) -> Color:
	return [BULLSHIT_COLOR, GameColors.GOLD, BELIEVE_COLOR][clampi(tier, 0, 2)]


## "Low (33%)" in the current language.
static func tier_text(tier: int, node: Node) -> String:
	return RumorTier.label(tier, node.tr)


static func seat_name(seat: Seat, node: Node) -> String:
	return node.tr(seat.title_key())


## Panel with a margin and a column inside; returns the column.
static func column(panel: PanelContainer, separation: int = 6, pad: int = 10) -> VBoxContainer:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, pad)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	margin.add_child(box)
	return box


static func wrapped(text: String, color: Color = Color.WHITE, size: int = 0) -> Label:
	var l := GameFmt.label(text, color, size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l
