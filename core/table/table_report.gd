## Everything that happened when a table-mode day was resolved. A DayReport, so GameManager treats it like any other.
class_name TableReport
extends DayReport

## Rumors that resolved today (the daily one, and the Boss rumor on review days).
var resolved_table: Array[TableRumor] = []
## One entry per settled bet: {"seat","rumor","boss","side","premium","payout","won"}.
var payouts: Array[Dictionary] = []
## Seat ids fired at today's quarter review.
var fired_seats: Array[int] = []
var human_fired: bool = false
## The Boss rumor that was announced today (null if none).
var boss_announced: TableRumor
## 1..3 when a quarter ended today, otherwise 0.
var quarter_ended: int = 0
