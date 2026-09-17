# Architecture Decision Records

このディレクトリは、このリポジトリで下した設計判断の**記録**です。規約集ではありません。

- 1ファイル = 1つの決定。日付と `Status` を持ち、後から `superseded by ADR-XXXX` で置き換えられます。
- 決定を変えたくなったら、既存の ADR を書き換えるのではなく、新しい ADR を足して古い方の Status を更新します。
- 書式は [Michael Nygard 版テンプレート](https://github.com/joelparkerhenderson/architecture-decision-record/blob/main/locales/en/templates/decision-record-template-by-michael-nygard/index.md)に、
  [MADR](https://github.com/adr/madr) の `Confirmation`（この決定が守られているかを何で確認するか）を足したものを使っています。

ここに書いてあることのうち、**実際に強制されるのは `Confirmation` で「CI が落とす」と明記されたものだけ**です。
それ以外は「今はこう考えている」という指針で、破っても何も起きません。

| # | タイトル | Status |
|---|---|---|
| [0001](0001-test-layering-and-injected-time.md) | 品質テストの3層化と、時間・入力のホスト注入 | proposed（決定6は 0002 が置き換え） |
| [0002](0002-core-modes-split.md) | core と modes への分離、およびモードレジストリ | proposed |
| [0003](0003-weekly-large-update-automation.md) | 週次大型アップデートの自動化 | proposed |
