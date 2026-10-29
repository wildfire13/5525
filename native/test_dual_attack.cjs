'use strict';
// Historical-ID fixtures retain the old roster; new-game/one-time migration
// behavior is tested separately in test_updateplan_roster.cjs.
const assert=require('node:assert/strict'),C=require('./campaign.js'),B=require('./campaign-battle.js');
const clone=x=>JSON.parse(JSON.stringify(x));
function scene(){const s=require('./test-current-fixture.cjs')();s.location='east';s.gold=1000;assert.ok(C.buyGear(s,'mage','sword-wood','rightHand'));assert.ok(C.buyGear(s,'mage','staff-wood','leftHand'));const c=s.characters.mage;c.level=2;c.xp=100;c.skillPoints=1;c.allocations.str=2;const t=C.trial(s,'mage','sword-wood','rightHand');return {s,t,a:t.battle.units.find(u=>u.id==='mage'),e:t.battle.units.find(u=>u.id==='enemy-guard')};}
let count=0;const test=(name,fn)=>{fn();count++;console.log('PASS '+name);};
test('sword1 staff2: near sums both, far staff only, growth added exactly once',()=>{
 for(const [position,base,slots] of [[25,41,['rightHand','leftHand']],[26,15,['leftHand']]]){
  const {t,a,e}=scene();e.pos=position;const before=clone(t.battle),p=B.attackPreview(t.battle,a,e);
  assert.equal(B.attackReach(a),2);assert.ok(B.legal(t.battle,'attack',e.id));assert.equal(p.base,base);assert.equal(p.bonus,1);assert.deepEqual(p.weapons.map(w=>w.slot),slots);assert.deepEqual(clone(t.battle),before);
  const hp=e.hp,mp=a.mp;assert.ok(C.trialAct(t,'attack',e.id));assert.equal(hp-e.hp,p.hpLoss);assert.equal(a.mp,mp);assert.equal(t.battle.actions,1);
 }
});
test('out of union rejects atomically, source character atk is not added',()=>{
 const {t,a,e}=scene();e.pos=27;const old=clone(t.battle);assert.equal(B.legal(t.battle,'attack',e.id),false);assert.equal(B.attackPreview(t.battle,a,e),null);assert.equal(C.trialAct(t,'attack',e.id),false);assert.deepEqual(clone(t.battle),old);assert.equal(B.reachFilteredPower(a,e).base,0);
});
test('preview matches cover, guard, formation and loneWolf; passive emits once',()=>{
 const {t,a,e}=scene(),b=t.battle,protector=b.units.find(u=>u.id==='enemy-archer');a.effects=['loneWolf'];b.units.filter(u=>u.side==='ally'&&u!==a).forEach((u,i)=>u.pos=[0,10][i]);
 e.pos=25;protector.pos=16;b.units.find(u=>u.id==='enemy-mage').pos=36;protector.cover=e.id;protector.guard=true;
 const p=B.attackPreview(b,a,e),before=clone(b);assert.equal(p.recipientId,protector.id);assert.deepEqual(clone(b),before);
 const hp=protector.hp,ehp=e.hp;assert.ok(C.trialAct(t,'attack',e.id));assert.equal(hp-protector.hp,p.hpLoss);assert.equal(e.hp,ehp);assert.equal(b.skillEvents.filter(x=>x.skillId==='loneWolf').length,1);
});
test('legacy summary fields stay stable while contextual power is calculated separately',()=>{
 const {a}=scene();assert.equal(a.atk,27);assert.equal(a.reach,1);assert.equal(B.activeSkill(a),'mage');assert.equal(B.attackReach(a,'skill'),2);
});
test('porter stays unable to attack with two weapons',()=>{
 const {a,t,e}=scene();a.job='porter';assert.equal(B.legal(t.battle,'attack',e.id),false);assert.equal(B.reachFilteredPower(a,e).base,0);
});
test('save validates weapon contributions and shared bonus',()=>{
 const {s}=scene();C.depart(s,'astaris');C.travel(s,'safe',()=>.2);const saved=C.serialize(s);assert.deepEqual(C.deserialize(saved),clone(s));
 for(const mutate of [a=>a.attackWeapons[0].atk++,a=>a.attackBonus++,a=>a.attackWeapons[0].reach++,a=>delete a.attackBonus]){const bad=clone(s);mutate(bad.battle.units.find(u=>u.id==='mage'));assert.equal(C.validate(bad).ok,false);}
});
console.log(`PASS ${count} dual-attack groups`);
