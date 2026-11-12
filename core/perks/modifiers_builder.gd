## Builds RunModifiers from scratch: base values + character + difficulty + owned perks (in order).
## Saves store only ids; loading rebuilds with this function.
## CONTRACT: signature frozen. Owner of the body: meta-progression.
class_name ModifiersBuilder
extends RefCounted


static func build(config: RunConfig, owned_perks: Array[PerkDef]) -> RunModifiers:
	var mods := RunModifiers.new()
	mods.apply_effects(config.character.effects, config.character.flags, config.character.id)
	for perk in config.character.starting_perks:
		mods.apply(perk)
	for perk in owned_perks:
		mods.apply(perk)
	return mods
