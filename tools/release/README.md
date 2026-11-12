# Release notes and checklists (release-qa)

## What exists
- `export_presets.cfg`: Web preset, single thread (no COOP/COEP headers needed), exports to `build/web/index.html`. Renderer: Compatibility (project.godot).
- `.github/workflows/ci.yml`: test -> export-web -> deploy (Pages, only on push to main). Godot pinned to 4.7.2 via `.github/actions/setup-godot`.
- `ui/audio/audio_feedback.*` + `audio/kenney_*/` (four Kenney CC0 packs, one folder each, original names)
- `tools/balance_sim.gd`, `tests/integration/test_balance_smoke.gd`.

## Local commands
```bash
scripts/test.sh
godot --headless --path . --script res://tools/balance_sim.gd -- --runs=200 > build/balance.csv
mkdir -p build/web && godot --headless --path . --export-release "Web" build/web/index.html
python3 -m http.server 8060 --directory build/web
```
Export needs the 4.7.2 export templates (Editor -> Manage Export Templates); they were NOT installed on the dev machine when this was written, so the Web export was not run locally.

## Balance status
Wave 3 not started: GameSession/Portfolio are stubs, so every strategy scores exactly the start cash. Re-run after session-integration merges and write `balance-report.md` here.

## Web checklist
See docs/implementation-plan.md 13.12.
