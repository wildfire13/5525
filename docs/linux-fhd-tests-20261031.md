# Linux FHD検査と目的監査（2026-10-31）

基点 `b72deb568d892f33d1b6dcabf6ecaf1b7d5a72d9`。製品コード・ゲームルール・CI timeout/並列構成は変更しない。
ユーザー指示: 画面は1920×1080のみ。目的不明・同条件重複・廃止仕様は除き、長い/失敗するという理由では削除しない。

## 検査の判断
全60 Godot suiteのassert/失敗ガードとgit導入履歴、関連文書を照合。名前の日付だけで旧仕様とは判定しない。
詳細な静的検査箇所は [CSV](linux-test-audit-20261031.csv)。行は動的なパラメータ展開数ではなく、assert/失敗ガードのソース位置。目的はsuite内の契約単位で記す。コード照合/ローカル実行/CI/実画面は別の証拠。
目的不明としてsuite全体を削除できるものは現時点で見つからない。重複する見た目検査があっても、実取引・D&D・遅延応答の異なる入口は保持する。

### 削除・統合した条件と根拠
- 複数親解像度で同一の施設/戦闘/取引/長文操作を反復するループをFHD1条件へ統合。操作・金額/保存比較は残す。変更前の全条件は基点SHAのgit履歴で追跡可能。
- `facility_npc_regression`: 低解像度NPC非表示条件を削除。FHDのNPC存在/非遮蔽は既存の施設別検査が担当。連続renderの直後に同一renderをもう一度する重複も削除。切断時RNGと復帰は保持。
- `feedback_backdrops_regression`: 施設ごとのFHD検査と再描画不変確認の後に同じ店を再検査する末尾のサイズ巡回を削除。低解像度でNPCを消す条件は対象外。
- `feedback3_speech_regression`: 狭画面のNPC抑制と420×110固定の2条件を削除。FHDで3種の文字送り/全文/非重複、新規訪問の再開は保持。
- `deployment_start_regression`: 同じFHD寸法を再代入しただけの配置/戦闘geometry再実行を削除。自然出発→配置→開始と実盤面/開始ボタンの非遮蔽は保持。
- `window_resize_regression`: 親の縮小復帰は対象外。FHD relayout通知、子窓/長文/再表示/フォーカスを保持。`status_layout_lifecycle` は画面外の人物窓をFHDへ補正する条件へ変更。
- `equipment_hover_f4`: 親縮小による古いhover解放を、FHDでの実際の人物ビュー再構築へ移植。全文/末尾スクロール・取消・再表示の契約を保持。
- `painted_vfx_regression`: boardのアスペクト変更に代えてFHDでカメラ変換を変更し、途中姿勢のスケール/足元復元を確認。
- `turn_order_keyboard_regression`: FHD通常の5枚表示に加え、同じFHD内で行動順部品にoverflowを作る隔離fixture。キー/ホイール/境界チェックを空のゼロ移動検査にしない。
- `feedback2_party_strip_regression`: 到達/スワイプ/フォーカスのassertを狭幅限定の死んだ分岐に残さずFHDの実カードで検査。通常の11/12人表示を確認後、FHD内のバー幅だけを制限する隔離部品fixtureでスクロール境界を再現。
- `feedback3_guild_regression`: FHDでは旧6人のスクロール位置が下端に達するため、実在する8人を選び左右とも140pxの中間位置を確保して交換前後を検査。12人の横スワイプはFHD内のバー幅だけを制限する隔離部品fixture。
- 人物子窓619px/420px、64pxアイコン、吹出し寸法等はゲーム画面解像度ではない。FHD内で利用できる部品サイズ/内容境界として保持。
- 素材原本SHA/透過・DB参照/セーブ互換・ログ秘匿は解像度非依存なので保持。asset-only検査を画面未描画という理由で失敗させない。

