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
