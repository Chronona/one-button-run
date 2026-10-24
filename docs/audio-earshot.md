# ゲーム音声を earshot で作る

このゲームの効果音は、録音素材の寄せ集めではなく、earshot
（https://github.com/Leonxlnx/earshot、MIT）のバンクからコード合成で
作ります。バンクのレンダーはモデルもネットワークも不要で、numpy /
scipy だけで再現できます。

## 今の対応表

| 出力ファイル | earshot バンク | 役割 |
| --- | --- | --- |
| `assets/se/jump.wav` | `ui_pop/soft` | act（ジャンプ／フラップ／切替／フック／射撃／パルスは今はこのファイルを共有） |
| `assets/se/land.wav` | `knock/wood` | land |
| `assets/se/gameover.wav` | `pro_impact/short` | fail |
| `assets/se/highscore.wav` | `mallet/up4` | record |

対応表そのものは `audio/earshot-manifest.json` が唯一の真実源です。
音を変えたいときは WAV を直接差し替えるのではなく、マニフェストの
`bank_id` を変えてから生成し直してください。

## 生成方法

```sh
# earshot を clone しただけの場合（pip install しなくてもよい）
EARSHOT_PATH=/path/to/earshot python3 scripts/generate-audio.py

# 書き込まずに監査だけ確認する
EARSHOT_PATH=/path/to/earshot python3 scripts/generate-audio.py --check
```

出力はモノラル 44.1 kHz 16-bit WAV で、従来のアセットと同じ形式です。
生成するたびに earshot のモデルフリー監査（クリック・クリッピング・
DC・リング・切れたテールなど）を走らせ、監査に通らない音は書き込み
ません。検証済みの組み合わせはすべて監査 clean でした。

## まだやらないこと（この PR の範囲外）

- モードごとに act 音を分けること。今は全モードの act が `jump.wav`
  を共有しており、音の個性を分けるのは次のステップです。
- `core/` や `tests/` の変更。シーンが参照するファイル名は変わらない
  ため、フィードバックの仕組み（`get_feedback_map()`）には触れていません。
- CI への組み込み。生成を CI で走らせるかどうかは、この PR の音が
  実際にゲームで問題なく鳴ることを確認してから決めます。
- 既存 WAV の `.import` ファイルの手作り。Godot の `--import` が
  生成するものなので、CI のインポート手順に任せます。

## ライセンスの注意

earshot のコードは MIT です。バンクの音はコード合成で、録音素材を
含みません。`fit/` 系（実録音からフィットしたもの）はこのマニフェスト
では使っていません。将来 `fit/` を使う場合は、その音の出典ライセンス
をマニフェストに併記してください。
