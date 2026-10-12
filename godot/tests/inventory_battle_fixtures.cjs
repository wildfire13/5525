'use strict';
const C=require('../../native/campaign.js'),assert=require('node:assert/strict');
function make(actor){
 const s=C.create();assert(C.inventoryAction(s,'guard','ether','transfer','porter',1,null,C.inventoryToken(s)));
 assert(C.depart(s,'east'));assert(C.travel(s,'safe',()=>0));assert(C.begin(s));
 const b=s.battle;for(const u of b.units)u.next=1000;
 const a=b.units.find(u=>u.id===actor);a.next=1;b.actor=actor;
 const guard=b.units.find(u=>u.id==='guard');guard.hp=20;guard.mp=0;
 function place(unit,pos){const other=b.units.find(u=>u!==unit&&u.pos===pos);if(other)other.pos=unit.pos;unit.pos=pos;}
 const archer=b.units.find(u=>u.id==='archer');place(archer,24);
 const enemy=b.units.find(u=>u.side==='enemy');place(enemy,25);
 assert(C.validate(s).ok,C.validate(s).error);return JSON.parse(C.serialize(s));
}
// OS.execute decodes through the Windows console code page; keep transport ASCII.
console.log(JSON.stringify({archer:make('archer'),guard:make('guard'),porter:make('porter')}).replace(/[^\x00-\x7f]/g,c=>'\\u'+c.charCodeAt(0).toString(16).padStart(4,'0')));
