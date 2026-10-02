# 0007. GitHub Flow の継続と、SemVer タグによるバージョン管理

## Status

proposed（2026-10-02）

> このリポジトリの現時点の判断を記録したものです。一般的な best practice の主張ではありません。

## Context

ブランチ運用を明文化していなかった。実態は次のとおり。

- 長命ブランチは `main` のみ。作業は短命ブランチ → PR → squash マージ（#33〜#47）。
- `main` への push で `deploy-pages.yml` が GitHub Pages にデプロイする（継続的デリバリー）。
- `auto-improve.yml`（毎日）と `weekly-update.yml`（毎週）が `main` 宛ての PR を自動生成する。
- タグ・リリースは1つも無く、「どの時点が何版か」を指せない。

git flow（`develop`・`release/*`・`hotfix/*`）への移行も検討した。

## Decision

### 1. GitHub Flow を続けることにした

git flow は採らない。考案者自身が継続的デリバリーには勧めていない。

> "If your team is doing continuous delivery of software, I would suggest to adopt a much simpler
> workflow (like GitHub flow) instead of trying to shoehorn git-flow into your team."
> — [Vincent Driessen, "A successful Git branching model", Note of reflection (2020)](https://nvie.com/posts/a-successful-git-branching-model/)

移行すると、デプロイのトリガー、自動フロー2本の PR 宛先、`develop` と `main` の同期を
すべて作り直すことになるが、それで得られる「リリース安定化期間」を今は必要としていない。
運用は [GitHub flow](https://docs.github.com/en/get-started/using-github/github-flow) のとおり。

### 2. ブランチ名に接頭辞を付けることにした

| 接頭辞 | 用途 |
| --- | --- |
| `feat/` | 機能・モード追加 |
| `fix/` | 不具合修正 |
| `refactor/` | 挙動を変えない整理 |
| `docs/` | ドキュメント・ADR |
| `chore/` | CI・設定・依存更新 |
| `opencode/` | 自動フロー（既存の命名をそのまま使う） |

### 3. `main` 上のコミットに SemVer の注釈付きタグを打つことにした

形式は `vMAJOR.MINOR.PATCH`（[Semantic Versioning 2.0.0](https://semver.org/lang/ja/)）。
ゲームには公開 API が無いので、SemVer の「互換性」を次のように読み替える。

| 上げる桁 | 条件 |
| --- | --- |
| MINOR | 遊べるモードが増えた / `registry.json` の `active` が変わった（＝週次アップデート） |
| PATCH | それ以外（日次改善、修正、整理） |
| MAJOR | 当面 `0` に固定。正式公開版と言える時点で `v1.0.0` にする |

`0.y.z` から始めるのは、SemVer が「初期開発中は 0.y.z」と定めているため
（[SemVer 仕様 4](https://semver.org/lang/ja/#spec-item-4)）。初回は `v0.1.0`。

軽量タグではなく注釈付きタグ（`git tag -a`）にするのは、作成者・日時・メッセージを
タグ自身が持つため（[git-tag ドキュメント](https://git-scm.com/docs/git-tag)
"Annotated tags are meant for release while lightweight tags are meant for private or temporary object labels."）。

### 4. タグ付けは人間が手動で行い、GitHub Release を添えることにした

タグ付けは自動化しない。自動フローは `.github/workflows/**` を変更できず（`guard`）、
PR は人間がレビューしてマージする（[ADR 0003](0003-weekly-large-update-automation.md) 決定5）ので、
「どの時点を版にするか」もマージする人間が決める。リリースノートは GitHub の
[自動生成機能](https://docs.github.com/en/repositories/releasing-projects-on-github/automatically-generated-release-notes)を使う。
手順は README の「リリース（タグ付け）」節。

## Consequences

- Good: ワークフローの変更が不要。運用を明文化しただけで、既存の自動フローはそのまま動く。
- Good: 版を指して「この時点に戻す」「この版から何が変わったか」が言えるようになる。
- Bad: デプロイはタグではなく `main` への push で起きるので、**公開中の Pages がタグの版と
  一致するとは限らない**。タグは「記録」であってリリースの関門ではない。
- Bad: 手動なのでタグを打ち忘れうる。打ち忘れても実害は無く、後から過去コミットに打てる。

## Confirmation

**CI が落とすもの（＝実際に強制されること）**

- なし。

**指針にとどめるもの（＝破っても何も起きないこと）**

- ブランチ名の接頭辞。
- タグの形式と桁の上げ方。
- `main` 以外のコミットにタグを打たないこと。
