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
  # パスを固定で書くとファイルを移動したときに黙って検査対象から外れるので、
  # 実在する .gd を毎回探索する。
  for f in $(find . -name '*.gd' -not -path './.godot/*' | sed 's|^\./|res://|' | sort); do
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

echo "== uid scan (.gd without a matching .uid)"
# Godot 4.4 以降は .gd ごとに .uid を作る。追跡漏れがあると、import を実行した人の
# 作業ツリーに毎回未追跡ファイルが現れ、環境ごとに違う UID が振られる。
missing_uid=""
for gd in $(find . -name '*.gd' -not -path './.godot/*' | sort); do
  [ -f "$gd.uid" ] || missing_uid="$missing_uid $gd.uid"
done
if [ -z "$missing_uid" ]; then
  echo "(clean)"
else
  for u in $missing_uid; do echo "  missing: $u"; done
  echo "ERROR: 上記の .uid がありません。'$GODOT_BIN --headless --path . --import' で生成し、コミットに含めてください。" >&2
  exit 1
fi
echo ""

echo "== contract (L0) + regression (L2) tests"
if command -v "$GODOT_BIN" >/dev/null 2>&1; then
  "$PROJECT_DIR/scripts/test.sh"
else
  echo "WARNING: godot command not found; skipping contract tests." >&2
fi
