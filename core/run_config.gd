## Everything that identifies one run before it starts: character, difficulty, seed.
## CONTRACT: frozen.
class_name RunConfig
extends RefCounted

const TRADING_DAYS := 60
const DRAFT_EVERY_DAYS := 10
const COMPANIES_PER_RUN := 6

var character: CharacterDef
## 1 = easiest. Levels above 1 are P2 content.
var difficulty: int = 1
var seed_value: int = 0
## Fixed per run. When false: no short selling and leverage 1x (ModifiersBuilder enforces it).
var margin_enabled: bool = false


static func make(p_character: CharacterDef, p_difficulty: int = 1, p_seed: int = 0, p_margin_enabled: bool = false) -> RunConfig:
	var c := RunConfig.new()
	c.character = p_character
	c.difficulty = p_difficulty
	c.seed_value = p_seed if p_seed != 0 else randi()
	c.margin_enabled = p_margin_enabled
	return c
