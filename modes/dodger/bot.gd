extends RefCounted

# ドッジャーモード用の参照プレイヤー。
# 「ボットが書けない = 人間にも理不尽である」という仮定のもと、
# このボットが規定秒数を生存できることをプレイアビリティの代理指標にしている。
#
# 方針: まだ通過していないトゲのうち最も手前のものを見て、
# 自機と同じレーンにあれば切り替える。切替は瞬時で、トゲは必ず
# 1 つずつ交互のレーンに来るため、この判断だけで回避が完結する。

# 通過済みとみなす後端の余白。トゲ半幅(28)と自機半幅(20)の合計より
# 大きく取るので、切り替えた先でかすめることはない。
const PASSED_MARGIN := 60.0

func decide(main: Node, harness: RefCounted) -> void:
	var mode: Node = main.get_active_mode()
	var nearest: Node2D = null
	var nearest_x: float = 1.0e9
	for spike_node in main.get_tree().get_nodes_in_group("spikes"):
		var sx: float = spike_node.position.x
		if sx >= mode.PLAYER_X - PASSED_MARGIN and sx < nearest_x:
			nearest = spike_node
			nearest_x = sx
	if nearest != null and nearest.lane == mode.player_lane:
		harness.press()
	else:
		harness.release()
