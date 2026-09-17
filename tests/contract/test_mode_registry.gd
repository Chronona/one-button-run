extends RefCounted

# L0 契約: モードレジストリが常に整合していること。
#
# 週次の大型アップデートは「新しいモードを追加して active を切り替える」形で入る。
# そのとき壊れやすいのは次の2つで、どちらもゲームを起動しないと気づけない。
#
#   - 追加したモードの scene / spec / bot のどれかが欠けている
#   - ロールバック先として残しているはずの旧モードが、参照切れで実は戻せない
#
# active なモードだけでなく登録されている全モードを検査するので、
# 「active を戻すだけで巻き戻せる」という前提が保たれていることを毎回確認できる。

const REGISTRY_PATH := "res://modes/registry.json"

# 新しいモードが同梱しなければならない契約値。ここが欠けていると
# test_playability.gd が「遊べるか」を判定できない。
const REQUIRED_SPEC_KEYS := [
	"bot",
	"bot_min_survival_seconds",
	"idle_death_max_seconds",
	"grace_seconds_min",
	"required_feedback_events",
	"input_isolated_scripts",
]

func run(reporter: RefCounted, _tree: SceneTree, _spec: Dictionary) -> void:
	reporter.begin_case("registry.json が読める")
	if not reporter.check(FileAccess.file_exists(REGISTRY_PATH), "registry.json がない"):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY_PATH))
	if not reporter.check(parsed is Dictionary, "registry.json が JSON オブジェクトではない"):
		return
	var registry: Dictionary = parsed

	var modes: Dictionary = registry.get("modes", {})
	reporter.begin_case("モードが1つ以上登録されている")
	reporter.check(not modes.is_empty(), "modes が空")

	reporter.begin_case("active が登録済みのモードを指している")
	var active: String = registry.get("active", "")
	reporter.check(active != "" and modes.has(active),
		"active='%s' は modes のキー %s に存在しない" % [active, str(modes.keys())])

	for mode_id in modes:
		var entry: Dictionary = modes[mode_id]

		reporter.begin_case("モード '%s' のシーンが解決できる" % mode_id)
		var scene_path: String = entry.get("scene", "")
		reporter.check(scene_path != "" and ResourceLoader.exists(scene_path),
			"scene が解決できない: '%s'" % scene_path)

		reporter.begin_case("モード '%s' の spec が読める" % mode_id)
		var spec_path: String = entry.get("spec", "")
		if not reporter.check(spec_path != "" and FileAccess.file_exists(spec_path),
				"spec が見つからない: '%s'" % spec_path):
			continue
		var mode_spec: Variant = JSON.parse_string(FileAccess.get_file_as_string(spec_path))
		if not reporter.check(mode_spec is Dictionary, "spec が JSON オブジェクトではない"):
			continue

		reporter.begin_case("モード '%s' の spec に必須項目が揃っている" % mode_id)
		for key in REQUIRED_SPEC_KEYS:
			reporter.check((mode_spec as Dictionary).has(key), "spec に '%s' がない" % key)

		# ボットが無いモードは「遊べるか」を判定できないので、ロールバック先にできない。
		reporter.begin_case("モード '%s' に参照ボットが同梱されている" % mode_id)
		var bot_path: String = (mode_spec as Dictionary).get("bot", "")
		reporter.check(bot_path != "" and ResourceLoader.exists(bot_path),
			"bot が解決できない: '%s'" % bot_path)
