## Difficulty levels (P2 content). Level 1 changes nothing; each level adds one penalty on top of the previous.
## CONTRACT: signature frozen. Owner of the body: meta-progression.
##   2: fees +50%   3: rumors 10 points less truthful   4: maintenance margin +10 points
##   5: one draft option fewer (pick 1 of 2).
## Not implemented: "daily volatility +20%" (no RunModifiers field; see docs/team/requests/meta-progression.md).
class_name Difficulty
extends RefCounted

const MAX_LEVEL := 5


## Applies the cumulative penalties of `level` to mods. Called by ModifiersBuilder.
static func apply(level: int, mods: RunModifiers) -> void:
	var lvl := clampi(level, 1, MAX_LEVEL)
	if lvl >= 2:
		mods.fee_rate *= 1.5
	if lvl >= 3:
		mods.rumor_truth_bonus -= 0.10
	if lvl >= 4:
		mods.maintenance_margin += 0.10
	if lvl >= 5:
		mods.draft_choices -= 1
