# 再監査F1/F2・候補ランチャーの修正

2026-10-07。隔離候補 `5525-godot-work` / `godot-prototype`。独立再監査 [5525-godot-reaudit-20261007.md](G:/Apps/Codex/2026-10-07/task-2/5525-godot-reaudit-20261007.md) で旧R1〜R5の元症状解消が確認され、追加されたF1/F2を修正した。今回もcommit・push・通常PC適用・ダウンロード・追加インストールなし。

## 音声2件

**F1: 再接続後に新Nodeの音声を抑止する。** engine_bridgeは起動したNodeごとにconnection_generationを進める。render時にaudioが世代を追従し、世代変更時だけphase/SEの再生済み記録と結果キーを初期化する。演出キーとaction/impactグループキーの両方に世代を含めた。同一世代の同一演出・同一impactの重複抑止は維持する。通常の音楽restoreはこれらの記録を変更しない。

**F2: 終了済み戦闘セーブの読込で結果SEを2回開始する。** campaign_load成功時、updateが新しいcampaign・画像・曲メタデータを反映してから一度だけrenderする。load_gameの後段restore/renderを除去。audio.restoreは音楽だけを復元し、結果キーを消さない。結果キーは接続世代・campaignToken・campaignStage・結果を使い、結果なしの状態へ戻ったときに解除するため、独立した木人2戦の勝利音も保持する。

追加のphase_voice_started/phase_sound_startedシグナルは実際にWAVのplayを呼んだ場合にだけ発火する。試聴の代用とは扱わず、重複/欠落の回帰観測に使用する。

## 追加回帰

`godot/tests/audio_regression.gd` **21項目成功**。

- 実ルールで検証済みの合成開始/終了セーブを生成し、実ファイルadapter経由で読み込む。個人セーブは使用しない。
- 実Nodeの攻撃演出でguard/attackボイス・attack SEを各1回。同じphaseを再呼出すると0回、同じimpactグループも重複しない。
- 実Nodeを終了し、UIの再接続処理を通す。再接続前後のpresentation ID/index/action IDが同一でも、異なる接続世代で各1回再生し、ACK用の待機時間が0にならない。観測は2接続でボイス2回・攻撃SE2回。
- 終了済み戦闘の実ファイル読込でvictoryが1回。再描画3回やmusic restoreでは増えず、campaign・goldも不変。
- townへ戻って再ロードしても1回。不正音楽メタデータの拒否では状態・音楽・結果再生記録が不変。
- 先行の障害47項目には、実ルールで独立した一息木人戦を2回勝利し、victory2回を確認する回帰を保持。
- 合成fixtureはWindowsのOS.execute出力で日本語JSONが壊れるため、試験用stdoutだけASCII Unicodeエスケープにした。製品のpipe/file通信形式は変えていない。

## 候補の起動入口

| ファイル | 動作 |
|---|---|
| Start-5525.cmd | 候補内の既定入口。Godotランチャーへ委譲 |
| Start-5525-Godot.cmd | PowerShellをプロセス内の実行ポリシー指定で起動。PCのポリシーは書き換えない |
| godot/launch.ps1 | 既存ランタイムと必要プロジェクトファイルを確認し、フルパスを子プロセスへ渡して起動 |
| Start-5525-Python.cmd | 変更前Start-5525.cmdと同一バイトのPython UI入口 |

`Start-5525.cmd -Check` は依存をJSONで返す読み取り診断。`-SmokeTest` はheadless/Dummyで実アプリ初期化・campaign_saveのメモリ取得・通常終了を通す。通常ダブルクリック時は可視Godotを起動する。今回のランチャー検証はheadlessで、可視ウィンドウのダブルクリックや人の試聴はしていない。

検出結果はGodot **4.6.3.stable.official.7d41c59c4**、Node **25.2.1**、Python **3.13.15**、Pillow **12.3.0**。Godotは既存比較デモの実行ファイル、Node/Pythonは既存インストールを使用する。Godot 4.6.x、Node22以上、Python3.10以上＋Pillowを検査する。

上書き指定は `GODOT_BIN`、`NATIVE5525_NODE`、`NATIVE5525_PYTHON` のフルパス。無効な明示先は別環境へ黙って切替えず停止する。未指定時はPATH、既知の候補内runtime/godot、隣接5525のGodotディレクトリ、既存Python環境を限定して検出する。インストール・ネットワークアクセス・システム環境変数の変更なし。

ランチャー **7項目成功**: 自動検出、明示Godot、3種の不正明示先拒否、既定CMD→実アプリ起動/終了（Node残留0）、Python入口のSHA256一致。Python fallbackは同じ候補nativeルールを使う旧UI入口で、旧コミットへ戻すロールバックとは異なる。通常版のStart-5525.cmdは未変更。

## 最終証跡

```powershell
python -X utf8 -B 'G:\Apps\CodexProjects\5525-godot-work\godot\check.py' --godot 'G:\Apps\CodexProjects\5525\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --full
```

- [qa/headless-report.json](qa/headless-report.json): 旧Godot8段階＋今回2段階＋native呼出しの全11エントリ成功。エラー/解放警告も失敗条件のまま。
- [qa/launcher-report.json](qa/launcher-report.json): 解決した依存パス/バージョン、7項目、stdout/stderrと所有Node終了。
- [qa/audit-faults-report.json](qa/audit-faults-report.json): 先行障害47項目＋保存/ACK待ち終了2ケース成功。
- [../native/qa-check-report.json](../native/qa-check-report.json): 既存18段階・Python151件成功。
- [qa/reaudit-fix-preservation.json](qa/reaudit-fix-preservation.json): 前回固定72ファイルからの差分、今回全対象ハッシュ、通常版/素材/個人画像の保全。先行audit-fix-preservation.jsonは履歴として保持。

## 今回の製品差分と残事項

製品コードはgodot/audio.gd、engine_bridge.gd、main.gd。候補起動入口はStart-5525.cmd、新規Start-5525-Godot.cmd、Start-5525-Python.cmd、godot/launch.ps1。nativeルール・保存adapter・音源には今回変更なし。

追加試験はaudio_fixtures.cjs、audio_regression.gd、launcher_checks.py、launcher_smoke.gdと生成UID。godot/check.pyに追加2段階を登録。root READMEとGodot引継ぎ文書を更新。

独立再監査と親のゲート確認まで差分を固定する。push/通常適用は実施しない。実ユーザーセーブ、全11技のGodot入力網羅、主観試聴、実exportは引き続き未確認。現PCのソース起動と自己完結した配布物の完成は別で、exportテンプレート/依存梱包の追加取得は未実施。
