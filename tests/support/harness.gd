extends RefCounted

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const FIXED_DELTA := 1.0 / 60.0

var main: Node = null
var feedback_log: Array[String] = []

# main.tscn を丸ごと立ち上げたうえで自走を止める。実プレイと同じシーン構成のまま、
# 時間だけをテストが握る形にするので、演出やノード構成の変更に巻き込まれない。
func setup(tree: SceneTree, rng_seed: int = 12345) -> void:
	main = MAIN_SCENE.instantiate()
	tree.root.add_child(main)
	main.set_process(false)
	main.set_process_input(false)
	main.set_rng_seed(rng_seed)
	main.feedback_emitted.connect(_on_feedback)

func teardown() -> void:
	if is_instance_valid(main):
		main.get_parent().remove_child(main)
		main.free()
	main = null
	feedback_log.clear()

func _on_feedback(event_name: String) -> void:
	feedback_log.append(event_name)

func press() -> void:
	main.press_act()

func release() -> void:
	main.release_act()

func tap() -> void:
	main.press_act()
	main.tick(FIXED_DELTA)
	main.release_act()
	main.tick(FIXED_DELTA)

func step_once() -> void:
	main.tick(FIXED_DELTA)

func step(seconds: float) -> void:
	for i in _frames_for(seconds):
		main.tick(FIXED_DELTA)

# 無操作で放置する。失敗したら経過秒数を返し、しなければ seconds を返す。
func step_until_failure(seconds: float) -> float:
	var elapsed := 0.0
	for i in _frames_for(seconds):
		main.tick(FIXED_DELTA)
		elapsed += FIXED_DELTA
		if main.is_game_over():
			return elapsed
	return elapsed

# ボットに操作させる。生存できた秒数を返す。
func run_with_bot(bot: RefCounted, seconds: float) -> float:
	var elapsed := 0.0
	for i in _frames_for(seconds):
		bot.decide(main, self)
		main.tick(FIXED_DELTA)
		elapsed += FIXED_DELTA
		if main.is_game_over():
			return elapsed
	return elapsed

func _frames_for(seconds: float) -> int:
	return int(round(seconds / FIXED_DELTA))
