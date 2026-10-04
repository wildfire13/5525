# 11装備案：音声・統合契約（試作）

作業基準 b0176d6。対象はキャンペーンのみ。親から復元された2026-10-02 11:11 UTC原案が根拠。引き波は引き寄せではなく「退き斬り」。カタログ取得はWindows公式helperの `os.setxattr` 非対応で未完了。数値・射程・価格・枠は試作判断。

| skillId | 名前 | 分類 | 発動 |
|---|---|---|---|
| retreatSlash | 退き斬り | active | skill、敵ID、MP1・射程1・70%攻撃＋後退 |
| knockback | 吹き飛ばし | active | skill、敵ID、MP1・射程1・100%＋押出1 |
| splitShot | 分け撃ち | active | skill、異なる敵ID配列2件、MP1・射程3・各60% |
| pincer | 挟撃 | active | skill、敵ID、MP1・射程1・別味方が敵隣接なら150% |
| healingCross | 癒しの輪 | active | skill、味方ID、MP2・射程2・中心十字HP30 |
| defenseLine | 防衛線 | active | skill、味方ID配列1～2件、MP1・射程1 |
| manaGift | 魔力譲渡 | active | skill、別味方ID、射程2・MP最大2移譲 |
| returnHome | 帰還 | active | **return**、自陣空きセル整数、MP0・一戦1回 |
| victoryBreath | 一息 | passive | 勝利確定時、生存者のみMP＋2 |
| loneWolf | 孤軍 | passive | 非隣接時の与ダメージ×1.25 |
| firstStride | 先駆け | passive | 最初のmove、経路2→3（短距離でも消費） |

全アクティブは1行動。基本アクティブはunit.equippedSkill、帰還はunit.effects内のreturnHomeで判別。装飾はaccessory1/2。effectsは重複排除済み。ポーターの攻撃禁止を維持し、武器交換しても基本アクティブはporterのまま。帰還やパッシブは使用可。

`state.skillEvents`（bridge応答でもskillEvents）に最大100件の直近イベントを保持：
`{sequence,type:'skill.activated',actorId,skillId,classification,target?,amount?}`。
sequenceは戦闘内の単調増加。プレビュー・無効操作・取消では増えない。戦闘開始／ロード／試用切替で音声側の戦闘IDを更新し、初回viewの既存イベントを再生せずsequenceを基準値にする。以降の成功act応答で新sequenceだけを消費する。begin中の敵行動がイベントを出す可能性もあるため成功begin応答にも同じ比較を適用する。敗北で一息は出ない。

`battle.action`診断ログにもskillIdとskillEventsが含まれるが、毎回直近履歴を含むので音声の直接再生トリガーにはせずsequenceで重複排除する。loneWolfはダメージ計算1回につき1イベント（分け撃ちはまとめて1件）。MP上限時の一息もamount:0として発動は1回。既存6スキルの音声処理は既存契約を維持。

共同編集禁止：このworktreeの差分を親が音声worktreeの変更と統合する。commit/push/merge/配布は未実施。統合後のAstra試遊・デバッグ・再検証を経て反映する。
