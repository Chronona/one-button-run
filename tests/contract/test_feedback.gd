extends RefCounted

# L0 契約: 操作・失敗・記録更新には反応がある。
# ノード名ではなくイベント名で検査するので、演出やアセットを丸ごと差し替えても壊れない。

const HARNESS := preload("res://tests/support/harness.gd")

func run(reporter: RefCounted, tree: SceneTree, spec: Dictionary) -> void:
	var harness = HARNESS.new()
	harness.setup(tree)
	var main = harness.main
	var feedback_map: Dictionary = main.FEEDBACK_MAP

	for event_name in spec.get("required_feedback_events", []):
		reporter.begin_case("イベント '%s' に反応が定義されている" % event_name)
		if not reporter.check(feedback_map.has(event_name), "FEEDBACK_MAP に未定義"):
			continue
		var entry: Dictionary = feedback_map[event_name]
		var particles_name: String = entry.get("particles", "")
		var se_name: String = entry.get("se", "")
		var has_visual := particles_name != "" and main.get_node_or_null(particles_name) != null
		var has_audio := se_name != "" and main.get_node_or_null(se_name) != null
		reporter.check(has_visual or has_audio, "視覚・聴覚どちらの反応も解決できない")

	for event_name in spec.get("dual_channel_feedback_events", []):
		reporter.begin_case("イベント '%s' は視覚と聴覚の両方で反応する" % event_name)
		var entry: Dictionary = feedback_map.get(event_name, {})
		var particles_name: String = entry.get("particles", "")
		var se_name: String = entry.get("se", "")
		reporter.check(particles_name != "" and main.get_node_or_null(particles_name) != null,
			"視覚反応が解決できない: '%s'" % particles_name)
		reporter.check(se_name != "" and main.get_node_or_null(se_name) != null,
			"聴覚反応が解決できない: '%s'" % se_name)

	reporter.begin_case("操作すると 'act' が発火する")
	harness.tap()
	reporter.check(harness.feedback_log.has("act"), "発火したイベント: %s" % str(harness.feedback_log))

	reporter.begin_case("失敗すると 'fail' が発火する")
	harness.feedback_log.clear()
	main.high_score = 999999
	main.game_over()
	reporter.check(harness.feedback_log.has("fail"), "発火したイベント: %s" % str(harness.feedback_log))

	reporter.begin_case("記録更新で 'record' が発火する")
	harness.feedback_log.clear()
	main.start_game()
	main.high_score = 0
	main.score = 50.0
	main.game_over()
	reporter.check(harness.feedback_log.has("record"), "発火したイベント: %s" % str(harness.feedback_log))

	harness.teardown()
