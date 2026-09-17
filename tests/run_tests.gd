extends SceneTree

# L0 契約テストのヘッドレスランナー。
#   godot --headless --path . --script res://tests/run_tests.gd
# 時間はテスト側が固定タイムステップで注入するため、実時間を待たずに
# 数百秒ぶんのプレイを検証できる。結果は終了コードで返す。

const CONTRACT_DIR := "res://tests/contract"
const SPEC_PATH := "res://tests/spec/active.spec.json"
const REPORTER := preload("res://tests/support/reporter.gd")

func _initialize() -> void:
	# root は _initialize の時点ではまだツリーに入っておらず、追加した子の _ready が
	# 走らない。1フレーム待ってからテストを始める。
	await process_frame

	var spec := _load_spec()
	if spec.is_empty():
		printerr("FATAL: spec を読み込めない: %s" % SPEC_PATH)
		quit(1)
		return

	print("== L0 契約テスト (mode=%s)" % spec.get("id", "?"))
	var reporter = REPORTER.new()
	var scripts := _contract_scripts()
	if scripts.is_empty():
		printerr("FATAL: 契約テストが1件も見つからない: %s" % CONTRACT_DIR)
		quit(1)
		return

	for path in scripts:
		var before: int = reporter.failures.size()
		reporter.begin_suite(path.get_file())
		var test_script: GDScript = load(path)
		test_script.new().run(reporter, self, spec)
		var added: int = reporter.failures.size() - before
		print("  %s %s" % ["FAIL" if added > 0 else "ok  ", path.get_file()])

	print("")
	if reporter.failures.is_empty():
		print("== 全 %d 件の契約を満たしています" % reporter.passed)
		quit(0)
		return

	print("== 契約違反 %d 件 (成功 %d 件)" % [reporter.failures.size(), reporter.passed])
	for failure in reporter.failures:
		print("  - %s" % failure)
	quit(1)

func _load_spec() -> Dictionary:
	if not FileAccess.file_exists(SPEC_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPEC_PATH))
	return parsed if parsed is Dictionary else {}

func _contract_scripts() -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(CONTRACT_DIR)
	if dir == null:
		return found
	for file_name in dir.get_files():
		# エクスポート後は .gd が .gdc / .remap になるが、テストはソースから実行する
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			found.append("%s/%s" % [CONTRACT_DIR, file_name])
	found.sort()
	return found