### 今回対象外になる実条件
960/1180等の親画面での配置・親縮小→復帰・狭画面のNPC非表示の実測は行わない。FHDの成功でこれらも正常とは言わない。
現ユーザー要件から多解像度を必須とする根拠はなく、再導入は依頼時に判断。子窓操作や保存位置補正はFHDでも起こるので残す。

## suite別の目的と根拠
導入commitは起点、関連記録は後続仕様も含む。最新のユーザー方針と現行assertを優先する。

| suite | 判断 | 守る仕様/回帰リスク | 根拠 |
|---|---|---|---|
| `facility_art_261021` | 保持 / 画面条件のみFHD統合 | 施設絵の採用原本・入力透過・訪問中の絵とRNG/取引状態保持 | `e8a84fb` / [記録](facility-backgrounds-20261022.md) |
| `hover_regression` | 保持 / 画面条件のみFHD統合 | 床マスを基準にhover/クリック/右情報の対象を一致させる | `aae0d20` / [記録](ui-selection-20261024.md) |
| `hover_lifetime_regression` | 保持 / 画面条件のみFHD統合 | 遅延hover応答・切断・解放済ノードによる古い画面の上書きを拒否 | `f736137` / [記録](ui-selection-20261024.md) |
| `icons_approved_261021` | 保持 / 画面条件のみFHD統合 | 承認済み旧アイコンの読込・空枠/拳・レベル差分を保持 | `e98a76a` / [記録](individual-icons-20261025.md) |
| `feedback_261021` | 保持 / 画面条件のみFHD統合 | 装備/購入D&Dの対象部位・取消・二重課金防止と選択表示 | `3885250` / [記録](feedback-261021-review.md) |
| `inventory_header_261020` | 保持 / 画面条件のみFHD統合 | 人物タブをまたぐインベントリ見出し・所有者/フィルタ/取消の保持 | `f71660a` / [記録](ui-descriptions-inventory-20261025.md) |
| `status_layout_lifecycle` | 保持 / 画面条件のみFHD統合 | 旧保存矩形移行と同フレーム再構築による人物窓高さ破損の防止 | `ee81380` / [記録](ui-layout-fixes-20261025.md) |
| `status_empty_inventory` | 保持 / 画面条件のみFHD統合 | 空の所有者へ切替時の縦文字化・旧持物残留防止 | `ee81380` / [記録](ui-layout-fixes-20261025.md) |
| `feedback_261019_3` | 保持 / 画面条件のみFHD統合 | メニュー/施設戻る・店別商品フィルタ・冗長表示の承認仕様 | `2e23880` / [記録](feedback-261021-review.md) |
| `feedback_261019_2` | 保持 / 画面条件のみFHD統合 | 施設戻る位置・個数/所有者見出しと下部バーの位置整合 | `2af9df4` / [記録](feedback-261021-review.md) |
| `feedback_261019_input` | 保持 / 画面条件のみFHD統合 | ポインタ入力の窓移動・D&D・保存復帰の整合 | `8a8d55d` / [記録](feedback-261021-review.md) |
| `guild_regression` | 保持 / 画面条件のみFHD統合 | ギルド選択/交換/人物詳細と個体所有物・成長保持 | `efd0ecc` / [記録](feedback2-ui-20261026.md) |
| `inventory_regression` | 保持 / 画面条件のみFHD統合 | 所持品の使用/受渡し/破棄/装備の確認取消と資源整合 | `c5cb3b9` / [記録](ui-descriptions-inventory-20261025.md) |
| `ui_feedback2_20261016` | 保持 / 画面条件のみFHD統合 | 比較窓/スキル範囲/条件表示と既存操作契約 | `885a953` / [記録](ui-descriptions-inventory-20261025.md) |
| `ui_feedback2_20261017` | 保持 / 画面条件のみFHD統合 | 地図/店/人物の承認済み選択状態と重複文言抑制 | `60e8329` / [記録](feedback-261021-review.md) |
| `ui_feedback_20261016` | 保持 / 画面条件のみFHD統合 | 装備確認の1回確定・カメラ/パネル保存・敵手番表示 | `8cd1414` / [記録](ui-layout-fixes-20261025.md) |
| `shop_rows_regression` | 保持 / 画面条件のみFHD統合 | 商品行からの購入/試着と売却の金額・所有者・制限 | `7398b7d` / [記録](shop-feedback-20261030.md) |
| `owned_equipment_regression` | 保持 / 画面条件のみFHD統合 | 8装備部位・装飾2枠・所有者在庫・比較/装備/転送の整合 | `649547d` / [記録](ui-descriptions-inventory-20261025.md) |
| `frontend_smoke` | 保持 / 画面条件のみFHD統合 | 起動→旧データ移行→移動→戦闘→保存の結合境界 | `98dc3c6` / [記録](updateplan-20261029-progress.md) |
| `ui_preferences_restart` | 保持 / 画面条件のみFHD統合 | 別プロセス再起動後のUI矩形/カメラ永続化 | `8cd1414` / [記録](ui-layout-fixes-20261025.md) |
| `brushup_formation_regression` | 保持 / 画面条件のみFHD統合 | 職業フィルタと交換相手・非表示候補・セーブ不変 | `b465bc7` / [記録](ui-guidelines-20261030.md) |
| `brushup_comparison_regression` | 保持 / 画面条件のみFHD統合 | 購入者/部位の比較一致・古い応答排除・実際の金額/個数 | `b465bc7` / [記録](comparison-regression-20261030.md) |
| `facility_npc_regression` | 保持 / 画面条件のみFHD統合 | NPC原本・非遮蔽・訪問RNG・取引/切断時のライフサイクル | `1acc000` / [記録](facility-npcs-20261024.md) |
| `research2_descriptions` | 保持 / 画面条件のみFHD統合 | スキル説明が実効果と一致し長文/条件/原文を欠落させない | `a4b0d8d` / [記録](ui-descriptions-inventory-20261025.md) |
| `text_cleanup_regression` | 保持 / 画面条件のみFHD統合 | 不要文言削除後も料金/危険度/凡例/効果説明を残す | `4633264` / [記録](text-cleanup-20261028.md) |
| `battle_selection_regression` | 保持 / 画面条件のみFHD統合 | スキル/アイテムの黄/●統一とクリックした右情報固定 | `4633264` / [記録](battle-selection-20261028.md) |
| `inventory_context_regression` | 保持 / 画面条件のみFHD統合 | 大量持物/長名・数量編集・取消/遅延応答/二重確定防止 | `a4b0d8d` / [記録](ui-layout-fixes-20261025.md) |
| `window_resize_regression` | 保持 / 画面条件のみFHD統合 | FHD内の子窓relayout・長文・フォーカス・保存位置再表示 | `3482e80` / [記録](ui-layout-fixes-20261025.md) |
| `battle_layout_f2` | 保持 / 画面条件のみFHD統合 | 戦闘可動パネルによるボタン/行動順遮蔽と付与元選択保持 | `3482e80` / [記録](ui-layout-fixes-20261025.md) |
| `inventory_short_window_regression` | 保持 / 画面条件のみFHD統合 | FHD内の低い人物子窓でも取引操作と取消復帰へ到達 | `3482e80` / [記録](ui-layout-fixes-20261025.md) |
| `equipment_hover_f4` | 保持 / 画面条件のみFHD統合 | 装備説明hoverの全文/スクロール・入力非遮蔽・古い窓解放 | `3482e80` / [記録](ui-layout-fixes-20261025.md) |
| `skill_effect_regression` | 保持 / 画面条件のみFHD統合 | 確定戦闘packetに従うVFX時系列・発動条件と無副作用 | `41b62d1` / [記録](skill-effects-ui-followup-20261025.md) |
| `ui_p3_drag_regression` | 保持 / 画面条件のみFHD統合 | 実Viewport dragからの装備確認・取消・同品再操作/フォーカス | `2171c86` / [記録](ui-layout-fixes-20261025.md) |
| `turn_order_keyboard_regression` | 保持 / 画面条件のみFHD統合 | 行動順のキー/ホイール・境界・盤面フォーカスの分離 | `2171c86` / [記録](ui-layout-fixes-20261025.md) |
| `deployment_start_regression` | 保持 / 画面条件のみFHD統合 | 通常出発から配置開始へ到達し盤面/開始/メニューを遮蔽しない | `b43351c` / [記録](deployment-guard-followup-20261025.md) |
| `guard_visibility_regression` | 保持 / 画面条件のみFHD統合 | 防御盾VFXの角度/ズーム別可読性とHP非遮蔽・後始末 | `b43351c` / [記録](deployment-guard-followup-20261025.md) |
| `individual_icons_regression` | 保持 / 画面条件のみFHD統合 | 個別承認画像の全画素・Lvバッジ・未制作仮印/共通素材不変 | `79086fb` / [記録](individual-icons-20261025.md) |
| `audio_options_regression` | 保持 / 画面条件のみFHD統合 | 音量/ミュート/設定永続化・QA音OFFが本設定を汚さない | `68a2158` / [記録](feedback-ui-20261026.md) |
| `feedback_backdrops_regression` | 保持 / 画面条件のみFHD統合 | 施設背景/共通位置金額/顔ヒントと訪問RNG不変 | `68a2158` / [記録](feedback2-ui-20261026.md) |
| `loading_screen_check` | 保持 / 画面条件のみFHD統合 | ロードスチルの入力遮断・順序/所有token・失敗/勝敗/報酬非重複 | `e5d4d5f` / [記録](loading-transitions-20261026.md) |
| `results_regression` | 保持 / 画面条件のみFHD統合 | 勝利/依頼結果の実報酬・成長と再表示/再読込の非重複付与 | `104b5fb` / [記録](results-ui-20261026.md) |
| `painted_vfx_regression` | 保持 / 画面条件のみFHD統合 | 制作VFX原本・対象/実数値/着弾順序・連続発動の残留防止 | `104b5fb` / [記録](production-battle-vfx-20261026.md) |
| `vfx_expansion_regression` | 保持 / 画面条件のみFHD統合 | 追加VFXの付与元/対象/実結果と取消/保存/RNG非干渉 | `c37f9d2` / [記録](vfx-expansion-20261026.md) |
| `facility_feedback2_regression` | 保持 / 画面条件のみFHD統合 | 施設トップ/売買戻り・無効機能/価格・売却所有者/二重処理 | `a3a8e28` / [記録](shop-feedback-20261030.md) |
| `feedback2_guild_regression` | 保持 / 画面条件のみFHD統合 | ギルド12人上限/追加除外並替・cargo確認・個体保持 | `a3a8e28` / [記録](feedback2-ui-20261026.md) |
| `deployment_drag_regression` | 保持 / 画面条件のみFHD統合 | 出場5人と控えのD&D・無効/ESC/上限/再送・死亡者制限 | `a3a8e28` / [記録](feedback2-ui-20261026.md) |
| `feedback2_party_strip_regression` | 保持 / 画面条件のみFHD統合 | 11/12人バー到達・swipe誤クリック防止・売却所有者・死亡者除外 | `a3a8e28` / [記録](feedback2-ui-20261026.md) |
| `native_file_dialog` | 保持 / 画面条件のみFHD統合 | native保存読込の取消/上書き承認/二重開閉とJSON互換 | `f5b38d8` / [記録](feedback3-ui-20261026.md) |
| `feedback3_guild_regression` | 保持 / 画面条件のみFHD統合 | 控え↔出場D&D・スクロール保持・スライド終了/再送拒否 | `f5b38d8` / [記録](feedback3-ui-20261026.md) |
| `feedback3_speech_regression` | 保持 / 画面条件のみFHD統合 | 3種吹出しの文字送り/再表示とNPC非重複・情報全文 | `f5b38d8` / [記録](feedback3-ui-20261026.md) |
| `speech_tail_regression` | 保持 / 画面条件のみFHD統合 | 吹出しの尾が実話者へ向き本文と絵は反転しない | `678813e` / [記録](speech-tail-20261026.md) |
| `status_footer_stability` | 保持 / 画面条件のみFHD統合 | メッセージ無/短/長/エラーでも下部人物座標を固定 | `74cca4c` / [記録](status-footer-stability-20261026.md) |
| `debug_window_check` | 保持 / 画面条件のみFHD統合 | 独立デバッグ窓のrelease非生成・入力/ゲーム終了分離 | `dfd913b` / [記録](debug-window-20261026.md) |
| `debug_log_accuracy` | 保持 / 画面条件のみFHD統合 | 実操作とログの成否/時間/順序・200件境界・個人情報排除 | `fa4b4cb` / [記録](debug-window-20261026.md) |
| `debug_store_regression` | 保持 / 画面条件のみFHD統合 | 永続SQLiteログのreadback/相関/CT回数/秘匿/容量/終了 | `c6a873b` / [記録](debug-database-20261028.md) |
| `debug_store_teardown` | 保持 / 画面条件のみFHD統合 | 応答停止したログworkerも終了で回収しコルーチンを残さない | `d0ac7b5` / [記録](debug-database-20261028.md) |
| `inn_feedback3_regression` | 保持 / 画面条件のみFHD統合 | 宿の一度だけ課金/全員回復・取消/離脱/全快/不足/演出整合 | `f5b38d8` / [記録](feedback3-ui-20261026.md) |
| `quest_board_feedback3` | 保持 / 画面条件のみFHD統合 | 掲示板左右詳細とポーター2段階確定・取消/二重受注防止 | `f5b38d8` / [記録](feedback3-ui-20261026.md) |
| `warehouse_regression` | 保持 / 画面条件のみFHD統合 | 倉庫の出入庫・方向/古いD&D拒否・所有者切替と戻る | `3e191d8` / [記録](updateplan-20261029-progress.md) |
| `updateplan_regression` | 保持 / 画面条件のみFHD統合 | 24人と人数上限・スタンプ予約時MP/取消/再読込/発動二重消費防止 | `3e191d8` / [記録](updateplan-20261029-progress.md) |

