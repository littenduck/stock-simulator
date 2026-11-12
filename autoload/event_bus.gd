## Global signal bus. Declares signals only: no logic, no state.
## CONTRACT: frozen. Signals may only be added by the lead.
## Autoload scripts must not declare class_name.
extends Node

## GameManager.State value.
signal state_changed(state: int)
signal day_advanced(day: int)
## Prices changed: charts and portfolio values must redraw.
signal prices_updated
## Cash or positions changed.
signal portfolio_changed
signal rumor_posted(rumor: Rumor)
## A rumor was confirmed or debunked (rumor.is_true tells which).
signal rumor_resolved(rumor: Rumor)
signal order_placed(order: Order)
signal order_filled(order: Order, result: TradeResult)
signal order_cancelled(order_id: int)
## reason is a localization key.
signal trade_failed(reason: String)
signal margin_called
## options: Array of PerkDef.
signal draft_offered(options: Array)
signal perks_changed
signal run_finished(score: float)
