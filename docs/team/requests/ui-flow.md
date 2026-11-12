# ui-flow requests

1. **Profile must be updated before `EventBus.run_finished` is emitted** (session-integration).
   GameOverDialog reads rank from `SaveManager.profile.top_scores` and new unlocks by diffing
   `SaveManager.profile.unlocked` against a snapshot taken when the game screen loads.
   If `record_run` runs after the signal, rank shows "Not in your top 10" and unlocks are empty.
2. **Unlock id conventions** (meta-progression): RunSetup treats a difficulty level N > 1 as unlocked when
   `profile.is_unlocked(&"difficulty_N")`. Characters use `CharacterDef.unlock_id`. Unlock hint text is looked up
   as `UI_FLOW_UNLOCK_HINT_<CHARACTER_ID upper>` (day_trader, value_investor exist); other ids get a generic text.
3. **Optional**: `GameManager.start_run` must also switch to `GAME_SCENE` (the setup screen only calls it).
