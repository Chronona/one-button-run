extends Node2D

# ゲームモードの抽象インターフェース。
#
# モードは「今タップされた」という事実だけを受け取る。ジャンルの差は
# タップが何を意味するか（ジャンプ / 羽ばたき / 発射 / 判定）で吸収するので、
# 1ボタンという制約がアーキテクチャ側で強制される。
#
# 時間も外から注入される。モードが自前の _process を持たないため、テストは
# 実時間を待たずに固定タイムステップで何十秒ぶんでも再生できる。
# この2点は tests/contract/test_input_isolation.gd が静的に検査している。

var host: Node = null

# ホストから一度だけ呼ばれる。RNG などはここで受け取った host 経由で使う。
func mode_setup(game_host: Node) -> void:
	host = game_host

# 1ラウンドの開始。残存物の掃除と初期配置を行う。
func mode_start() -> void:
	pass

# 進行。delta も入力もホストが渡す。
func mode_tick(_delta: float, _act_pressed: bool, _act_released: bool) -> void:
	pass

# このラウンドが失敗で終わったか。ホストはこれを見て GAME_OVER に遷移する。
func is_failed() -> bool:
	return false

# 難易度の現在値。単位はモードごとに異なってよい（ランナーなら速度）。
# 契約テストは「単調非減少かつ上限つき」であることだけを見る。
func get_difficulty() -> float:
	return 0.0

# 演出イベント名 -> { particles: ノード名, se: ノード名 }。
# ノードはモードのシーン内にある。イベント名で契約するので、演出やアセットを
# 丸ごと差し替えても tests/contract/test_feedback.gd は書き換わらない。
func get_feedback_map() -> Dictionary:
	return {}

# そのイベントの演出をどこに出すか。ジャンルごとにプレイヤーの持ち方が違うので
# モードが答える。ホストは座標を知らないし、知る必要もない。
func get_feedback_position(_event_name: String) -> Vector2:
	return Vector2.ZERO

# 演出の再生。ノードの解決も配置もモードのシーン内で完結する。
# ホストはイベント名を渡すだけで、見た目・音・位置のどれも知らない。
func play_feedback(event_name: String) -> void:
	var entry: Dictionary = get_feedback_map().get(event_name, {})

	var particles_name: String = entry.get("particles", "")
	if particles_name != "":
		var particles = get_node_or_null(particles_name)
		if particles != null and particles.has_method("restart"):
			particles.position = get_feedback_position(event_name)
			particles.restart()

	var se_name: String = entry.get("se", "")
	if se_name != "":
		var sound_player = get_node_or_null(se_name)
		if sound_player != null and sound_player.has_method("play"):
			sound_player.play()
