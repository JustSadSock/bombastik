#!/usr/bin/env bash
# Runs all GDScript unit tests
set -euo pipefail

echo "=== Running All GDScript Tests ==="

# First check syntax
echo "Checking GDScript syntax..."
godot --headless --quit --path . --check-only project.godot 2>&1 || {
    echo "FAILED: GDScript syntax check"
    exit 1
}
echo "✓ Syntax check passed"

echo ""
echo "Note: Unit tests are designed to run within Godot scenes."
echo "To run them interactively, open the project and instantiate test scripts."
echo ""
echo "=== Syntax Check Complete ==="
