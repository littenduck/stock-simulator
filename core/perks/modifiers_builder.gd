## Builds RunModifiers from scratch: base values, character, difficulty, starting perks, owned perks (in that order).
## Saves store only ids; loading rebuilds with this function.
## CONTRACT: signature frozen. Owner of the body: meta-progression.
class_name ModifiersBuilder
extends RefCounted


static func build(config: RunConfig, owned_perks: Array[PerkDef]) -> RunModifiers:
	var mods := RunModifiers.new()
	var applied: Array[StringName] = []
	if config.character != null:
		mods.apply_effects(config.character.effects, config.character.flags, config.character.id)
	Difficulty.apply(config.difficulty, mods)
	if config.character != null:
		for perk in config.character.starting_perks:
			if perk.id not in applied:
				applied.append(perk.id)
				mods.apply(perk)
	for perk in owned_perks:
		if perk.id not in applied:
			applied.append(perk.id)
			mods.apply(perk)
	if not config.fees_enabled:
		mods.fee_rate = 0.0
	if not config.margin_enabled:
		mods.can_short = false
		mods.max_leverage = 1.0
	return mods
