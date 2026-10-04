> Final integration status: see [INTEGRATION-QA.md](INTEGRATION-QA.md). Earlier pending/hold statements below are historical implementation records. Runtime now contains 137 voice clips and six BGM tracks; independent manual GUI QA is complete.

# 仮アテBGM基盤（runtime6曲導入済み）

最新状態：手動保存されたruntime ZIPを既知サイズ・SHA-256・CRC・安全なパスと照合して導入済み。
実manifestの `tracks` 配列／`routes.locations`／`routes.battle` を直接読み、各ファイルのSHA、
サイズ、PCM形式、全フレームのループ範囲を検証するようMusicCatalogを更新した。
6曲の実Windows再生・切替・戦闘曲自然ループ・ボイス共存・ミュート・終了解放が成功。
現在の一括版・検証結果は [INTEGRATION-QA.md](INTEGRATION-QA.md)。以下の未取得記述や仮契約は過去の経緯。

ユーザー採用は戦闘BGMの候補2と5拠点曲。評価は「微妙だが仮アテなのでOK」であり、
完成音楽品質の承認とは扱わない。ゲーム用ループ音源は未受領で、現在の作業版のBGMは無音。
作業は `5525-voice-work` 内だけ。通常起動先への反映・commit・push・配布は保留。

## 選曲

| 状態 | キー／再生方針 |
|---|---|
| アスタリス、ノース、イース、ウエス、サウス | `astaris`, `north`, `east`, `west`, `south` の各拠点曲 |
| 確定後の戦闘、木人試用 | `battle2`（採用された候補2だけ） |
| 戦闘の勝敗確定、街道へ戻る前 | 戦闘曲を停止。専用勝敗曲は未指定 |
| 到着画面 | 旅程の目的地の拠点曲 |
| 配達結果、撤退／敗北後の復帰 | エンジンが確定した現在拠点の曲 |
| 移動中、野営、配置画面 | 無音。未指定の道中曲を代用しない |
| 木人から店へ戻る | 現在拠点の曲へ戻す |

通常キャンペーンのすべてのページ／ロード／再開は同じ選曲関数を使う。
未完の戦闘窓を閉じても戦闘状態のままなので戦闘曲を継続し、再開時にリセットしない。
同拠点内で掲示板・商店等を切り替えたり再描画しても曲を最初から再生しない。
単体戦闘と旧版戦闘窓でも戦闘曲2を使う。旧版の街道画面には拠点曲を新設しない。

## 再生・ミュート

キャンペーン全体で1個のBGMプレイヤーを共有し、親画面と戦闘窓のBGMミュートも共有。
ボイスのミュートは別。BGMはWindows MCIの専用デバイス別名、ボイスは既存WinSoundを使い、
互いの再生／停止を上書きしない。音量変更はOS側、ゲーム内にはBGM／ボイス別のミュートを用意。
BGMミュート解除時は現在の曲を先頭から再開する。ミュート中の場面変更も現在地に追従。

再生コマンドに待機指定は付けない。Tkタイマーで100msごとに終了を確認して先頭へ戻す。
このためループ境界に最大約100ms＋OS遅延の間があり、サンプル単位のシームレスループではない。
終了時はタイマーとこのBGMデバイスだけを閉じる。欠落ファイル・再生失敗・Windows以外では
ゲームを継続し、同画面再描画による失敗リトライを繰り返さない。

