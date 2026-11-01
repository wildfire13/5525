# キャラ別イベント音声の適用（2026-11-01）

基点 main: `362ae90c1aa625df8f7a7072b02fc5b3ac432692`。音声と関連回帰だけを別worktreeで実装。元worktreeの未commitTypography/unslopとAutopilotは保全し、同梱しない。

## 素材と対応

- 採用中の `recruit-{guard/scout/porter/mage}-{human/elf/dwarf}-{male/female}` 24人に固定IDで対応。guardは音声側warrior。
- 5イベント×24人＝120 MP3、約7.7MiB。48kHz mono 192kbps。WAV原音・モデルはゲームへ追加しない。
- 02候補5人25本はゲーム未採用のため同梱/再生しない。除外名はmanifestに列挙。ポーター01_02は同一人物の画像差分で独立音声なし。
- 旧11人は従来の正確なID音声を維持。種族/性別/職業や画像だけで旧人物・敵・不明IDへ新音声を流用しない。画像は一切変更しない。
- 台詞、採用元slug、参照WAV SHA、MP3 SHA、長さは `native/assets/event-voices/manifest.json`。

## 再生ルール

- 通常攻撃は既存action演出の実行時。スキル（帰還等含む）は本人のattack音声を共用し、専用セリフは生成しない。スタンプは構え時には鳴らさず発動時に既存skillイベントから鳴らす。
- HPが実際に減ったhurt演出でdamage。HPが正から0以下へ遷移した時のみincapacitatedを追加。同じ行動中の重複を抑止し、被ダメージ→戦闘不能を単一チャンネルで順番再生。
- バトル勝利は当該戦闘の生存参加者で音声のある人からランダム1人。控え・敵・戦闘不能は除外。ゼロなら無音。既存resultキーで再描画の再抽選/再生を防ぐ。読み込んだ過去リザルトは再発声しない。
- クエストクリアは成功したcompleteQuest応答で、所持パーティ(selected)中の音声のある人からランダム1人。依頼完了カウンタで重複を防ぎ、閲覧/再表示/失敗応答/保存の読込では発声しない。
- 勝利とクリアが連続してもqueueで順番再生。既存ボイス音量/ミュートを尊重し、ミュート・音量0・接続切替・新規/ロード・終了はキューを止める。ゲーム判定やセーブ形式は変更しない。

## 検証

- `native/test_event_voice_integration.cjs`：24IDと種族/性別/職業、120hash、02除外、action/skill/cast、HP減少/戦闘不能/回復/拒否を検証。
- `godot/tests/event_voices_regression.gd`：120MP3を実デコード。技能共用、順番再生、packet重複、音量/ミュート、勝利母集団/戦闘不能除外/ゼロ対象、クリア母集団/重複、連続イベント、ロード抑止、接続切替を検証。最後は正規検証済みの新規ロスター依頼境界fixtureから実updateコマンドを通す。戦闘を自然に完走した証拠ではない。
- ローカル最終：対象5suite（event_voice_assets、event_voices_regression、frontend_smoke、audio_options_regression、results_regression）成功。その後追加した実コマンド導線assertはevent_voice_assets/event_voices_regressionの対象再実行で成功。
- 既存 `test_battle_presentation.cjs`、`test_voice_events.cjs`、Python `test_voice.py`15件も成功。
- FHD 1920×1080、専用プロファイル、Dummy出力。環境にDISPLAYがなくOS実画面・主観聴取・Windows実機は未確認。音声一致/発音を確認済みとはしない。
- GitHub Actionsは既存自動フル構成のまま。今回無断で軽量化設定を変更せず、ローカルは対象限定。新規回帰だけ既存runnerへ登録。
- 最初のeditor importは既定ホームへの書込不可で設定/キャッシュ作成に失敗。専用XDGプロファイルへ切替後のimportは成功。権限拡張・本人設定変更なし。

## 生成来歴

Irodori-TTS (`Aratako/Irodori-TTS`) code `59be938c99d48b5653ca5aa3fdd0cddaa56940e5`。
`phasefield-audio/Irodori-TTS-v4.1-Anime` revision `6b259f5baa5e236b3d14cbd1f8555ca87d92b530` (model card: MIT)。採用済み合成WAVを参照し本人承認の台本/演技指定を使用。実在人物や声優のクローンではない。watermark保持。原制作は145本全数でfinite/非無音/非クリップ/長さ/decodeを検証。生成設定原本は非公開納品commit `77e90016aa4432b8024baa515738d3cad7954568`。

ゲームへの適用/公開main pushは今回ユーザー承認済み。PC側pullや本人試聴は実施しない。
