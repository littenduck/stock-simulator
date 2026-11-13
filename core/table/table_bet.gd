## One option bought on a rumor: the premium is paid up front, a win returns premium * odds, a loss returns nothing.
class_name TableBet
extends RefCounted

var seat_id: int = 0
var rumor_id: int = 0
var side: int = RumorTier.Side.BELIEVE
var premium: float = 0.0
## Effective payout multiplier (tier odds + character bonuses, times the copy discount).
var odds: float = 1.0
## Seat this bet was copied from (Copilot); -1 = a own decision.
var copied_from: int = -1
var doubled: bool = false


## Gross money back when the rumor resolves.
func payout(rumor_true: bool) -> float:
	var won := (side == RumorTier.Side.BELIEVE) == rumor_true
	return premium * odds if won else 0.0


func to_dict() -> Dictionary:
	return {"seat": seat_id, "rumor": rumor_id, "side": side, "premium": premium, "odds": odds, "copied_from": copied_from, "doubled": doubled}


static func from_dict(d: Dictionary) -> TableBet:
	var b := TableBet.new()
	b.seat_id = int(d.get("seat", 0))
	b.rumor_id = int(d.get("rumor", 0))
	b.side = int(d.get("side", 1))
	b.premium = float(d.get("premium", 0.0))
	b.odds = float(d.get("odds", 1.0))
	b.copied_from = int(d.get("copied_from", -1))
	b.doubled = bool(d.get("doubled", false))
	return b
