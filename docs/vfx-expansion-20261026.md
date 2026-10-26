# スキル専用VFXの拡張

基点main a3a8e28。前段の通常攻撃・命中・足払い・ヒール・スタンプ・防御を維持し、未対応の発動可能スキルへ専用グラフィックとruntime演出を追加する。新しい技、Lv、能力、報酬、乱数、保存仕様は追加しない。

## 現行一覧と扱い

| ID | 名称 | 今回の扱い |
|---|---|---|
| legSweep | 足払い Lv1〜3 | 既存の成功判定付き演出を維持 |
| mage | ヒール | 既存の実HP増加演出を維持 |
| stamp | スタンプ | 既存の正規3マス・実被害者演出を維持 |
| guard | かばう | 実cover設定へ守護翼・連結光。防御コマンドとは別 |
| defenseLine | 防衛線 | 実coversの1〜2人へ盾縁と連結 |
| porter | 陣形強化 | 実boost成立と同side生存者へ小さな旗形 |
| healingCross | 癒しの輪 | 正規十字の実回復者へ五片花・着光・数値 |
| manaGift | 魔力譲渡 | 実MP正増で元→先の結晶リボン、実量を表示 |
| archer | スナイプ | 専用矢の発射と確定被弾を分離 |
| scout | 奇襲 Lv1〜3 | 実移動への折り紙残像、実被害への接触 |
| poleVault | ポールヴォールト Lv1のみ | 既存jump移動へ上向き筆致・着地粉塵 |
| grapple | 引き寄せ Lv1のみ | 鉤縄と張力、実move時だけ引く軌跡 |
| retreatSlash | 退き斬り | 巻き込む刃と実後退への足元余韻 |
| knockback | 吹き飛ばし | 圧縮接触、実押出時のみ移動軌跡 |
| splitShot | 分け撃ち | 異なる2方向へ順次発射、実被害者だけ着弾 |
| pincer | 挟撃 | 実連携条件と実hurt時だけ第二方向の刃 |
| returnHome | 帰還 | 実移動の出発・着地へ折り門、既存一戦一回制約 |
| itemUse | アイテム使用 Lv1〜3 | 既存item/etherコマンドの実HP/MP正増へ器と光片 |
| loneWolf | 孤軍 | 実skillEventとhurtがある時だけ短い牙の筆致 |
| firstStride | 先駆け | 実初回moveイベントだけ足元の風紋 |
| victoryBreath | 一息 | 勝利時の実MP正増だけ回復数値。量0は吐息のみ |
| swift / invasion | 俊足 / 侵入 | 継続的な移動条件。専用離散発動イベントがなく常時演出は追加しない |

通常攻撃と防御コマンドはスキルIDとは別の既存コマンド。装備gradeとスキルLvは別であり、未実装の上位段階は作らない。拳は空き手の仮想装備、既存の戦闘内外アイテム条件を保持する。

## グラフィックと同期

正規imagegenによる独自19層（物理10、支援9）を`godot/assets/vfx_expansion`へ追加した。矢・残像・鉤縄・上昇刃・粉塵・巻刃・楔・二射・折り門、守護翼・盾縁・三旗・花・魔力リボン・器・牙・風紋・吐息を、技の意味に合わせて再構成する。元動画の画像・紋章を切り出していない。各manifestはRGBA寸法、透明余白、SHA256、用途を記録する。元生成画像は公開素材へ混ぜない。

`expanded_physical_vfx.gd`/`expanded_support_vfx.gd`は既存world描画層の専用helper。既存19層と共有materialを保ち、全体上限64emitters・16caption、短い余韻、移動actorへの追従、地面の正規セルmaskを使う。保存・設定・engine API・ゲーム乱数を呼ばない。

`battle-presentation.cjs`に一時的な対象/連携/実support書込、既存skillEventsの新sequence、実MP正増resource packetを追加。cover/covers/boostの実書込だけを成功とし、単なる装備・preview・無効行動は成功演出にしない。MP消費だけのpacketは増やさない。既存のHP/posの確定packetで着弾・回復・移動を描く。元からないpropertyを実書込で作る場合も列挙属性と挿入順を維持し、delete/解除を復活させない。

移動演出は既存board tweenを保持し、VFXの再生のために人物移動を省略しない。パッシブは実イベントを対応phaseに一度だけ添え、aggregate metadataを再生しない。MP上限の一息で+2を捏造しない。複数射撃や範囲技の肩代わり元対象はAPIが保証しない部分を推測せず、実hurtの被害者を使用する。

## 検証入口と制約

- `node native/test_vfx_expansion_presentation.cjs`: 正規実行とcaptureの状態・JSON・乱数呼出数一致、descriptor復元、31境界。
- `node godot/tests/vfx_expansion_fixtures.cjs --verify`: 正規C.validate/B.legal/B.actを用いる64境界。合成QAであり前の手番をプレイした証拠ではない。
- `godot/tests/vfx_expansion_regression.gd`: 実board再生、実量/対象/範囲/重複/消失/保存不変、キャンセルとロード、Godot描画区間の乱数非消費。
- `python native/check.py` / `python godot/tests/run_inventory_header_261020.py --evidence <checkout外>`に登録する。旧VFXの不可視を期待していた敵スナイプケースは新しい専用演出を期待し、元の実HP・対象条件は維持する。

独立視覚評価はテスト成功件数と分けて記録する。FHD優先、狭画面、カメラ反転、盤端、複数対象、取消、連続、ロード後の残留を確認する。音3種OFF。環境はllvmpipe CPU描画で実GPUやWindows実UI/DPIの測定ではない。既存の配置パネル縮小復帰P3は変更しない。Library/Chromium/CIartifactの既知拒否を再試行・迂回しない。連番観察とmovieの等倍連続視聴は区別する。

## 軽い描画負荷確認

同じ正規packet・FHD・yaw0/pitch0.7/zoom16.5、音3種OFFで旧mainと最終描画を別プロセス比較。各3ケースの初回/2回目、idle18frame、録画/PNG readback/他の試験は停止。旧計測を不要に再実施せず、最終予備動作調整後は新版だけ再確認した。

環境はOpenGL3 / llvmpipe LLVM19.1.7のCPU描画、実GPU比較ではない。下表はaction phaseのframe_post_draw間隔中央値ms（初回 / 2回目）。CPU全threadの仕事量やロード時間とは異なる。

| 表示 | 旧版 | 最終版 |
|---|---:|---:|
| 癒しの輪 | 151.6 / 156.7 | 173.3 / 158.8 |
| 魔力譲渡 | 132.5 / 165.5 | 166.6 / 165.3 |
| 分け撃ち | 162.5 / 156.3 | 155.7 / 158.3 |

各phase標本は1〜3frameと少なく、idleにも変動がある。特に魔力譲渡の最終castは0.26秒で1標本しかなく、差の原因・高速化・実GPUでの速度を断定しない。グラフィック追加分のdrawcallは代表の中央値で約1〜3増加。全6cleanupずつでnodes485一定、VFX mesh0/active0、3ケースとも正規保存状態不変。保持textureは19→38（意図したキャッシュ）で、長期soakや全VRAMの測定ではない。

実視覚指摘により陣形旗の台座隠れ、MP消費ラベルの他人物との重なりを修正。MP譲渡は短い予備集束→実MP受領、奇襲の接触方向は実着地位置、先駆けの入替は本人moveへ同期する。癒しの輪の幾何範囲は保持し、cast花も同actionの実HP正増リストから選び、敵や全快中心へ回復成功を誤表示しない。
