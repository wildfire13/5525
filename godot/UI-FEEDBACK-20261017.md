# 2026-10-17 本人PCでのUI修正候補

起点: `b204845341bc7fcb96f5894e0d38427d59ecb42e`。
通常使用チェックアウト `G:\Apps\CodexProjects\5525-git` は main・未コミット変更なし。origin は `https://github.com/wildfire13/5525.git`。作業終了前の `ls-remote` でもmainは同じコミット。
実装候補は `G:\Apps\Codex\2026-10-17\task\5525-ui-feedback`、ブランチ `ui-feedback-20261017`。親から通常checkoutへの安全な統合とPCからmainへのpush指示を受領。未コミット変更がない場合のみfast-forwardで統合し、force pushは行わない。

## 原本確認

- Library ID: `libfile_95738ed30c04819194d6da696e9f0503`、原本 `261017_5525_UI_feedback.xlsx`、3,297,043 bytes。
- SHA-256: `b4b9ca466ad413390c4562c4896a48751d921ced7f13d662a05ca9b1b6c5e775`。
- 現行Libraryヘルパーを取得して実行。Windows版Pythonには `os.setxattr` がなく保存未完了になったため、本人PCに既存のUbuntu/WSLで同じ公式ヘルパーを実行し、Library属性を保持して取得。
- 永続保存先: `\\wsl.localhost\Ubuntu\home\wildf\.local\share\5525-feedback-20261017\261017_5525_UI_feedback.xlsx`。クラウドのパスではない。
- 6feedback＋templateを確認。埋込PNGを元解像度で確認し、図形テキストも抽出。専用Excelインスタンスで読取専用で開き、6シートの矢印・囲みを実画素で照合。templateは対象外。
- ExcelのPDF印刷経路は利用できず、専用ウィンドウの撮影へ切替。原本は保存していない。既存ユーザーExcel・ゲームは終了していない。

## 変更

- 配置: 両陣形ボタンのhoverに成立条件と既存の実倍率を表示。位置調整見出し・プルダウン・操作説明を削除。配置中の行動予測案内を非表示。
- 売却: 商品行に単価または売却不可を表示し、不可品にもdisabledの売却ボタンを表示。価格・可否は取引と同じsaleQuoteから取得。人物名の重複見出しを削除。
- 成長: Lv/経験値を人物名の右、＋1/−1を能力値の近くへ移動。「仮」だけを除去し未確定増分を保持。不要な説明を削除。確定を180pxにし未確定配分中は緑。
- 詳細: 下部閉じるボタンを削除しX/外クリックで閉じる。下部人物クリックは同じ窓・同じタブの人物切替。表示人物は青。未確定配分の破棄確認と取消を維持し、背景のEnter誤操作を遮断。詳細窓は下部人物ボタンを隠さない領域へ制限。
- ギルド: 2人のクリックで控え対編成、編成内順序を交換。通常確認を省略し、荷物を持つ実際のポーターを控えへ移す場合だけ警告を維持。0.32秒のスライド中は再操作を遮断。リスト外クリックで選択解除、下部の選択人物も緑。不要な入替開始・取消ボタンを削除。
- 戦闘: 表示する一覧を現在のコマンドに限定。合法対象がない場合でもコマンド選択で古い一覧を閉じられる。確定時の合法対象・消費チェックは維持。
- CCT・保留装飾品・戦闘計算・実セーブには変更なし。

## 検証

本人PCの既存Godot 4.6.3、Node 25.2.1を使用。APPDATA/LOCALAPPDATA/TEMP等を検証専用フォルダへ分離し、合成状態のみを使用。

- Godot import: 成功。
- `godot/tests/run_ui_feedback_20261016.py`: 最終13工程249チェック成功。新規 `ui_feedback_20261017.gd` の41チェックを含む。Windows用の隔離パス表記も修正。
- 新規テストの可視GUI実行: FHD 1920×1080、AMD Radeon RX 9060 XT/OpenGL、41チェック成功。アプリのViewportへマウス/キー入力を注入し、描画された9枚を画素確認。OS全体へのマウス注入や人による手動操作ではない。
- 成長取消・人物切替取消・YES連打、売却取消・YES連打、両方向の編成交換・同一人物再クリック・控え移動/再追加・スライド途中、荷物警告と取消、戦闘コマンドの切替・消費不変を確認。
- `node native/test_shop_transactions.cjs`: 9群成功。
- `node native/test_quest_cargo.cjs`: 15チェック成功。
- `git diff --check`: 成功。

PC上の証跡:

- `G:\Apps\Codex\2026-10-17\task\pc-regression-final\results.json` と各工程ログ。
- `G:\Apps\Codex\2026-10-17\task\pc-qa\feedback-20261017-visible.json`、`ui_feedback_20261017-visible.log`。
- 同じ `pc-qa` 内の `growth-pending.png`、`sale-rows.png`、`guild-selected.png`、`guild-sliding.png`、`guild-swapped.png`、`cargo-warning.png`、`deployment.png`、`formation-hover.png`、`battle-command.png`。
- 原本の検査用画像は `G:\Apps\Codex\2026-10-17\task\feedback-inspection`。原本画像はリポジトリへ追加していない。

再実行例（既存Godotを使用）:

```powershell
python -X utf8 godot/tests/run_ui_feedback_20261016.py --godot 'G:\Apps\CodexProjects\5525\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --node 'C:\Program Files\nodejs\node.exe' --evidence 'G:\Apps\Codex\2026-10-17\task\pc-regression-final'
```

## 既存テストの制約

`native/test_ui_feedback_rules.cjs` は6群通過後、79行目の `s.result.hours` で `result == null` により失敗する。未変更のmain `b204845` でも同一箇所・同一エラーを再現した。今回のUI差分に由来しないため、旅程仕様やこのテストは変更していない。
旧GuildSwap/GuildConfirm/StatusCloseを前提とする歴史的テスト全体の成功は主張しない。今回の新しい操作契約は新規41項目と上記回帰ランナーで確認した。

既存テスト失敗の再確認: 受注中の `arrive()` は街へ移り `result=null` のまま荷物の手渡しを待つ。`completeQuest()` が報酬と結果を生成する。79行の到着直後の結果参照はこの現行仕様と不一致。今回のcampaign差分はinventoryViewのsaleQuote公開のみで、到着・納品処理は変更していない。未変更mainと候補の両方で同じ失敗、現行仕様のcargo 15チェックとshop 9群は再実行でも成功。
