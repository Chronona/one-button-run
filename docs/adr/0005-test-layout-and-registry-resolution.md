# 0005. テスト層のディレクトリ分離と、モードレジストリ解決の一本化

## Status

proposed（2026-09-17）

> このリポジトリの現時点の判断を記録したものです。一般的な best practice の主張ではありません。

## Context

テストが8ファイル・470行まで増え、次の2つが読みにくさとして出てきた。

**1. L0 と L2 が同じディレクトリに同居していた。**
[ADR 0001](0001-test-layering-and-injected-time.md) は層を「安定性の地平線」で切ると決めたが、
実装上の置き場所は L0 も L2 も `tests/contract/` だった。結果として、

- `tests/contract/test_playability.gd` の内部関数 `_test_difficulty_curve()`（L0: カーブの形）と
  `tests/contract/test_difficulty_curve.gd`（L2: 記録値との一致）が同名で並んでいた
- 落ちたときに「遊べていない」のか「体感が変わった」のかが、ファイル名から判別できなかった

この2つは失敗したときに人間が取るべき行動が違う。L0 が落ちたら直す。L2 が落ちたら
意図した変更かを判断し、意図的なら `scripts/record-golden.sh` で記録し直す。

**2. registry.json の読み方が5箇所に写経されていた。**
「`active` が指すモードから `scene` / `spec` / `bot` を引く」という手順が、
`core/game_host.gd`・`tests/run_tests.gd`・`tests/contract/test_difficulty_curve.gd`・
`tests/contract/test_mode_registry.gd`・`tests/tools/record_golden.gd` にそれぞれ別実装であった。
`core/game_host.gd` には「テストもここを通して spec を引く」というコメントがあったが、
実際にはテスト側が自前で読んでいて、コメントと実態がずれていた。

[ADR 0003](0003-weekly-large-update-automation.md) の通り、週次フローはレジストリの形に
依存して動く。レジストリの構造を変えたときに一部だけ古い読み方のまま残るのは、
自動フローが壊れる経路として現実的である。

## Decision

### 1. 層をディレクトリで分けることにした

| ディレクトリ | 層 | 落ちたときの意味 |
|---|---|---|
| `tests/contract/` | L0 不変契約 | 遊べていない。直す |
| `tests/regression/` | L2 回帰検出 | 体感が変わった。意図を判断する |

`tests/run_tests.gd` は両方を走査し、L0 -> L2 の順で実行して見出しを分けて出力する。
順序を固定したのは、契約が落ちている状態で回帰差分まで並ぶと原因が埋もれるため。

あわせて `tests/contract/test_playability.gd` の内部関数を `_test_difficulty_shape()` に改名した。
L0 が見ているのはカーブの「形」（下がらない・青天井でない）だけである、という役割を名前に出す。

### 2. レジストリの解決を `core/mode_registry.gd` に一本化することにした

`active_id()` / `active_entry()` / `active_spec()` の3つを公開し、ホストもテストも
ゴールデン記録ツールもここを通す。`core/` に置いたのは、レジストリがゲーム本体の
起動に必要な構造であって、テスト都合の道具ではないため。

### 3. 「黙って空を返す」版と「null を返す」版の2つを持たせることにした

通常の呼び出し側は失敗を空 Dictionary として受け取れば足りる。一方
`tests/contract/test_mode_registry.gd` は「ファイルが無い」のか「JSON として壊れている」のかを
名指しするのが仕事なので、区別が潰れると検査にならない。この1箇所のために
`read_json_or_null()` を残した。

レジストリが壊れていないことの検査は `core/mode_registry.gd` の責務にしていない。
解決経路が自分で検査すると、検査をすり抜けた前提でホストが動く形になるため。

## Consequences

- Good: テストが落ちたとき、ディレクトリ名から取るべき行動が決まる。
- Good: レジストリの構造を変えるときに直す場所が1箇所になった。ホストとテストが
  同じ読み方を通るので、「テストは通るが実機で解決できない」形のずれが起きない。
- Good: `core/game_host.gd` のコメント（テストもここを通す）と実態が一致した。
- Bad: **テストがプロダクションコード（`core/mode_registry.gd`）に依存するようになった。**
  レジストリの解決自体が壊れると、ホストとテストが同時に同じ壊れ方をする。
  その一点を守るのが `tests/contract/test_mode_registry.gd` で、こちらは生の
  ファイル読みと JSON パースに近い経路（`read_json_or_null`）を通している。
- Bad: 層がディレクトリで分かれたことで、新しいテストを足す人は置き場所を判断する
  必要が出た。判断基準は「落ちたら直すのか、人間が意図を判断するのか」。
- Bad: ADR 0004 が `tests/contract/test_difficulty_curve.gd` と書いている箇所は、
  この ADR 以降 `tests/regression/test_difficulty_curve.gd` を指す。ADR は記録なので
  遡って書き換えない。

## Confirmation

**CI が落とすもの（＝実際に強制されること）**

- `tests/contract/**` と `tests/regression/**` の全項目。どちらも `tests/run_tests.gd` が
  走らせ、`ci.yml` の `contract` ジョブが実行する。ディレクトリを増やしても
  ランナーが走査するため、置き忘れたテストが黙って実行対象から外れることはない。
- `opencode/` 始まりのブランチからの PR が `core/**`・`tests/**` を変更していないこと。
  `ci.yml` の `guard` ジョブ。`core/mode_registry.gd` と `tests/regression/**` は
  どちらも既存のパターン（`^core/`・`^tests/`）に含まれるため、guard の定義は変更していない。

**指針にとどめるもの（＝破っても何も起きないこと）**

- 新しいテストを L0 と L2 のどちらに置くかの判断。
- レジストリを読みたくなったら `core/mode_registry.gd` を通すという規約。
  自前で `JSON.parse_string` を書いても CI は落ちない。
