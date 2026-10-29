'use strict';
// Historical-ID fixtures retain the old roster; new-game/one-time migration
// behavior is tested separately in test_updateplan_roster.cjs.
const assert=require('node:assert/strict'),C=require('./campaign.js'),B=require('./campaign-battle.js'),I=require('./intent-info.cjs');
let checks=0;const test=(name,fn)=>{fn();checks++;console.log('PASS '+name)};
const clone=x=>JSON.parse(JSON.stringify(x));
test('potion proposal changes purchase price only, same initial resources and cap',()=>{
 const s=require('./test-current-fixture.cjs')();assert.deepEqual(C.inventoryTotals(s),{potion:3,ether:1});s.location='south';
 const item=C.items.find(i=>i.id==='potion');assert.equal(item.price,40);assert.equal(item.amount,55);
 assert(C.buyItem(s,'potion',2,'guard',C.inventoryToken(s)));assert.equal(s.gold,100);assert.equal(C.inventoryTotals(s).potion,5);
 s.characters.guard.inventory.potion=99;assert(!C.buyItem(s,'potion',1,'guard',C.inventoryToken(s)));assert.equal(C.inventoryTotals(s).potion,99);
});
function battle(){const s=require('./test-current-fixture.cjs')();assert(C.inventoryAction(s,'guard','ether','transfer','porter',1,null,C.inventoryToken(s)));C.depart(s,'north');C.travel(s,'safe',()=>.2);C.begin(s);const b=s.battle;for(const u of b.units)u.next=1e6;const p=b.units.find(u=>u.job==='porter'&&u.side==='ally');p.next=1;b.actor=p.id;return {s,b,p};}
test('ether porter only, infinite distance, MP+3 bounded, one item/action',()=>{
 const {s,b,p}=battle(),ally=b.units.find(u=>u.id==='guard'),enemy=b.units.find(u=>u.side==='enemy');
 p.pos=0;ally.pos=49;ally.mp=0;p.mp=4;
 assert(B.legalFor(b,p,'ether',ally.id));assert(!B.legalFor(b,ally,'ether',p.id));assert(!B.legalFor(b,p,'ether',enemy.id));
 const before=b.actions;assert(C.act(s,'ether',ally.id));assert.equal(ally.mp,3);assert.equal(b.ethers,0);assert.equal(b.actions,before+1);assert.equal(p.mp,4);
 assert(!B.legalFor(b,p,'ether',ally.id));
});
test('ether cap/KO/full-MP cancellation is atomic',()=>{
 const {s,b,p}=battle();p.mp=p.maxMp;const original=clone(b);assert(!B.legalFor(b,p,'ether',p.id));assert.deepEqual(clone(b),original);
 const ally=b.units.find(u=>u.id==='guard');ally.hp=0;ally.mp=0;assert(!B.legalFor(b,p,'ether',ally.id));
 p.mp=p.maxMp-1;assert(C.act(s,'ether',p.id));assert.equal(p.mp,p.maxMp);assert.equal(b.ethers,0);
});
test('ether survives save/load and rolls back on retreat; malformed resource rejected',()=>{
 const {s,b,p}=battle();p.mp=0;assert(C.act(s,'ether',p.id));
 const loaded=C.deserialize(C.serialize(s));assert.equal(loaded.battle.ethers,0);
 const bad=clone(loaded);bad.battle.ethers=-1;assert(!C.validate(bad).ok);
 assert(C.retreat(s));assert.equal(C.inventoryTotals(s).ether,1);assert.equal(s.characters.porter.inventory.ether,1);
});
test('victory transfers remaining ether without duplicating item',()=>{
 const {s,b,p}=battle();p.mp=0;assert(C.act(s,'ether',p.id));
 for(const e of b.units.filter(u=>u.side==='enemy'))e.hp=0;
 b.result='test victory';assert(C.finishBattle(s));assert.equal(C.inventoryTotals(s).ether,0);assert.equal(s.characters.porter.inventory.ether,undefined);assert(!C.finishBattle(s));
});
test('swift feet adds one movement; firstStride adds another only first move',()=>{
 const s=require('./test-current-fixture.cjs')();s.location='west';assert(C.buyGear(s,'porter','swift-boots','feet'));
 assert(C.stats(s.characters.porter).effects.includes('swift'));
 s.characters.porter.accessory1='pioneer-gloves-1';C.depart(s,'astaris');C.travel(s,'safe',()=>.2);
 const p=s.battle.units.find(u=>u.id==='porter');assert.equal(B.moveReach(p),4);p.firstMoveUsed=true;assert.equal(B.moveReach(p),3);
 assert(C.validate(s).ok);assert.equal(C.deserialize(C.serialize(s)).characters.porter.feet,'swift-boots');
 assert.equal(B.moveReach({effects:[]}),2);assert.equal(B.moveReach({effects:['firstStride']}),3);
});
test('pushed attacker keeps fixed prediction, reports invalid, then misses',()=>{
 const s=B.create({ally:['guard','porter'],enemy:['guard'],deployment:true,enemyPotions:0});const [a,p,e]=s.units;
 a.pos=24;p.pos=22;e.pos=25;a.next=0;p.next=100;e.next=1;a.equippedSkill='knockback';s.actor=a.id;s.deploying=false;
 B.plan(s,e);assert(I.describe(B,s,e).valid);const intent=clone(e.intent);
 const {Presentation}=require('./battle-presentation.cjs'),seq=new Presentation();assert(seq.start(s,B,()=>B.act(s,'skill',e.id)));
 let invalid=false;while(seq.pending){if(e.pos===26&&!invalid){assert.deepEqual(clone(e.intent),intent);assert(!I.describe(B,s,e).valid);invalid=true;}const p=seq.info();seq.next(p.id,p.index);}
 assert(invalid);assert.equal(a.hp,a.max);assert(s.log.some(l=>l.includes('空振り')));
});
test('battle saves survive JSON key sorting while forged equipment remains rejected',()=>{
 const {s}=battle();const sort=x=>Array.isArray(x)?x.map(sort):x&&typeof x==='object'?Object.fromEntries(Object.keys(x).sort().map(k=>[k,sort(x[k])])):x;
 const sorted=sort(JSON.parse(C.serialize(s)));assert.deepEqual(C.deserialize(sorted),clone(s));
 const weapon=clone(sorted);weapon.state.battle.units.find(u=>u.id==='guard').attackWeapons[0].atk++;assert.throws(()=>C.deserialize(weapon));
 const source=clone(sorted);source.state.battle.units.find(u=>u.id==='guard').skillSources[0].itemId='forged';assert.throws(()=>C.deserialize(source));
});
test('warrior normal intent uses fixed cell after original target leaves or is replaced',()=>{
 for(const replacement of [false,true]){
  const s=B.create({ally:['guard','porter'],enemy:['warrior'],deployment:true,enemyPotions:0});
  const a=s.units.find(u=>u.id==='guard'),p=s.units.find(u=>u.id==='porter'),e=s.units.find(u=>u.side==='enemy');
  a.pos=24;p.pos=22;e.pos=25;e.mp=0;a.next=0;p.next=2;e.next=1;s.actor=a.id;s.deploying=false;
  B.plan(s,e);assert.equal(e.intent.kind,'attack');assert.deepEqual(e.intent.cells,[24]);
  const intent=clone(e.intent);a.pos=replacement?0:15;if(replacement)p.pos=24;
  assert.equal(I.describe(B,s,e).valid,replacement);
  assert.deepEqual(clone(e.intent),intent);const hp=p.hp;
  assert(B.act(s,'guard'));
  assert.equal(p.hp,hp-(replacement?26:0));
  if(!replacement)assert(s.log.some(line=>line.includes('空振り')));
 }
});
console.log(JSON.stringify({suite:'godot_rules',checks,passed:true}));
