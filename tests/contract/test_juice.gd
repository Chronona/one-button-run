extends RefCounted

# L0 契約: 失敗の演出（ヒットストップ・シェイク・フラッシュ）は、再開すれば必ず元に戻る。
# time_scale が残るとゲーム全体が止まって見えるので、どのモードでも破ってはいけない。

const HARNESS := preload("res://tests/support/harness.gd")

func run(reporter: RefCounted, tree: SceneTree, _spec: Dictionary) -> void:
	var harness = HARNESS.new()
	harness.setup(tree)
	var main = harness.main
	var camera: Camera2D = main.get_node("Camera")
	var flash_rect: ColorRect = main.get_node("FlashLayer/FlashRect")

	reporter.begin_case("失敗するとヒットストップとフラッシュが始まる")
	main.start_game()
	main.game_over()
	reporter.check(Engine.time_scale < 1.0, "time_scale=%s" % Engine.time_scale)
	reporter.check(flash_rect.color.a > 0.0, "flash alpha=%s" % flash_rect.color.a)

	reporter.begin_case("ヒットストップ中に再開しても演出が残らない")
	main.start_game()
	reporter.check(is_equal_approx(Engine.time_scale, 1.0), "time_scale=%s" % Engine.time_scale)
	reporter.check(camera.offset == Vector2.ZERO, "camera offset=%s" % camera.offset)
	reporter.check(is_zero_approx(flash_rect.color.a), "flash alpha=%s" % flash_rect.color.a)

	reporter.begin_case("演出を残したままシーンを破棄しても time_scale が戻る")
	main.game_over()
	harness.teardown()
	reporter.check(is_equal_approx(Engine.time_scale, 1.0), "time_scale=%s" % Engine.time_scale)
