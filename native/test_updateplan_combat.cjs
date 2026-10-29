'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js'),B=require('./campaign-battle.js');
function battle(weapon='javelin-wood'){
 const s=C.create(),id=s.selected[0];s.characters[id].weapon=weapon;s.characters[id].inventory.potion=2;
 assert(C.depart(s,'east'));assert(C.travel(s,'safe',()=>.2));assert(C.begin(s));
 const b=s.battle,a=b.units.find(u=>u.id===id),enemy=b.units.find(u=>u.side==='enemy');
 for(const [i,u] of b.units.entries()){u.pos=i;u.next=100;}
 a.pos=22;enemy.pos=26;a.next=1;b.actor=id;
 return {s,b,a,enemy};
}
{
 const {s,b,a,enemy}=battle();assert(B.selectSkill(b,'spearThrow'));
 enemy.pos=25;assert(!B.legal(b,'skill',enemy.id));enemy.pos=27;assert(!B.legal(b,'skill',enemy.id));enemy.pos=26;
 const before=enemy.hp,mp=a.mp;assert(B.act(b,'skill',enemy.id));assert(enemy.hp<before);assert.equal(a.mp,mp);
 assert.equal(a.equipment.rightHand,'empty-rightHand');assert(!a.attackWeapons.some(w=>w.slot==='rightHand'));
 assert(!B.activeSkillOptions(a).some(o=>o.id==='spearThrow'));assert.equal(B.itemUseLevel(a),1);
 assert.equal(s.characters[a.id].weapon,'javelin-wood');assert(C.validate(s).ok,C.validate(s).error);
 const loaded=C.deserialize(C.serialize(s));assert.deepEqual(loaded.battle.units.find(u=>u.id===a.id).thrownWeapons,{rightHand:'javelin-wood'});
 for(const u of b.units.filter(u=>u.side==='enemy'))u.hp=0;b.result='勝利';
 assert(C.finishBattle(s));assert.equal(s.characters[a.id].weapon,'javelin-wood');
}
{
 const {s,b,a}=battle('empty-rightHand');b.itemInventories[a.id].potion=2;b.potions.ally=2;a.hp-=60;
 assert(!B.activeSkillOptions(a).some(o=>o.id==='itemUse'));
 assert(B.act(b,'item',a.id));assert(!a.skillCooldowns||!Object.keys(a.skillCooldowns).length);
 assert.equal(B.itemUseLevel(a),1);assert(C.validate(s).ok,C.validate(s).error);
}
console.log('PASS spear exact reach, fist conversion, single use, save/load, recovery; passive fist no CT');
{
 const s=C.deserialize(C.serialize(C.createLegacy()));s.selected=['warrior','porter'];s.characters.warrior.inventory={};
 assert(C.depart(s,'east'));assert(C.travel(s,'safe',()=>.2));assert(C.begin(s));
 const b=s.battle,a=b.units.find(u=>u.id==='warrior'),p=b.units.find(u=>u.id==='porter');
 b.units.forEach((u,i)=>{u.pos=i;u.next=100});a.pos=22;a.next=1;p.next=2;b.actor=a.id;
 assert(B.selectSkill(b,'stamp'));assert.deepEqual(B.stampCells(a,23),[13,23,33]);assert.deepEqual(B.stampCells(a,21),[]);
 const mp=a.mp,health=b.units.map(u=>u.hp),frames=require('./battle-presentation.cjs').capture(b,B,()=>B.act(b,'skill',23)).frames;
 assert.equal(a.mp,mp-1);assert.deepEqual(b.units.map(u=>u.hp),health);assert(a.pendingStamp);
 assert(!frames.some(frame=>frame.phase==='hurt'));assert.equal(frames[0].kind,'cast');
 const loaded=C.deserialize(C.serialize(s));assert.deepEqual(loaded.battle.units.find(u=>u.id==='warrior').pendingStamp,a.pendingStamp);
 // The target cells stay empty: an empty cast still resolves without paying MP again.
 for(let i=0;i<5&&a.pendingStamp;i++)assert(B.act(b,'guard',null));
 assert.equal(a.pendingStamp,undefined);assert.equal(a.mp,mp-1);assert(C.validate(s).ok,C.validate(s).error);
 assert(b.log.some(text=>text.includes('空振り')));
}
console.log('PASS stamp right three cells, reservation, no early hit, save/load, empty resolution');
{
 const fs=require('node:fs'),path=require('node:path');
 const original=fs.readFileSync(path.join(__dirname,'test_fixtures/campaign-4633264-javelin.json'),'utf8');
 const migrated=C.deserialize(original);assert.equal(migrated.phase,'town');assert.equal(migrated.characters.guard.weapon,'javelin-wood');
 assert.equal(Object.keys(migrated.characters).length,35);assert.deepEqual(C.deserialize(C.serialize(migrated)),migrated);
 const invalid=JSON.parse(original);invalid.state.battle.units.find(u=>u.id==='guard').atk+=999;assert.throws(()=>C.deserialize(invalid));
 console.log('PASS frozen pre-update javelin battle migration, unchanged equipment, idempotence, corrupt stat rejected');
}
{
 for(const grants of [0,1,2])for(const roll of [.05,.15,.95]){
  const b=B.create({ally:['guard','porter'],enemy:['guard'],deployment:true,enemyPotions:0});
  const [a,p,e]=b.units;a.pos=24;p.pos=32;e.pos=25;b.deploying=false;b.actor=a.id;
  for(const u of b.units)u.next=u===a?1:100000;
  e.skillSources=Array.from({length:grants},(_,i)=>({id:'evasion',slot:'accessory'+(i+1),itemId:'test-evasion',grantSlot:1,level:1,classification:'passive'}));
  const before=structuredClone(b);const preview=B.attackPreview(b,a,e);assert.equal(preview.evasionChance,grants*.1);
  B.damagePreview(b,a,'attack',e.id);assert.deepEqual(b,before,'previews do not mutate or roll');
  let rolls=0;assert(B.act(b,'attack',e.id,()=>{rolls++;return roll}));
  assert.equal(rolls,grants?1:0);assert.equal(e.hp===before.units[2].hp,roll<grants*.1);
 }
 console.log('PASS evasion additive grants, actual hits/misses, no roll without evasion, preview read-only');
}
{
 const b=B.create({ally:['warrior','porter'],enemy:['guard','mage'],deployment:true,enemyPotions:0});
 const [a,p,e,f]=b.units;a.pos=22;p.pos=2;e.pos=23;f.pos=33;
 a.next=1;p.next=2;e.next=f.next=100;b.actor=a.id;b.deploying=false;
 const mp=a.mp;assert(B.act(b,'skill',23));assert(a.pendingStamp);assert.equal(a.mp,mp-1);
 // Fixture simulates intervening movement/knockback. Both reservation and VFX
 // must retain the originally chosen cells, not chase either participant.
 e.pos=24;a.pos=21;const hp=e.hp,insideHp=f.hp;
 const frames=[];for(let n=0;n<5&&a.pendingStamp;n++)frames.push(...require('./battle-presentation.cjs').capture(b,B,()=>B.act(b,'guard')).frames);
 assert.equal(a.pendingStamp,undefined);assert.equal(a.mp,mp-1);assert.equal(e.hp,hp);assert(f.hp<insideHp);
 const hit=frames.find(frame=>frame.kind==='skill'&&frame.skill_id==='stamp');assert.deepEqual(hit.resolved.cells,[13,23,33]);
 assert.deepEqual(B.stampCells({pos:8},9),[9,19]);assert.deepEqual(B.stampCells({pos:48},49),[39,49]);assert.deepEqual(B.stampCells({pos:29},30),[]);
 console.log('PASS fixed stamp cells after target/caster movement, authoritative VFX cells, board edges');
}
{
 const s=C.deserialize(C.serialize(C.createLegacy()));s.selected=['warrior','porter'];s.characters.warrior.inventory={};
 assert(C.depart(s,'east'));assert(C.travel(s,'safe',()=>.2));assert(C.begin(s));const b=s.battle,a=b.units.find(u=>u.id==='warrior'),p=b.units.find(u=>u.id==='porter');
 b.units.forEach((u,i)=>{u.pos=i;u.next=100});a.pos=22;a.next=1;p.next=2;b.actor=a.id;
 const mp=a.mp;assert(B.act(b,'skill',23));assert(a.pendingStamp);a.skipNextTurn=true;
 for(let i=0;i<5&&a.skipNextTurn;i++)assert(B.act(b,'guard'));
 assert.equal(a.pendingStamp,undefined);assert.equal(a.mp,mp-1);assert.equal(B.activeSkillOptions(a).find(o=>o.id==='stamp').cooldown,0);
 assert(C.validate(s).ok,C.validate(s).error);const loaded=C.deserialize(C.serialize(s));assert.equal(loaded.battle.units.find(u=>u.id===a.id).pendingStamp,undefined);
 assert(b.log.some(line=>line.includes('構えは足払いで中断')));
 console.log('PASS leg sweep cancels queued stamp without refund/activation CT; save reload does not resurrect it');
}
{
 const s=C.deserialize(C.serialize(C.createLegacy()));s.selected=['warrior','porter'];s.characters.warrior.inventory={};
 assert(C.depart(s,'east'));assert(C.travel(s,'safe',()=>.2));assert(C.begin(s));
 const b=s.battle,a=b.units.find(u=>u.id==='warrior'),p=b.units.find(u=>u.id==='porter');
 b.units.forEach((u,i)=>{u.pos=i;u.next=100});a.pos=22;a.next=1;p.next=2;b.actor=a.id;
 a.mp=0;const before=structuredClone(b);assert.equal(B.act(b,'skill',23),false);assert.deepEqual(b,before);
 a.mp=1;assert(B.selectSkill(b,'stamp'));B.damagePreview(b,a,'skill',23);assert.equal(a.mp,1);assert.equal(a.pendingStamp,undefined,'selection/preview never commits cast');
 assert(B.act(b,'skill',23));assert.equal(a.mp,0);assert(a.pendingStamp);
 let loaded=C.deserialize(C.serialize(s));loaded=C.deserialize(C.serialize(loaded));
 const hero=loaded.battle.units.find(u=>u.id===a.id);assert.equal(hero.mp,0);assert(hero.pendingStamp);
 for(let i=0;i<5&&hero.pendingStamp;i++)assert(B.act(loaded.battle,'guard'));
 assert.equal(hero.pendingStamp,undefined);assert.equal(hero.mp,0);assert(loaded.battle.log.some(t=>t.includes('スタンプ →')));
 assert.equal(C.deserialize(C.serialize(loaded)).battle.units.find(u=>u.id===a.id).mp,0);
 console.log('PASS stamp MP shortage atomicity, selection/preview free, prepaid zero-MP resolution, repeated save/load no recharge/refund');
}
