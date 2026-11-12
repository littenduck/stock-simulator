# Requests from meta-progression

1. **volatility_mult (done on this branch, needs lead sign-off):** the user approved adding
   `var volatility_mult := 1.0` to `core/perks/run_modifiers.gd` (frozen file, so `check_scope.sh` will
   flag it; the lead should accept this one line when merging). `Difficulty.apply` level 4 sets it to 1.2.
   **market-engine:** `MarketSim.step()` must multiply each company's volatility by `mods.volatility_mult`.
   Until it does, level 4 only raises the maintenance margin.
2. **Unlock ids for companies** (market-engine, set `CompanyDef.unlock_id`): MOON = `company_moon`,
   OLDE = `company_olde`, the other three unlockable companies = `company_extra_1`, `company_extra_2`,
   `company_extra_3` (constants in `core/meta/profile.gd`).
3. **session-integration:** call `Profile.record_run` only for finished (day 60) runs, pass the final
   `score()`; filter characters/companies/difficulties in the UI with `Profile.is_unlocked(def.unlock_id)` and
   `Profile.difficulty_unlock_id(level)`. `ModifiersBuilder` skips a perk already applied as a character
   starting perk, so passing it again in `owned_perks` is harmless.
