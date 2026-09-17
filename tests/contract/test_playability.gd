extends RefCounted

# L0 契約: ゲームとして成立していること。
#  - 操作しなければ必ず死ぬ（= 放置で遊べてしまうゲームではない）
#  - 参照ボットは規定秒数を生存できる（= 理不尽な詰み配置がない）
#  - 開始直後に猶予がある / 難易度は単調非減少で上限がある

const HARNESS := preload("res://tests/support/harness.gd")

func run(reporter: RefCounted, tree: SceneTree, spec: Dictionary) -> void:
	_test_grace(reporter, tree, spec)
	_test_idle_death(reporter, tree, spec)
	_test_difficulty_curve(reporter, tree, spec)
	_test_bot_survival(reporter, tree, spec)

func _test_grace(reporter: RefCounted, tree: SceneTree, spec: Dictionary) -> void:
	var grace_min: float = spec.get("grace_seconds_min", 1.0)
	reporter.begin_case("開始直後に猶予がある（%.1f 秒は無操作でも死なない）" % grace_min)
	var harness = HARNESS.new()
	harness.setup(tree)
	harness.main.start_game()
	harness.step(grace_min)
	reporter.check(not harness.main.is_game_over(), "開始から %.1f 秒以内に失敗した" % grace_min)
	harness.teardown()

func _test_idle_death(reporter: RefCounted, tree: SceneTree, spec: Dictionary) -> void:
	var limit: float = spec.get("idle_death_max_seconds", 10.0)
	reporter.begin_case("無操作なら %.0f 秒以内に必ず失敗する" % limit)
	var harness = HARNESS.new()
	harness.setup(tree)
	harness.main.start_game()
	harness.step_until_failure(limit)
	reporter.check(harness.main.is_game_over(), "無操作で %.0f 秒生き延びてしまった（脅威が機能していない）" % limit)
	harness.teardown()

func _test_difficulty_curve(reporter: RefCounted, tree: SceneTree, spec: Dictionary) -> void:
	var cap: float = spec.get("max_speed_cap", 600.0)
	var harness = HARNESS.new()
	harness.setup(tree)
	var main = harness.main
	main.start_game()

	reporter.begin_case("難易度は単調非減少")
	var previous: float = main.get_difficulty()
	var monotonic := true
	for i in 600:
		main.tick(harness.FIXED_DELTA)
		if main.is_game_over():
			main.start_game()
			previous = main.get_difficulty()
			continue
		if main.get_difficulty() < previous - 0.0001:
			monotonic = false
			break
		previous = main.get_difficulty()
	reporter.check(monotonic, "進行中に難易度が下がった")

	reporter.begin_case("難易度に上限がある")
	main.start_game()
	main.score = 100000.0
	main.tick(harness.FIXED_DELTA)
	reporter.at_most(main.get_difficulty(), cap, "速度が上限 %.0f を超えた" % cap)

	harness.teardown()

func _test_bot_survival(reporter: RefCounted, tree: SceneTree, spec: Dictionary) -> void:
	var target: float = spec.get("bot_min_survival_seconds", 60.0)
	var bot_path: String = spec.get("bot", "")
	reporter.begin_case("参照ボットが %.0f 秒生存できる" % target)
	if bot_path == "" or not ResourceLoader.exists(bot_path):
		reporter.check(false, "spec の bot が見つからない: %s" % bot_path)
		return

	var bot_script: GDScript = load(bot_path)
	for rng_seed in spec.get("bot_seeds", [1]):
		var harness = HARNESS.new()
		harness.setup(tree, int(rng_seed))
		harness.main.start_game()
		var survived: float = harness.run_with_bot(bot_script.new(), target)
		reporter.check(not harness.main.is_game_over(),
			"seed=%d で %.2f 秒しか生存できなかった（目標 %.0f 秒）" % [int(rng_seed), survived, target])
		harness.teardown()
