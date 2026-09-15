extends RefCounted

# L0 契約: 出荷できる状態であること。
# 週次でジャンルごと入れ替えても、Web に出せなくなったら遊んでもらえない。

func run(reporter: RefCounted, _tree: SceneTree, spec: Dictionary) -> void:
	reporter.begin_case("メインシーンが存在する")
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
	reporter.check(main_scene != "" and ResourceLoader.exists(main_scene),
		"run/main_scene が解決できない: '%s'" % main_scene)

	var presets_path := "res://export_presets.cfg"
	reporter.begin_case("エクスポートプリセット定義が存在する")
	if not reporter.check(FileAccess.file_exists(presets_path), "export_presets.cfg がない"):
		return
	var presets := FileAccess.get_file_as_string(presets_path)
	for preset_name in spec.get("required_export_presets", []):
		reporter.begin_case("'%s' プリセットが定義されている" % preset_name)
		reporter.check(presets.contains('name="%s"' % preset_name), "プリセットが見つからない")