追加依存を増やさない仮実装としてWindows標準APIを使用。
[Microsoftのplayコマンド仕様](https://learn.microsoft.com/en-us/windows/win32/multimedia/play)
ではwaveaudioのrepeat指定がないため、WAVでも動く終了検出方式を採用した。

## 素材受入れ用の仮契約

BGM側の実manifest未受領のため、次のローカル形式を定義。実素材受領時に合わせる。
`native/assets/music/manifest.json` にschema 1と6トラックを登録し、同ディレクトリ以下に
採用曲だけを配置する。WAV／MP3を受け付ける。音声ファイルの内容照合と実曲のループ確認は未完了。

```json
{
  "schema_version": 1,
  "tracks": {
    "astaris": {"path": "astaris.wav"},
    "north": {"path": "north.wav"},
    "east": {"path": "east.wav"},
    "west": {"path": "west.wav"},
    "south": {"path": "south.wav"},
    "battle2": {"path": "battle2.wav"}
  }
}
```

## 検証

`python native/check.py` の集約10工程・Python100件成功（BGM追加11件）。
5拠点、到着、戦闘／木人終了、再描画、ループ、ミュート中の場面変更、終了、欠落／失敗、
ボイス停止の独立性、親子画面のプレイヤー共有を検証。

`python native/smoke_music.py` はWindows限定の明示的な実API検査。
一時的な0.4秒無音WAVでMCIループとWinSound再生を併用する。ゲーム用素材は作らない。
音源の聴感や完成音楽品質、実曲での音量バランスを検証したことにはならない。

Windows実行結果：開始0.109秒、3回の再生開始（終端ループを含む）、UIタイマー38回、
ボイス再生中／ボイス停止後ともBGM継続、親窓終了でデバイス解放、エラー0。
最初の一時検査は「20msタイマー40回ぴったり」という過剰な仮定で38回を失敗判定したため、
OSのタイマー精度を前提にしない「20回以上」でUI継続を確認する検査に修正した。
実Tk非表示のキャンペーン＋戦闘窓も生成し、BGMプレイヤー共有、共通ミュート、再描画、
子窓を閉じても親のプレイヤーを維持し、親終了時に破棄する経路を確認した。

次回反映は行動ボイス＋戦闘／5拠点BGM＋11装備スキルの一括版。
親側で差分統合後、実際の試遊・デバッグ・修正再検証を経てから反映する。
本worktreeでは装備スキル担当の差分を直接編集・統合していない。

## 実BGM ZIPの転送試行

入力 `libfile_4e30ea0539f8819182b2878548ad7b45`、`5525-bgm-runtime-v1.zip`、
39,272,703 bytes、期待SHA-256
`e8f1df4c6a8e6be0c762a0c07c7f72f2ad4a6b05a986a1bbcc26abcaf8f8f9f8`。
Windows内 `bgm-input-v1` 宛ての `prepare_materialize` は成功し、対象1件・欠落なし、
返却ファイル名とサイズは一致した。現行Library skillから取得した公式helperへ
transfer全体を渡し、materializeを一度実行した結果は
`library file transfer failed: download failed`（終了コード1）。
HTTPステータスなし。403／権限拒否とは断定できない。追加再試行・独自取得はしていない。

実ZIP・実manifestはWindows未取得。親側から伝達された正式形式は
`schema_version: 1`、`tracks` 配列、`routes.locations` が拠点ID→track ID、
`routes.battle: battle`。各trackは `filename`, `sha256`, 音声形式, `frames`,
`loop_start_frame`, `loop_end_frame_exclusive` を持つ。ファイルは
`loops/{astaris,north,east,west,south,battle}.wav`、48kHz／24bit／stereo。
上の仮受入れ形式とは異なるため、実manifest受領後にMusicCatalogのadapterを変更する必要がある。
未確認のフィールド名やループ区間を推測して実装済みとは扱わない。

## 手動保存先の実物確認

ユーザー指定 `M:\dl\5525` にあったBGMは以下のプレビュー6ファイル。
元ファイルは保持し、ゲーム用ループへの変換・切り出し・登録はしていない。

| ファイル | 形式／長さ |
|---|---|
| `01_Astaris_two_cycles_48k24.flac` | 48kHz／24bit／stereo、39.989秒 |
| `02_North_two_cycles_48k24.flac` | 同、52.750秒 |
| `03_East_two_cycles_48k24.flac` | 同、40.878秒 |
| `04_West_two_cycles_48k24.flac` | 同、51.839秒 |
| `05_South_two_cycles_48k24.flac` | 同、51.440秒 |
| `2_WithQualityTags_Battle_SA3_comparison32s_48000.wav` | 48kHz／24bit／stereo、32.000秒 |

FLACのSTREAMINFOとWAVヘッダーを読み、形式・フレーム数を確認。
不足は `5525-bgm-runtime-v1.zip` 全体（実manifest＋6つの `loops/*.wav`）。
戦闘曲2の比較用音源は存在するが、ゲーム用の確定ループ素材ではない。
