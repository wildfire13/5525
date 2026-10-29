'use strict';
// Explicit QA-only snapshots. These are controlled battle boundaries, not evidence
// of reaching the scene by playing every preceding encounter.
const C=require('../../native/campaign.js'),assert=require('node:assert/strict');
function fixture(kind){
 const s=require('../../native/test-current-fixture.cjs')(),c=s.characters.guard;
 if(kind.startsWith('sweep'))c.lowerBody=kind==='sweep50'?'kungfu-pants':'kungfu-pants-3';
 if(kind==='vault'){c.weapon='longspear-wood';c.leftHand='empty-leftHand';}
 if(kind.startsWith('grapple')){c.weapon='grappling-rope';c.leftHand='empty-leftHand';}
 // One empty hand and two empty hands both supply passive Lv1 item range;
 // the retired paid fist must not recreate an active Lv2 command.
 if(kind.startsWith('item')){c.weapon='empty-rightHand';c.leftHand=kind==='item1'?'guard-shield-wood':'empty-leftHand';}
 if(kind==='item3'){c.inventory={};s.characters.porter.inventory={potion:2,ether:1};}
 assert(C.depart(s,'east'));assert(C.travel(s,'short',()=>0));assert(C.begin(s));
 const b=s.battle,a=b.units.find(u=>u.id===(kind==='item3'?'porter':'guard'));
 const positions={guard:22,archer:12,mage:13,scout:4,porter:32};
 for(const u of b.units){u.hp=u.max;u.mp=u.maxMp;u.next=100;u.guard=false;u.cover=null;u.boost=false;if(u.side==='ally')u.pos=positions[u.id];}
 const enemies=b.units.filter(u=>u.side==='enemy');enemies.forEach((e,i)=>{e.pos=[24,15,35][i];e.next=80+i;});
 if(kind.startsWith('sweep')){a.pos=24;enemies.forEach((e,i)=>{e.pos=[25,15,35][i];e.next=2+i;});a.selectedSkill='legSweep';}
 if(kind==='vault'){b.units.find(u=>u.id==='mage').pos=23;enemies[0].pos=25;a.selectedSkill='poleVault';}
 if(kind.startsWith('grapple')){a.selectedSkill='grapple';if(kind==='grapple-blocked')b.units.find(u=>u.id==='mage').pos=23;}
 if(kind.startsWith('item')){a.hp-=40;b.units.find(u=>u.id==='mage').hp-=30;b.units.find(u=>u.id==='mage').pos=23;delete a.selectedSkill;}
 a.next=1;b.actor=a.id;
 for(const e of enemies)require('../../native/campaign-battle.js').plan(b,e);
 assert(C.validate(s).ok,C.validate(s).error);
 return JSON.parse(C.serialize(s));
}
const cases=Object.fromEntries(['sweep50','sweep100','vault','grapple','grapple-blocked','item1','item2','item3'].map(kind=>[kind,fixture(kind)]));
const town=require('../../native/test-current-fixture.cjs')();town.gold=3000;town.characters.guard.inventory={potion:5,'javelin-wood':1,'grappling-rope':1,'kungfu-pants':1,'kungfu-pants-1':1,'kungfu-pants-2':1,'kungfu-pants-3':1,'longspear-wood':1};cases.town=JSON.parse(C.serialize(town));
if(require.main===module)console.log(JSON.stringify(cases).replace(/[^\x00-\x7f]/g,c=>'\\u'+c.charCodeAt(0).toString(16).padStart(4,'0')));
module.exports=cases;
