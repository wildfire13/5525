# 専用VFXの描画負荷比較

基点e5d4d5fと新版を同じ正規packet・戦場・FHD1920×1080・yaw0/pitch0.7/zoom16.5で比較した。足払い、ヒール、防御、近接、防御被弾、スタンプを各5回（初回・2回目・反復3回）。録画、PNG、viewport読み戻し、他の描画/encode/回帰処理は停止し、音3種OFF、隔離XDGで測定した。caseごとのidle90frame、各再生後1秒＋10frameの後始末も同条件。

環境はOpenGL Compatibility / Mesa llvmpipe LLVM19.1.7のCPUソフトウェア描画。`/dev/dri`なし、CPU affinity5、cgroup quota4CPU、メモリ上限16GiB。VSync変更はdriver未対応。実GPUや「オンボードGPU」の測定ではない。

表は反復3〜5回の各phase中央値の中央値、単位ms。スタンプ被弾は3個の実被害phaseを各反復内でまとめた値。

| 表示 | 基点 | 新版 |
|---|---:|---:|
| 足払い発動 | 156.5 | 142.0 |
| ヒール発動 | 147.4 | 135.7 |
| ヒール結果 | 145.4 | 159.8 |
| 防御起動 | 138.7 | 129.1 |
| 通常近接の発動 | 159.9 | 136.8 |
| 通常近接の被弾 | 142.9 | 131.8 |
| 防御された攻撃の発動 | 144.0 | 127.7 |
| 防御された被弾 | 145.6 | 136.3 |
| スタンプ発動 | 144.5 | 134.7 |
| スタンプ被弾 | 138.6 | 141.2 |

ヒール結果は+9.9%。一方でidle中央値自体も旧141.6〜148.3ms、新134.3〜154.3msと変動した。短いphaseの描画標本は多くが2〜5個（スタンプ被弾は一部12個）で、p95も安定したtail推定には足りない。版順の各1プロセス比較であり、高速化や差の原因を確定する試験ではない。基点から約1,000drawcallsの戦場をCPU描画している制約が大きい。別の都市画面のframe時間とは場面が異なる。

`frame_post_draw`間隔は画面フレーム間隔で、Godot `TIME_PROCESS`ともCPU全threadの総仕事量とも異なる。phase開始で時計をresetするため最初のframe標本は端数区間を含む。CPU総時間は `/proc/self/stat` のutime+stime（100Hz）から概算し、並列thread分の仕事を合計する。約600ms CPU/frameでも画面が600ms止まるという意味ではない。初回は通常の読込とmaterial warmup後で、完全なcold decode/import/shader測定ではない。

演出の描画frame数は旧235・新195、idleは双方540。表示duration自体を変えているため、一連のwall時間やframe数の少なさを高速化としない。全runのCPU quota throttlingは旧83.0秒相当、新77.0秒相当増加しており、実GPUへの外挿はできない。

全30cleanupで旧nodes478・新485と各版内は一定、VFXメッシュ0・active0、6ケースとも正規backend保存状態不変。新版は19texture（PNG計8,927,398bytes）を保持する設計。MEMORY_STATICは旧97.356→98.023MiB、新98.446→99.383MiBだが、このmonitorはtexture/driverを含む全VRAMやRSSではない。長時間soakやmemory leakの不存在までは保証しない。

実GPU、Windows実UI/DPI、cold起動/初import、長時間の安定性は未測定。画質を落とす最適化やゲーム規則変更は行わない。基点の正常完了1runと同条件で正常完了した新版1runだけを採用し、起動設定ミスや途中停止した計測は含めていない。
