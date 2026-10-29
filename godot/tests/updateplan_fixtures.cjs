'use strict';
// Isolated current-schema fixtures, never a player's profile.
const C=require('../../native/campaign.js');
const s=C.deserialize(C.serialize(C.createLegacy()));s.selected=['warrior','porter'];s.characters.warrior.inventory={};
C.depart(s,'east');C.travel(s,'safe',()=>.2);C.begin(s);
const b=s.battle,a=b.units.find(u=>u.id==='warrior'),p=b.units.find(u=>u.id==='porter');
b.units.forEach((u,i)=>{u.pos=i;u.next=100});a.pos=22;a.next=1;p.next=2;b.actor=a.id;a.mp=1;
if(!C.validate(s).ok)throw Error(C.validate(s).error);
console.log(JSON.stringify({stamp:JSON.parse(C.serialize(s)),town:JSON.parse(C.serialize(C.create()))}));
