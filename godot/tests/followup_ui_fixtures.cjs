'use strict';
const C=require('../../native/campaign.js'),B=require('../../native/campaign-battle.js'),assert=require('node:assert/strict');
function battle(actor='guard',mp=3,formed=true){
 const s=C.create();
 s.characters.guard.weapon='hammer-wood';s.characters.guard.leftHand='guard-shield-wood';
 // Synthetic four-ether fixture now has an explicit owner before battle starts.
 delete s.characters.guard.inventory.ether;s.characters.porter.inventory.ether=4;
 assert(C.depart(s,'east'));assert(C.travel(s,'short',()=>.5));assert(C.begin(s));
 const b=s.battle;
 // R04: this fixed-position regression intentionally resumes the legacy formation.
 b.formationVersion=1;
 for(const u of b.units){u.hp=u.max;u.next=u.side==='ally'?2:10000;}
 b.actor=actor;const a=b.units.find(u=>u.id===actor);a.next=1;a.mp=mp;
 const guard=b.units.find(u=>u.id==='guard');guard.hp=60;guard.mp=actor==='guard'?mp:0;guard.selectedSkill='guard';
 b.units.find(u=>u.id==='mage').hp=0;
 // Keep the three formation cells occupied, using the living scout in place of the mage.
 const scout=b.units.find(u=>u.id==='scout');scout.pos=33;
 if(!formed)scout.pos=30;
 b.units.find(u=>u.id==='porter').pos=23;
 b.potions.ally=3;b.ethers=4;
 assert.equal(B.formation(b,'ally'),formed);assert(C.validate(s).ok,C.validate(s).error);
 return JSON.parse(C.serialize(s));
}
function camp(){
 const f=battle(),s=f.state;for(const u of s.battle.units)if(u.side==='enemy')u.hp=0;
 s.battle.result='勝利！ ミラーマッチを制した。';assert(C.finishBattle(s));assert.equal(s.phase,'camp');
 assert(C.validate(s).ok,C.validate(s).error);return JSON.parse(C.serialize(s));
}
function support(right,left,skill){
 const s=C.create();s.characters.mage.weapon=right;s.characters.mage.leftHand=left;
 assert(C.depart(s,'east'));assert(C.travel(s,'short',()=>.5));assert(C.begin(s));
 const b=s.battle;for(const u of b.units)u.next=u.side==='ally'?2:10000;
 const mage=b.units.find(u=>u.id==='mage');mage.next=1;mage.pos=22;mage.selectedSkill=skill;b.actor=mage.id;
 const guard=b.units.find(u=>u.id==='guard');guard.pos=24;guard.hp=10;
 b.units.find(u=>u.id==='porter').pos=21;
 assert(C.validate(s).ok,C.validate(s).error);return JSON.parse(C.serialize(s));
}
const result={heal_left:support('sword-wood','staff-wood','mage'),heal_right:support('staff-wood','sword-wood','mage'),cover_staff:support('staff-wood','guard-shield-wood','guard'),camp:camp(),guard:battle(),mp0:battle('guard',0),porter:battle('porter'),broken:battle('porter',3,false)};
if(require.main===module)console.log(JSON.stringify(result).replace(/[^\x00-\x7f]/g,c=>'\\u'+c.charCodeAt(0).toString(16).padStart(4,'0')));
module.exports=result;
