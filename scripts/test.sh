#!/usr/bin/env bash
# Import (refreshes the class cache) and run all tests. Usage: scripts/test.sh [dir] [--filter=text]
set -euo pipefail
cd "$(dirname "$0")/.."
godot --headless --path . --import >/dev/null 2>&1 || true
godot --headless --path . --script res://tests/run_tests.gd -- "$@"
