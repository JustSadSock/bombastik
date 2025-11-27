#!/usr/bin/env bash
set -euo pipefail

godot --headless --quit --path . --check-only project.godot
godot --headless --path . --script res://tests/run_tests.gd
