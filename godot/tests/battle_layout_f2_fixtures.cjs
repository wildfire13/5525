'use strict';
const C=require('../../native/campaign.js'),assert=require('node:assert/strict');
const cases={};
for(const kind of ['sweep50','sweep100']){
 const s=C.create(),id='recruit-guard-human-female';
 s.characters[id].lowerBody=kind==='sweep50'?'kungfu-pants':'kungfu-pants-3';
 assert(C.depart(s,'east'));assert(C.travel(s,'short',()=>0));assert(C.begin(s));
 const b=s.battle,a=b.units.find(u=>u.id===id);
 for(const u of b.units){u.hp=u.max;u.mp=u.maxMp;u.next=100;}
 a.pos=24;
 b.units.filter(u=>u.side==='enemy').forEach((u,i)=>{u.pos=[25,15,35][i];u.next=2+i;});
 a.next=1;a.selectedSkill='legSweep';b.actor=a.id;
 assert(C.validate(s).ok,C.validate(s).error);
 cases[kind]=JSON.parse(C.serialize(s));
}
require('node:fs').writeFileSync(process.argv[2],JSON.stringify(cases),'utf8');
