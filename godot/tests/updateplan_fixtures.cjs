'use strict';
// Isolated current-schema fixtures, never a player's profile.
const C=require('../../native/campaign.js');
const s=C.create(), actorId='recruit-guard-human-female', porterId='recruit-porter-human-female';
s.selected=[actorId,porterId];
s.characters[actorId].weapon='hammer-wood';
s.characters[actorId].leftHand='empty-leftHand';
C.depart(s,'east');C.travel(s,'safe',()=>.2);C.begin(s);
const b=s.battle,a=b.units.find(u=>u.id===actorId),p=b.units.find(u=>u.id===porterId);
b.units.forEach((u,i)=>{u.pos=i;u.next=100});a.pos=22;a.next=1;p.next=2;b.actor=a.id;a.mp=1;
if(!C.validate(s).ok)throw Error(C.validate(s).error);
console.log(JSON.stringify({stamp:JSON.parse(C.serialize(s)),town:JSON.parse(C.serialize(C.create()))}).replace(/[^\x00-\x7f]/g, c => '\\u' + c.charCodeAt(0).toString(16).padStart(4, '0')));
