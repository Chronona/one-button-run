extends RefCounted

# フラッピーモード用の参照プレイヤー。
# 「ボットが書けない = 人間にも理不尽である」という仮定のもと、
# このボットが規定秒数を生存できることをプレイアビリティの代理指標にしている。
#
# 方針: いちばん近いゲートの隙間の高さを目標に保つ。ゲートが無ければ
# 中央付近で待つ。目標より低く、かつ上昇中ではなければ羽ばたく。

const HOVER_Y := 280.0
const DEADBAND := 12.0
const PLAYER_FRONT_X := 200.0
# この上昇速度より速い（負に大きい）間は追加で羽ばたかない。
# 毎フレーム羽ばたいて天井に張り付くのを防ぐ。
const RISE_LIMIT := -120.0

func decide(main: Node, harness: RefCounted) -> void:
	var mode: Node = main.get_active_mode().get_player()
	var target: float = HOVER_Y
	var nearest: Node2D = null
	var nearest_x: float = 1.0e9
	for gate_node in main.get_tree().get_nodes_in_group("gates"):
		var front: float = gate_node.front_x()
		if front >= PLAYER_FRONT_X - 40.0 and front < nearest_x:
			nearest = gate_node
			nearest_x = front
	if nearest != null:
		target = nearest.gap_center
	if mode.player_pos.y > target + DEADBAND and mode.velocity_y > RISE_LIMIT:
		harness.press()
	else:
		harness.release()
