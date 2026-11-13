## State machine + the only bridge between UI and rules. Turn based: nothing happens until the
## player acts. Holds the current GameSession and translates DayReports into EventBus signals.
## CONTRACT: public signatures frozen. Owner of the body: session-integration.
## Autoload scripts must not declare class_name.
extends Node

enum State { MENU, PLAYING, DRAFTING, GAME_OVER }

const MAIN_MENU_SCENE := "res://ui/main_menu/main_menu.tscn"
const RUN_SETUP_SCENE := "res://ui/run_setup/run_setup.tscn"
const GAME_SCENE := "res://ui/game_screen/game_screen.tscn"
const TABLE_SCENE := "res://ui/table/table_screen.tscn"
const HIGH_SCORES_SCENE := "res://ui/high_scores/high_scores.tscn"
const SETTINGS_SCENE := "res://ui/main_menu/settings.tscn"

var state: State = State.MENU
## Read-only for UI. Null in the menu.
var session: GameSession


func _unhandled_input(event: InputEvent) -> void:
	# Table mode has no Space shortcut: the turn is moved by the Next button at the bottom.
	if state == State.PLAYING and not session is TableSession and event.is_action_pressed("next_day"):
		next_day()


## True from the start of a new table run until its screen has played (or skipped) the opening.
var opening_pending: bool = false


func start_run(config: RunConfig) -> void:
	if config == null or config.character == null:
		return
	if config.mode == RunConfig.Mode.TABLE:
		session = TableSession.new(config, ContentDb.companies(), ContentDb.perks(), ContentDb.news(), _unlocked_ids())
	else:
		session = GameSession.new(config, ContentDb.companies(), ContentDb.perks(), ContentDb.news(), _unlocked_ids())
	session.start()
	if session is TableSession:
		(session as TableSession).strict_windows = true
	opening_pending = config.mode == RunConfig.Mode.TABLE
	SaveManager.save_run(session)
	_enter_game()


## Resumes the saved run. Returns false if there is none.
func continue_run() -> bool:
	opening_pending = false
	var data := SaveManager.load_run_data()
	if data.is_empty():
		return false
	var config := GameSession.config_from_dict(data)
	if config == null:
		return false
	var loaded: GameSession
	if config.mode == RunConfig.Mode.TABLE:
		loaded = TableSession.from_dict(data, config, ContentDb.companies(), ContentDb.perks(), ContentDb.news())
	else:
		loaded = GameSession.from_dict(data, config, ContentDb.companies(), ContentDb.perks(), ContentDb.news())
	if loaded == null or loaded.is_finished():
		SaveManager.delete_run()
		return false
	session = loaded
	if session is TableSession:
		(session as TableSession).strict_windows = true
	_enter_game()
	return true


func has_saved_run() -> bool:
	return SaveManager.has_run()


## Advance one trading day (only in PLAYING).
func next_day() -> void:
	if state != State.PLAYING or session == null:
		return
	if session is TableSession:
		_table_next()
		return
	var report := session.next_day()
	_emit_report(report)
	if report.finished:
		_finish_run()
		return
	SaveManager.save_run(session)
	if not report.draft_offer.is_empty():
		_change_state(State.DRAFTING)
		EventBus.draft_offered.emit(report.draft_offer)


## Table mode: the first press reveals everybody's bets, the second one resolves the day.
func _table_next() -> void:
	var table := session as TableSession
	if table.phase == TableSession.Phase.ACTION:
		var entries := table.reveal()
		SaveManager.save_run(table)
		EventBus.portfolio_changed.emit()
		EventBus.table_revealed.emit(entries)
	elif table.phase == TableSession.Phase.REVEALED:
		var report := table.advance()
		_emit_report(report)
		EventBus.table_resolved.emit(report)
		if report.finished:
			_finish_run()
			return
		SaveManager.save_run(table)


## Table mode: something the player did (a call, a skill, a trade) changed the state.
func table_refresh() -> void:
	if session == null:
		return
	SaveManager.save_run(session)
	EventBus.portfolio_changed.emit()
	EventBus.table_changed.emit()


