'use strict';
// Source: restored proposal, 2026-10-02 11:11 UTC. All numbers are playtest values.
const definitions = {
  itemUse:{name:'アイテム使用',classification:'active',cost:0,target:'item',description:'バトル中にもアイテムを使用できる。本人の所持品を1個使用。Lv1は自身のみ、Lv2は自身と隣接する味方、Lv3は距離制限なし。MP0。'},
  legSweep:{name:'足払い',classification:'active',cost:1,reach:1.5,target:'self',description:'周囲8マスの敵それぞれに足払い判定。Lv1:50%、Lv2:75%、Lv3:100%。ダメージ0、成功時は次の1手番をスキップ（重複なし）。MP1。'},
  grapple:{name:'引き寄せ',classification:'active',cost:1,reach:2,target:'unit',description:'右2マス先の敵味方を1マス引き寄せる。途中が占有されている場合もMP1と行動を消費するが移動しない。'},
  poleVault:{name:'ポールヴォールト',classification:'active',cost:1,reach:2,target:'cell',description:'上下左右2マス先へ跳躍。途中の空き・人物を問わず、盤内の移動可能な空きマスに着地。MP1。'},
  swift:{name:'俊足',classification:'passive',description:'通常移動力+1。先駆けと加算（暫定）：通常3、初回4。侵入制限・行動数は変更しない。'},
  retreatSlash:{name:'退き斬り',classification:'active',cost:1,reach:1,target:'unit',description:'射程1の敵へ70%攻撃後、自陣側へ1マス後退。退路が塞がる／盤外なら使用不可。MP1。'},
  knockback:{name:'吹き飛ばし',classification:'active',cost:1,reach:1,target:'unit',description:'射程1の敵へ通常攻撃。対象の先が空いていれば1マス押す。盤外・占有時は攻撃のみ。MP1。'},
  splitShot:{name:'分け撃ち',classification:'active',cost:1,reach:3,target:'pair',description:'射程3の異なる敵2体を順に指定し、各60%攻撃。同じ敵への集中不可。MP1。'},
  pincer:{name:'挟撃',classification:'active',cost:1,reach:1,target:'unit',description:'射程1の敵へ攻撃。対象に別の生存味方が縦横隣接していれば150%、それ以外100%。MP1。'},
  healingCross:{name:'癒しの輪',classification:'active',cost:2,reach:2,target:'unit',description:'射程2の生存味方を中心に、中心＋上下左右の生存味方のHPを各30回復。MP2。'},
  defenseLine:{name:'防衛線',classification:'active',cost:1,reach:1,target:'upToTwo',description:'縦横隣接の味方を1～2人指定。次の本人の番までかばう。同じ対象の重複指定不可。MP1。'},
  manaGift:{name:'魔力譲渡',classification:'active',cost:0,reach:2,target:'unit',description:'射程2の別の生存味方へMPを最大2移譲。自分の残量・相手の空き分まで。総量は増えない。1行動。'},
  returnHome:{name:'帰還',classification:'active',cost:0,reach:null,target:'cell',description:'1戦1回、自陣の指定空きマスへ帰還。MP0、1行動。装備中はスキル一覧から選択。'},
  victoryBreath:{name:'一息',classification:'passive',description:'勝利時、生存している装備者のMPを2回復（上限まで）。重複装備しても1回。'},
  loneWolf:{name:'孤軍',classification:'passive',description:'別の生存味方と縦横隣接していない間、与ダメージ125%。重複装備しても1回。'},
  firstStride:{name:'先駆け',classification:'passive',description:'各戦闘の最初の移動だけ経路3まで。短い移動・入替でも消費。侵入制限は変わらない。'},
};
const weapons=[
 ['undertow-sword','引き波の剣','sword','retreatSlash',26,1,8,0,0],
 ['breaker-hammer','突き崩しの槌','hammer','knockback',29,1,14,0,0],
 ['twin-bow','双射の弓','bow','splitShot',25,3,8,0,10],
 ['partner-dagger','相棒の短剣','dagger','pincer',23,1,0,0,11],
 ['rest-staff','憩いの杖','staff','healingCross',14,2,0,8,0],
 ['battleline-shield','戦列の盾','shield','defenseLine',20,1,8,0,0],
 ['sharing-tome','分かちの魔導書','book','manaGift',14,2,0,8,0],
].map(([id,name,type,skill,atk,reach,str,int,agi])=>({id,name,type,...(type==='bow'?{hands:2}:{}),skill,atk,reach,str,int,agi,slot:'weapon',material:'wood',grade:0,price:100,note:definitions[skill].description+(type==='shield'?' 右手または左手に装備。':'')}));
const accessories=[['return-ring','帰り路の指輪','returnHome'],['victory-earring','凱歌の耳飾り','victoryBreath'],['lone-ring','一匹狼の指輪','loneWolf'],['pioneer-gloves','先駆者の手袋','firstStride'],['invasion-charm','侵入用装飾品（既存効果の仮枠化）','invasion']];
const gear=[...weapons,...['accessory1','accessory2'].flatMap((slot,index)=>[
 {id:`empty-${slot}`,name:`装飾${index+1}：なし`,slot,allowedSlots:['accessory1','accessory2'],type:'empty',material:'cloth',grade:0,price:0,str:0,int:0,agi:0},
 ...accessories.map(([id,name,effect])=>({id:`${id}-${index+1}`,name,shopProductId:`${id}-1`,slot,type:'accessory',effect,material:'cloth',grade:0,price:70,str:0,int:0,agi:0,note:definitions[effect]?.description||'敵陣侵入を許可。ポーターは侵入不可。帰還指輪と併用すると2枠使用。'}))
])];
module.exports={definitions,gear};
