# Stock Simulator

A turn-based stock Roguelike (60 trading days, 6 of 15 fictional companies, a perk every 10 days,
rumors that come true or not). Web build first; Steam later.

- Version: v0.1
- Engine: Godot 4.7 (GDScript, Compatibility renderer)
- Game design: [docs/game-design.md](docs/game-design.md)
- Implementation plan: [docs/implementation-plan.md](docs/implementation-plan.md) (section 13 overrides 1-12)
- Overall plan: [docs/plan.md](docs/plan.md)

## Run

```bash
godot --path .                 # play / open the stub flow
scripts/test.sh                # import + all tests (no addons needed)
```

## Team workflow (parallel agents)

Roles, file ownership, contracts and the per-role prompts: [docs/team/](docs/team/)
([ROLES](docs/team/ROLES.md), [WORKFLOW](docs/team/WORKFLOW.md), [CONTRACTS](docs/team/CONTRACTS.md),
[prompts](docs/team/prompts/)).

```
autoload/    EventBus, GameManager, SaveManager          core/   pure rules (no nodes)
data/        defs (Resource classes) + .tres content     ui/     scenes and scripts
localization one CSV per owner                           tests/  unit, contract, integration
scripts/     test, scope check, worktree + merge helpers tools/  headless balance tool
```
