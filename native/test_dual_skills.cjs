'use strict';
const assert=require('node:assert/strict'),B=require('./campaign-battle.js');
const clone=x=>JSON.parse(JSON.stringify(x));
const weapon=(slot,atk,reach,skill)=>({slot,itemId:slot,name:slot,atk,reach,skill});
function scene(skill,weapons){const s=B.create({ally:['guard','mage','porter'],enemy:['guard','archer','mage'],enemyPotions:0,deployment:true});const [a,f,p,e,e2,e3]=s.units;a.pos=24;f.pos=0;p.pos=10;e.pos=25;e2.pos=15;e3.pos=35;a.activeSkills=[skill];a.attackWeapons=weapons;a.attackBonus=0;a.mp=8;a.atk=weapons[0].atk;a.reach=weapons[0].reach;for(const u of s.units){u.next=u===a?1:100000;if(u.side==='enemy')u.hp=u.max=999;}s.actor=a.id;s.deploying=false;return {s,a,e,e2,e3};}
let count=0;const test=(name,fn)=>{fn();count++;console.log('PASS '+name);};
function actAndCompare(s,a,target){const before=clone(s),preview=B.damagePreview(s,a,'skill',target);assert.deepEqual(clone(s),before);const hp=Object.fromEntries(s.units.map(u=>[u.id,u.hp]));assert.ok(B.act(s,'skill',target));for(const id of new Set(preview.map(x=>x.recipientId)))assert.equal(hp[id]-s.units.find(u=>u.id===id).hp,preview.filter(x=>x.recipientId===id).reduce((n,x)=>n+x.hpLoss,0));return preview;}
test('snipe extends every weapon by one: sword1/staff2 -> dist2 both dist3 staff',()=>{
 for(const [pos,base,parts] of [[26,40,2],[27,14,1]]){const {s,a,e}=scene('archer',[weapon('rightHand',26,1),weapon('leftHand',14,2)]);e.pos=pos;assert.equal(B.attackReach(a,'skill'),3);const previews=actAndCompare(s,a,e.id);assert.equal(previews[0].damage,base);assert.equal(previews[0].weapons.length,parts);assert.equal(a.mp,7);}
 const {s,a,e}=scene('archer',[weapon('rightHand',26,1),weapon('leftHand',14,2)]);e.pos=28;assert.equal(B.legal(s,'skill',e.id),false);
});
test('splitShot computes each target separately and emits loneWolf once',()=>{
 const {s,a,e,e2}=scene('splitShot',[weapon('rightHand',25,3,'splitShot'),weapon('leftHand',26,1)]);a.effects=['loneWolf'];e2.pos=27;const previews=actAndCompare(s,a,[e.id,e2.id]);assert.deepEqual(previews.map(x=>x.base),[51,25]);assert.deepEqual(previews.map(x=>x.damage),[38,19]);assert.equal(a.mp,7);assert.equal(s.skillEvents.filter(x=>x.skillId==='loneWolf').length,1);
});
test('stamp source hammer covers all three cells, other sword only near target',()=>{
 const {s,a}=scene('stamp',[weapon('rightHand',29,1,'stamp'),weapon('leftHand',26,1)]);const before=s.units.map(u=>u.hp);assert.deepEqual(B.damagePreview(s,a,'skill',25),[]);assert(B.act(s,'skill',25));assert.deepEqual(s.units.slice(3).map((u,i)=>before[i+3]-u.hp),[55,29,29]);assert.equal(a.mp,7);assert.equal(s.actions,2,'reservation plus next personal opportunity');
});
test('ambush sums after landing; passive, MP and movement remain single action',()=>{
 const {s,a,e}=scene('scout',[weapon('rightHand',23,1,'scout'),weapon('leftHand',14,2)]);a.canInvade=true;e.pos=27;const previews=actAndCompare(s,a,e.id);assert.equal(a.pos,26);assert.equal(previews[0].base,37);assert.equal(a.mp,7);assert.equal(s.actions,1);
});
test('same skill on two weapons adds only their ATK, no special duplication bonus',()=>{
 const {s,a,e}=scene('archer',[weapon('rightHand',25,3,'archer'),weapon('leftHand',31,3,'archer')]);e.pos=28;a.attackBonus=2;const previews=actAndCompare(s,a,e.id);assert.equal(previews[0].base,58);assert.equal(a.mp,7);assert.equal(s.actions,1);
});
console.log(`PASS ${count} dual-skill groups`);
