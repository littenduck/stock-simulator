## A rumor template. Becomes a Rumor at runtime; resolves 1-3 days later.
## CONTRACT: frozen. Fields may only be added by the lead.
class_name NewsEventDef
extends Resource

@export var id: String = ""
## Localization key of the headline, e.g. "NEWS_TECH_BREAKTHROUGH".
@export var headline_key: String = ""
## Sector hit by the event; "" = not sector based, "all" = whole market.
@export var target_sector: String = ""
## Single ticker hit; if not empty it wins over target_sector.
@export var target_symbol: String = ""
## Total price impact if true. +0.20 = about +20%, -0.15 = about -15%.
@export_range(-0.9, 2.0) var total_impact: float = 0.1
## Number of days the impact is spread over.
@export_range(1, 60) var duration_days: int = 5
## Chance per day that this template fires (0..1).
@export_range(0.0, 1.0) var daily_chance: float = 0.03
@export_range(0, 365) var cooldown_days: int = 30
## Earliest day it may fire.
@export_range(0, 365) var min_day: int = 0
## Base probability that the rumor is true.
@export_range(0.0, 1.0) var truth_chance: float = 0.6
## When the rumor turns out false: counter-impact as a ratio of total_impact (e.g. -0.2).
@export_range(-1.0, 0.0) var denial_impact_ratio: float = -0.2
