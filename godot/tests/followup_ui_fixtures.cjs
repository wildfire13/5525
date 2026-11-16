'use strict';
const C=require('../../native/campaign.js'),B=require('../../native/campaign-battle.js'),assert=require('node:assert/strict');
const {ids,fresh,save}=require('./ui_current_fixtures.cjs');
function battle(actor=ids.guard,mp=3,formed=true){
 const s=fresh();
  // The empty right hand grants passive item-use; the shield still grants cover.
  s.characters[ids.guard].weapon='empty-rightHand';s.characters[ids.guard].leftHand='guard-shield-wood';
 // Synthetic four-ether fixture now has an explicit owner before battle starts.
 delete s.characters[ids.guard].inventory.ether;s.characters[ids.porter].inventory.ether=4;
 assert(C.depart(s,'east'));assert(C.travel(s,'short',()=>.5));assert(C.begin(s));
 const b=s.battle;
 for(const u of b.units){u.hp=u.max;u.next=u.side==='ally'?2:10000;}
 b.actor=actor;const a=b.units.find(u=>u.id===actor);a.next=1;a.mp=mp;
 const guard=b.units.find(u=>u.id===ids.guard);guard.hp=60;guard.mp=actor===ids.guard?mp:0;guard.selectedSkill='skill_cover';
 b.units.find(u=>u.id===ids.mage).hp=0;
 // Keep the three formation cells occupied, using the living scout in place of the mage.
 guard.pos=24;b.units.find(u=>u.id===ids.archer).pos=13;
 const scout=b.units.find(u=>u.id===ids.scout);scout.pos=33;
 if(!formed)scout.pos=30;
 b.units.find(u=>u.id===ids.porter).pos=actor===ids.porter?22:23;
  b.potions.ally=3;b.ethers=4;
  assert(B.selectSkill(b,actor===ids.porter?'skill_formation_boost':'skill_cover'),'preselect current source-qualified skill');
 if(actor===ids.porter)assert.equal(B.formation(b,'ally'),formed);
 assert(C.validate(s).ok,C.validate(s).error);
 return save(s);
}
function camp(){
 const f=battle(),s=f.state;for(const u of s.battle.units)if(u.side==='enemy')u.hp=0;
 s.battle.result='勝利！ ミラーマッチを制した。';assert(C.finishBattle(s));assert.equal(s.phase,'camp');
 assert(C.validate(s).ok,C.validate(s).error);return save(s);
}
function support(right,left,skill){
 const s=fresh();s.characters[ids.mage].weapon=right;s.characters[ids.mage].leftHand=left;
 assert(C.depart(s,'east'));assert(C.travel(s,'short',()=>.5));assert(C.begin(s));
 const b=s.battle;for(const u of b.units)u.next=u.side==='ally'?2:10000;
 const mage=b.units.find(u=>u.id===ids.mage);mage.next=1;mage.pos=22;mage.selectedSkill=skill;b.actor=mage.id;
 const guard=b.units.find(u=>u.id===ids.guard);guard.pos=24;guard.hp=10;
  b.units.find(u=>u.id===ids.porter).pos=21;
  assert(B.selectSkill(b,skill),'preselect current source-qualified support skill');
 assert(C.validate(s).ok,C.validate(s).error);return save(s);
}
const result={heal_left:support('sword-wood','staff-wood','skill_heal'),heal_right:support('staff-wood','sword-wood','skill_heal'),cover_staff:support('staff-wood','guard-shield-wood','skill_cover'),camp:camp(),guard:battle(),mp0:battle(ids.guard,0),porter:battle(ids.porter),broken:battle(ids.porter,3,false)};
if(require.main===module)console.log(JSON.stringify(result).replace(/[^\x00-\x7f]/g,c=>'\\u'+c.charCodeAt(0).toString(16).padStart(4,'0')));
module.exports=result;
