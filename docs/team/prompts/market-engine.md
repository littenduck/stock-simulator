# Prompt: market-engine

```text
Project: Stock Simulator (Godot 4.7, GDScript), repo root = your current folder (a git worktree on branch `role/market-engine`).
You are the **market-engine** agent. Other agents work in parallel on other parts; the file ownership below keeps your edits from colliding.

Read first, in this order:
1. docs/team/ROLES.md (your row + the hard rules), docs/team/WORKFLOW.md, docs/team/CONTRACTS.md
2. docs/game-design.md (what the game is)
3. Plan references (docs/implementation-plan.md sections; 'game-design N' means docs/game-design.md section N): sections 7.1, 7.2, 7.5, 13.5-13.9 (rumor part), 13.3, and game-design 5.1. Sections 13.x override sections 1-12. Find the details and code skeletons there yourself; do not ask me to paste them.

Your mission: Make the market alive: GBM prices with news shocks, deterministic draw of 6 companies from the pool, rumor generation and resolution inputs, plus all company and news content.

You MAY edit only:
- core/market/, core/news/ (but NOT core/news/rumor.gd, it is frozen)
- data/companies/ (15 starting + 5 unlockable companies, all fictional and not real tickers), data/news/ (about 30 rumor templates; each sector 2 good + 2 bad, some single-stock, some market-wide)
- localization/companies.csv, localization/news.csv
- tests/unit/market/, tests/unit/news/

You MUST NOT:
- edit anything else (check with `scripts/check_scope.sh market-engine`); if you need a change elsewhere, write it in docs/team/requests/market-engine.md and carry on against the current stubs
- change any public signature, signal, enum or field that the stubs/contracts define (bodies are yours; `tests/contract` guards this)
- merge, rebase onto other branches, push, or switch away from `role/market-engine`; commit only here, messages prefixed `market-engine: `
- touch Portfolio, trading, perks or UI code

Guidelines:
- Implement the stubs in place: GbmPriceModel, MarketSim (step, apply_news with shocks spread over duration_days, history capped, to_dict/load_dict, draw_companies), NewsDirector (roll, due, pending, cooldowns, truth/credibility/credibility range, Early Bird lead days, sector bonus, Insider Friend guaranteed rumor, serialization).
- Every random draw uses the injected rng, in a stable order. Same seed => identical prices; write tests for that, for draw_companies, for shock spreading, and for rumor truth statistics.
- Rumors must only target symbols/sectors present in the market; see how `roll(day, mods, market)` gets them.
- Content values: follow the table in game-design 5.1; check the 20 tickers/names do not match real listed companies.
- Add the localization keys for every company name and headline you create.

Definition of done: scripts/test.sh green, scripts/check_scope.sh market-engine prints 'scope ok', content loads through ContentDb, and a 60-day simulation of a seed looks plausible (no price below the floor, no explosion).
Finish with a short report: what is implemented, what is not, and the contents of your request file (if any).
```
