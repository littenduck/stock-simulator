# Requests from release-qa

1. **GitHub Pages setting (repo owner, not code):** Settings -> Pages -> Source = "GitHub Actions". Without it `deploy` fails.
2. **project.godot (frozen):** nothing required. Renderer is already `gl_compatibility`; Web preset has thread support off.
3. **Design question for the lead:** the docs define no win condition (only score ranking / top 10). `tools/balance_sim.gd`
   treats "won" as `score >= start_cash * --target` (default 1.5). Tell me the real target if there is one.
4. **Observation:** `tests/run_tests.gd` hangs forever (instead of failing) when a test script has a compile error. Suggest a fix on main.
5. **Observation:** autoload names (`EventBus`, `GameManager`) do not compile in tests; `AudioFeedback` therefore looks them up by path (`/root/EventBus`).
