'use strict';
// Canonical eight-slot view; legacy storage keys preserve v1 saves losslessly.
const slots={rightHand:'右手',leftHand:'左手',head:'頭',upperBody:'上半身',lowerBody:'下半身',feet:'足',accessory1:'装飾1',accessory2:'装飾2'};
const storage=slot=>({rightHand:'weapon',upperBody:'armor'})[slot]||slot;
const canonical=slot=>({weapon:'rightHand',armor:'upperBody'})[slot]||slot;
const allowed=g=>g.hands===2?['rightHand']:g.allowedSlots||(g.slot==='weapon'?['rightHand','leftHand']:g.slot==='armor'?['upperBody']:g.type==='accessory'?['accessory1','accessory2']:[canonical(g.slot)]);
const identity=id=>id; // Legacy accessory -1/-2 IDs are separately purchased copies.
const extraGear=['rightHand','leftHand','head','upperBody','lowerBody','feet'].map(slot=>({id:`empty-${slot}`,name:`${slots[slot]}：なし`,slot:storage(slot),allowedSlots:[slot],type:'empty',material:'cloth',price:0,grade:0,str:0,int:0,agi:0,hp:0,atk:0,reach:1}));
extraGear.push(...[['head','布の帽子'],['lowerBody','布のズボン'],['feet','布の靴']].map(([slot,name])=>({id:`cloth-${slot}`,name,slot,type:'armor',material:'cloth',price:30,grade:0,str:0,int:0,agi:0,hp:0,note:'部位交換確認用の仮装備。能力補正・スキルなし。'})));
// Approved comparison-playtest values; no new skills or ammunition resource.
extraGear.push(...[
 ['greatsword-wood','木製の両手剣','greatsword',2,50,1,14,140],
 ['spear-wood','木製の片手槍','spear',1,23,2,10,90],
 ['longspear-wood','木製の両手槍','spear',2,34,2,14,140],
 ['javelin-wood','木製の投げ槍','spear',1,21,3,10,100],
].map(([id,name,type,hands,atk,reach,str,price])=>({id,name,slot:'weapon',type,hands,atk,reach,str,price,int:0,agi:0,grade:0,material:'wood',note:`比較試作用の仮数値。${hands===2?'両手2枠占有・攻撃力は1回だけ加算。':'片手1枠。'}独自スキルなし。${id==='javelin-wood'?'投擲に弾数・消耗品・MPの消費なし。':''}火力だけでなく射程・占有枠を含めてバランス検証予定。`})));
extraGear.push({id:'swift-boots',name:'俊足の靴（試作）',slot:'feet',type:'armor',material:'cloth',price:70,grade:0,str:0,int:0,agi:0,hp:0,effect:'swift',note:'移動力+1。先駆けと加算は暫定。価格70Gは試遊用の提案値。'});
// 261019 user-approved effects. Prices remain provisional test equipment values.
extraGear.push(...[
 ['kungfu-pants','カンフーパンツ',5,1,0],['kungfu-pants-1','カンフーパンツ＋1',25,1,1],
 ['kungfu-pants-2','カンフーパンツ＋2',25,2,2],['kungfu-pants-3','カンフーパンツ＋3',25,3,3]
].map(([id,name,hp,skillLevel,grade])=>({id,name,slot:'lowerBody',type:'armor',material:'cloth',hp,skill:'legSweep',skillLevel,grade,str:0,int:0,agi:0,price:70+grade*30,note:'足払い。価格は試遊用の仮値。'})));
extraGear.push(...[
 ['fist','拳',1],['fist-1','拳＋1',2],['fist-2','拳＋2',3]
].map(([id,name,skillLevel])=>({id,name,slot:'weapon',hands:1,type:'fist',material:'cloth',atk:0,reach:1,str:0,int:0,agi:0,hp:0,grade:skillLevel-1,skill:'itemUse',skillLevel,price:skillLevel===2?100:0,...(skillLevel===2?{}:{starterOnly:true,virtualDefault:true}),...(skillLevel===3?{jobOnly:'porter'}:{}),note:skillLevel===2?'擬似個人スキルの試験用。価格100Gは仮値。':'空の手枠の既定性能。所持品には生成しない。'})));
extraGear.push({id:'grappling-rope',name:'鉤縄',slot:'weapon',hands:1,type:'rope',material:'cloth',atk:0,reach:2,str:0,int:0,agi:0,hp:0,grade:0,skill:'grapple',skillLevel:1,price:100,note:'引き寄せ。価格100Gは試遊用の仮値。穴地形は未実装。'});
const pole=extraGear.find(g=>g.id==='longspear-wood');
pole.skill='poleVault';pole.skillLevel=1;pole.note='両手2枠占有。ATK34、ポールヴォールト。価格140Gは既存試遊用の仮値。';
module.exports={slots,storage,canonical,allowed,identity,extraGear};
