'use strict';
const C=require('../../native/campaign.js'),B=require('../../native/campaign-battle.js'),assert=require('assert/strict');
function battle(actor='guard',gear=null){
 const s=C.create();s.location='east';s.gold=1000;
 if(gear)assert(C.buyGear(s,actor,gear,'rightHand'));
 assert(C.depart(s,'astaris'));assert(C.travel(s,'short',()=>0));assert(C.begin(s));
 const b=s.battle,unit=b.units.find(u=>u.id===actor);
 b.units.forEach(u=>u.next=1000000);
 if(actor!=='guard'){b.units.find(u=>u.id==='guard').pos=14;unit.pos=24;}
 b.units.filter(u=>u.side==='enemy').forEach((u,i)=>{u.pos=[25,15,35][i];if(i===0)u.next=2;B.plan(b,u);});
 unit.next=1;b.actor=unit.id;
 if(actor==='mage')b.units.find(u=>u.id==='guard').hp=60;
 assert(C.validate(s).ok,C.validate(s).error);
 return JSON.parse(C.serialize(s));
}
const low=battle();low.state.battle.units.find(u=>u.id==='guard').hp=44;low.state.battle.units.find(u=>u.id==='archer').hp=25;
assert(C.deserialize(low));
console.log(JSON.stringify({low,attack:battle(),split:battle('archer','twin-bow'),heal:battle('mage')}).replace(/[^\x00-\x7F]/g,c=>'\\u'+c.charCodeAt(0).toString(16).padStart(4,'0')));
