# Prompt: ui-gameplay

```text
Project: Stock Simulator (Godot 4.7, GDScript), repo root = your current folder (a git worktree on branch `role/ui-gameplay`).
You are the **ui-gameplay** agent. Other agents work in parallel on other parts; the file ownership below keeps your edits from colliding.

Read first, in this order:
1. docs/team/ROLES.md (your row + the hard rules), docs/team/WORKFLOW.md, docs/team/CONTRACTS.md
2. docs/game-design.md (what the game is)
3. Plan references (docs/implementation-plan.md sections; 'game-design N' means docs/game-design.md section N): sections 7.8 (GameScreen, PriceChart, TradePanel pattern), 13.3 (UI part), 13.10, and game-design 2 (#14, #18) and 3. Sections 13.x override sections 1-12. Find the details and code skeletons there yourself; do not ask me to paste them.

Your mission: Build the in-run screen so a player can read the market and act: top bar (day, cash, net worth, Next Day), price chart, stock list, order panel (market/limit/stop, long/short), portfolio view, pending orders with cancel, rumor feed with credibility and outcome, perk bar, keyboard shortcuts.

You MAY edit only:
- ui/game_screen/ (scenes, scripts and any dev harness you create under ui/game_screen/dev/)
- localization/ui_game.csv (UI_GAME_* keys)

You MUST NOT:
- edit anything else (check with `scripts/check_scope.sh ui-gameplay`); if you need a change elsewhere, write it in docs/team/requests/ui-gameplay.md and carry on against the current stubs
- change any public signature, signal, enum or field that the stubs/contracts define (bodies are yours; `tests/contract` guards this)
- merge, rebase onto other branches, push, or switch away from `role/ui-gameplay`; commit only here, messages prefixed `ui-gameplay: `
- remove or rename the Overlays node or its three instances in game_screen.tscn (PerkDraftDialog, GameOverDialog, AudioFeedback belong to other roles)
- edit ui/theme/ (ui-flow's); use the default theme plus local overrides; keep up/down colors in a small ui/game_screen/colors.gd (green up, red down, plus the arrows)

Guidelines:
- UI reads state from GameManager.session and listens to EventBus; it never mutates core objects and never decides rules. Orders go through GameManager.submit_order(Order).
- The real GameManager/GameSession arrive later. Build a dev harness (a scene that constructs a GameSession with sample data and emits the EventBus signals by hand) so you can run and screenshot your screen now. Use the built-in browser or `godot --path .` to check layout at 1280x720 and 1920x1080.
- Use unique node names (%Name), handlers `_on_<signal>`, static typing, `tr()` for every string, up/down shown with colour and arrow.
- Shortcuts: Space = next day, B / S = buy / sell, 1-6 = select stock, Esc = menu (input actions already exist in project.godot).
- Honour the flags: Fact Checker shows credibility_low..high; Insider Friend rumors (is_guaranteed) are marked.

Definition of done: the screen runs with your dev harness, is readable at both resolutions, scripts/test.sh is still green, scripts/check_scope.sh ui-gameplay prints 'scope ok'. Include screenshots paths in your report.
Finish with a short report: what is implemented, what is not, and the contents of your request file (if any).
```
