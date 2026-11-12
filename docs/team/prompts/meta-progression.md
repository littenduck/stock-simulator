# Prompt: meta-progression

```text
Project: Stock Simulator (Godot 4.7, GDScript), repo root = your current folder (a git worktree on branch `role/meta-progression`).
You are the **meta-progression** agent. Other agents work in parallel on other parts; the file ownership below keeps your edits from colliding.

Read first, in this order:
1. docs/team/ROLES.md (your row + the hard rules), docs/team/WORKFLOW.md, docs/team/CONTRACTS.md
2. docs/game-design.md (what the game is)
3. Plan references (docs/implementation-plan.md sections; 'game-design N' means docs/game-design.md section N): sections 13.5, 13.1, 13.3, 13.11 (profile.json), and game-design 2 (#5, #7, #11, #12, #20) and 5.2-5.4. Sections 13.x override sections 1-12. Find the details and code skeletons there yourself; do not ask me to paste them.

Your mission: Everything that changes between runs and between picks: perk drafting, building RunModifiers from character + difficulty + perks, the 15 perks, 3 characters, difficulty levels, and the Profile (unlocks and local top 10).

You MAY edit only:
- core/perks/perk_drafter.gd, core/perks/modifiers_builder.gd (NOT core/perks/run_modifiers.gd, it is frozen)
- core/meta/
- data/perks/ (15 perks with the exact effects of game-design 5.2), data/characters/ (3 characters of 5.3)
- localization/perks.csv, localization/characters.csv
- tests/unit/perks/, tests/unit/meta/

You MUST NOT:
- edit anything else (check with `scripts/check_scope.sh meta-progression`); if you need a change elsewhere, write it in docs/team/requests/meta-progression.md and carry on against the current stubs
- change any public signature, signal, enum or field that the stubs/contracts define (bodies are yours; `tests/contract` guards this)
- merge, rebase onto other branches, push, or switch away from `role/meta-progression`; commit only here, messages prefixed `meta-progression: `
- add fields to RunModifiers: if a perk cannot be expressed with the existing fields or the flags in CONTRACTS.md, write the request instead

Guidelines:
- Implement PerkDrafter (rarity weights 60/30/10, no duplicates, deterministic), ModifiersBuilder (order: base, character, difficulty, starting perks, owned perks), Difficulty.apply (cumulative penalties from game-design 5.4), Profile.record_run (top 10 sorted, total_runs, unlock rules from 5.3 and the unlockable companies/difficulties).
- Perks are data: write .tres files by copying the format of data/perks/low_fees.tres (op enum: ADD=0, MULTIPLY=1, SET=2). Special perks use the flags table in CONTRACTS.md.
- Write one test per perk that builds modifiers and checks the changed numbers/flags, plus tests for drafter determinism/weights, profile ordering and unlock rules.
- Unlock ids you invent must be listed at the top of core/meta/profile.gd as constants; CompanyDef/CharacterDef.unlock_id refer to them.

Definition of done: scripts/test.sh green and scripts/check_scope.sh meta-progression prints 'scope ok'; all 15 perks and 3 characters load via ContentDb and have localization keys.
Finish with a short report: what is implemented, what is not, and the contents of your request file (if any).
```
