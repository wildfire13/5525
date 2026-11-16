'use strict';
const C=require('../../native/campaign.js'),B=require('../../native/campaign-battle.js'),assert=require('assert/strict');
const GUARD='recruit-guard-human-female',SCOUT='recruit-scout-human-female',MAGE='recruit-mage-elf-female';
function battle(actor=GUARD,gear=null){
 const s=C.create();s.location='east';s.gold=1000;
 if(gear){const c=s.characters[actor];c.xp=100;c.level=2;c.statPoints=1;c.skillPoints=1;c.allocations.str=1;}
 if(gear)assert(C.buyGear(s,actor,gear,'rightHand'));
 assert(C.depart(s,'astaris'));assert(C.travel(s,'short',()=>0));assert(C.begin(s));
 const b=s.battle,unit=b.units.find(u=>u.id===actor);
 b.units.forEach(u=>u.next=1000000);
 if(actor!==GUARD){b.units.find(u=>u.id===GUARD).pos=14;unit.pos=24;}
 b.units.filter(u=>u.side==='enemy').forEach((u,i)=>{u.pos=[25,15,35][i];if(i===0)u.next=2;});
 unit.next=1;b.actor=unit.id;
 if(actor===MAGE)b.units.find(u=>u.id===GUARD).hp=60;
 assert(C.validate(s).ok,C.validate(s).error);
 return JSON.parse(C.serialize(s));
}
const low=battle();for(const u of low.state.battle.units){if(u.id===GUARD)u.hp=Math.max(1,Math.ceil(u.max/4)-1);if(u.id===SCOUT)u.hp=Math.ceil(u.max/4);}
assert(C.deserialize(low));
console.log(JSON.stringify({low,attack:battle(),split:battle(SCOUT,'twin-bow'),heal:battle(MAGE)}).replace(/[^\x00-\x7F]/g,c=>'\\u'+c.charCodeAt(0).toString(16).padStart(4,'0')));
