# 独立監査 R1〜R5 の修正と再監査用証跡

2026-10-07。対象は隔離候補 `G:\Apps\CodexProjects\5525-godot-work` / `godot-prototype`。起点HEADは `fc36fdf7b5cbb6eeaff0a45b18f4e872f713bbe3`。親から受領した [読み取り監査](G:/Apps/Codex/2026-10-07/task-2/5525-godot-readonly-audit-20261007.md) のR1〜R5を修正した。通常版への適用、commit、push、配布、追加取得は行っていない。今回の検証はheadless・Dummy音声で、可視GUI操作なし。

## 修正と確認

| 所見 | 修正 | 再現・確認 |
|---|---|---|
| R1 P1 ファイル遅延がゲームNodeを終了 | ゲームNodeとファイルPythonをGodotが別々に所有。pipe実装を共通化し、I/OをゲームNode経由にしない。EOF/不正JSON/期限切れは所有PIDを終了、worker回収、handles無効化。実ゲーム接続断は操作を止め「再接続」を表示 | 保存公開前の遅延で未保存と通知、公開後の応答喪失で実ファイルを照合し保存成功へ復旧。どちらもゲームNodeのPIDとcampaign完全一致。読込遅延/不正応答/EOF/Python不存在もゲーム継続。Node不存在/外部終了/不正JSON/EOF/hangは一貫した接続断と明示再接続 |
| R2 P2 戦士の通常攻撃の固定予告 | スタンプ除外を「skillかつstamp」だけに限定。通常攻撃は予告マスの現在占有者と射程で判定 | warrior25/MP0、予告24。guardが15へ退避すると無効・実行空振り。guard0/porter24なら有効・実行26ダメージ。予告の再計画なし |
| R3 P2 Esc後に遅延preview復活 | 取消・コマンド/技/画面/状態/読込/終了の変更で世代を無効化。応答時に世代・actor・行動数・command・target・skillの一致を確認 | 実Nodeに250msのpreview遅延を注入。rootへEsc入力3回、移動後の別射程プレビュー中のEsc、コマンド切替でghost/射程が復活せず、行動・資源・状態不変 |
| R4 P2 保存先がhardlink必須 | Windowsは同フォルダー内の上書き拒否renameで公開。既存ファイルをreplaceしない。排他的に作った要求別tempだけを清掃 | Windows上でos.linkを非対応エラーにしても成功。権限/容量失敗、2書込の同名競合、temp衝突、既存保護を確認。実exFAT/ネットワークドライブは未試験 |
| R5 P3 木人2戦目の勝利SE欠落 | 結果なしの状態と正常なrestoreで重複抑止キーをリセット | 実ルールの一息試用を独立に2回勝利。victoryイベント2回。同じ結果を3回renderしても重複しない。聴感試験ではない |

