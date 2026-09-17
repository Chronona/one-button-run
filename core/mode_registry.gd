extends RefCounted

# モードレジストリの唯一の解決経路。
#
# 「registry.json の active が指すモードから scene / spec / bot を引く」という手順は
# ホスト・契約テスト・ゴールデン記録ツールのすべてが必要とする。同じ手順が各所に
# 写経されていると、レジストリの形を変えたときに一部だけ古い読み方のまま残る。
# 読み方はここ1箇所に置き、呼ぶ側は結果だけを受け取る。
#
# 読めないときは黙って空を返す。「レジストリが壊れていないこと」を検査するのは
# tests/contract/test_mode_registry.gd の仕事で、ここは検査をしない。
# 壊れている理由を名指ししたい呼び出し側は read_json_or_null を使う。

const REGISTRY_PATH := "res://modes/registry.json"

# JSON オブジェクトとして読む。ファイルが無い・壊れている・オブジェクトでない
# ときは null を返す（どれで失敗したかを呼び出し側が区別できるようにする）。
static func read_json_or_null(path: String) -> Variant:
	if path == "" or not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else null

static func read_json(path: String) -> Dictionary:
	var parsed: Variant = read_json_or_null(path)
	return parsed if parsed is Dictionary else {}

static func registry() -> Dictionary:
	return read_json(REGISTRY_PATH)

static func active_id() -> String:
	var active: String = registry().get("active", "")
	return active

# active が指すモードの定義（scene / spec のパス）。
static func active_entry() -> Dictionary:
	var reg := registry()
	var active: String = reg.get("active", "")
	var modes: Dictionary = reg.get("modes", {})
	var entry: Dictionary = modes.get(active, {})
	return entry

# active が指すモードの spec。spec 側に id が無ければ registry のキーで補う。
static func active_spec() -> Dictionary:
	var spec_path: String = active_entry().get("spec", "")
	var spec := read_json(spec_path)
	if spec.is_empty():
		return {}
	spec["id"] = spec.get("id", active_id())
	return spec
