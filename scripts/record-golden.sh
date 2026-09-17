#!/usr/bin/env bash
# いま有効なモードの難易度カーブを記録し直す（Linux/macOS 用）。
# バランス調整で意図的にカーブを変えたときだけ実行する。
set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

GODOT_BIN="${GODOT_BIN:-godot}"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  echo "ERROR: godot コマンドが見つかりません。" >&2
  exit 127
fi

exec "$GODOT_BIN" --headless --path . --script res://tests/tools/record_golden.gd
