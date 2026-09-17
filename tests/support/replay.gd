extends RefCounted

# 決定論リプレイ。シードを固定して参照ボットに操作させ、指定した時刻での
# 難易度と「ボットが何回タップしたか」を記録する。
#
# 記録と照合の両方がこのコードを通るので、ゴールデン値の生成とテストが
# 同じ再生手順であることが構造的に保証される。

const HARNESS := preload("res://tests/support/harness.gd")

# checkpoints_seconds の各時刻でサンプルを取り、配列で返す。
static func replay(tree: SceneTree, bot_script: GDScript, rng_seed: int, checkpoints_seconds: Array) -> Array:
	var points: Array = checkpoints_seconds.duplicate()
	points.sort()

	var harness = HARNESS.new()
	harness.setup(tree, rng_seed)
	harness.main.start_game()
	var bot = bot_script.new()

	var samples: Array = []
	var frames_done: int = 0
	for point in points:
		var target_frames: int = int(round(float(point) / harness.FIXED_DELTA))
		while frames_done < target_frames:
			# 失敗後は操作させない。press_act は PLAYING でないと start_game を
			# 呼ぶので、ボットに触らせるとラウンドが勝手に再開してしまう。
			if not harness.main.is_game_over():
				bot.decide(harness.main, harness)
				harness.main.tick(harness.FIXED_DELTA)
			frames_done += 1
		samples.append({
			"t": float(point),
			"difficulty": harness.main.get_difficulty(),
			"act_count": harness.feedback_log.count("act"),
			"alive": not harness.main.is_game_over(),
		})

	harness.teardown()
	return samples
