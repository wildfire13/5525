'use strict';
// Historical-ID fixtures retain the old roster; new-game/one-time migration
// behavior is tested separately in test_updateplan_roster.cjs.
const assert=require('node:assert/strict'),C=require('./campaign.js'),B=require('./campaign-battle.js');
const master=require('./master-data.cjs').getMaster();
let count=0;function test(name,fn){fn();count++;console.log('PASS '+name);}
function trial(accessory2){
 const s=C.createLegacy();s.location='east';s.characters.guard.accessory1='lone-ring-1';
 if(accessory2)s.characters.guard.accessory2=accessory2;
 const t=C.trial(s,'guard','sword-wood','rightHand');assert.ok(t);
 const b=t.battle,a=b.units.find(u=>u.id==='guard'),enemy=b.units.find(u=>u.side==='enemy');
 a.pos=24;enemy.pos=25;
 for(const [i,u] of b.units.filter(u=>u!==a&&u!==enemy).entries())u.pos=[0,10,19,39][i];
 return {t,b,a,enemy};
}
function checkDamage(f,expectedPercent){
 const {t,b,a,enemy}=f,base=B.reachFilteredPower(a,enemy).base;
 const before=structuredClone(b),preview=B.attackPreview(b,a,enemy);
 assert.deepEqual(b,before,'preview cannot mutate sources, events or resources');
 const expected=Math.round(base*(1+expectedPercent/100));assert.equal(base,26);
 assert.equal(preview.damage,expected,'percentage contributions sum before multiplication');
 if(expectedPercent===50)assert.notEqual(preview.damage,Math.round(base*1.25*1.25),'not successive multipliers');
 const hp=enemy.hp,mp=a.mp;assert.ok(C.trialAct(t,'attack',enemy.id));
 assert.equal(hp-enemy.hp,expected);assert.equal(a.mp,mp);assert.equal(b.actions,1);
 assert.equal((b.skillEvents||[]).filter(e=>e.skillId==='loneWolf').length,expectedPercent?1:0,'one resolved passive feedback event, not repeated attacks');
}
test('two grant slots on one item add +25% +25% and preserve both sources',()=>{
 const original=master.grantsByEquipment['lone-ring-1'];
 try{
  master.grantsByEquipment['lone-ring-1']=[...original.map(g=>({...g})),{...original[0],slotNo:2}];
  const f=trial();assert.deepEqual(f.a.skillSources.filter(g=>g.id==='loneWolf').map(g=>g.grantSlot),[1,2]);
  assert.equal(B.effectCount(f.a,'loneWolf'),2);assert.equal(B.percentageIncrease(f.a,'loneWolf',25),50);checkDamage(f,50);
 }finally{master.grantsByEquipment['lone-ring-1']=original;}
});
test('two separately equipped accessory IDs add +25% +25% with exact preview/execution parity',()=>{
 const f=trial('lone-ring-2');assert.deepEqual(f.a.skillSources.filter(g=>g.id==='loneWolf').map(g=>g.slot),['accessory1','accessory2']);
 assert.equal(B.effectCount(f.a,'loneWolf'),2);checkDamage(f,50);
});
test('adjacent living ally suppresses all conditional contributions',()=>{
 const f=trial('lone-ring-2');f.b.units.find(u=>u.side==='ally'&&u!==f.a).pos=23;checkDamage(f,0);
});
console.log(`PASS ${count} SQLite passive-grant groups`);