Windowsの `os.rename` は既存の宛先があると失敗する仕様を使用した。[Python 3.13公式仕様](https://docs.python.org/3.13/library/os.html#os.rename)。非Windowsは安全な既存hardlink方式を維持し、そこでの非対応FS対応を完了したとは扱わない。

## 期限・保存結果・終了

- 通常のゲーム要求は15秒、独立I/Oは10秒、保存結果の回復照合は5秒。I/Oで10秒＋回復5秒かかっても、ゲームNodeの15秒タイマーは動かない。
- 保存はランダム128bitの要求IDで同じ保存先フォルダーの `.5525-save-<id>.tmp` を排他的に作り、全書込・flush・fsync後に公開する。既存宛先を削除/上書きしない。
- 応答喪失時はhelper終了後、同じ宛先が要求したバイト列と完全一致するかを別helperで確認する。一致なら保存済み、不在/別内容なら未保存と報告する。清掃対象はその要求IDのtempだけ。
- 保存先自体が応答しない等で回復照合も失敗した場合は **保存結果不明** と明示し、別名保存を案内する。ゲーム進行は保持するが、この場合のtemp清掃や保存成功を保証しない。
- 実ゲームNodeが外部終了/破損応答等で失われた場合、未保存進行を復元したとは言わない。UIも喪失を表示し、明示再接続→新規状態→保存済みファイル読込へ進める。
- 保存中とACK待ち中に実際の `close_game()` を呼び、所有Node/Python残留0、対象temp残留0を外側Pythonプロセスから確認した。PIDの確認はWindows OpenProcess/GetExitCodeProcessを使用する。
- 検証中に、停止直後のAudioStreamWAV/Playbackが終了時に残る警告を再現した。固定100ms待機を、弱参照による音源解放確認（上限1秒）へ変更。通常終了と障害試験に適用し、警告を合格条件から除外していない。Godot内部でも停止はmix側処理とmain側cleanupを経る。[Godot 4.6 AudioServer実装](https://github.com/godotengine/godot/blob/4.6-stable/servers/audio/audio_server.cpp)

## 検証コマンドと証跡

```powershell
python -X utf8 -B 'G:\Apps\CodexProjects\5525-godot-work\godot\check.py' --godot 'G:\Apps\CodexProjects\5525\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --full
```

- [qa/headless-report.json](qa/headless-report.json): Godot側8段階＋既存native全回帰呼出し、9エントリすべて成功。
- 内訳: 候補ルール9群、保存/画像Python8件、通信12項目、frontend35項目、UIパリティ59項目、音楽56項目、障害47項目＋終了2ケース、import/parse。
- [qa/audit-faults-report.json](qa/audit-faults-report.json): 障害・終了のstdout/stderr、所有PIDと残留確認。最終実行でエラー/解放警告なし。
- [../native/qa-check-report.json](../native/qa-check-report.json): 既存18段階成功、Python151件（元143件＋候補保存系8件）。
- [qa/audit-fix-preservation.json](qa/audit-fix-preservation.json): 通常版・個人画像・既存素材・BGM原本の保全と、最終候補の全対象ハッシュ。先行UIパリティ50ファイルの記録との差分一覧も含む。
- UIパリティの実2戦は、初回全回帰でランダム編成により180秒タイムアウトした。単独再実行59項目成功を確認後、試験専用Node入口だけのMath.randomを固定し、既存の旅程/納期/報酬/全表示チェックを維持した。製品のランダム編成は変更しない。
- 失敗した中間診断は `qa/audit-leak-diagnostic-*.log` に残す。合格の根拠は最終レポートとその時点のハッシュ。可視12画面の証跡は前工程のもので、この修正後に人の操作/試聴を行ったとは扱わない。

## 今回の変更ファイル

製品コード:
- `godot/engine_bridge.gd`、新規 `godot/pipe_transport.gd`（およびGodot生成UID）
- `godot/main.gd`、`godot/audio.gd`
- `native/godot-io.cjs`、`native/godot_files.py`、`native/intent-info.cjs`

試験・ランナー:
- `native/test_godot_rules.cjs`、`native/test_godot_files.py`
- `godot/check.py`、`godot/tests/ui_parity_smoke.gd`
- 新規 `godot/tests/audit_checks.py`、`audit_faults.gd`、`shutdown_case.gd`、`fault_file_helper.py`、`fault_rules.cjs`、`seeded_rules.cjs` とGodot生成UID

文書:
- 本書、README.md、MIGRATION-CHECKLIST.md、APPLY-PLAN.md、qaの証跡。
- 元6ファイルのルール差分（価格/俊足/エーテル等）は今回の監査修正では増やしていない。R2は候補専用intent-info.cjsの表示解釈だけを修正した。

## 再監査・適用前の残事項

独立再監査と親の最終QAゲートを待つ。通常起動用Godotランチャー/Pythonへの戻り口、実ユーザーセーブコピーの確認、主観試聴、全11技のGodot入力による網羅は未完了。自己完結したexportのテンプレート・依存配置も未整備。現在PCの既存ランタイムによるソース起動には追加インストールは不要。以後の適用は [APPLY-PLAN.md](APPLY-PLAN.md)、配布依存は [EXPORT-READINESS.md](EXPORT-READINESS.md) に従う。
