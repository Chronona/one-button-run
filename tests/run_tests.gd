extends SceneTree

# 品質テストのヘッドレスランナー。
#   godot --headless --path . --script res://tests/run_tests.gd
# 時間はテスト側が固定タイムステップで注入するため、実時間を待たずに
# 数百秒ぶんのプレイを検証できる。結果は終了コードで返す。
#
# 層はディレクトリで分かれている（docs/adr/0001, 0005）。
#   tests/contract/   L0: ジャンルが変わっても不変の契約。落ちたら「遊べていない」
#   tests/regression/ L2: 記録した値との差分検出。落ちたら「体感が変わった」
# どちらも同じランナーから同じ順（L0 -> L2）で走らせる。先に契約が落ちている
# ときに回帰差分まで並ぶと、原因が埋もれるため。

const CONTRACT_DIR := "res://tests/contract"
const REGRESSION_DIR := "res://tests/regression"
const REPORTER := preload("res://tests/support/reporter.gd")
const MODE_REGISTRY := preload("res://core/mode_registry.gd")
const REGISTRY_CONTRACT := "res://tests/contract/test_mode_registry.gd"

func _initialize() -> void:
	# root は _initialize の時点ではまだツリーに入っておらず、追加した子の _ready が
	# 走らない。1フレーム待ってからテストを始める。
	await process_frame

	var reporter = REPORTER.new()
	var contract_scripts := _scripts_in(CONTRACT_DIR)
	if contract_scripts.is_empty():
		printerr("FATAL: 契約テストが1件も見つからない: %s" % CONTRACT_DIR)
		quit(1)
		return

	var spec: Dictionary = MODE_REGISTRY.active_spec()
	if spec.is_empty():
		# spec が引けない原因はほぼ registry の不整合なので、他のテストを走らせて
		# 二次被害の失敗を並べるより、レジストリ契約だけを回して原因を名指しする。
		print("== L0 契約テスト (有効なモードの spec を解決できない)")
		_run_one(reporter, REGISTRY_CONTRACT, {})
		_report(reporter)
		return

	print("== L0 契約テスト (mode=%s)" % spec.get("id", "?"))
	for path in contract_scripts:
		_run_one(reporter, path, spec)

	var regression_scripts := _scripts_in(REGRESSION_DIR)
	if not regression_scripts.is_empty():
		print("")
		print("== L2 回帰検出 (mode=%s)" % spec.get("id", "?"))
		for path in regression_scripts:
			_run_one(reporter, path, spec)

	_report(reporter)

func _run_one(reporter: RefCounted, path: String, spec: Dictionary) -> void:
	var before: int = reporter.failures.size()
	reporter.begin_suite(path.get_file())
	var test_script: GDScript = load(path)
	test_script.new().run(reporter, self, spec)
	var added: int = reporter.failures.size() - before
	print("  %s %s" % ["FAIL" if added > 0 else "ok  ", path.get_file()])

func _report(reporter: RefCounted) -> void:
	print("")
	if reporter.failures.is_empty():
		print("== 全 %d 件の契約を満たしています" % reporter.passed)
		quit(0)
		return

	print("== 契約違反 %d 件 (成功 %d 件)" % [reporter.failures.size(), reporter.passed])
	for failure in reporter.failures:
		print("  - %s" % failure)
	quit(1)

func _scripts_in(dir_path: String) -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	for file_name in dir.get_files():
		# エクスポート後は .gd が .gdc / .remap になるが、テストはソースから実行する
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			found.append("%s/%s" % [dir_path, file_name])
	found.sort()
	return found
