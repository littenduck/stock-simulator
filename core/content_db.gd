## Loads every content Resource under data/ (works in editor and in web exports).
## CONTRACT: public signatures frozen. Owner of the body: session-integration.
## Mods later: add a JSON source here, nowhere else.
class_name ContentDb
extends RefCounted

static var _cache: Dictionary = {}


static func companies() -> Array[CompanyDef]:
	var out: Array[CompanyDef] = []
	out.assign(_load_dir("res://data/companies"))
	return out


static func news() -> Array[NewsEventDef]:
	var out: Array[NewsEventDef] = []
	out.assign(_load_dir("res://data/news"))
	return out


static func perks() -> Array[PerkDef]:
	var out: Array[PerkDef] = []
	out.assign(_load_dir("res://data/perks"))
	return out


static func characters() -> Array[CharacterDef]:
	var out: Array[CharacterDef] = []
	out.assign(_load_dir("res://data/characters"))
	return out


static func perk_by_id(id: StringName) -> PerkDef:
	for p in perks():
		if p.id == id:
			return p
	return null


static func character_by_id(id: StringName) -> CharacterDef:
	for c in characters():
		if c.id == id:
			return c
	return null


## Files sorted by name so the order (and therefore RNG draws) is stable.
static func _load_dir(dir_path: String) -> Array:
	if _cache.has(dir_path):
		return _cache[dir_path]
	var names: Array[String] = []
	for f in DirAccess.get_files_at(dir_path):
		# Exported builds list "x.tres.remap" instead of "x.tres".
		var n := f.trim_suffix(".remap")
		if n.ends_with(".tres"):
			names.append(n)
	names.sort()
	var out: Array = []
	for n in names:
		var res := load(dir_path.path_join(n))
		if res != null:
			out.append(res)
	_cache[dir_path] = out
	return out
