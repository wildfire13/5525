# 4シートUI改修の公開前性能診断

対象は `79086fb71ed883eff42f6eed89a965f564458d69`（A）と、改修版 `68a2158a3320f9d28cc3ce00fb5510478c3746a5`（B）。本診断では実行コード・画像・ゲームデータを変更していない。実験用の暗幕非表示・面積縮小・Shader統合は外部スクリプトで評価し、製品へ採用していない。

## 指標と比較条件

従来の都市14.0→22.9msは、`Time.get_ticks_usec()` で記録した `RenderingServer.frame_post_draw` 同士のwall時間間隔の中央値。描画とフレーム進行・待ち・OSスケジューリングを含むため、純粋なスクリプトCPU時間、GPU時間、本人PCのFPSと解釈しない。

- A1→B1→B2→A2→A3→B3の順、各版3fresh process/別検証profile。同じ画像・NPC・表示用乱数seed・1920×1080。ロード/import/クリック/PNG読出は計測外。
- 各場面90frame以上かつ1.5秒以上暖機し180frameを計測。計18場面/3,240frame。全6runが成功。
- Godot4.6.3 / OpenGL Compatibility / X11 / Mesa llvmpipe(LLVM19.1.7)。テストプロセスのみVSync Disabled/maxFPS0/low-CPU-mode false。製品の上限設定は変更していない。
- 親・担当間で重い試験を並走させない。可視CPU/affinityは5、cgroup quotaは4CPU相当。Bは平均3.86〜3.90CPUを使い、quotaによるthrottleも発生。
- wall raw分布とGodot全threadの `/proc` utime+stimeを別々に記録。CPU総時間はparallel workerの合計なのでwall時間を上回る。GodotのTIME_PROCESS等monitorは最大約1秒遅れて更新され得るため、それだけを純CPU時間として用いない。
- BGM/ボイス/SE OFF、Dummy出力。BのhoverはCanvas Control1/Layer1025/native PopupPanel0を前後assertし、旧native代替表示のサンプルは除外。

公式の信号/monitor定義: [RenderingServer](https://docs.godotengine.org/en/4.6/classes/class_renderingserver.html#signals)、[Performance](https://docs.godotengine.org/en/4.6/classes/class_performance.html)。

## 反復結果

各欄は3試行中央値の代表値。括弧は試行ごとのwall中央値の最小〜最大。

|場面|A wall ms|B wall ms|全thread CPU ms/frame A→B|wall p95代表値 A→B ms|
|---|---|---|---|---|
|都市|15.06 (13.71〜15.13)|21.06 (20.92〜22.72)|57.39→82.44|19.61→26.36|
|宿屋|21.36 (20.82〜22.56)|28.49 (26.41〜28.75)|82.17→113.22|26.05→35.78|
|スタンプ全文hover|34.02 (33.30〜35.22)|40.13 (39.82〜40.72)|130.28→158.28|40.62→47.74|

3場面ともA/Bの試行間中央値範囲は重ならず、Godotが実行したCPU総仕事量も増えた。増加は単発サンプルのばらつきだけでは説明できない。固定されたCPU上限でのソフトウェア描画の結果であり、実GPUの性能低下率や製品の必要CPU数へ一般化しない。OS/cacheを破壊しておらず、長時間負荷・温度変動までは評価していない。

## 原因の切り分け

背景ツリーは一つのstill、一つの可読性shadeと必要なNPCであり、背景textureの重複配置はない。背景再生成はrender/画面更新時のみ。main._processから毎frame作り直していない。都市のdrawcallは27→26とむしろ1減っており、呼出数だけで描画仕事量は判断できない。

68aの同じ都市を同一processで切り替える診断（各180frame、暖機あり）では次を観測した。全normal復帰とmain停止画像は通常画像とbyte完全一致した。

|診断状態|wall中央値 ms|CPU総ms/frame|
|---|---:|---:|
|通常の時間変動範囲|20.14〜23.37|78.50〜90.89|
|shade非表示|18.13|62.83|
|背景+shadeの描画面積56.25%|17.28|64.44|
|mainの_processだけ停止|23.56|90.67|
|直後の通常復帰|23.37|90.89|

FHDのshadeは毎frame約207万pixelのblendを追加する。全面画像と透過合成の面積を下げる介入でCPU総時間も減り、main callback停止では改善が見えないため、都市の主因はCPU raster/透過overdraw増と考える。shade非表示/面積縮小は見た目を変える診断であり、製品には適用しない。追加の同process診断では、宿屋のNPC非表示でwall25.70→23.86ms/CPU103.78→96.33ms/frameとなり、復帰で28.56/112.83へ戻った。描画寄与と整合するがnormalにドリフトがあり、NPCだけの固定悪化率にはしない。hoverの毎frame処理停止ではwall40.28→39.16→39.97ms、CPU157.17→153.44→157.22ms/frame、drawcall279同一。小さい寄与は否定しないが単回ノイズも残り、支配的原因とは判断しない。NPC/hoverの全復帰画像とhover停止画像はbyte一致、セーブと3種の表示用乱数も不変。これらの停止/非表示は診断中だけ行い、製品へ残していない。

## 小さい最適化候補の採否

外部runtimeでshadeの色合成を背景fragmentへ統合し、1draw減らす2案を試した。原画31枚は不透明RGBで、色の理論式は `.56 × texture + .44 × (.025,.04,.06)`。単純な乗算modulateでは加算項が消えるため等価ではない。

直接式と、入力RGBを8bit丸めしてから合成する式を比較したが、両案の出力は同一で、旧2passとは最大1/255のRGBA差が残った。FHD差分pixelは都市217,979、宿屋133,419、武器店97,047。元へ戻した全画像は差分0、NPC/UI/セーブ/訪問乱数は維持した。宿屋・武器店の単回サンプルでは短縮したものの、都市はノイズが大きく、採用可能な改善率は未確定。

**画素差の許容判断と追加の反復比較が必要な案として採用しない。** 画像縮小、NPC縮小、shade削除、FPS上限/renderer切替、画質/情報削減も行わない。同rect再設定等のcacheは都市の支配要因を解決する証拠がなく、未測定の変更を増やさない。要求した見た目を保ったまま明確に利益のある小修正は今回確定できず、68aの描画を維持する。

## 確認結果と残る範囲

実行コードは68aから変更していないため、既存の最終標準40/40・native23/23・全文hover525/525・独立OSの各成功は同じsource hashに対応する。今回の追加検証は統制6run、runtime診断、画素比較と復帰確認。原本画像・施設/NPC/アイコン・AGENTSの決定文面も変更していない。

実GPU搭載PCのFPS、Windows実UI/OS DPI、長時間負荷、音声実聴は未確認。push/main merge/本人PC操作をしておらず、このbranchのCIも未実施。既知CI artifact403/Library upload401を再試行していない。
