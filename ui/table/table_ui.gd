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


## True while a pop-up (the rumor card or the reveal / verdict window) is in front: Space must not move the turn then.
static var modal_open: bool = false

## The step of the turn the screen is in (TurnBar.Step). Only step 1 (market open) lets you trade or open the rumor card.
static var current_step: int = 0

## True while a skill animation plays: nothing moves on until it is over (the Next button waits).
static var skill_busy: bool = false


static func set_busy(on: bool) -> void:
	skill_busy = on
	EventBus.table_changed.emit()


static var _arrow: ImageTexture = null

const ARROW_ROWS := [
	"k........", "kk.......", "kwk......", "kwwk.....", "kwwwk....", "kwwwwk...",
	"kwwwk....", "kwwk.....", "kwk......", "kk.......", "k........",
]


## A small white right arrow with a dark edge, drawn here because the font has no arrow glyph.
static func arrow_right() -> ImageTexture:
	if _arrow == null:
		var img := Image.create(9, 11, false, Image.FORMAT_RGBA8)
		for y in ARROW_ROWS.size():
			var row: String = ARROW_ROWS[y]
			for x in row.length():
				if row[x] == "k":
					img.set_pixel(x, y, Color("#232130"))
				elif row[x] == "w":
					img.set_pixel(x, y, Color.WHITE)
		img.resize(18, 22, Image.INTERPOLATE_NEAREST)
		_arrow = ImageTexture.create_from_image(img)
	return _arrow
