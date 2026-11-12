## Fails if a role removed or re-shaped a frozen public method. Lead-owned.
## Format: script path -> {method name: argument count}.
extends TestCase

const CONTRACTS := {
	"res://core/market/market_sim.gd": {"_init": 3, "draw_companies": 4, "symbols": 0, "sectors": 0, "has_symbol": 1, "company_of": 1, "price_of": 1, "history_of": 1, "day_change": 1, "set_price": 2, "apply_news": 2, "step": 0, "to_dict": 0, "load_dict": 1},
	"res://core/market/price_model.gd": {"next_price": 4},
	"res://core/news/news_director.gd": {"_init": 2, "roll": 3, "due": 1, "pending": 0, "to_dict": 0, "load_dict": 1},
	"res://core/news/rumor.gd": {"impact_scale": 0, "to_dict": 0},
	"res://core/portfolio/portfolio.gd": {"_init": 1, "shares_of": 1, "held_symbols": 0, "apply_fill": 4, "long_value": 1, "short_value": 1, "net_worth": 1, "gross_exposure": 1, "liquidate_all": 1, "to_dict": 0, "load_dict": 1},
	"res://core/trading/trade_service.gd": {"execute": 4},
	"res://core/trading/order_book.gd": {"place": 1, "cancel": 1, "cancel_all": 0, "pending": 0, "process": 3, "to_dict": 0, "load_dict": 1},
	"res://core/trading/daily_effects.gd": {"apply": 3},
	"res://core/trading/margin.gd": {"check": 4},
	"res://core/perks/perk_drafter.gd": {"_init": 2, "offer": 2},
	"res://core/perks/modifiers_builder.gd": {"build": 2},
	"res://core/meta/profile.gd": {"is_unlocked": 1, "record_run": 2, "to_dict": 0, "load_dict": 1},
	"res://core/meta/difficulty.gd": {"apply": 2},
	"res://core/game_session.gd": {"_init": 5, "start": 0, "next_day": 0, "submit": 1, "cancel_order": 1, "choose_perk": 1, "net_worth": 0, "score": 0, "is_finished": 0, "to_dict": 0, "from_dict": 5},
	"res://core/content_db.gd": {"companies": 0, "news": 0, "perks": 0, "characters": 0, "perk_by_id": 1, "character_by_id": 1},
	"res://autoload/game_manager.gd": {"start_run": 1, "continue_run": 0, "has_saved_run": 0, "next_day": 0, "submit_order": 1, "cancel_order": 1, "choose_perk": 1, "abandon_run": 0, "go_to_menu": 0, "open_scene": 1},
	"res://autoload/save_manager.gd": {"save_run": 1, "has_run": 0, "load_run_data": 0, "delete_run": 0, "save_profile": 0, "reset_profile": 0},
}

const SIGNALS := ["state_changed", "day_advanced", "prices_updated", "portfolio_changed", "rumor_posted", "rumor_resolved", "order_placed", "order_filled", "order_cancelled", "trade_failed", "margin_called", "draft_offered", "perks_changed", "run_finished"]


func test_frozen_methods_exist_with_same_arity() -> void:
	for path in CONTRACTS:
		var found := _scan_methods(path)
		for method in CONTRACTS[path]:
			checks += 1
			if not found.has(method):
				failures.append("%s lost method %s()" % [path, method])
			elif found[method] != CONTRACTS[path][method]:
				failures.append("%s.%s() now takes %d args, contract says %d" % [path, method, found[method], CONTRACTS[path][method]])


## Reads method names and argument counts from the source text. Text based on purpose:
## autoload scripts cannot be compiled outside a running game.
func _scan_methods(path: String) -> Dictionary:
	var out := {}
	var src := FileAccess.get_file_as_string(path)
	var re := RegEx.new()
	re.compile("(?s)\\bfunc\\s+(\\w+)\\s*\\((.*?)\\)\\s*(?:->[^:]*)?:")
	for m in re.search_all(src):
		out[m.get_string(1)] = _count_args(m.get_string(2))
	return out


func _count_args(params: String) -> int:
	params = params.strip_edges().trim_suffix(",")
	if params == "":
		return 0
	var depth := 0
	var n := 1
	for ch in params:
		if ch in "[(":
			depth += 1
		elif ch in "])":
			depth -= 1
		elif ch == "," and depth == 0:
			n += 1
	return n


func test_event_bus_signals() -> void:
	var script: GDScript = load("res://autoload/event_bus.gd")
	var names: Array[String] = []
	for s in script.get_script_signal_list():
		names.append(s.name)
	for sig in SIGNALS:
		assert_true(sig in names, "EventBus lost signal %s" % sig)
