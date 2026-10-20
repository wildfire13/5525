# 装備8部位・合算攻撃・剣盾分割：統合契約

基準 a51a7737b1c9f7e6310225c352692a735079a935。作業先 `G:\Apps\CodexProjects\5525-equipment-work`、branch equipment-slots。commit/push/merge/配布なし。通常起動先・他担当worktreeは変更しない。

## 決定済みルール

- 右手、左手、頭、上半身、下半身、足、装飾2の8枠。旧weapon/armor保存キーは右手/上半身へ対応。
- 通常攻撃は対象距離に届く各攻撃武器ATKを合算。武器射程のunionが合法射程。例：剣26/射程1＋杖14/射程2なら距離1は40、距離2は14。
- 成長補正floor(allocations.str/2)は寄与武器がある場合に1回だけ加算。キャラテンプレートATK・基礎STRは追加しない。陣形・孤軍・防御等は合算後に従来どおり適用。
- 攻撃スキルも対象別の武器ATK合算。スナイプは全攻撃武器の射程+1、倍率は通常攻撃と同じ。剣1/杖2なら距離2で両方、距離3で杖のみ。
- 同じskillIdが複数源にあっても選択肢は1つ、MP・行動消費は1回。独自の重複ボーナスなし。パッシブ同効果は1回、別効果は共存。帰還本人1戦1回。永続習得なし。
- 旧剣盾セットは剣と盾で左右1枠ずつ。剣の既存ID/ATK/価格を保持し、かばうは新guard-shield-wood / guard-shield-iron-1へ移す。盾ATK0/価格0は資産価値を増減させないための仮配分。
- 既存種族素材・能力条件を維持。職業による槌制限を追加しない。ポーターは従来の装備条件、通常攻撃不可、陣形強化・帰還・パッシブ利用。

## 既存スキルを維持する仮細部

- スタンプ付与元の槌は従来の3マス範囲全体へ寄与。他武器は各対象への通常射程で寄与。
- 二股は対象別距離と既存60%倍率。孤軍の発動イベントは複数対象でも1行動1回。
- 奇襲は従来どおり着地した後の距離で合算。退き斬り・吹き飛ばし等は既存の固有射程／移動／倍率を維持。
- 回復や支援スキルへ武器ATKは加算しない。

## セーブ互換・競合

- envelope version1継続。各キャラのequipmentRevision:2で分割移行済みを識別。
- まず旧ルールで既存保存内容を検証し、複製を移行後に再検証。元ファイルを自動更新しない。
- 現在のcharactersとrollback.charactersを移行。戦闘unitの装備源・攻撃武器を更新し、HP/MP・資金・位置・かばう・帰還済み・先駆け済み等を保持。再読込で盾を増やさない。
- 内部試作セーブで分割先の左手に別品がある場合、品を消したり無断売却したりせず、競合ID付きの説明で読込を原子的に拒否。現在の進行と元JSONは保持。旧試作で左手を空け、別名保存して再読込する。
- 同一キャラの同一ID二重使用は不可。旧装飾-1/-2は別購入品IDとして保持。同型装備のキャラ間共有は禁止しない。

## 2枠占有・追加4武器

- hands:2の装備は右手だけに実体を保存し、左手をoccupiedBy:rightHandで表示。左手の空きが必要。左手が埋まっていれば購入／試用を拒否し、無断下取りしない。
- 左手への直接装備は不可。右手の両手装備を外すと左手も開放。ステータス／ATK／スキル源は1回だけ数える。
- 両手剣はドワーフの刀剣制限に含む。槍は刀剣には含めない。
- 両手剣・片手槍・両手槍・無消費投げ槍を追加済み。旧企画原文（2026-10-20削除済み）には分類と条件方針のみあり、数値／射程／独自スキル指定なし。
- 親承認済みの比較試作用仮値（木製・新スキルなし）：両手剣ATK50/射程1/STR14/140G、片手槍23/2/10/90G、両手槍34/2/14/140G、投げ槍21/3/10/100G。カタログ・イースの店・購入・試着・木人試用に接続。両手は単一武器1回寄与。片手2本の合算より低火力となる組合せはバランス検証事項であり、射程・装備条件・占有枠を含めて評価する。
- 既存槌・弓等の占有は未変更。頭／下半身／足の布仮装備は補正0・スキルなし・30G。

## 共通ファイル／API

- campaign.js: equipment/stats/applyEquipment/quote/buyGear/previewGear/trial/view/validate/deserialize。slot任意引数は既存末尾に追加。
- equipment-slots.js: 部位・保存キー・適合枠・空装備・布仮装備。hands:2はrightHandのみ。
- unit.attackWeapons:[{slot,itemId,name,atk,reach,skill}]とattackBonus。unit.atk/reachは互換表示用であり、実攻撃計算に直接使わない。旧unitは旧方式へフォールバック。
- unit.activeSkillsはskillコマンドの重複除去ID、skillSourcesは全源{id,slot,itemId,classification}。帰還は従来の専用returnコマンド。
- B.reachFilteredPower(actor,target,kind)、B.attackReach、B.damagePreviewが計算契約。damagePreviewは複製上で同じapply/receiveを実行し、対象ごとの寄与武器・基礎威力・成長補正・被覆先・実HP減少を返す。ライブ状態／イベントは不変。
- bridge select_skill/skillset/normalAttackReach/skillReachを追加。preview.damagePreviewは対象別予測。skillset.sourcesには表示用itemNameを追加。
- app.py: 複数active選択・装備源表示・対象別ダメージ予測。campaign_app.py: 8枠表示・ショップ枠指定・試用／購入のslot引渡し。演出／画像担当の同じメソッドとの競合を確認すること。
- skillEvents形式は不変。選択スキルはB.activeSkill(actor)を参照し、equippedSkill単独で判定しない。選択自体はMP／行動数／発動イベントを消費しない。

## 検証

- native/test*.cjs全成功。追加：通常合算6群、スキル合算5群、部位10群、旧セーブ移行4群、2枠占有3群、新4武器6群。既存装備skill17群・campaign47群・音声・凍結エンジン等も成功。
- Python -X utf8 -m unittest discover -s native -p test_*.py : 117件成功。
- test_fixtures/campaign-a51a773-battle.jsonはa51a773実コードで生成した旧戦闘セーブ。returnUsed/firstMoveUsed/coverとrollbackを含む移行・再保存・撤退を検証。
- 実Tk非表示の8枠描画・2active切替は前段階で確認済み。最終統合後の人によるGUI／新武器プレイは未実施。
- GitAGENTS/AGENTS.mdと.agents/skillsはリポジトリ／祖先／関連5525ディレクトリで発見できず。既存README・SKILLS11・契約・ソーステストを確認。

## 2026-10-04 承認更新

全4種の弓は両手2枠を占有。両手剣ATKは50。槌・槍の数値、対象別合算とスナイプ射程+1は維持。旧セーブの弓と左手が競合する場合は装備を破棄せず、キャラ/装備と解消手順を示して読込を拒否。弓単独の旧セーブは保持して移行する。

槌の比較完了・親採用：片手占有を維持し、木29／鉄39／突き崩し29のまま。スタンプと副手合算、押し出しによる陣形解除の用途を評価し、今回は強化しない。弓両手化・両手剣50・槍据え置きで今回の統合仕様を確定。
