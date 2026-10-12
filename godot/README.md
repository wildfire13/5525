# 5525 Godot prototype

独立監査の不合格7件への対応、仕様待ち7件、既存の並行保存リスクは [INDEPENDENT-REVIEW-FIXES.md](INDEPENDENT-REVIEW-FIXES.md) を参照してください。

固定候補2981a74に対する購入計画の再接続復元・売却範囲の追補は [PLAN-RECONNECT-FIXES.md](PLAN-RECONNECT-FIXES.md) を参照してください。以下の過去記録にある「切断で計画破棄」「サウスAPI売却可」は、この別候補では修正済みです。

個人在庫候補c5cb3b9に対するUIUXレビュー4点の別コピー修正は [UIUX-INVENTORY-FIXES.md](UIUX-INVENTORY-FIXES.md) を参照してください。

2026-10-12 個人在庫・購入計画の隔離候補については [INVENTORY-HANDOFF.md](INVENTORY-HANDOFF.md) を参照してください。以下は以前の移行記録です。今回の固定ID・非GUI検証・未完事項を過去のQA結果と混同しないでください。

2026-10-07。隔離試作の引き継ぎ用。配布物・通常利用版ではありません。

- 作業場所: `G:\Apps\CodexProjects\5525-godot-work`
- ブランチ: `godot-prototype`。起点 `fc36fdf7b5cbb6eeaff0a45b18f4e872f713bbe3`。変更は未コミット。
- 通常版: `G:\Apps\CodexProjects\5525-git` の main。起動は従来の `Start-5525.cmd`。
- Godotが画面と音声を担当し、子Nodeプロセスの既存ルールをJSON行通信で利用します。Pythonは既存の画像正規化とJSON入出力に使用します。
- 拠点、旅程、編成、商店、配置、戦闘、木人を同一Godotウィンドウに収容。F11全画面切替。ダイアログも埋め込み。
- **可視GUI確認済み**。Godot内のマウス/キー入力注入とアプリメソッドで、3視点・全画面往復・画像・戦闘・配達・取消/再読込を検証。専用デスクトップ操作ツールはなく、人の実操作や実音声の試聴は未確認です。
- **新しい旅曲3曲は統合済み**。ユーザー手渡しZIPのサイズ・ハッシュを確認し、実WAVのループ/戦闘往復/保存選択/拠点帰着をヘッドレスで検証しました。聴感は未確認です。Library403は再試行していません。
- 旧Python UIを画面・操作単位で再照合し、判明した表示省略を補完しました。模式地図、依頼/旅程、装備比較/仲間詳細、宿屋/結果/戦闘情報等の対応表は [UI-PARITY.md](UI-PARITY.md) に記録しています。

再監査F1/F2の音声回帰を修正し、候補の通常ランチャーを仕上げました。最新の差分・回帰・起動証跡は [REAUDIT-FIXES.md](REAUDIT-FIXES.md)。先行する独立監査R1〜R5を修正し、障害注入と終了時の残留確認を追加しました。最新の修正・制約・再監査対象は [AUDIT-FIXES.md](AUDIT-FIXES.md)、全機能照合は [MIGRATION-CHECKLIST.md](MIGRATION-CHECKLIST.md) を参照してください。

旧版との独立比較で見つかった赤太字・行動者の揺れ・同名上書き保存の差は [LEGACY-PARITY-FIXES.md](LEGACY-PARITY-FIXES.md) に修復内容と検証範囲を記録しています。過去のQA記録にある「既存ファイルへの保存拒否」は、この修復後の製品仕様ではありません。

## 実行環境と起動

確認した実行ファイル:

```text
Godot 4.6.3.stable.official.7d41c59c4
G:\Apps\CodexProjects\5525\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe
Node 25.2.1
C:\Program Files\nodejs\node.exe
Python 3.13.15 + Pillow
```

親のGUI開始指示に基づいて実行済みの候補版起動コマンド（QAでは音声をDummyに設定）:

```powershell
& 'G:\Apps\CodexProjects\5525\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --path 'G:\Apps\CodexProjects\5525-godot-work\godot'
```

候補内の `Start-5525.cmd` は `Start-5525-Godot.cmd` → `godot/launch.ps1` を通して既存実行ファイルを検出します。`Start-5525.cmd -Check` は依存の読取診断、`-SmokeTest` はheadless/Dummyで起動・終了します。必要に応じ `GODOT_BIN`、`NATIVE5525_NODE`、`NATIVE5525_PYTHON` をフルパスで指定できます。明示先が無効なら別環境へ黙って切替えず停止します。元のPythonランチャーは同一バイトの `Start-5525-Python.cmd` に保持。通常作業ツリーと既存Godot比較デモは未変更です。エクスポート済みexeやランタイム同梱は未作成です。テンプレート追加取得と依存配置の条件は [EXPORT-READINESS.md](EXPORT-READINESS.md) を参照してください。

