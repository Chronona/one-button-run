#!/usr/bin/env bash
# 品質テストを実行する（Linux/macOS 用）。
# L0 契約（tests/contract/: ジャンルが変わっても不変の条件）と
# L2 回帰検出（tests/regression/: 記録した難易度カーブとの差分）を、この順で走らせる。
# 時間はテスト側が固定タイムステップで注入するため、数百秒ぶんのプレイが一瞬で終わる。
set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

GODOT_BIN="${GODOT_BIN:-godot}"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  echo "ERROR: godot コマンドが見つかりません。契約テストを実行できません。" >&2
  exit 127
fi

"$GODOT_BIN" --headless --path . --script res://tests/run_tests.gd
status=$?

# Godot は終了時に ObjectDB のリーク警告を出すことがある（--script 実行の副作用で、
# テスト結果とは無関係）。判定は終了コードだけで行い、最後に結論を明示する。
echo ""
if [ "$status" -eq 0 ]; then
  echo "== RESULT: 契約テスト PASS"
else
  echo "== RESULT: 契約テスト FAIL (exit=$status)"
fi
exit "$status"
