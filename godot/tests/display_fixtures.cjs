'use strict';
// Read-only synthetic fixtures; the production battle calculation is the oracle.
const C=require('../../native/campaign.js'),B=require('../../native/campaign-battle.js');
const assert=require('node:assert/strict');
const profiles=[];
for(const [name,right,left,growth,id='guard'] of [
 ['sword-shield','sword-wood','guard-shield-wood',0],
 ['mixed-reach','spear-wood','javelin-wood',0],
 ['mixed-reach-growth','spear-wood','javelin-wood',6],
 ['reversed-hands','javelin-wood','spear-wood',6],
 ['left-only','empty-rightHand','javelin-wood',6],
 ['empty-with-growth','empty-rightHand','empty-leftHand',6],
 ['two-handed','longspear-wood','empty-leftHand',6],
 ['two-handed-sword','greatsword-wood','empty-leftHand',0],
 ['porter','porter-kit','empty-leftHand',6,'porter'],
]){
 const s=C.create(),c=s.characters[id];c.weapon=right;c.leftHand=left;c.allocations.str=growth;
 const stats=C.stats(c),actor={...stats,job:id,pos:0};
 const powers=[1,2,3,4].map(d=>B.reachFilteredPower(actor,{pos:d},'attack').base);
 profiles.push({name,stats,powers,reach:B.attackReach(actor,'attack')});
}
const s=C.create();s.location='east';s.gold=250;
assert(C.buyGear(s,'guard','spear-wood','rightHand'));
const quote=C.previewGear(s,'guard','javelin-wood','leftHand');
assert.equal(quote.before.atk,23);assert.equal(quote.after.atk,23);
assert.deepEqual(profiles.find(p=>p.name==='mixed-reach').powers,[44,44,21,0]);
const shop=JSON.parse(C.serialize(s));
assert(C.buyGear(s,'guard','javelin-wood','leftHand'));
assert(C.depart(s,'astaris'));assert(C.travel(s,'short',()=>0));
const deployment=JSON.parse(C.serialize(s));assert(C.begin(s));
const battle=s.battle,guard=battle.units.find(u=>u.id==='guard');
battle.units.forEach(u=>u.next=1000000);guard.pos=24;guard.next=1;battle.actor=guard.id;
battle.units.filter(u=>u.side==='enemy').forEach((u,i)=>{u.pos=[25,15,35][i];B.plan(battle,u);});
assert(C.validate(s).ok,C.validate(s).error);
console.log(JSON.stringify({profiles,shop,quote,deployment,battle:JSON.parse(C.serialize(s))})
 .replace(/[^\x00-\x7F]/g,c=>'\\u'+c.charCodeAt(0).toString(16).padStart(4,'0')));