## 解像度非依存の検査
- `facility_asset_integrity.py`: 21原本のハッシュ/寸法とCSV・manifestの対応。採用原本の欠落/取り違えを検出するため保持。
- `individual_icons_integrity.py`: 承認画像と対象ID、PNG構造/原本の一致。全画素合成を調べるGodot版とは検査層が異なるため保持。
- `icons_approved_261021` / `individual_icons_regression`: 前者は旧承認アイコンの空枠/拳/未承認Lv、後者は個別画像合成/placeholderを検査。単に名称が似ているだけなので一括削除しない。
- `ui_preferences_restart` のwrite/readは別プロセスの永続化が目的。1プロセスへ統合しない。
- Linux後続の `test_debug_store.py` は独立DB/保持上限/ロック/秘匿、`test_master_data.py` はスキーマ/参照/改変検出、`test_sqlite_grant_save.cjs` は付与元の保存互換を検査する。
- `test_skill_cooldowns` / `test_sqlite_passive_grants` / `test_sqlite_grant_combat` は独立CT/割合加算/戦闘実処理をそれぞれ検査。`test_updateplan_roster` は旧人物保持と24人移行の非重複、`test_inventory_capacity` / `test_equipment_permissions` / `test_warehouse` は枠/着用受渡し制約/倉庫取引を検査する。
- `test_updateplan_skill_levels` / `test_updateplan_combat` / `test_updateplan_flow` はLv別マスタ値/予約スタンプ・槍投げ/通常連続導線の異なる境界。今回はこれらを削除・改変しない。

