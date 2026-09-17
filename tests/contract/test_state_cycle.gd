extends RefCounted

# L0 契約: START -> PLAYING -> GAME_OVER -> PLAYING が、その1アクションだけで一周する。
# 途中で別の入力やメニュー操作を要求したら「1ボタンで遊べる」は成立しない。

const HARNESS := preload("res://tests/support/harness.gd")

func run(reporter: RefCounted, tree: SceneTree, _spec: Dictionary) -> void:
	var harness = HARNESS.new()
	harness.setup(tree)
	var main = harness.main

	reporter.begin_case("初期状態では進行していない")
	reporter.check(not main.is_playing(), "起動直後に PLAYING になっている")

	reporter.begin_case("無入力では勝手に開始しない")
	harness.step(2.0)
	reporter.check(not main.is_playing(), "無入力なのに PLAYING に遷移した")

	reporter.begin_case("1アクションで開始する")
	harness.tap()
	reporter.check(main.is_playing(), "アクションを入れても PLAYING にならない")

	reporter.begin_case("失敗すると GAME_OVER になる")
	main.game_over()
	reporter.check(main.is_game_over(), "game_over 後も GAME_OVER になっていない")

	reporter.begin_case("GAME_OVER から無入力では復帰しない")
	harness.step(2.0)
	reporter.check(main.is_game_over(), "無入力なのに GAME_OVER から復帰した")

	reporter.begin_case("同じ1アクションで再開する")
	harness.tap()
	reporter.check(main.is_playing(), "アクションを入れても再開しない")

	reporter.begin_case("再開時にスコアと障害物がリセットされる")
	reporter.at_most(main.score, 0.5, "再開後もスコアが残っている")

	harness.teardown()
