## Single place where the screen sends commands. Defaults to GameManager; the dev harness
## overrides the callables because the real GameManager arrives in wave 2.
class_name GameCommands
extends RefCounted

static var submit_override: Callable
static var next_day_override: Callable
static var cancel_override: Callable


static func submit_order(order: Order) -> TradeResult:
	if submit_override.is_valid():
		return submit_override.call(order)
	return GameManager.submit_order(order)


static func next_day() -> void:
	if next_day_override.is_valid():
		next_day_override.call()
		return
	GameManager.next_day()


static func cancel_order(order_id: int) -> bool:
	if cancel_override.is_valid():
		return cancel_override.call(order_id)
	return GameManager.cancel_order(order_id)