## Market orders fill now; limit/stop orders are queued. Failures also emit EventBus.trade_failed.
func submit_order(order: Order) -> TradeResult:
	if state != State.PLAYING or session == null:
		return TradeResult.fail("TRADE_ERR_NOT_IMPLEMENTED", order)
	var result := session.submit(order)
	if not result.ok:
		EventBus.trade_failed.emit(result.reason)
		return result
	if result.pending:
		EventBus.order_placed.emit(order)
	else:
		EventBus.order_filled.emit(order, result)
		EventBus.portfolio_changed.emit()
	SaveManager.save_run(session)
	return result


func cancel_order(order_id: int) -> bool:
	if session == null or state != State.PLAYING:
		return false
	var ok := session.cancel_order(order_id)
	if ok:
		EventBus.order_cancelled.emit(order_id)
		SaveManager.save_run(session)
	return ok


func choose_perk(perk: PerkDef) -> void:
	if state != State.DRAFTING or session == null or perk not in session.pending_draft:
		return
	session.choose_perk(perk)
	SaveManager.save_run(session)
	EventBus.perks_changed.emit()
	EventBus.portfolio_changed.emit()
	_change_state(State.PLAYING)


## Throws the current run away (no score is recorded) and returns to the menu.
func abandon_run() -> void:
	SaveManager.delete_run()
	session = null
	go_to_menu()


func go_to_menu() -> void:
	_change_state(State.MENU)
	UiFx.change_scene(get_tree(), MAIN_MENU_SCENE)


func open_scene(path: String) -> void:
	UiFx.change_scene(get_tree(), path)


func _unlocked_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in SaveManager.profile.unlocked.keys():
		out.append(StringName(id))
	return out


## Switches to the game scene; once it is loaded (its overlays listen to EventBus) sends the
## current state: prices, and the open draft if there is one.
func _enter_game() -> void:
	_change_state(State.DRAFTING if not session.pending_draft.is_empty() else State.PLAYING)
	await UiFx.change_scene(get_tree(), TABLE_SCENE if session is TableSession else GAME_SCENE)
	# change_scene_to_file is deferred; wait until the new scene's _ready has run.
	await get_tree().process_frame
	await get_tree().process_frame
	if session == null:
		return
	EventBus.day_advanced.emit(session.day)
	EventBus.prices_updated.emit()
	EventBus.portfolio_changed.emit()
	if not session is TableSession:
		EventBus.perks_changed.emit()    # table mode has no perks: no pick sound either
	EventBus.table_changed.emit()
	for r in session.news.pending():
		EventBus.rumor_posted.emit(r)
	for o in session.book.pending():
		EventBus.order_placed.emit(o)
	if state == State.DRAFTING:
		EventBus.draft_offered.emit(session.pending_draft)


func _emit_report(report: DayReport) -> void:
	EventBus.day_advanced.emit(report.day)
	for r in report.resolved_rumors:
		r.resolved = true
		EventBus.rumor_resolved.emit(r)
	EventBus.prices_updated.emit()
	for res in report.fills:
		if res.ok:
			EventBus.order_filled.emit(res.order, res)
		else:
			EventBus.order_cancelled.emit(res.order.id)
			EventBus.trade_failed.emit(res.reason)
	if report.margin_called:
		EventBus.margin_called.emit()
	for r in report.new_rumors:
		EventBus.rumor_posted.emit(r)
	EventBus.portfolio_changed.emit()


func _finish_run() -> void:
	var final_score := session.score()
	# Profile first: the game-over dialog reads rank and unlocks from it.
	SaveManager.profile.record_run(final_score, session.config)
	SaveManager.save_profile()
	SaveManager.delete_run()
	_change_state(State.GAME_OVER)
	EventBus.run_finished.emit(final_score)


func _change_state(new_state: State) -> void:
	state = new_state
	EventBus.state_changed.emit(new_state)
