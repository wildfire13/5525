# UI移植に伴う報酬・帰路API（2026-11-06）

今回承認されたモックの報酬区分と帰路をゲームの既存処理へ接続する。戦闘・装備数値や単発依頼の時刻条件は変更しない。

## 報酬

- 新規掲載の依頼は `rewardRevision: 1`。`rewardType` は `money` または `experience`。
- `reward` は条件達成時の合計額、従来の `xp` はこの版ではRP合計。`partyRP` を独立して保存する。ランク上昇曲線は未確定なのでランク値を創作しない。
- 表示用 `rewards` は `type/base/bonus/baseRP/bonusRP/legacyXP`。通常の金銭/EXP報酬は基本 `floor(reward*0.65)`、追加は差額。150は97+53。RPは60+40。
- EXP報酬は達成時の各同行メンバーへ同額。控えには加算せず、パーティ人数で割らない。初期アスタリス掲示板のウエス向け部品箱は150EXP+100RPの例。
- `result.gold/xp/rp/rewardType/partyRP` が実際の支給を示す。`xp` はキャラクター用、`rp` はパーティ用。
- 版のない受注済み旧セーブは約束済みの旧EXP報酬を維持。ロード時の過去報酬再計算・再配布はしない。過去のキャラクター成長をRPへ巻き戻さない。
- 単発依頼の受取場所・時刻・失敗・車輪の遅配額は既存処理のまま。期限失敗型の基本額0を通常依頼の65%へ変えない。

## 帰路

- `turnBack` は第1区間後の野営地、または「次へ」の後で第2区間の道をまだ選んでいない状態で使用可。`view.canTurnBack` と `view.returnHours` をUI用に返す。
- `journey.returning/outboundDestination/outboundRoute` に帰路と当初の目的地・通過経路を保存。帰着先は `journey.destination == journey.origin`。
- 操作すると第1区間と同じ近道/迂回路で実際の遭遇・配置画面に入る。移動時間2/4時間、勝利後1時間。帰路の戦闘報酬は通常戦闘と同じ。既に使った時間・消耗は巻き戻さない。
- 帰着してもクエストは未完了。既存の配達操作と荷物確認が必要。
- 既存の戦闘中 `retreat` は失敗復元として保持。帰路選択と混同しない。
- `forecast('turnBack')` は読み取りのみ。キャンセルした場合に状態を戻す必要はない。

## 検証

`node native/test_mock_ui_rules.cjs` は報酬区分、期限境界、6人のEXP、旧受注セーブ、二重支給防止、近道/迂回帰路、休息、再読込、無効操作の原子性を検証。戦闘勝利は制御fixtureであり、実プレイの証明とは別。既存 `test_campaign.cjs` は実戦闘操作を含む。

## 装備の直接受け渡し

`inventoryQuote` / `inventoryAction` の action `transferEquipped` は、装備中の実体1個を指定slotから外し、同行する別メンバーのインベントリへ原子的に移す。受取枠・解除後の送り主枠・removable/transferable・両手占有・トークンを検証する。失敗時は両者とも無変更。通常の解除と受渡しを2回呼び出す方式ではない。

## 最終検証記録

- mock_ui_rules: 12件、campaign: 47件、quest_cargo: 15件、standalone_quests: 8群、ui_feedback_rules: 8群通過。
- native/check.py全32段階を実行。Python213件中1件の旧旅fixture `enemy-scout-2` 不在は、HEAD版campaign/bridgeを使う隔離環境でも同じStopIterationを確認。今回の変更に起因しない。初回の旧EXP期待値はRPへ更新し個別再検証済み。
- Godot importと移動UI回帰7件通過。frontend_smokeは36件中34件通過（同じfixtureを一時ASCII JSON経由で投入）。残りは削除済みBGM曲名表示の旧期待値とDummy環境の再生状態確認。音源ファイルは存在するが後者の原因は未確定。
- 通常依頼の残り時間は `deadline - (elapsedHours + journey.hours)`。arrive時にjourney.hoursをelapsedHoursへ加算した後journeyをnullにするため二重計上しない。単発依頼はworldTimeとeventEpochの差を使用。
- 移動中の全体地図は表示専用の開閉。既定は横一本道で、開閉状態はセーブへ書き込まない。地図から新たな目的地・出発操作はできない。
