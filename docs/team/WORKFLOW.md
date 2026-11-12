# Git workflow (v0.1)

```
main  ──●──────────────●────────●────────●──────  only the lead merges here (no fast-forward)
         \            /        /        /
          role/market-engine ─●─●─●
          role/trading-engine ──●─●─●─●
          role/ui-gameplay ─────●─●
          ...one branch per role, each cut from main
```

## For a role (the agent)

```bash
# the lead has already run: scripts/new_role.sh <role>   (creates ../stock-simulator-wt/<role>)
cd ../stock-simulator-wt/<role>
scripts/test.sh                 # must be green from the start
# ... work, small commits: "<role>: <what and why>" ...
scripts/test.sh
scripts/check_scope.sh <role>   # must print "scope ok <role>"
```

Rules:
- Commit only on `role/<role>`. Never merge, rebase onto other role branches, push, or touch `main`.
- Commit messages start with `<role>:` and describe one thing each.
- End with a short report: what is done, what is missing, anything in `docs/team/requests/<role>.md`.

## For the lead

```bash
scripts/new_role.sh market-engine        # one per role; every role gets its own folder (git worktree)
scripts/merge_role.sh market-engine      # checks scope + tests, then merges into main (--no-ff)
```

Merge order inside a wave does not matter (the owned paths do not overlap).
After wave 1 is merged, run `scripts/new_role.sh session-integration` so it starts from the merged `main`.
If a role asked for a contract change in its request file, the lead edits the contract on `main`
first, then the roles run `git merge main` to receive it.

## Testing

`scripts/test.sh` imports the project and runs every `tests/**/test_*.gd`
(`scripts/test.sh tests/unit/market` for one folder, `--filter=text` for one file).
Tests extend `TestCase` (`tests/test_case.gd`); methods are named `test_*`.
