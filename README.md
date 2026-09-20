# One Button Run

このゲームは、Godot 4を使用して作成されたシンプルな2Dのワンボタンランクローンです。
1ボタンでジャンプし続けられるゲームです。

## 操作方法

- ジャンプ: Spaceキー / ↑矢印キー / マウスクリック / タップ
- 再開: ゲームオーバー後、ジャンプ入力で再開

## 起動方法

Godotエディタでプロジェクトを起動するには:

```
godot --path .
```

または、プロジェクトフォルダ内で以下を実行:

```
godot .
```

## チェックツール

| コマンド | 内容 |
| --- | --- |
| `bash scripts/check.sh` | 静的チェック（構文・ヘッドレス起動・インデント）と契約テストを一括実行 |
| `bash scripts/test.sh` | 契約テストのみを実行 |
| `bash scripts/record-golden.sh` | 難易度カーブの基準値を記録し直す（意図的なバランス変更時のみ） |
| `.\check.ps1` | Windows 版。上と同じ内容を実行 |

`GODOT_BIN` 環境変数で Godot の実行ファイルを指定できます（既定は `godot`）。

## テスト

テストは「落ちたときに何をすべきか」で分かれています。時間と入力はテスト側が固定タイムステップで
注入するため、数百秒ぶんのプレイ検証が1秒未満で終わります。

| ディレクトリ | 層 | 落ちたときの意味 |
| --- | --- | --- |
| `tests/contract/` | L0 不変契約 | 「1ボタン(タップ)で遊べるゲームである」が壊れている。直す |
| `tests/regression/` | L2 回帰検出 | 記録時から体感が変わっている。意図した変更かを判断する |

どちらも同じランナーが L0 -> L2 の順で実行します。

```
godot --headless --path . --script res://tests/run_tests.gd
```

また、シードを固定して参照ボットに操作させ、決まった時刻での難易度と「ボットが何回タップしたか」を
`tests/golden/<mode>.json` の記録値と比べることで、バランス調整の積み重ねによるカーブの変化を
検出します。意図的にカーブを変えたときは `bash scripts/record-golden.sh` で記録し直してください
（`tests/` は自動フローから変更できないため、この操作は人間が行います）。

閾値（猶予秒数、無操作死の上限、参照ボットの生存目標など）は、いま有効なモードの spec
（`modes/registry.json` の `active` が指すもの。既定では `modes/runner/spec.json`）にあります。
設計の経緯は [docs/adr/0001](docs/adr/0001-test-layering-and-injected-time.md) と
[docs/adr/0005](docs/adr/0005-test-layout-and-registry-resolution.md) を参照してください。

## 構成

| ディレクトリ | 役割 |
| --- | --- |
| `core/` | ジャンルが変わっても不変な部分。状態機械、スコアとハイスコア、唯一の入力経路、モードの読み込み |
| `modes/` | 実際のゲームプレイ。`registry.json` の `active` が有効なモードを指す |
| `tests/` | L0 契約テスト（`contract/`）、L2 回帰検出（`regression/`）と実行基盤 |
| `docs/` | 設計判断の記録（`adr/`）と、未実装のゲームモードの企画書（`proposals/`） |

`registry.json` の解決（`active` が指すモードの `scene` / `spec` / `bot`）は
`core/mode_registry.gd` に一本化してあり、ホストもテストも同じ経路を通ります。

ゲームモードは `core/game_mode.gd` のインターフェースを実装します。時間も入力もホストから
注入されるため、モードは `_process` も `_input` も持ちません。

## 自動更新フロー

| ワークフロー | 実行 | 内容 |
| --- | --- | --- |
| `auto-improve.yml` | 毎日 06:00 JST | 小さな安全な改善を1件。射程は `modes/` 配下 |
| `weekly-update.yml` | 毎週月曜 07:00 JST | 新しいジャンルのモードを追加し、`registry.json` の `active` を切り替える。作るジャンルは `docs/proposals/` の未実装の企画書から選ぶ |
| `ci.yml` | PR ごと | L0 契約テスト、静的チェック、Web エクスポートの実走 |

`docs/proposals/` に未実装の企画書があるとき、週次更新はジャンルを自分で決めずにその企画書を
実装します。`mode_id` に対応する `modes/<mode_id>/` が無いものを未実装とみなし、`priority` の
小さいものから着手します。指示は [ADR 0002 の「週次エージェントへの実行指示」](docs/adr/0002-core-modes-split.md#週次エージェントへの実行指示)
にあり、経緯は [docs/adr/0006](docs/adr/0006-proposals-as-weekly-input.md) を参照してください。
ワークフロー定義は変更していないため、この運用をやめるときは ADR 0002 の追記節を消すだけで戻ります。

どちらの自動フローも `core/`・`tests/`・`.github/workflows/` を変更できません（CI の
`guard` ジョブが落とします）。生成された PR は人間がレビューしてマージします。

> **注意:** `GITHUB_TOKEN` が作成した PR の CI は `approval-required` 状態で止まります
> （[GitHub の仕様](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow#triggering-a-workflow-from-a-workflow)）。
> PR のマージボックスに出る **Approve workflows to run** を押すまで契約テストは走りません。
> 押さずにマージすると、PR 本文のエージェントの自己申告しか根拠が無い状態になります。
> このため両フローは、生成後に自分で `scripts/check.sh` と保護対象の検査を回して、
> 失敗ならワークフロー実行自体を赤にします（Actions タブで確認できます）。
> 恒久対策としては、main にブランチ保護を設定して CI を required status check に
> するか、`GITHUB_TOKEN` の代わりに PAT / GitHub App トークンを使う方法があります。

週次更新が不調だった場合は、`modes/registry.json` の `active` を前のモード ID に戻せば
巻き戻せます。旧モードは削除されません。

## ライセンス

MIT License
