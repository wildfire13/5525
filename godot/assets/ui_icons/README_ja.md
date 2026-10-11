# 5525 採用アイコン 正式受け渡しパッケージ 52点

最新版wiki v40の採用一覧から、採用済みPNGだけをそのまま収録した実装用の受け渡しZIPです。
PNGの再生成、描き直し、再縮小、改名、ゲームコード変更は行っていません。

## 基準と内容

- wiki source commit: 5fffd4a9eb290ed7cc0bbef555faea1155c5aaf1
- 内訳：従来採用UI・種族39点（4ジョブを含む）＋武器種8点＋追加5点（銃・短剣・本・素手・EXP）＝52点
- EXPは右上がりに斜め配置した「EXP」3文字ロゴの最新版
- 種族は人間・エルフ・ドワーフの右向き無顔頭部3点。目・鼻・口・眉・頭髪なし。ドワーフの髭は保持
- 耳だけ／髭だけの比較候補、旧顔、旧EXP、単品比較剣、比較シートは収録しない
- 元資料の公開・頒布ライセンスを新規に設定するものではありません。既存プロジェクトで採用された素材の私的な受け渡しです

## ファイル

- icons64/：採用PNG 52点。64×64px、RGBA、全周4px以上の透明余白、本体最大56×56px
- manifest.json：ID・日本語名・分類・寸法・透明余白・SHA-256・採用元の来歴
- labels.tsv：実装時に参照しやすい名前と分類一覧
- category_mapping.json：wikiの9分類
- skill_mapping.json / skill_mapping.tsv：wikiの19スキルとの対応
- command_mapping.json：5コマンドと表示方式
- validation.json：検証結果
- SHA256SUMS：このファイルを含む全同梱ファイルの検証用ハッシュ（SHA256SUMS自身を除く）

## 分類

- 種族：3点
- ジョブ：4点
- 能力・状態：8点
- コマンド：5点
- 装備部位：7点
- 武器種：12点
- 消耗品：2点
- 拠点・施設：7点
- 効果（共通）：4点

## 実装時の表示規約

C：コマンド欄は採用アイコン＋文字で表示する。攻撃・移動・スキル・アイテム・防御は各コマンドの画像と、読める名称を併記する。アイコンだけに置き換えない。
画像内に文字を追加加工せず、名称はUIテキストとして別に置く。ジョブ用画像は戦士・スカウト・魔法使い・ポーターの4点。
速度画像の素材名はspeed / SPDだが、既存仕様の能力名AGIを変更しない。武器種・効果画像は共通アイコンで、個別技能専用アートではない。
城画像は都市アスタリスを表す。装飾品屋の配置先はwikiでは未定。

## スキル対応

wiki v40で確認した対応です。付与する装備の武器種・防具部位・装飾品を使い、同種装備が複数あってもアイコンは1つにまとめます。陣形強化だけは共通のskill.pngです。
この対応のためにスキル性能や付与条件を変更しないでください。

- 俊足（swift） → feet.png
- 退き斬り（retreatSlash） → sheet_one_handed_sword.png
- 吹き飛ばし（knockback） → sheet_hammer.png
- 分け撃ち（splitShot） → sheet_bow.png
- 挟撃（pincer） → dagger.png
- 癒しの輪（healingCross） → sheet_staff.png
- 防衛線（defenseLine） → sheet_shield.png
- 魔力譲渡（manaGift） → book.png
- 帰還（returnHome） → accessory.png
- 一息（victoryBreath） → accessory.png
- 孤軍（loneWolf） → accessory.png
- 先駆け（firstStride） → accessory.png
- 侵入（invasion） → accessory.png
- スナイプ（archer） → sheet_bow.png
- ヒール（mage） → sheet_staff.png
- 奇襲（scout） → dagger.png
- スタンプ（stamp） → sheet_hammer.png
- 陣形強化（porter） → skill.png
- かばう（guard） → sheet_shield.png

## 検証範囲

52/52点をwiki manifestおよび各採用元PNGのSHA-256と照合。すべて64×64 RGBA、全周4px以上の透明余白を確認。種族3点とEXPの見た目も確認済み。
本ZIPは素材の受け渡しです。ゲーム内の配置・描画サイズ・GPU取り込み・操作確認は別途実装側で行ってください。
ゲームへの組み込み完了、リポジトリ反映、PC同期の完了を示すものではありません。
