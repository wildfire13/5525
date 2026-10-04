> Final integration status: see [INTEGRATION-QA.md](INTEGRATION-QA.md). Earlier pending/hold statements below are historical implementation records. Runtime now contains 137 voice clips and six BGM tracks; independent manual GUI QA is complete.

# キャラクターボイス組込み（137音声導入済みの作業版）

スキル11案とBGM6曲の統合を完了。新アクティブ8種の追加72音声を受入れ、計137音声が利用可能。
最新の起動方法と検証結果は [INTEGRATION-QA.md](INTEGRATION-QA.md)。
以下の65件・素材待ちの記述は作業履歴。製品コードはqa2と同一、テストはv3向けに更新済み。

## 最新状態：手動保存素材を受入れ済み

ユーザー指定 `M:\dl\5525\5525-character-voices-full-v2.zip` を読み取り、
14,546,716 bytesと既知SHA-256
`a1417faa871aa975fde4b5cc52d0caa8906265924d2d47229d9eb1cd14d92551` の一致を確認。
ZIP全178エントリのCRC、重複パス、絶対／親パス、リンクを検査。
個別65WAVと元manifest、licenses資料だけを `native/assets/voices` に安全展開した。
結合試聴WAV・生成スクリプトはランタイムへ入れていない。元ダウンロードは変更・削除していない。
各クリップのSHA-256、48kHz／mono、長さ、11人65キー完全一致を消費側でも確認。
素材不足0（現行5スキル＋ポーター陣形強化。別担当の11装備スキル差分は未統合）。
元manifestは承認済み17件、追加48件は `not_auditorily_reviewed` のまま維持。

同じ確定応答内の同一キャラ／同一キューは一度だけ発声するよう重複抑制を追加。
現在の集約チェック10工程・Python102件成功。以下のLibrary転送失敗の節は取得経緯であり、
現時点の音声素材未取得を意味しない。BGMランタイム素材と親側統合・実試遊は別途必要。

実Windows／非表示Tkで、実Nodeの勝利直前局面から弓通常攻撃を確定して実WAV再生を確認。
続いてガロのかばう、ミオのヒール、ニカの奇襲、トトの陣形強化、槌戦士のスタンプ、
guard-2の被弾を同じVoicePlayerから順次再生し、全7クリップのAPI再生開始成功・エラーなし。
10.55秒間でUIタイマー334回、窓終了時停止を確認。6クリップの手動キュー確認は、
各スキルを実ゲームで操作した証拠とは区別する。聴感の新規承認・全65件の実聴取は未実施。

2026-10-04、基準 `b0176d6`。作業場所は別worktree
`G:\Apps\CodexProjects\5525-voice-work`。通常起動先の `5525-git` は未変更。
commit / push / merge / 配布は行っていない。

## 実装

- 共通戦闘画面で、成功した確定行動のレスポンスだけを再生する。
  キャンペーン・木人・旧版で同じ経路を使う。プレビュー、取消、拒否、再描画、
  保存読込、途中再開では音声イベントを再生しない。
- `voice-events.cjs` は行動実行中だけHP書込みを観測し、必ず元の通常プロパティに戻す。
  戦闘ルール・セーブ状態・凍結エンジンは変更しない。
  味方の攻撃／実スキルと、実際にHPが減った味方本人（かばう先ではなく身代わり）を通知。
  敵への味方音声流用はしない。複数の被弾は順序を維持する。
- キャラIDとcueの完全一致のみ。職業、名前、画像による別人へのフォールバックなし。
  ヒールは `skill:mage`。装備変更後の `activeSkill` を使用する。
- Windows標準 `winsound` の非同期再生とTkタイマーで1クリップずつ再生する。
  次行動は前の再生と待機列を停止して差替え。ミュートで即停止。
  窓破棄・撤退・木人終了・RESETで停止し、ミュートはアプリセッション内で共通。
  Linux等は無音で動作。追加依存やネット通信なし。
- 対象は確定した `act` とそれに続く敵の自動行動、および配置確定 `begin` の先制敵行動。
  開始応答のイベントは新規戦闘窓に一度だけ渡す。開始前取消・拒否・画面再開では再生しない。

## 素材受入れ形式（提供された正式schema v1）

`native/assets/voices/manifest.json` と、その下に元ZIPの個別WAVツリーを配置する。
`schema_version: 1`、`characters` 配列の各 `id` と `prepared` 辞書を直接使用する。
`prepared` のキーは `attack`, `hurt`, `skill:実スキルID`、値は `path`, `text`,
`sha256`, `duration_seconds`, `sample_rate`, `channels` などの素材情報。
パスは `voices/{character_id}_{attack|hurt}_01.wav` または
`voices/{character_id}_skill_{actual_skill_id}_01.wav`。
したがって素材WAVは `native/assets/voices/voices/` 下に置かれる。
元manifestの構造変換は不要。SHA-256、実WAVのサンプルレート・チャンネル数・長さを照合する。

