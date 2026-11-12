# ui-flow requests

1. **Profile must be updated before `EventBus.run_finished` is emitted** (session-integration).
   GameOverDialog reads rank from `SaveManager.profile.top_scores` and new unlocks by diffing
   `SaveManager.profile.unlocked` against a snapshot taken when the game screen loads.
   If `record_run` runs after the signal, rank shows "Not in your top 10" and unlocks are empty.
2. **Unlock id conventions** (meta-progression): RunSetup treats a difficulty level N > 1 as unlocked when
   `profile.is_unlocked(&"difficulty_N")`. Characters use `CharacterDef.unlock_id`. Unlock hint text is looked up
   as `UI_FLOW_UNLOCK_HINT_<CHARACTER_ID upper>` (day_trader, value_investor exist); other ids get a generic text.
3. **Optional**: `GameManager.start_run` must also switch to `GAME_SCENE` (the setup screen only calls it).
4. **CREDITS.md (release-qa):** please credit "Pixel UI Pack" by Kenney (www.kenney.nl), CC0, used in `ui/theme/assets/kenney_pixel-ui-pack/`
   (and the 2x copies in `ui/theme/assets/ui_2x/`). Kenney's other downloaded packs (audio, icons, emotes) are not in this branch.
5. **Black bars on the web page (lead, `project.godot`):** with the current `display/window/stretch/mode="canvas_items"` and the default
   aspect ("keep"), any browser window that is not 16:9 gets black bars top/bottom (or left/right). Please add
   `window/stretch/aspect="expand"` under `[display]`. All ui-flow scenes anchor full-rect, so they fill the extra space; ui-gameplay
   should check its layout still works with a taller or wider viewport.

## Settings screen / margin switch (added with the Settings screen)

The main menu now has Settings (`ui/main_menu/settings.tscn`, `settings.gd`) backed by `GameSettings`
(`ui/main_menu/game_settings.gd`, static class, file `user://settings.cfg`). `ui/settings/` is not in `owners.txt`,
so the screen lives under `ui/main_menu/`. Switches: Margin trading (default OFF), master volume (0-100 %, 0 = muted),
Fullscreen (hidden on web). Buying and selling are not switchable. `GameSettings.margin_enabled()` is the source of truth.

6. **RunConfig (lead, frozen): add `margin_enabled`.** Proposed:
   `var margin_enabled: bool = false` and `static func make(p_character, p_difficulty := 1, p_seed := 0, p_margin_enabled := false) -> RunConfig`
   (extra optional parameter, so existing callers still compile). Why: the rule must be fixed per run and travel with the
   config into `GameSession`/save files. Once it exists, RunSetup passes `GameSettings.margin_enabled()` (one-line change in
   `run_setup.gd:_on_start_button_pressed`; ask me or the lead to do it after merge). Saved runs must store the flag
   (session-integration) so Continue keeps the original setting even if the player changes Settings later.
7. **ModifiersBuilder (meta-progression):** `ModifiersBuilder.build(config, perks, ...)` must, when `not config.margin_enabled`,
   produce `can_short = false` and `max_leverage = 1.0` regardless of character or perk bonuses (apply as the last step, so
   `margin_account` cannot raise it). When enabled, behaviour is unchanged. The ui-gameplay screen already hides short/leverage
   UI for exactly these values.
8. **PerkDrafter (meta-progression):** `PerkDrafter.draft(...)` must skip perks that only matter with margin
   (`margin_account`, `cheap_borrow`, `iron_hands`, `value_investor`) when margin is off. Proposed: give the drafter the flag,
   e.g. a `margin_enabled: bool = true` parameter on the draft call (or a `requires_margin` bool on `PerkDef`, lead-owned,
   which is the cleaner data-driven option), and filter before the weighted pick. Keep a fallback so a draft never has
   fewer than 3 choices because of this filter.
9. **Apply settings at startup (lead):** `GameSettings.apply_once()` is called from the main menu `_ready`, which is enough
   because the menu is the first scene. If another entry scene is ever used, call it from there. No autoload needed.
10. **Audio buses (release-qa), optional:** only `Master` exists, so Settings has one volume. If separate Music/SFX buses are
    added later, tell ui-flow and the screen gets two steppers.
11. **GameManager (session-integration), optional:** a `SETTINGS_SCENE` constant next to the other scene paths; ui-flow
    currently keeps the path in `main_menu.gd`.
12. **Run-setup hint:** RunSetup shows "Margin trading: On/Off" read-only under the difficulty text. Until item 6 lands the
    value is only informational (the run does not yet use it).
