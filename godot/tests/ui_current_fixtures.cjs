'use strict';
// Fresh live recruits with explicit scenario equipment; enemy identities stay native.
const C=require('../../native/campaign.js'),B=require('../../native/campaign-battle.js');
const assert=require('node:assert/strict');
const ids={guard:'character_mirei',scout:'character_rio',
 archer:'character_shion',mage:'character_merina',porter:'character_yuno'};
function fresh(){
 const s=C.create();
 for(const u of Object.values(s.characters))u.accessory2='pouch-belt-3';
 s.characters[ids.guard].inventory={potion:3,ether:1};
 return s;
}
function save(s){
 assert(C.validate(s).ok,C.validate(s).error);
 assert.deepEqual(Object.keys(s.characters).sort(),B.recruitRoster.map(u=>u.id).sort());
 if(s.battle)assert(s.battle.units.every(u=>u.side==='enemy'||B.recruitRoster.some(r=>r.id===u.id)));
 const value=JSON.parse(C.serialize(s));assert(C.deserialize(value));return value;
}
function battle(actor=ids.guard,right=null,left=null){
 const s=fresh();s.location='east';s.gold=1000;
 if(right)s.characters[actor].weapon=right;
 if(left)s.characters[actor].leftHand=left;
 assert(C.depart(s,'astaris'));assert(C.travel(s,'short',()=>0));assert(C.begin(s));
 const b=s.battle;
  const positions={[ids.guard]:24,[ids.scout]:3,[ids.archer]:13,[ids.mage]:33,[ids.porter]:22};
 for(const u of b.units){u.next=1000000;if(u.side==='ally')u.pos=positions[u.id];}
 b.units.filter(u=>u.side==='enemy').forEach((u,i)=>{u.pos=[25,35,15][i];});
 const a=b.units.find(u=>u.id===actor);a.next=1;b.actor=actor;
 return s;
}
const town=fresh(),east=fresh(),west=fresh();east.location='east';east.gold=313;west.location='west';west.gold=313;
const attack=battle(),low=battle();
for(const u of low.battle.units)if(u.id===ids.guard)u.hp=Math.floor(u.max/4)-1;else if(u.id===ids.archer)u.hp=Math.ceil(u.max/4);
const heal=battle(ids.mage);heal.battle.units.find(u=>u.id===ids.guard).hp=60;
const healLeft=battle(ids.mage,'sword-wood','staff-wood');healLeft.battle.units.find(u=>u.id===ids.guard).hp=10;
const porter=battle(ids.porter),victory=battle(ids.mage);
for(const u of victory.battle.units)if(u.side==='enemy')u.hp=u.pos===35?1:0;
const sequence=battle(ids.porter);
const trialTown=fresh();trialTown.location='east';
const trial=C.trial(trialTown,ids.mage,'staff-wood');
const healer=structuredClone(trial.battle.units.find(u=>u.id==='enemy-mage'));
healer.id='enemy-mage-2';healer.max=healer.hp=B.roster.find(u=>u.id==='mage-2').max;
healer.atk=healer.attackWeapons[0].atk;
sequence.battle.units=sequence.battle.units.filter(u=>u.id!=='enemy-archer-2').concat(healer);
sequence.battle.units.filter(u=>u.side==='enemy').forEach((u,i)=>{u.pos=[25,35,15][i];u.next=1000000;});
sequence.battle.units.find(u=>u.id===ids.mage).next=3;
const enemy=sequence.battle.units.find(u=>u.id==='enemy-mage-2');
assert(enemy,'keep current enemy healer identity');enemy.next=2;
const camp=battle();for(const u of camp.battle.units)if(u.side==='enemy')u.hp=0;
camp.battle.result='Victory';assert(C.finishBattle(camp));
const fixtures={town:save(town),attack:save(attack),guard:save(attack),low:save(low),heal:save(heal),
 heal_left:save(healLeft),porter:save(porter),camp:save(camp),
 'synthetic-east':save(east),'synthetic-west':save(west),
 'synthetic-one-hit-victory':save(victory),'porter-enemy-attack':save(sequence)};
if(require.main===module)process.stdout.write(JSON.stringify(fixtures));
module.exports={fixtures,ids,fresh,save};
