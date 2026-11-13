## One player at the table (the human is seat 0): character, account and per-quarter skill state.
class_name Seat
extends RefCounted

var id: int = 0
var character: CharacterDef
var is_human: bool = false
var portfolio: Portfolio
var mods: RunModifiers
var alive: bool = true
## Day on which the seat was fired (-1 = still in).
var fired_day: int = -1
## Consecutive won bets (visual only).
var streak: int = 0
## Active skill already used this quarter.
var skill_used: bool = false
## What this seat knows about a rumor: rumor id -> true/false (Insider only).
var knowledge: Dictionary = {}


func has_flag(flag: StringName) -> bool:
	return character != null and flag in character.flags


func title_key() -> String:
	return character.title_key if character != null else ""


func to_dict() -> Dictionary:
	return {
		"id": id, "character": String(character.id), "human": is_human, "portfolio": portfolio.to_dict(),
		"alive": alive, "fired_day": fired_day, "streak": streak, "skill_used": skill_used,
		"knowledge": knowledge.duplicate(), "locked": mods.locked_symbol,
	}
