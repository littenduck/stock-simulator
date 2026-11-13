## The live 3D model of a table character (Kenney Mini Characters, CC0, in ui/theme/models/), used for the opening
## introductions. The game screen itself keeps the flat busts of PortraitView.
## Same looks as the busts: Saving Son has the light skin tone, Goldfish Gus is painted goldfish orange with red fins.
class_name CharacterModel
extends RefCounted

const FOLDER := "res://ui/theme/models/"
const MODELS := {
	"saving_son": "character-male-a",
	"double_dan": "character-male-e",
	"goldfish_gus": "character-male-b",
	"hodl_hana": "character-female-e",
	"copilot_cody": "character-robot",
	"insider_inu": "character-male-d",
}
## The move each character makes when it is introduced, then it settles into the idle loop.
const INTRO_MOVE := {
	"saving_son": "emote-yes",
	"double_dan": "attack-melee-right",
	"goldfish_gus": "jump",
	"hodl_hana": "interact-right",
	"copilot_cody": "emote-yes",
	"insider_inu": "pick-up",
}


static func has_model(character_id: String) -> bool:
	return MODELS.has(character_id) and ResourceLoader.exists(FOLDER + String(MODELS[character_id]) + ".glb")


## A fresh copy of the model, or null when there is none for this character.
static func make(character_id: String) -> Node3D:
	if not has_model(character_id):
		return null
	var scene: PackedScene = load(FOLDER + String(MODELS[character_id]) + ".glb")
	var model := scene.instantiate() as Node3D
	if character_id == "saving_son":
		_light_skin(model)
	elif character_id == "goldfish_gus":
		_goldfish(model)
	return model


## Plays the character's intro move once, then the idle loop.
static func introduce(model: Node3D, character_id: String) -> void:
	var anim: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if anim == null:
		return
	if anim.has_animation("idle"):
		anim.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
	var move: String = INTRO_MOVE.get(character_id, "idle")
	if move != "idle" and anim.has_animation(move):
		anim.get_animation(move).loop_mode = Animation.LOOP_NONE
		anim.play(move)
		anim.animation_finished.connect(func(_n: StringName) -> void:
			if anim.has_animation("idle"):
				anim.play("idle"), CONNECT_ONE_SHOT)
	elif anim.has_animation("idle"):
		anim.play("idle")


## A transparent viewport that shows the model, lit and framed head to toe. Add it to a SubViewportContainer.
static func make_viewport(model: Node3D, px: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = px
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.add_child(model)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 0.43, 3), Vector3(0, 0.43, 0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, 20, 0)
	vp.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.72, 0.72, 0.78)
	vp.add_child(env)
	return vp


## Matte colour with a little self-light, so the added blocks sit next to the pack's palette-lit models.
static func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	m.metallic_specular = 0.0
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.2
	return m


static func _box(parent: Node3D, mat: Material, pos: Vector3, size: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	mi.material_override = mat
	mi.position = pos
	mi.scale = size
	parent.add_child(mi)


## Repaints cells of the shared 8x8 colour grid (64 px cells) of some meshes, for this model only.
static func _repaint(model: Node3D, parts: Array, paint: Dictionary, copy: Dictionary = {}) -> void:
	for part: String in parts:
		var mi: MeshInstance3D = model.find_child(part, true, false)
		if mi == null or mi.mesh == null:
			continue
		var base := mi.mesh.surface_get_material(0) as StandardMaterial3D
		if base == null or base.albedo_texture == null:
			continue
		var mat := base.duplicate() as StandardMaterial3D
		var img: Image = mat.albedo_texture.get_image()
		if img.is_compressed():
			img.decompress()
		for cell: Vector2i in copy:
			var src: Vector2i = copy[cell]
			img.fill_rect(Rect2i(cell.x * 64, cell.y * 64, 64, 64), img.get_pixel(src.x * 64 + 32, src.y * 64 + 32))
		for cell: Vector2i in paint:
			img.fill_rect(Rect2i(cell.x * 64, cell.y * 64, 64, 64), paint[cell])
		mat.albedo_texture = ImageTexture.create_from_image(img)
		mi.set_surface_override_material(0, mat)


static func _light_skin(model: Node3D) -> void:
	_repaint(model, ["head-mesh", "body-mesh"], {}, {Vector2i(1, 4): Vector2i(2, 4), Vector2i(1, 5): Vector2i(2, 5)})


static func _goldfish(model: Node3D) -> void:
	_repaint(model, ["head-mesh"], {Vector2i(2, 4): Color("#ff9244"), Vector2i(2, 5): Color("#ff7c44"),
		Vector2i(0, 5): Color("#ffa75a"), Vector2i(1, 5): Color("#ff7c44")})
	var red := _flat(Color("#f36744"))
	var deep := _flat(Color("#cf534f"))
	_box(model, red, Vector3(0, 0.685, 0.0), Vector3(0.07, 0.07, 0.22))
	_box(model, red, Vector3(0, 0.745, -0.04), Vector3(0.07, 0.07, 0.15))
	_box(model, deep, Vector3(0, 0.8, -0.07), Vector3(0.07, 0.06, 0.09))
	for s in [-1.0, 1.0]:
		_box(model, red, Vector3(0.2 * s, 0.56, 0.0), Vector3(0.07, 0.17, 0.15))
		_box(model, deep, Vector3(0.235 * s, 0.53, -0.02), Vector3(0.05, 0.1, 0.1))
