extends RefCounted

# L0 契約: ゲームプレイ側のスクリプトは入力も時間も自前で取りに行かない。
# 入力はホストが注入する1経路だけ、時間は tick(delta) だけ。
# これが守られている限り、2つ目の操作が生えることも、テストが実時間に縛られることもない。

const FORBIDDEN_PATTERNS := {
	"Input.": "Input シングルトンを直接参照している（入力はホストから注入する）",
	"func _input(": "_input を持っている（入力経路はホストに一本化する）",
	"func _unhandled_input(": "_unhandled_input を持っている（入力経路はホストに一本化する）",
	"func _process(": "_process を持っている（時間はホストから tick で注入する）",
	"func _physics_process(": "_physics_process を持っている（時間はホストから tick で注入する）",
}

func run(reporter: RefCounted, _tree: SceneTree, spec: Dictionary) -> void:
	var paths: Array = spec.get("input_isolated_scripts", [])
	reporter.begin_case("検査対象が spec に定義されている")
	reporter.check(not paths.is_empty(), "input_isolated_scripts が空")

	for path in paths:
		reporter.begin_case("%s が入力と時間を自前で取っていない" % path)
		if not FileAccess.file_exists(path):
			reporter.check(false, "ファイルが存在しない")
			continue
		var source := FileAccess.get_file_as_string(path)
		for pattern in FORBIDDEN_PATTERNS:
			reporter.check(not source.contains(pattern), FORBIDDEN_PATTERNS[pattern])