## 実行方法
共通runnerはエンジン初期化完了後にFHDを設定して元suiteの初期化へ渡す。画面suiteは全フレームのroot window/viewport一致を監視し、不一致をERRORとして失敗扱いにする。画面を生成せず終了する資産・設定・worker検査は監視から明示的に除外。
各suiteに実行秒数とソースSHA256を保存。固定sleep/timeout/CI並列構成は変更していない。`--only` は従来どおり対象再試験用。

## サイズ巡回の統合一覧
親画面のループ内操作は維持し、解像度条件をFHDへ統合した。部品寸法だけのループはこの一覧から除く。

| suite | 基点の解像度巡回（幅×高さ） | 現在 |
|---|---|---|
| `facility_art_261021` | 1920×1080 → 1180×812 | FHD（重複/狭画面専用は前節に従い削除） |
| `hover_regression` | 1920×1080 → 1180×812 | FHD（重複/狭画面専用は前節に従い削除） |
| `inventory_header_261020` | 1920×1080 → 1364×1024 | FHD（重複/狭画面専用は前節に従い削除） |
| `status_layout_lifecycle` | 1364×1024 → 1920×1080 | FHD（重複/狭画面専用は前節に従い削除） |
| `status_empty_inventory` | 1364×1024 → 1920×1080 | FHD（重複/狭画面専用は前節に従い削除） |
| `feedback_261019_3` | 1364×1024 → 1920×1080 | FHD（重複/狭画面専用は前節に従い削除） |
| `feedback_261019_2` | 1364×1024 → 1920×1080 | FHD（重複/狭画面専用は前節に従い削除） |
| `feedback_261019_input` | 1364×1024 → 1920×1080 | FHD（重複/狭画面専用は前節に従い削除） |
| `brushup_formation_regression` | 1920×1080 → 1180×812 | FHD（重複/狭画面専用は前節に従い削除） |
| `brushup_comparison_regression` | 1920×1080 → 1180×812 | FHD（重複/狭画面専用は前節に従い削除） |
| `facility_npc_regression` | 1920×1080 → 1180×812; 1024×720 → 800×600 | FHD（重複/狭画面専用は前節に従い削除） |
| `research2_descriptions` | 1920×1080 → 1180×812 | FHD（重複/狭画面専用は前節に従い削除） |
| `text_cleanup_regression` | 1920×1080 → 960×540 | FHD（重複/狭画面専用は前節に従い削除） |
| `battle_selection_regression` | 1920×1080 → 1180×812 → 960×540 | FHD（重複/狭画面専用は前節に従い削除） |
| `inventory_context_regression` | 1920×1080 → 1180×812 | FHD（重複/狭画面専用は前節に従い削除） |
| `window_resize_regression` | 960×540 → 1180×812 → 1920×1080 → 960×540 → 1180×812; 1180×812 → 960×540 → 1920×1080 | FHD（重複/狭画面専用は前節に従い削除） |
| `battle_layout_f2` | 1180×812 → 1920×1080 | FHD（重複/狭画面専用は前節に従い削除） |
| `equipment_hover_f4` | 1280×800 → 1180×812 → 1920×1080; 960×540 → 1920×1080 → 1180×812 | FHD（重複/狭画面専用は前節に従い削除） |
| `ui_p3_drag_regression` | 1180×812 → 1920×1080 | FHD（重複/狭画面専用は前節に従い削除） |
| `turn_order_keyboard_regression` | 1180×812 → 960×540 → 1920×1080 | FHD（重複/狭画面専用は前節に従い削除） |
| `deployment_start_regression` | 1180×812 → 1283×832 → 1920×1080; 1180×812 → 1283×832 → 1920×1080 | FHD（重複/狭画面専用は前節に従い削除） |
| `guard_visibility_regression` | 900×650 → 1180×812 → 1920×1080 | FHD（重複/狭画面専用は前節に従い削除） |
| `feedback_backdrops_regression` | 1920×1080 → 1180×812; 960×540 → 1920×1080 → 1180×812 | FHD（重複/狭画面専用は前節に従い削除） |
| `loading_screen_check` | 1920×1080 → 1180×812 → 960×540 → 1920×1080 | FHD（重複/狭画面専用は前節に従い削除） |
| `results_regression` | 1920×1080 → 1180×812 → 960×540 → 1920×1080 | FHD（重複/狭画面専用は前節に従い削除） |
| `facility_feedback2_regression` | 1920×1080 → 1180×812 → 960×540 → 1920×1080; 1920×1080 → 1180×812 → 960×540 | FHD（重複/狭画面専用は前節に従い削除） |
| `feedback2_guild_regression` | 1920×1080 → 1180×812 → 960×540 → 1920×1080 | FHD（重複/狭画面専用は前節に従い削除） |
| `deployment_drag_regression` | 1920×1080 → 1180×812 → 960×540 → 1920×1080 | FHD（重複/狭画面専用は前節に従い削除） |
| `feedback2_party_strip_regression` | 1920×1080 → 1180×812 → 960×540 → 1920×1080 | FHD（重複/狭画面専用は前節に従い削除） |
| `feedback3_speech_regression` | 1920×1080 → 1180×812 | FHD（重複/狭画面専用は前節に従い削除） |
| `speech_tail_regression` | 480×160 → 295×160 → 420×110 | FHD（重複/狭画面専用は前節に従い削除） |
| `status_footer_stability` | 1920×1080 → 1180×812 → 960×540 | FHD（重複/狭画面専用は前節に従い削除） |
| `debug_window_check` | 1920×1080 → 960×540 | FHD（重複/狭画面専用は前節に従い削除） |
| `inn_feedback3_regression` | 1920×1080 → 1180×812 → 960×540 | FHD（重複/狭画面専用は前節に従い削除） |
| `quest_board_feedback3` | 1920×1080 → 960×540 | FHD（重複/狭画面専用は前節に従い削除） |
| `warehouse_regression` | 1920×1080 → 1180×812 → 960×540 | FHD（重複/狭画面専用は前節に従い削除） |
| `updateplan_regression` | 1920×1080 → 1180×812 → 960×540 | FHD（重複/狭画面専用は前節に従い削除） |