## 検証

可視ウィンドウを出さず、音声出力をDummyにして実行:

```powershell
python -X utf8 -B 'G:\Apps\CodexProjects\5525-godot-work\godot\check.py' --godot 'G:\Apps\CodexProjects\5525\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe'
```

`--full` を加えると既存nativeの全18段階回帰も再実行します。直近の証跡:

- `qa/headless-report.json`: Godot構文・import、候補ルール9群、ファイル8テスト、通信12項目、画面操作35項目、UIパリティ59項目、音楽状態56項目、障害47項目＋終了2ケース。既存Godot側8段階に追加音声21項目・候補ランチャー7項目の2段階を加えた全10段階が成功。
- `../native/qa-check-report.json`: 全18段階成功、Python151テストを含む。候補保存系8件を含むため、元版の143件より8件多い。
- `qa/visual-report.json`: 可視確認16条件成功、操作手段・合成データ・BGM転送エラー・残る確認を記録。
- `VISUAL-QA.md`: 可視確認の結果とスクリーンショット一覧。
- `qa/audit-faults-report.json`: I/O障害・接続断・取消競合・独立木人2勝・音源解放・保存/ACK待ち中終了の最終証跡。
- `qa/reaudit-fix-preservation.json`: 今回の通常版保全と固定候補ハッシュ。先行R1〜R5は `qa/audit-fix-preservation.json`、初期の元デモ保全は `qa/preservation.json`。
- `qa/launcher-report.json`: 依存検出、無効な明示先の拒否、既定CMDからの実起動/終了、Python入口の同一バイトを確認。
- Godotエラー、スクリプトエラー、リソース解放警告もランナーの失敗条件です。
- 音楽状態検証は新しい3曲の実WAVを使用し、デコードとループ折返し、戦闘往復を確認します。音質・内容・聴感の検証ではありません。
- `qa/bgm-integration-report.json`: 原本ZIP・既存6曲・新3曲と通常版のハッシュ保全証跡。

## 保存と画像

Godot専用の `user://`（custom user dir名 `5525-godot-prototype`）を使用します。埋込ダイアログで保存先を選び、`5525-godot-<時刻>-<識別値>.json` を初期名にした新規ファイルへ保存します。初期フォルダーは候補専用 `user://` です。既存ファイルは上書き確認後、完成した一時ファイルとの原子的な置換で保存します。取消・書込失敗・確認後の内容変更では元ファイルを保持します。

旧JSONの読込は読み取りのみで、画像と音楽の付加情報を切り離して既存Nodeの検証・旧装備移行を通した後に反映します。キャラ画像は既存Python正規化を用い、PNGとSHA256をセーブの `nativePortraits` に格納します。現在の画像ファイル群はコピーも上書きもしていません。

実ユーザーの進行セーブは今回指定されていません。旧fixture、戦闘中のファイル再読込、合成データでは検証済みですが、実セーブとの照合は未確認です。新装備・新効果を含む候補版セーブを、旧Python版へ逆輸入する互換性は保証していません。

## 実装の入口

- `engine_bridge.gd` / `pipe_transport.gd`: NodeとファイルPythonを別所有、非同期pipe、ACK、独立期限、保存結果照合、接続断/再接続と所有プロセス終了
- `main.gd`: 同一ウィンドウの全画面、拠点・旅程・編成・商店・戦闘画面
- `campaign_panels.gd` / `town_map.gd`: 旧UIの町・地図・依頼・仲間・比較・宿屋・結果の情報
- `battle_board.gd`: 2D Sprite3D、3視点、予告線、陣形、移動仮置き、座標変換
- `demo_courtyard.gd`: 既存比較デモからコピーした背景。元ファイルは未変更
- `audio.gd` / `portraits.gd`: 既存素材の再利用、旅曲の選択保持、画像差替
- `../native/intent-info.cjs`: 固定予告の現在有効性を表示用に解釈。AI再計画はしない
- `../native/godot-io.cjs` / `godot_files.py`: 上書きを拒否する保存と画像正規化

Game Development StudioのCLIは未導入です。導入・生成・プロバイダ利用・認証は行っていません。通常のGodot/Node試作は親の実装許可に基づくもので、未導入プラグインの操作とは別です。
