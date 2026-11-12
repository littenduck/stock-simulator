## Pure rules for the share-quantity text of the order ticket: parsing, validation and the quick-chip
## maths. No nodes and no autoloads, so it runs in unit tests. The player's text is the source of truth:
## whatever is in the box right now is what a Buy/Sell press orders (no Enter needed).
class_name OrderEntry
extends RefCounted

enum Status { OK, EMPTY, NOT_A_NUMBER, ZERO, TOO_BIG, OVER_MAX, NOTHING_TO_TRADE }

const MAX_SHARES := 1000000


## Whole shares from the box text (spaces and thousands commas allowed), or -1 when it is not a plain
## positive-or-zero integer.
static func parse(text: String) -> int:
	var t: String = text.strip_edges().replace(",", "").replace(" ", "")
	if t == "" or not t.is_valid_int():
		return -1
	var n: int = t.to_int()
	return n if n >= 0 else -1


## `max_shares` < 0 = unknown (never complains). `hard` = the max is certain (an order above it is
## certain to be rejected); otherwise going over only warns (OVER_MAX) because leverage makes it an estimate.
static func status(text: String, max_shares: int = -1, hard: bool = true) -> Status:
	if text.strip_edges() == "":
		return Status.EMPTY
	var n: int = parse(text)
	if n < 0:
		return Status.NOT_A_NUMBER
	if n == 0:
		return Status.ZERO
	if n > MAX_SHARES:
		return Status.TOO_BIG
	if max_shares == 0 and hard:
		return Status.NOTHING_TO_TRADE
	if max_shares >= 0 and n > max_shares:
		return Status.OVER_MAX
	return Status.OK


## Can a Buy/Sell press go through with this text?
static func is_submittable(status_value: Status, hard: bool) -> bool:
	match status_value:
		Status.OK:
			return true
		Status.OVER_MAX:
			return not hard
	return false


## Localization key of the inline message ("" = nothing to say).
static func message_key(status_value: Status, hard: bool) -> String:
	match status_value:
		Status.EMPTY:
			return "UI_GAME_ERR_EMPTY"
		Status.NOT_A_NUMBER:
			return "UI_GAME_ERR_NOT_NUMBER"
		Status.ZERO:
			return "UI_GAME_ERR_SHARES"
		Status.TOO_BIG:
			return "UI_GAME_ERR_TOO_BIG"
		Status.OVER_MAX:
			return "UI_GAME_ERR_OVER_MAX" if hard else "UI_GAME_WARN_OVER_MAX"
		Status.NOTHING_TO_TRADE:
			return "UI_GAME_ERR_NOTHING"
	return ""


## Current number plus `delta`, never below 1 (an unreadable box counts as 0).
static func stepped(text: String, delta: int) -> int:
	return clampi(maxi(parse(text), 0) + delta, 1, MAX_SHARES)


## `fraction` of the max, at least 1 share.
static func fraction_of(max_shares: int, fraction: float) -> int:
	return clampi(int(floor(maxf(float(max_shares), 0.0) * fraction)), 1, MAX_SHARES)


## The order for "what is typed in the box right now". null when the text is not a positive whole number.
## The order panel builds every order through here, so a click right after typing orders the typed amount.
static func build_order(side: Order.Dir, kind: int, symbol: String, text: String, trigger: float) -> Order:
	var n: int = parse(text)
	if n <= 0 or n > MAX_SHARES or symbol == "":
		return null
	match kind:
		Order.Kind.LIMIT:
			return Order.limit(side, symbol, n, trigger)
		Order.Kind.STOP:
			return Order.stop(side, symbol, n, trigger)
	return Order.market(side, symbol, n)
