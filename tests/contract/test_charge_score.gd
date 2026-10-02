extends RefCounted

# チャージ投擲モード固有の契約（ADR 0010）: スコアは標的の破壊でだけ入り、
# 経過時間では増えない。他モードが有効なときは何も検査しない。

const HARNESS := preload("res://tests/support/harness.gd")

func run(reporter: RefCounted, tree: SceneTree, spec: Dictionary) -> void:
	if spec.get("id", "") != "charge":
		return
	var harness = HARNESS.new()
	harness.setup(tree)
	var main = harness.main
	var mode = main.get_active_mode()

	reporter.begin_case("構えずに時間が過ぎてもスコアは増えない")
	main.start_game()
	harness.step(1.5) # 最初の見送り（1.8 秒）より手前
	reporter.equal(main.score, 0.0, "経過時間でスコアが増えた")

	reporter.begin_case("標的を1つ壊すと TARGET_SCORE が入る")
	var target: Node2D = tree.get_nodes_in_group("targets")[0]
	target.position = mode.muzzle_pos() + Vector2(300.0, 0.0)
	mode.shell_pos = target.position
	mode.flying = true
	mode._hit_target(target)
	reporter.equal(main.score, mode.TARGET_SCORE, "標的破壊の加点が反映されない")

	reporter.begin_case("加点後も時間ではスコアが動かない")
	mode.flying = false
	var before: float = main.score
	harness.step(1.0)
	reporter.equal(main.score, before, "破壊後に経過時間でスコアが増えた")

	harness.teardown()
