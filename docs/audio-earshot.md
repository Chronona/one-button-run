# ゲーム音声を earshot で作る

このゲームの効果音は、録音素材の寄せ集めではなく、earshot
（https://github.com/Leonxlnx/earshot、MIT）のバンクからコード合成で
作ります。バンクのレンダーはモデルもネットワークも不要で、numpy /
scipy だけで再現できます。

## 今の対応表

| 出力ファイル | earshot バンク | 役割 |
| --- | --- | --- |
| `assets/se/jump.wav` | `ui_pop/soft`（pitch A5） | act（ジャンプ／フラップ／切替／フック／射撃／パルスは今はこのファイルを共有） |
| `assets/se/land.wav` | `ui_pop/soft`（pitch E4） | land（jump と同じ音色を低くしたもの） |
| `assets/se/gameover.wav` | `mallet/celesta` E5 → C5 → A4（0.28秒間隔） | fail（下がっていくフレーズで、ランが終わったことを伝える） |
| `assets/se/highscore.wav` | `mallet/up4` | record（上がっていく mallet フレーズ） |

## 統一感の設計

単体でいい音を集めるだけでは、ゲームの音にはなりません。ジャンプと
着地が別の系統だと、ジャンプ→着地の順で聴いたときに違和感が出ます。
また、ゲームオーバーを1発の衝撃音だけにすると、音だけでは何が
起きたか伝わりません。

そこで、このセットはこう統一しています。

- **jump / land は同じ音色で高さだけ変える**：`ui_pop/soft` を jump は
  高い A5、land は低い E4 で鳴らします。ジャンプ→着地が1つの動き
  として聞こえます。
- **gameover は下がっていくフレーズにする**：`mallet/celesta` の
  E5 → C5 → A4 を並べた約1秒の音列です。highscore の上がる
  mallet フレーズと同じ家族なので、全体の統一感も出ます。
- マニフェストのエントリは、単音（`bank_id`＋任意の `pitch`）か、
  フレーズ（`sequence`＋`spacing_s`）のどちらかです。フレーズの
  各音はそれぞれ earshot の監査を通す必要があります。

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

## CI への組み込み

- `.github/workflows/ci.yml` の `audio` ジョブが、すべての PR と
  main への push で `scripts/generate-audio.py --check` を走らせ、
  マニフェストの音が earshot の監査を通ることを確認します。
- WAV バイナリとマニフェストの一致までは CI で見ていません。
  上流の `assets/se/*.wav` はまだ旧音のままで、一致チェックは
  WAV の置き換えが済むまで赤になってしまうためです。WAV の
  置き換えが済んだら、一致チェックの追加を検討してください。
- 週次の weekly-update と日次の auto-improve のプロンプトにも、
  音の変更はマニフェスト経由で行うことが書いてあります。新しい
  モードは、既存の音を `volume_db` / `pitch_scale` で使い回すか、
  マニフェストにエントリを追加して生成し直すかのどちらかです。
  WAV の手作り・直接差し替えはしません。

## まだやらないこと

- モードごとに act 音を分けること。今は全モードの act が `jump.wav`
  を共有しており、音の個性を分けるのは次のステップです。
- `core/` や `tests/` の変更。シーンが参照するファイル名は変わらない
  ため、フィードバックの仕組み（`get_feedback_map()`）には触れていません。
- WAV バイナリとマニフェストの一致チェック（上記の通り、WAV の
  置き換えが済んでから）。
- 既存 WAV の `.import` ファイルの手作り。Godot の `--import` が
  生成するものなので、CI のインポート手順に任せます。

## ライセンスの注意

earshot のコードは MIT です。バンクの音はコード合成で、録音素材を
含みません。`fit/` 系（実録音からフィットしたもの）はこのマニフェスト
では使っていません。将来 `fit/` を使う場合は、その音の出典ライセンス
をマニフェストに併記してください。
