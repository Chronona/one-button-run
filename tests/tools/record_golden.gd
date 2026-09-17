extends SceneTree

# いま有効なモードの難易度カーブを記録して tests/golden/<mode>.json に書き出す。
#   bash scripts/record-golden.sh
#
# ゴールデン値は tests/ 配下にあるため、自動フローは CI の guard ジョブによって
# 更新できない。バランス調整でカーブが変わったときは、人間が意図的に記録し直す。

const REGISTRY_PATH := "res://modes/registry.json"
const GOLDEN_DIR := "res://tests/golden"
const REPLAY := preload("res://tests/support/replay.gd")

const RNG_SEED := 424242
const CHECKPOINTS := [10.0, 30.0, 60.0, 120.0, 180.0]
const DIFFICULTY_TOLERANCE := 1.0
const ACT_COUNT_TOLERANCE := 1

func _initialize() -> void:
	await process_frame

	var registry := _read_json(REGISTRY_PATH)
	var active: String = registry.get("active", "")
	var entry: Dictionary = registry.get("modes", {}).get(active, {})
	var spec := _read_json(entry.get("spec", ""))
	var bot_path: String = spec.get("bot", "")

	if active == "" or bot_path == "" or not ResourceLoader.exists(bot_path):
		printerr("FATAL: 有効なモードか参照ボットを解決できない (active='%s', bot='%s')" % [active, bot_path])
		quit(1)
		return

	var samples := REPLAY.replay(self, load(bot_path), RNG_SEED, CHECKPOINTS)

	var golden := {
		"mode": active,
		"note": "決定論リプレイの基準値。バランス調整で意図的にカーブを変えたときだけ、scripts/record-golden.sh で記録し直す。",
		"seed": RNG_SEED,
		"checkpoints_seconds": CHECKPOINTS,
		"difficulty_tolerance": DIFFICULTY_TOLERANCE,
		"act_count_tolerance": ACT_COUNT_TOLERANCE,
		"samples": samples,
	}

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GOLDEN_DIR))
	var path := "%s/%s.json" % [GOLDEN_DIR, active]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("FATAL: 書き込めない: %s" % path)
		quit(1)
		return
	file.store_string(JSON.stringify(golden, "  ") + "\n")
	file = null

	print("== 記録しました: %s" % path)
	for sample in samples:
		print("  t=%5.1f  difficulty=%7.2f  act_count=%3d  alive=%s"
			% [sample["t"], sample["difficulty"], sample["act_count"], sample["alive"]])
	quit(0)

func _read_json(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
