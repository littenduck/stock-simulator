## Decisions of the three computer seats. Simple rules with a personality each; every random choice
## uses the session rng, so a seed always plays out the same way.
class_name NpcBrain
extends RefCounted

const BELIEVE_BY_TIER := {RumorTier.Tier.LOW: 0.2, RumorTier.Tier.MEDIUM: 0.5, RumorTier.Tier.HIGH: 0.75}


## Before the reveal: trades, flips, bets and boss bets of every computer seat, then the Copilot copies.
static func decide(s: TableSession, rng: RandomNumberGenerator) -> void:
	for seat in s.seats:
		if seat.is_human or not seat.alive:
			continue
		_trade(s, seat, rng)
		if seat.has_flag(&"insider") and s.can_flip(seat.id) and rng.randf() < 0.5:
			s.flip_armed[seat.id] = true
		if not seat.has_flag(&"copilot"):
			s.calls[seat.id] = _call(s, seat, rng)
		s.boss_calls[seat.id] = _boss_call(s, seat, rng)
	for seat in s.seats:
		if not seat.is_human and seat.alive and seat.has_flag(&"copilot"):
			s.copy_targets[seat.id] = _leader_other_than(s, seat.id)


## After the reveal, before the result: a computer Double Dan decides whether to double.
static func after_reveal(s: TableSession, rng: RandomNumberGenerator) -> void:
	for seat in s.seats:
		if seat.is_human or not seat.alive or not seat.has_flag(&"double_down") or seat.skill_used:
			continue
		var bet := s.daily_bet_of(seat.id)
		if bet == null:
			continue
		var tier: int = s.today_rumor.tier
		var good := (bet.side == RumorTier.Side.BELIEVE and tier == RumorTier.Tier.HIGH) \
				or (bet.side == RumorTier.Side.BULLSHIT and tier == RumorTier.Tier.LOW) \
				or seat.knowledge.has(s.today_rumor.id)
		if rng.randf() < (0.7 if good else 0.15):
			s.double_down(seat.id)


static func _call(s: TableSession, seat: Seat, rng: RandomNumberGenerator) -> int:
	var rumor := s.today_rumor
	if rumor == null:
		return RumorTier.Side.PASS
	if seat.knowledge.has(rumor.id):
		return RumorTier.Side.BELIEVE if bool(seat.knowledge[rumor.id]) else RumorTier.Side.BULLSHIT
	var p_pass := 0.1
	if seat.has_flag(&"saver"):
		p_pass = 0.35
	elif seat.has_flag(&"double_down"):
		p_pass = 0.0
	if rng.randf() < p_pass:
		return RumorTier.Side.PASS
	return _guess(s, seat, rumor, rng)


static func _boss_call(s: TableSession, seat: Seat, rng: RandomNumberGenerator) -> int:
	var boss := s.boss_rumor
	if boss == null or s.boss_bet_of(seat.id) != null:
		return RumorTier.Side.PASS
	var last_chance := s.day >= boss.resolve_day - 1
	if not last_chance and rng.randf() > 0.4:
		return RumorTier.Side.PASS
	if last_chance and rng.randf() < 0.15:
		return RumorTier.Side.PASS
	return _guess(s, seat, boss, rng)


## Mostly follows the shown tier. Goldfish Gus ignores it, Hodl Hana likes news about her own sector.
static func _guess(s: TableSession, seat: Seat, rumor: TableRumor, rng: RandomNumberGenerator) -> int:
	var p: float = float(BELIEVE_BY_TIER[rumor.tier])
	if seat.has_flag(&"goldfish"):
		p = 0.5
	if seat.mods.locked_symbol != "" and s.sector_of(rumor.primary_symbol()) == s.sector_of(seat.mods.locked_symbol):
		p = minf(0.95, p + 0.2)
	return RumorTier.Side.BELIEVE if rng.randf() < p else RumorTier.Side.BULLSHIT


static func _trade(s: TableSession, seat: Seat, rng: RandomNumberGenerator) -> void:
	if seat.has_flag(&"saver"):
		return
	var symbols := s.market.symbols()
	var nw := seat.portfolio.net_worth(s.market)
	var invested := seat.portfolio.long_value(s.market) / maxf(1.0, nw)
	var target := 0.8 if seat.has_flag(&"double_down") else 0.5
	if invested < target - 0.2 and rng.randf() < 0.5:
		s.buy_fraction(seat.id, symbols[rng.randi_range(0, symbols.size() - 1)], 0.5)
	elif rng.randf() < 0.15:
		var held := seat.portfolio.held_symbols()
		if not held.is_empty():
			s.sell_fraction(seat.id, held[rng.randi_range(0, held.size() - 1)], 0.5)


static func _leader_other_than(s: TableSession, seat_id: int) -> int:
	var best := -1
	var best_nw := -INF
	for seat in s.seats:
		if seat.id == seat_id or not seat.alive:
			continue
		var nw := seat.portfolio.net_worth(s.market)
		if nw > best_nw:
			best_nw = nw
			best = seat.id
	return best
