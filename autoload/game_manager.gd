## State machine + the only bridge between UI and rules. Turn based: nothing happens until the
## player acts. Holds the current GameSession and translates DayReports into EventBus signals.
## CONTRACT: public signatures frozen. Owner of the body: session-integration.
## Autoload scripts must not declare class_name.
## STUB: scene switching only.
extends Node

enum State { MENU, PLAYING, DRAFTING, GAME_OVER }

const MAIN_MENU_SCENE := "res://ui/main_menu/main_menu.tscn"
const RUN_SETUP_SCENE := "res://ui/run_setup/run_setup.tscn"
const GAME_SCENE := "res://ui/game_screen/game_screen.tscn"
const HIGH_SCORES_SCENE := "res://ui/high_scores/high_scores.tscn"

var state: State = State.MENU
## Read-only for UI. Null in the menu.
var session: GameSession


func _unhandled_input(event: InputEvent) -> void:
	if state == State.PLAYING and event.is_action_pressed("next_day"):
		next_day()


func start_run(_config: RunConfig) -> void:
	push_warning("STUB GameManager.start_run")


## Resumes the saved run. Returns false if there is none.
func continue_run() -> bool:
	return false


func has_saved_run() -> bool:
	return SaveManager.has_run()


## Advance one trading day (only in PLAYING).
func next_day() -> void:
	pass


## Market orders fill now; limit/stop orders are queued. Failures also emit EventBus.trade_failed.
func submit_order(order: Order) -> TradeResult:
	return TradeResult.fail("TRADE_ERR_NOT_IMPLEMENTED", order)


func cancel_order(order_id: int) -> bool:
	return session != null and session.cancel_order(order_id)


func choose_perk(_perk: PerkDef) -> void:
	pass


## Throws the current run away (no score is recorded) and returns to the menu.
func abandon_run() -> void:
	go_to_menu()


func go_to_menu() -> void:
	_change_state(State.MENU)
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func open_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)


func _change_state(new_state: State) -> void:
	state = new_state
	EventBus.state_changed.emit(new_state)
