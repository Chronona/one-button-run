# dino-run 健全性チェック: 構文 + インデント混在 + 短時間実走を一括取得する
# 使い方: dino-run フォルダで .\check.ps1 を実行し、コンソール出力をそのまま貼る
$ErrorActionPreference = "Continue"
$proj = $PSScriptRoot
$out = @()

$out += "== godot --version"
$out += (godot --version 2>&1 | Out-String).Trim()
$out += ""
$out += "== script check"
$scripts = Get-ChildItem -Path $proj -Filter *.gd -Recurse |
  Where-Object { $_.FullName -notmatch '\\\.godot\\' } |
  ForEach-Object { "res://" + ($_.FullName.Substring($proj.Length + 1) -replace '\\', '/') } |
  Sort-Object
foreach ($f in $scripts) {
  $out += "--- $f"
  $r = (godot --headless --path $proj --check-only --script $f 2>&1 | Out-String).Trim()
  $out += if ($r -eq "") { "(no output = parse clean とは限らない。run 行も参照)" } else { $r }
}
$out += ""
$out += "== indent scan (only lines with mixed/space indent are shown; empty means clean)"
$hits = Select-String -Path (Get-ChildItem -Path $proj -Filter *.gd -Recurse | Where-Object { $_.FullName -notmatch '\\\.godot\\' } | ForEach-Object { $_.FullName }) -Pattern '^(?=[ \t]*\S)[ \t]* ' -CaseSensitive
if ($hits) { $out += ($hits | ForEach-Object { "$($_.Filename):$($_.LineNumber): $($_.Line)" }) } else { $out += "(clean)" }
$out += ""
$out += "== run 8s (no output besides the Godot banner means no startup error)"
$out += (godot --headless --path $proj --quit-after 8 2>&1 | Out-String).Trim()
$out += ""
$out += "== L0 contract tests"
$out += (godot --headless --path $proj --script res://tests/run_tests.gd 2>&1 | Out-String).Trim()
$out += if ($LASTEXITCODE -eq 0) { "== RESULT: 契約テスト PASS" } else { "== RESULT: 契約テスト FAIL (exit=$LASTEXITCODE)" }

$out | ForEach-Object { $_ }
