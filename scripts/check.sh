#!/usr/bin/env bash
# one-button-run 健全性チェック（Linux/macOS 用）
# Godot が PATH にあれば構文・起動チェック、なければ静的チェックのみ行う。
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

GODOT_BIN="${GODOT_BIN:-godot}"

if command -v "$GODOT_BIN" >/dev/null 2>&1; then
  echo "== godot --version"
  "$GODOT_BIN" --version
  echo ""

  echo "== script check"
  for f in res://main.gd res://player.gd res://obstacle.gd; do
    echo "--- $f"
    if out=$("$GODOT_BIN" --headless --path . --check-only --script "$f" 2>&1); then
      [ -n "$out" ] && echo "$out" || echo "(no output = parse clean)"
    else
      echo "$out"
    fi
  done
  echo ""

  echo "== run headless startup (quit after first frame)"
  "$GODOT_BIN" --headless --path . --quit 2>&1 || true
  echo ""
else
  echo "WARNING: godot command not found; skipping runtime checks." >&2
fi

echo "== indent scan (leading spaces in *.gd)"
if find . -name '*.gd' -not -path './.godot/*' -print0 \
    | xargs -0 grep -nE '^[ ]+[[:alnum:]@_]'; then
  echo "Found lines with space indentation."
else
  echo "(clean)"
fi
echo ""

echo "== L0 contract tests"
if command -v "$GODOT_BIN" >/dev/null 2>&1; then
  "$PROJECT_DIR/scripts/test.sh"
else
  echo "WARNING: godot command not found; skipping contract tests." >&2
fi
