# Requests from release-qa

1. **GitHub Pages setting (repo owner, not code):** Settings -> Pages -> Source = "GitHub Actions". Without it `deploy` fails.
2. **project.godot (frozen):** nothing required. Renderer is already `gl_compatibility`; Web preset has thread support off.
3. **Design question for the lead:** the docs define no win condition (only score ranking / top 10). `tools/balance_sim.gd`
   treats "won" as `score >= start_cash * --target` (default 1.5). Tell me the real target if there is one.
4. **Observation:** `tests/run_tests.gd` hangs forever (instead of failing) when a test script has a compile error. Suggest a fix on main.
5. **Observation:** autoload names (`EventBus`, `GameManager`) do not compile in tests; `AudioFeedback` therefore looks them up by path (`/root/EventBus`).
6. **Scope conflict:** `scripts/owners.txt` gives release-qa `docs/release/`, but `scripts/frozen.txt` freezes all of `docs/`, so
   `check_scope.sh` rejects it. I put my notes in `tools/release/` instead. Lead: either add a `docs/release/` exception to the script, or keep `tools/release/`.
7. **Web export not run locally:** the 4.7.2 export templates are not installed on this machine (`godot --export-release "Web"` fails with missing templates). CI installs them.
