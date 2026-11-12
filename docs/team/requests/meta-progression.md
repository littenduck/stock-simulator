# Requests from meta-progression

1. **Difficulty 4 "daily volatility +20%" (game-design 5.4) is not implemented.** `RunModifiers` has no
   volatility field. Proposal: add `var volatility_mult := 1.0` to `RunModifiers` and have
   `MarketSim.step()` multiply each company's volatility by it; then `Difficulty.apply` level 4 gets
   `mods.volatility_mult *= 1.2` (one line). Until then levels 2-5 are: fees +50%, rumor truth -10 points,
   maintenance margin +10 points, draft choices -1.
2. **Unlock ids for companies** (market-engine, set `CompanyDef.unlock_id`): MOON = `company_moon`,
   OLDE = `company_olde`, the other three unlockable companies = `company_extra_1`, `company_extra_2`,
   `company_extra_3` (constants in `core/meta/profile.gd`).
3. **session-integration:** call `Profile.record_run` only for finished (day 60) runs, pass the final
   `score()`; filter characters/companies/difficulties in the UI with `Profile.is_unlocked(def.unlock_id)` and
   `Profile.difficulty_unlock_id(level)`. `ModifiersBuilder` skips a perk already applied as a character
   starting perk, so passing it again in `owned_perks` is harmless.
