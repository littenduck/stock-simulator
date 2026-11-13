## One fictional listed company (static data). Runtime price lives in MarketSim.
## CONTRACT: frozen. Fields may only be added by the lead.
class_name CompanyDef
extends Resource

## Globally unique ticker, e.g. "NOVA". Used as key in saves and orders.
@export var symbol: String = ""
## Localization key, e.g. "COMPANY_NVDO".
@export var display_name: String = ""
## "tech" / "space" / "consumer" / "finance" (used by sector news, Sector Fan and the UI theme colours)
@export var sector: String = ""
## Pixel icon id drawn by the UI (e.g. "chip", "rocket"). Purely visual.
@export var icon: String = ""
## Column prefix of the real stock in data/market/history.csv (e.g. "NVDA"). Empty = no real data (GBM fallback).
@export var history_key: String = ""
## Placeholder / fallback only: runs with real history start at the real close of the window's first day.
@export_range(1.0, 10000.0) var start_price: float = 50.0
## Annualised drift. 0.08 = +8% per year on average.
@export_range(-0.5, 0.5) var annual_drift: float = 0.06
## Annualised volatility. 0.2 = calm, 0.6 = wild.
@export_range(0.01, 2.0) var annual_volatility: float = 0.3
## Profile unlock id required to appear in the pool. Empty = always available.
@export var unlock_id: StringName = &""
