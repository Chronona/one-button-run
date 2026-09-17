extends RefCounted

# ランナーモード用の参照プレイヤー。
# 「ボットが書けない = 人間にも理不尽である」という仮定のもと、
# このボットが規定秒数を生存できることをプレイアビリティの代理指標にしている。

# プレイヤー矩形の前端 X。ここを障害物が越えると当たり判定に入る。
const PLAYER_FRONT_X := 170.0
# 何秒手前で踏み切るか。滞空時間 1.2 秒に対して十分な余裕がある値。
const LEAD_SECONDS := 0.35

func decide(main: Node, harness: RefCounted) -> void:
	var player = main.get_active_mode().get_player()
	if not player.on_ground:
		# 空中では押しっぱなしにして、ジャンプカットで高度を失わないようにする
		return

	var lead: float = main.get_difficulty() * LEAD_SECONDS
	for obstacle in main.get_tree().get_nodes_in_group("obstacles"):
		var distance: float = obstacle.position.x - PLAYER_FRONT_X
		if distance >= 0.0 and distance <= lead:
			harness.press()
			return
	harness.release()
