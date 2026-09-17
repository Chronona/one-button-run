extends RefCounted

# L0 契約: 操作は「1つのアクション」だけで、それがキー・マウス・タップに束ねられている。
# ジャンルが変わっても不変。ここが崩れたら「1ボタン(タップ)で遊べるゲーム」ではなくなる。

const HARNESS := preload("res://tests/support/harness.gd")

func run(reporter: RefCounted, tree: SceneTree, spec: Dictionary) -> void:
	var harness = HARNESS.new()
	harness.setup(tree)

	reporter.begin_case("ゲームプレイ用アクションはちょうど1つ")
	var gameplay_actions: Array[StringName] = []
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			gameplay_actions.append(action)
	reporter.equal(gameplay_actions.size(), 1, "ゲームプレイ用アクション数: %s" % str(gameplay_actions))

	reporter.begin_case("そのアクションは4系統の入力に束ねられている")
	var action: StringName = &"jump" if gameplay_actions.is_empty() else gameplay_actions[0]
	var has_space := false
	var has_up := false
	var has_mouse := false
	var has_touch := false
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			if event.physical_keycode == KEY_SPACE:
				has_space = true
			if event.physical_keycode == KEY_UP:
				has_up = true
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			has_mouse = true
		elif event is InputEventScreenTouch:
			has_touch = true
	reporter.check(has_space, "Space キーが割り当てられていない")
	reporter.check(has_up, "↑ キーが割り当てられていない")
	reporter.check(has_mouse, "左クリックが割り当てられていない")
	reporter.check(has_touch, "タップ(ScreenTouch)が割り当てられていない")

	harness.teardown()
