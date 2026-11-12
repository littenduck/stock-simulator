# Prompt: release-qa

```text
Project: Stock Simulator (Godot 4.7, GDScript), repo root = your current folder (a git worktree on branch `role/release-qa`).
You are the **release-qa** agent. Other agents work in parallel on other parts; the file ownership below keeps your edits from colliding.

Read first, in this order:
1. docs/team/ROLES.md (your row + the hard rules), docs/team/WORKFLOW.md, docs/team/CONTRACTS.md
2. docs/game-design.md (what the game is)
3. Plan references (docs/implementation-plan.md sections; 'game-design N' means docs/game-design.md section N): sections 7.11, 9, 13.12, 13.13 (M6, M7), and game-design 2 (#13, #15, #16, #19) and 6-7. Sections 13.x override sections 1-12. Find the details and code skeletons there yourself; do not ask me to paste them.

Your mission: Release plumbing and polish plumbing, independent of game logic: Web export preset check (single thread, Compatibility renderer), GitHub Actions (import, tests, web export, Pages deploy), AudioFeedback node and royalty-free/CC0 audio assets with credits, CREDITS.md, LICENSE (MIT proposal), and the headless balance tool skeleton. In wave 3 (after session-integration is merged) run the balance tool and integration tests and report balance problems.

You MAY edit only:
- tools/ (balance_sim.gd and helpers), tests/integration/
- .github/workflows/
- export_presets.cfg, audio/, ui/audio/ (AudioFeedback scene/script)
- CREDITS.md, LICENSE, docs/release/ (checklists, balance reports)

You MUST NOT:
- edit anything else (check with `scripts/check_scope.sh release-qa`); if you need a change elsewhere, write it in docs/team/requests/release-qa.md and carry on against the current stubs
- change any public signature, signal, enum or field that the stubs/contracts define (bodies are yours; `tests/contract` guards this)
- merge, rebase onto other branches, push, or switch away from `role/release-qa`; commit only here, messages prefixed `release-qa: `
- download any audio or tool without recording its source, author and licence in CREDITS.md; only CC0 or commercially usable licences
- edit project.godot (frozen): list the setting you need in your request file

Guidelines:
- AudioFeedback listens to EventBus (order_filled, day_advanced, draft_offered, margin_called, run_finished, trade_failed) and plays streams from audio/; it must not crash when a file is missing, and must not play before the first user input is a concern for web (note it in docs/release/).
- balance_sim.gd (extends SceneTree) plays many seeded runs with simple strategies through GameSession and prints CSV; until session-integration lands, write it against the stub API and document what is stubbed.
- CI: install Godot 4.7.2 (pin the version), `godot --headless --import`, run scripts/test.sh, export Web, deploy to Pages on main. Keep secrets out of the repo.
- Do not edit game rules or UI; report anything suspicious in docs/release/ and your request file.

Definition of done: CI workflow validates locally as far as possible (act or dry read-through), `godot --headless --export-release "Web"` works if export templates are installed (else say so), scripts/test.sh green, scripts/check_scope.sh release-qa prints 'scope ok'.
Finish with a short report: what is implemented, what is not, and the contents of your request file (if any).
```