`path` は音声ディレクトリ内の相対パス。重複キー、外部パス、不正WAV、欠落ファイルは
カタログを無効化し、ゲームは無音で継続する。未収録キーは無音。
結合試聴WAVは配置・登録しない。

必要なキャラIDは `guard`, `guard-2`, `archer`, `archer-2`, `mage`, `mage-2`,
`scout`, `scout-2`, `porter`, `porter-2`, `warrior`。
非ポーター9人は `attack`, `hurt`, `skill:guard`, `skill:mage`, `skill:archer`,
`skill:scout`, `skill:stamp`。ただしドワーフの `warrior` は刀剣・短剣を装備できず、
`skill:guard` と `skill:scout` は収録不要。ポーター2人は `hurt`, `skill:porter` の各2キュー。
必要数は計65キュー（9×7−2＋2×2）。通常攻撃／ダメージ／標準スキル31、装備差分34。
テストではエンジン単独の職横断対応まで45組を検証している。

## 検証と未完了

- `python native/check.py` に音声イベントテストを追加。
- 集約チェック全10工程成功。Python89件成功。結果は `native/qa-check-report.json`。
- 装備スキル45組、通常攻撃9人、ポーター2人、かばう、被弾後回復、拒否時無通知、
  例外時HP観測解除をNodeで確認。
- Python追加11件で完全一致、欠落素材、非同期フラグ、直列化、ミュート、割込み、破棄、
  音声APIエラー、確定二重押下／取消、実Node応答の一回性を確認。
- Windows実Tkを非表示で生成し、実際の勝利直前攻撃経路から検証用の無音WAVを再生。
  WinSound呼出し成功、行動処理0.032秒、再生中Tkタイマー10回、窓破棄時停止を確認。
  実画面の目視・承認音声の聴取証拠ではない。
- 入力 `libfile_8681b13b8420819188a8c179a3676b68` はWindows宛てに準備したが、
  現行Library公式helperの結果が `library file transfer failed: download failed`。
  個別WAVと元manifestの実ファイルは取得できず、音声素材の登録／実音声試聴は未完了。
  アクセス拒否の迂回、URL推測、別環境のパス利用は行っていない。
- 親側では不足48キューを準備中との連絡あり。素材取得後、元の17WAVを保持し、
  全キューのキャラ・セリフ・ハッシュを照合してから組込み／実再生確認が必要。

## 配置確定時の追加検証

実Nodeキャンペーンの公開操作でguardを(5,1)へ配置し、`begin` 後の先制被弾と
`guard/hurt` 一件を確認。開始前の取消記録・viewは状態不変で無通知。
開始の再要求は拒否され空イベント。旧エンジンでも同じ先制被弾経路をNodeで確認。
開始応答を新規戦闘窓へ一度だけ渡すコントローラーテストと、再開時に過去イベントを
渡さないテストを追加。実Tk非表示窓＋モック音声でも起動時一回・再描画無再生・破棄時停止を確認。

Library転送は既知IDの `prepare_materialize` → 現行skillの
`references/materialization.md` に従う公式 `library_file_transfer.py materialize` を使用。
Windows内の別worktree宛てに返されたtransferオブジェクト全体をstdinで渡した。
最後の返却は `library file transfer failed: download failed`（終了コード1）。
HTTPステータスや「アクセス拒否」の返却はなく、ダウンロード失敗以上の原因は判定できない。
最初の補助ファイル配置ではTEMPディレクトリ作成がAccess denied、PATH上のpythonも未検出だったため、
許可済みworkspaceと既存Python実体へ変更。その後の公式helper実行が上記エラー。
ダウンロード独自実装・追加再試行は行っていない。

## 完成版65音声ZIPの受入れ試行

新しい入力 `libfile_8a1fbff78db48191a83db5e69e28c3c8`、
`5525-character-voices-full-v2.zip`（14,546,716 bytes）について、
現行Libraryスキルと公式helperを新たに取得し、Windows別worktree内の
`voice-input-v2` 宛てに `prepare_materialize` を実行した。
準備結果は成功、対象1件、unavailableなし、ファイル名・サイズ一致。
返されたtransferオブジェクト全体を公式helperへ渡した結果は
`library file transfer failed: download failed`（終了コード1）。
HTTPステータスや403の明示はなく、権限拒否とは断定できない。
完成版ZIPのローカルファイルは存在せず、SHA-256照合・展開・実manifest照合・
65音声の登録／実再生確認には進めていない。独自取得や再試行はしていない。
共有された期待SHA-256は
`a1417faa871aa975fde4b5cc52d0caa8906265924d2d47229d9eb1cd14d92551`。
生成側の「不足0・旧17WAV byte一致・新48音声機械検査済み／聴感未確認」は受領情報であり、
このWindows環境で検証できたという意味ではない。
