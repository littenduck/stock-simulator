## Credibility tiers of table-mode rumors and the odds of the two bets (BELIEVE = Buy Call, BULLSHIT = Buy Put).
## The shown percentage is the real chance that the rumor comes true, and the odds are fair for it:
## over many bets BELIEVE and BULLSHIT both break even, so the edge comes from reading the market.
class_name RumorTier
extends RefCounted

enum Tier { LOW, MEDIUM, HIGH }
enum Side { PASS, BELIEVE, BULLSHIT }

const TRUTH := {Tier.LOW: 0.33, Tier.MEDIUM: 0.50, Tier.HIGH: 0.80}
const BELIEVE_ODDS := {Tier.LOW: 3.0, Tier.MEDIUM: 2.0, Tier.HIGH: 1.25}
const BULLSHIT_ODDS := {Tier.LOW: 1.5, Tier.MEDIUM: 2.0, Tier.HIGH: 5.0}
## How often each tier is dealt.
const WEIGHTS: Array[float] = [0.30, 0.40, 0.30]


## Gross payout multiplier of a winning bet (premium * odds comes back).
static func odds(side: int, tier: int) -> float:
	match side:
		Side.BELIEVE:
			return float(BELIEVE_ODDS[tier])
		Side.BULLSHIT:
			return float(BULLSHIT_ODDS[tier])
	return 0.0


static func truth_chance(tier: int) -> float:
	return float(TRUTH[tier])


static func tier_key(tier: int) -> String:
	return ["TIER_LOW", "TIER_MEDIUM", "TIER_HIGH"][clampi(tier, 0, 2)]


## "Low (33%)" in the current language.
static func label(tier: int, translate: Callable) -> String:
	return "%s (%d%%)" % [translate.call(tier_key(tier)), roundi(truth_chance(tier) * 100.0)]
