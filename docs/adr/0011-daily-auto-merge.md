# 0011. 日次フローの PR の自動マージ

## Status

proposed（2026-11-13）

> このリポジトリの現時点の判断を記録したものです。一般的な best practice の主張ではありません。

## Context

日次の自動フロー（`auto-improve.yml`）は `main` 宛ての PR を自動生成する。実際には
2026-11-10〜13 の 4 回で PR #81〜#84 が作られ、**うち 3 本（#81〜#83）は CI が一度も
走らないまま放置され**、4 本目（#84）だけ人間の手で承認してからマージされた。

原因は 2 つ重なっていた。

1. `GITHUB_TOKEN` が作った PR の CI は `approval-required` 状態で止まる（GitHub の仕様）。
   人が「Approve workflows to run」を押すまで `pull_request` トリガーの run が始まらない。
   実測で、run の `created_at` が 2026-11-13 01:36 UTC、job の開始が 08:43 UTC
   （7 時間後に人が承認）だった。#81〜#83 は承認されないまま PR を閉じたため、
   run は job を 1 つも実行しないまま `failure` で終わった。
2. ruleset「Protect main」の必須ステータスチェックは `L0 契約テスト` 1 件。
   1 が起きると必須チェックが永久に判定されないので、**bot の PR は原理的にマージできなかった**。

PR が放置されていたのは、放置したいからではなく、マージできる状態になっていないためで、
人間が「閉じる」判断を迫られていた。

自動マージを実装するには、この 2 つを解かないといけない。

- CI を承認待ちから解放する（自動承認できるか、PR の作者を人間にするか）
- マージしたあとの `main` への push で CI と Pages の公開が走るようにする

2 つ目は `GITHUB_TOKEN` では成立しない。`GITHUB_TOKEN` によるマージが作る push では
ワークフローが起動しない（GitHub の仕様。例外は `workflow_dispatch` と `repository_dispatch` のみ）。
`GITHUB_TOKEN` でマージすると `main` の CI も `deploy-pages.yml` も動かないため、
**ゲームが公開されない**。実測で素の `gh pr merge`（利用者 PAT）に置き換えると
`main` の push で CI とデプロイの両方が起動した。

## Decision

### 1. 日次フローの PR だけ自動マージすることにした

週次（`weekly-update.yml`）は新しいモードの追加という大きな変更で、
[ADR 0003](0003-weekly-large-update-automation.md) 決定 5 の「面白さは契約テストでは保証できない
ので週次 PR は人間がマージする」という判断はそのまま残す。自動マージの対象は日次だけ。

### 2. マージの判断基準は PR の CI だけにした

`auto-improve.yml` には生成後に自分で `scripts/check.sh` と保護対象の検査を回すステップが
既にある（[ADR 0003](0003-weekly-large-update-automation.md) の「CI が止まる前に自力で確かめる」運用）。
これは補助として残すが、**マージの可否は PR の CI の結果だけで決める**。
`gh pr checks --watch --fail-fast` で全チェックが緑になるまで待ち、赤ならマージしない。

### 3. CI の承認を自動化した

`POST /repos/{owner}/{repo}/actions/runs/{run_id}/approve` で保留中の run を承認する。
API の説明は「fork pull request 用」と書かれているが、同一リポジトリの
`app/github-actions` 作成 PR でも 201 で受理されることを実測で確認した
（2026-11-13、run 43403350934）。人が「Approve workflows to run」を押す運用は廃する。

### 4. 承認とマージの 2 ステップにだけ PAT を使った

`AUTO_MERGE_TOKEN`（fine-grained PAT、対象は、このリポジトリ 1 つだけ。権限は
Contents: Read and write / Pull requests: Read and write / Actions: Read and write）を
シークレットに置く。この PAT を使うのは承認ステップとマージステップの 2 つだけで、
**エージェントの実行環境には渡さない**。エージェントに PAT を渡すと、
生成されたコードからトークンを持ち出せる余地が残る。

PR の作者を人間にする（PAT で PR を作る）方針も検討したが、
エージェントの実行環境との差は「承認ステップ 1 つが不要になる」だけなので採らない。

## Consequences

- Good: `guard` ジョブが初めて実際に効く。自動フローが `core/`・`tests/`・
  `.github/workflows/` に触れた PR は、`ci.yml` の guard が落とす。
  これまで承認待ちで一度も走っていなかったため、
  「自動フローは保護対象を変更できない」は実際にはワークフロー内の自己申告だけだった。
- Good: 契約テストが緑になった PR は放置されず、その日のうちに `main` に入る。
  公開（GitHub Pages）も `main` の push に追随して更新される。
- Good: 人間の操作が要る場面は「CI が赤だったとき」だけになる。
- Bad: **PAT はシークレットなので、エージェントが万一それを漏らすと PR を操作できる。**
  漏らされたときに得られるのはこのリポジトリの自動マージ権限だけだが、
  対象を 1 リポジトリに絞って損害を限定している。
- Bad: 赤の PR は自動マージされないので、開いたまま残る。翌日のフローは
  新しい PR を作るので、赤 PR は積み上がる。掃除は人がする運用になる。
- Bad: マージ判断が機械的になるので、「小さな改善として妥当か」の判断は失われる。
  日次の作用域（`modes/` 配下の小さな改善）に閉じていることを前提とする。

## Confirmation

**CI が落とすもの（＝実際に強制されること）**

- `main` の必須ステータスチェック `L0 契約テスト`（ruleset「Protect main」）。
- `ci.yml` の `contract` ジョブ（L0 契約テスト全項目、Web エクスポートの実走）。
- `ci.yml` の `guard` ジョブ（`opencode/` 始まりのブランチが `core/`・`tests/`・
  `.github/workflows/` を変更していないこと）。
- `ci.yml` の `audio` ジョブ（earshot 監査）。
- 自動マージは上のチェックがすべて緑になった後にしか起きない（`gh pr checks --watch`）。

**指針にとどめるもの（＝破っても何も起きないこと）**

- 週次 PR を人間がマージすること（[ADR 0003](0003-weekly-large-update-automation.md) 決定 5）。
- 日次の PR を自動マージすること（この ADR で決定したものだが、強制手段は
  `auto-improve.yml` のマージステップ 1 箇所だけ。`AUTO_MERGE_TOKEN` を消せば止まる）。
- ブランチの接頭辞（[ADR 0007](0007-github-flow-and-semver-tags.md)）。
