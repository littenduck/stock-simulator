## Difficulty levels (P2 content). Level 1 changes nothing.
## CONTRACT: signature frozen. Owner of the body: meta-progression.
class_name Difficulty
extends RefCounted

const MAX_LEVEL := 5


## Applies the cumulative penalties of `level` to mods. Called by ModifiersBuilder.
static func apply(_level: int, _mods: RunModifiers) -> void:
	pass
