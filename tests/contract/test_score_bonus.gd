extends RefCounted

# L0 契約: モードはホストの add_score() で加点できる（ADR 0009）。
# 加点は PLAYING 中の正の値だけが効き、再開でリセットされる。

const HARNESS := preload("res://tests/support/harness.gd")

func run(reporter: RefCounted, tree: SceneTree, _spec: Dictionary) -> void:
	var harness = HARNESS.new()
	harness.setup(tree)
	var main = harness.main

	reporter.begin_case("開始前の加点は無視される")
	main.add_score(10.0)
	reporter.equal(main.score, 0.0, "START 中に加点された")

	reporter.begin_case("PLAYING 中の加点がスコアに乗る")
	main.start_game()
	main.add_score(10.0)
	reporter.equal(main.score, 10.0, "加点が反映されない")
	main.add_score(5.0)
	reporter.equal(main.score, 15.0, "加点が累積しない")

	reporter.begin_case("0 以下の加点は無視される")
	main.add_score(0.0)
	main.add_score(-3.0)
	reporter.equal(main.score, 15.0, "0 以下の値でスコアが動いた")

	reporter.begin_case("加点は表示にも反映される")
	reporter.equal(main.score_label.text, "Score: 15", "スコア表示が更新されない")

	reporter.begin_case("GAME_OVER 後の加点は無視される")
	# 記録更新扱いにならないようにして、実機のハイスコアファイルを書き換えない。
	main.high_score = 999999
	main.game_over()
	main.add_score(100.0)
	reporter.equal(main.score, 15.0, "GAME_OVER 後に加点された")

	reporter.begin_case("経過時間の加算は scores_by_time() の宣言に従う（ADR 0010）")
	main.start_game()
	harness.step(1.0) # 開始直後の猶予内なので、どのモードでも失敗しない
	if main.get_active_mode().scores_by_time():
		reporter.check(main.score > 0.9, "時間加算を宣言したモードでスコアが増えない: %.2f" % main.score)
	else:
		reporter.equal(main.score, 0.0, "時間加算なしを宣言したモードで経過時間がスコアになった")

	reporter.begin_case("再開で加点分もリセットされる")
	main.start_game()
	reporter.equal(main.score, 0.0, "再開後に加点が残っている")

	harness.teardown()
