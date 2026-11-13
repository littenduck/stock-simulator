## The six characters standing in a row under the main menu, small and in 3D. Each one rests in its idle pose and, every
## few seconds, plays one of its own one or two moves, in turn; nobody moves in step. Nothing reacts to the mouse. The row is as wide as the menu panel and stays below it; it is hidden when the window is too
## small to fit it.
class_name TitleCast
extends Control

const IDS := ["saving_son", "double_dan", "hodl_hana", "goldfish_gus", "copilot_cody", "insider_inu"]
## The moves of each character, played in turn (animations of the Kenney models).
const MOVES := {
	"saving_son": ["emote-yes", "pick-up"],
	"double_dan": ["attack-melee-right"],
	"hodl_hana": ["jump", "interact-right"],
	"goldfish_gus": ["emote-no", "jump"],
	"copilot_cody": ["interact-right", "emote-yes"],
	"insider_inu": ["pick-up", "emote-no"],
}
const MIN_HEIGHT := 56.0
const ASPECT := 0.8    # width / height of one character's cell

var _cells: Array[Control] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("no_fx", true)
	for id: String in IDS:
		var cell := Control.new()
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cell)
		_cells.append(cell)
		var model := CharacterModel.make(id)
		if model == null:
			continue
		var vp := CharacterModel.make_viewport(model, Vector2i(200, 250))
		vp.name = "View"
		cell.add_child(vp)
		var tex := TextureRect.new()
		tex.name = "Tex"
		tex.texture = vp.get_texture()
		tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(tex)
		_idle(model)
		_cycle(model, id, randf_range(0.5, 3.5))


## Lays the row out under `panel` (the menu panel): the same width, from its bottom edge to the bottom of the window.
func fit_under(panel: Control) -> void:
	var rect := panel.get_global_rect()
	var available := size_of_window().y - rect.end.y - 10.0
	visible = available >= MIN_HEIGHT
	if not visible:
		return
	var cell_h := minf(available, rect.size.x / float(IDS.size()) / ASPECT)
	var cell_w := cell_h * ASPECT
	var row_w := cell_w * IDS.size()
	var x0 := rect.position.x + (rect.size.x - row_w) * 0.5
	var y0 := size_of_window().y - cell_h - 6.0
	for i in _cells.size():
		_cells[i].position = Vector2(x0 + cell_w * i, y0)
		_cells[i].size = Vector2(cell_w, cell_h)


func size_of_window() -> Vector2:
	return get_viewport_rect().size


func _idle(model: Node3D) -> void:
	var anim: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if anim != null and anim.has_animation("idle"):
		anim.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
		anim.play("idle")


## Idle, then the next of this character's moves, then idle again, for as long as the menu is open.
func _cycle(model: Node3D, id: String, first_wait: float) -> void:
	var anim: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if anim == null:
		return
	var moves: Array = MOVES[id]
	var n := 0
	await get_tree().create_timer(first_wait).timeout
	while is_inside_tree():
		var move: String = moves[n % moves.size()]
		n += 1
		if anim.has_animation(move):
			anim.get_animation(move).loop_mode = Animation.LOOP_NONE
			anim.play(move)
			await anim.animation_finished
			_idle(model)
		await get_tree().create_timer(randf_range(2.0, 4.0)).timeout
