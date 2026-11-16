'use strict';
const assert=require('node:assert/strict');
const C=require('./campaign.js');
const B=require('./campaign-battle.js');

// Rule checks use synthetic combat state, independent of any player save.
{
  const battle=B.create({ally:["character_yuno","character_teo","character_mirei","character_kyle","character_merina"],enemy:['guard','archer','mage'],deployment:true});
  battle.deploying=false;
  const guard=battle.units.find(u=>u.id==="character_mirei");
  guard.pos=44;battle.actor=guard.id;
  assert.equal(B.legalFor(battle,guard,'action_move',45),true,'every combatant may move into the enemy half');
  assert.deepEqual(B.formationSlots(battle,'ally'),[24,13,33],'formation cells follow the allied porter');
  const secondPorter=battle.units.find(u=>u.id==="character_teo");
  assert.ok(secondPorter);
  secondPorter.pos=24;
  for(const [id,pos] of [['character_mirei',13],['character_kyle',33]])battle.units.find(u=>u.id===id).pos=pos;
  assert.equal(B.formation(battle,'ally'),false,'a second Porter cannot fill a guard slot');
  secondPorter.pos=14;
  battle.units.find(u=>u.id==="character_merina").pos=24;
  assert.equal(B.formation(battle,'ally'),true,'three living non-Porters complete the formation');
  assert.ok(battle.units.filter(u=>u.side==='enemy').every(u=>u.intent===undefined),'enemy actions are not stored as telegraphs');
  const enemy=battle.units.find(u=>u.id==='enemy-archer');
  const currentTarget=battle.units.find(u=>u.id==="character_mirei");
  enemy.pos=14;enemy.mp=0;
  currentTarget.pos=13;
  battle.units.find(u=>u.id==="character_kyle").pos=2;
  assert.equal(B.chooseAction(battle,enemy).target,'character_yuno','enemy chooses the Porter from the current board');
}

// A valid live-campaign state where the Porter is both at the far edge and
// downed must resolve as defeat. This is the blocked Windows boundary fixture.
{
  const simultaneous=C.create();
  assert(C.depart(simultaneous,'north'));
  assert(C.travel(simultaneous,'safe',()=>0.25));
  assert(C.begin(simultaneous));
  const porter=simultaneous.battle.units.find(u=>u.side==='ally'&&u.job==='job_porter');
  porter.pos=49;porter.hp=0;
  assert.equal(C.validate(simultaneous).ok,true,'fixture passes the live campaign save validator');
  assert(C.act(simultaneous,'action_defend',null),'complete the next action to run the battle outcome check');
  assert.equal(simultaneous.battle.resultKind,'defeat','Porter KO takes priority over far-edge breakthrough');
  assert.equal(simultaneous.battle.failure,'porter');
  assert.equal(C.validate(simultaneous).ok,true,'resolved defeat remains a valid campaign state');
}

console.log('PASS simultaneous KO priority');
