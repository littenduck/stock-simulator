## A starting character. Same effect/flag mechanism as perks.
## CONTRACT: frozen.
class_name CharacterDef
extends Resource

@export var id: StringName
@export var title_key: String
@export var description_key: String
@export var start_cash: float = 10000.0
@export var effects: Array[PerkEffectDef] = []
@export var flags: Array[StringName] = []
## Perks owned from day 0 (they do not count as a draft pick).
@export var starting_perks: Array[PerkDef] = []
## Profile unlock id required to select this character. Empty = always available.
@export var unlock_id: StringName = &""
## True for the six table-mode seats (rivals draw from these); the classic characters stay out of the table.
@export var table_role: bool = false
## One-line "easy / advanced" hint for the character picker: "easy" or "advanced".
@export var difficulty_tag: String = "easy"
