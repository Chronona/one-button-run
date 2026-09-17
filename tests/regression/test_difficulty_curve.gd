extends RefCounted

# L2 回帰検出: 難易度カーブが記録時と同じであること。
#
# L0 は「単調非減少」「上限つき」「ボットが生存できる」までしか見ないので、
# 日次の細かいバランス調整が積み重なってカーブが別物になっても気づけない。
# シードを固定して参照ボットに操作させ、決まった時刻での難易度と
# 「ボットが何回タップしたか」を記録値と比べる。
#
# act_count（参照ボットの操作回数）を見ているのがポイント。ジャンルに依存しない
# 行動指標なので、スポーン間隔でもジャンプ性能でも、体感の変化として現れたものは
# ここに出る。
#
# 基準値は tests/golden/<mode>.json にあり、tests/ は CI の guard ジョブが保護して
# いるため自動フローからは更新できない。意図的なバランス変更のときだけ、人間が
# scripts/record-golden.sh で記録し直す。

const GOLDEN_DIR := "res://tests/golden"
const MODE_REGISTRY := preload("res://core/mode_registry.gd")
const REPLAY := preload("res://tests/support/replay.gd")

func run(reporter: RefCounted, tree: SceneTree, spec: Dictionary) -> void:
	var active: String = MODE_REGISTRY.active_id()
	var golden_path := "%s/%s.json" % [GOLDEN_DIR, active]

	if not FileAccess.file_exists(golden_path):
		# 新しいモードには比較対象となる過去のカーブが無い。回帰検出は
		# 人間がカーブを固定した時点から始まる。黙って通さず、必ず表示する。
		print("       ※ モード '%s' のゴールデン値が未設定のため回帰検出は行われていません" % active)
		print("         固定するには: bash scripts/record-golden.sh")
		return

	var golden: Variant = JSON.parse_string(FileAccess.get_file_as_string(golden_path))
	reporter.begin_case("ゴールデン値が読める")
	if not reporter.check(golden is Dictionary, "%s が JSON オブジェクトではない" % golden_path):
		return

	var bot_path: String = spec.get("bot", "")
	reporter.begin_case("参照ボットが解決できる")
	if not reporter.check(bot_path != "" and ResourceLoader.exists(bot_path),
			"spec の bot が見つからない: '%s'" % bot_path):
		return

	var expected_samples: Array = (golden as Dictionary).get("samples", [])
	reporter.begin_case("ゴールデン値にサンプルがある")
	if not reporter.check(not expected_samples.is_empty(), "samples が空"):
		return

	var rng_seed: int = int((golden as Dictionary).get("seed", 0))
	var checkpoints: Array = (golden as Dictionary).get("checkpoints_seconds", [])
	var difficulty_tolerance: float = (golden as Dictionary).get("difficulty_tolerance", 1.0)
	var act_tolerance: int = int((golden as Dictionary).get("act_count_tolerance", 1))

	var actual_samples := REPLAY.replay(tree, load(bot_path), rng_seed, checkpoints)

	reporter.begin_case("サンプル数が一致する")
	if not reporter.equal(actual_samples.size(), expected_samples.size(), "サンプル数が違う"):
		return

	for i in expected_samples.size():
		var want: Dictionary = expected_samples[i]
		var got: Dictionary = actual_samples[i]
		var at: float = float(want.get("t", 0.0))

		reporter.begin_case("t=%.0f 秒でボットが生存しているか" % at)
		reporter.equal(got.get("alive"), want.get("alive"), "生存状態が変わった")

		reporter.begin_case("t=%.0f 秒の難易度" % at)
		var want_difficulty: float = float(want.get("difficulty", 0.0))
		var got_difficulty: float = float(got.get("difficulty", 0.0))
		reporter.check(absf(got_difficulty - want_difficulty) <= difficulty_tolerance,
			"難易度が変わった (記録=%.2f 実測=%.2f 許容=±%.2f)"
				% [want_difficulty, got_difficulty, difficulty_tolerance])

		reporter.begin_case("t=%.0f 秒までのボットの操作回数" % at)
		var want_acts: int = int(want.get("act_count", 0))
		var got_acts: int = int(got.get("act_count", 0))
		reporter.check(absi(got_acts - want_acts) <= act_tolerance,
			"操作回数が変わった＝体感が変わっている (記録=%d 実測=%d 許容=±%d)"
				% [want_acts, got_acts, act_tolerance])
