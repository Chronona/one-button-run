extends RefCounted

# チャージ投擲モード固有の契約（ADR 0008）: 前ステージの投擲数で分裂数が決まり、
# 1発で破壊すると発射後に弾が分裂する。他モードが有効なときは何も検査しない。

const HARNESS := preload("res://tests/support/harness.gd")

func run(reporter: RefCounted, _tree: SceneTree, spec: Dictionary) -> void:
	if spec.get("id", "") != "charge":
		return
	var harness = HARNESS.new()
	harness.setup(_tree)
	var mode = harness.main.get_active_mode()

	reporter.begin_case("投擲数 1 / 2 / 3以上 で分裂数が 3 / 2 / 1")
	reporter.check(mode.split_for_shots(1) == 3, "1発: %d" % mode.split_for_shots(1))
	reporter.check(mode.split_for_shots(2) == 2, "2発: %d" % mode.split_for_shots(2))
	reporter.check(mode.split_for_shots(3) == 1, "3発: %d" % mode.split_for_shots(3))
	reporter.check(mode.split_for_shots(9) == 1, "9発: %d" % mode.split_for_shots(9))

	reporter.begin_case("開始直後は分裂なし")
	reporter.check(mode.split_count == 1, "split_count=%d" % mode.split_count)

	reporter.begin_case("1発で標的を壊すと次ステージは3分裂、発射後に弾が増える")
	harness.main.start_game()
	var target: Node2D = mode.get_tree().get_nodes_in_group("targets")[0]
	var stage_before: int = mode.stage
	# 標的を砲口の真正面に置き、弾が確実に当たる位置へ動かす。
	target.position = mode.muzzle_pos() + Vector2(300.0, 0.0)
	mode.stage_shots = 0
	mode.shell_pos = target.position
	mode.flying = true
	mode.stage_shots = 1
	mode._hit_target(target)
	reporter.check(mode.stage == stage_before + 1, "ステージが進まない")
	reporter.check(mode.split_count == 3, "split_count=%d" % mode.split_count)
	reporter.check(mode.stage_shots == 0, "投擲カウントがリセットされない")

	mode.flying = false

	reporter.begin_case("3分裂の状態で発射すると0.4秒後に弾が2つ増える")
	# 命中でステージが進むと検証が曇るため、標的を遠くに退避させる。
	for t in mode.get_tree().get_nodes_in_group("targets"):
		t.position = Vector2(2000.0, 2000.0)
	harness.feedback_log.clear()
	mode.ammo = mode.MAX_AMMO
	mode.charging = true
	mode.charge_time = 0.8
	mode._fire()
	reporter.check(mode._shot_split == 3, "_shot_split=%d" % mode._shot_split)
	reporter.check(mode._extra_shells.size() == 0, "発射直後に増えている extra=%d" % mode._extra_shells.size())
	harness.step(mode.SPLIT_TIME + 0.2)
	reporter.check(mode._extra_shells.size() == 2, "分裂後に弾が増えない extra=%d" % mode._extra_shells.size())
	reporter.check(harness.feedback_log.has("split"), "splitイベントが発火しない: %s" % str(harness.feedback_log))

	mode.flying = false
	harness.teardown()
