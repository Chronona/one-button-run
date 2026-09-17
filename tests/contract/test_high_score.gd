extends RefCounted

# L0 契約: ハイスコアが永続化され、起動し直しても残る。
# 「毎日遊ぶ理由」を支える最小の状態なので、ジャンルが変わっても不変。

const HARNESS := preload("res://tests/support/harness.gd")

func run(reporter: RefCounted, tree: SceneTree, _spec: Dictionary) -> void:
	var path: String = "user://high_score.txt"
	var backup: String = ""
	var had_backup := FileAccess.file_exists(path)
	if had_backup:
		backup = FileAccess.get_file_as_string(path)

	var harness = HARNESS.new()
	harness.setup(tree)
	var main = harness.main
	path = main.HIGH_SCORE_PATH

	reporter.begin_case("記録更新がファイルに保存される")
	main.start_game()
	main.high_score = 0
	main.score = 123.0
	main.game_over()
	reporter.equal(main.high_score, 123, "メモリ上のハイスコアが更新されていない")
	reporter.check(FileAccess.file_exists(path), "保存先ファイルが作られていない")
	harness.teardown()

	reporter.begin_case("起動し直しても記録が残る")
	var reloaded = HARNESS.new()
	reloaded.setup(tree)
	reporter.equal(reloaded.main.high_score, 123, "再起動後にハイスコアが失われた")
	reloaded.teardown()

	# テスト前の状態に戻す
	var restore := FileAccess.open(path, FileAccess.WRITE)
	if restore != null:
		restore.store_string(backup if had_backup else "0")