## 実画面証拠
クラウドX11 `:88`、BGM/SE/ボイスOFF、隔離した新規プロフィール。通常のマウスクリック2回でギルドへ入場。root window、viewport、実際の描画画像がすべて1920×1080で一致（9確認成功）。画像を実見し、左右一覧/中央操作/下部バー/NPC/戻るを確認。これは全suiteのGUI完走を意味しない。

- 証拠: `/workspace/fhd-ci-20261031/gui/guild-fhd.png`（2,162,851 bytes、1920×1080）。
- SHA256: `b984138653afdb1dae3907fca1f7c098cc760d8ae89d14a98b5e9a4ea73fdc43`。
- ユーザーPC・本人セーブには触れていない。Windows OS実画面は未確認。

## ローカル検証結果
- 全63実行（資産2、Godot60種＋設定再起動のwrite/read分離）の最終結果は成功。最初の全体実行後、失敗/変更対象だけを再実行し統合。最初から一発全成功という意味ではない。
- 初回失敗: エンジン初期化前の64×64を監視したharness不備、画面を作らない検査への監視誤適用、旧人物窓幅期待値、解像度ループ最終回依存の戦闘終了、FHDでは中間でなく端となったギルドfixture。いずれも検査側を修正し、assertを単に除去せず再試験で成功。
- ギルドfixtureでは追加候補を末尾から選び、既存の先頭控え行/アンカーを変えずに8人へ増やす。左右140pxが本当に中間であるassertを追加。行削除でアンカー位置が変わる別条件を『同じpixel位置』と誤判定しない。
- FHD GUIは9確認/通常マウス2操作/画像1枚成功。headless試験と区別。
- ローカル証跡 `/workspace/fhd-ci-20261031/latest-results.json` と各再試験ディレクトリ。
- CI実時間は同commitのGitHub Actions完了後に報告。初回ローカル実行はharness修正とfixture再試験を含むため、旧CIとの高速化率には使わない。
