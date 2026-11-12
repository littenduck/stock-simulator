## A perk. Effects are data; special rules use flags checked via RunModifiers.has_flag().
## CONTRACT: frozen.
class_name PerkDef
extends Resource

enum Rarity { COMMON, RARE, LEGENDARY }

@export var id: StringName
@export var title_key: String
@export var description_key: String
@export var rarity: Rarity = Rarity.COMMON
@export var icon: Texture2D
@export var effects: Array[PerkEffectDef] = []
## Special-logic switches, e.g. &"insider_friend", &"iron_hands". See docs/team/CONTRACTS.md for the list.
@export var flags: Array[StringName] = []
