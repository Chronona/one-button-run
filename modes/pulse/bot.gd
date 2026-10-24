extends RefCounted

# パルスモード用の参照プレイヤー。
# 「ボットが書けない = 人間にも理不尽である」という仮定のもと、
# このボットが規定秒数を生存できることをプレイアビリティの代理指標にしている。
#
# 方針: 縮む輪の位相が許容窓に入った最初のフレームで叩く。
# 判定は時間を進める前に今の位相で行われるため、読んだ値と判定の値が
# 食い違うことはない。窓の外では叩かない（空振りは即失敗のため）。

func decide(main: Node, harness: RefCounted) -> void:
	var mode: Node = main.get_active_mode()
	if mode.is_failed():
		harness.release()
		return
	var phase: float = mode.phase
	if mode.window_start() <= phase and phase <= mode.window_end():
		harness.press()
	else:
		harness.release()
