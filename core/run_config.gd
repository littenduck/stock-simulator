## Everything that identifies one run before it starts: character, difficulty, seed.
## CONTRACT: frozen.
class_name RunConfig
extends RefCounted

const TRADING_DAYS := 60
const DRAFT_EVERY_DAYS := 10
const COMPANIES_PER_RUN := 6
## Table mode (rivals, daily rumor bets, quarters): 3 quarters of 10 days.
const TABLE_DAYS := 30
const QUARTER_DAYS := 10
const TABLE_SEATS := 4

enum Mode { CLASSIC, TABLE }

var character: CharacterDef
## 1 = easiest. Levels above 1 are P2 content.
var difficulty: int = 1
var seed_value: int = 0
## Fixed per run. When false: no short selling and leverage 1x (ModifiersBuilder enforces it).
var margin_enabled: bool = false
var mode: Mode = Mode.CLASSIC
## Length of this run in trading days (60 classic, 30 table).
var trading_days: int = TRADING_DAYS
## Classic runs charge trading fees; table runs make them a setting (off by default).
var fees_enabled: bool = true


static func make(p_character: CharacterDef, p_difficulty: int = 1, p_seed: int = 0, p_margin_enabled: bool = false) -> RunConfig:
	var c := RunConfig.new()
	c.character = p_character
	c.difficulty = p_difficulty
	c.seed_value = p_seed if p_seed != 0 else randi()
	c.margin_enabled = p_margin_enabled
	return c


## A table-mode run: 30 days, 3 quarters, 3 rivals. No margin trading, fees only when asked for.
static func make_table(p_character: CharacterDef, p_seed: int = 0, p_fees_enabled: bool = false) -> RunConfig:
	var c := RunConfig.make(p_character, 1, p_seed, false)
	c.mode = Mode.TABLE
	c.trading_days = TABLE_DAYS
	c.fees_enabled = p_fees_enabled
	return c
