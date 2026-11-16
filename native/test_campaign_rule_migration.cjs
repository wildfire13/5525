'use strict';
const assert=require('node:assert/strict');
const C=require('./campaign.js');
const B=require('./campaign-battle.js');

// Rule checks use synthetic combat state, independent of any player save.
{
  const battle=B.create({ally:["recruit-porter-human-female","recruit-porter-human-male","recruit-guard-human-female","recruit-scout-human-male","recruit-mage-elf-female"],enemy:['guard','archer','mage'],deployment:true});
  battle.deploying=false;
  const guard=battle.units.find(u=>u.id==="recruit-guard-human-female");
  guard.pos=44;battle.actor=guard.id;
  assert.equal(B.legalFor(battle,guard,'move',45),true,'every combatant may move into the enemy half');
  assert.deepEqual(B.formationSlots(battle,'ally'),[24,13,33],'formation cells follow the allied porter');
  const secondPorter=battle.units.find(u=>u.id==="recruit-porter-human-male");
  assert.ok(secondPorter);
  secondPorter.pos=24;
  for(const [id,pos] of [['recruit-guard-human-female',13],['recruit-scout-human-male',33]])battle.units.find(u=>u.id===id).pos=pos;
  assert.equal(B.formation(battle,'ally'),false,'a second Porter cannot fill a guard slot');
  secondPorter.pos=14;
  battle.units.find(u=>u.id==="recruit-mage-elf-female").pos=24;
  assert.equal(B.formation(battle,'ally'),true,'three living non-Porters complete the formation');
  assert.ok(battle.units.filter(u=>u.side==='enemy').every(u=>u.intent===undefined),'enemy actions are not stored as telegraphs');
  const enemy=battle.units.find(u=>u.id==='enemy-archer');
  const currentTarget=battle.units.find(u=>u.id==="recruit-guard-human-female");
  enemy.pos=14;enemy.mp=0;
  currentTarget.pos=13;
  battle.units.find(u=>u.id==="recruit-scout-human-male").pos=2;
  assert.equal(B.chooseAction(battle,enemy).target,'recruit-porter-human-female','enemy chooses the Porter from the current board');
}

// A valid live-campaign state where the Porter is both at the far edge and
// downed must resolve as defeat. This is the blocked Windows boundary fixture.
{
  const simultaneous=C.create();
  assert(C.depart(simultaneous,'north'));
  assert(C.travel(simultaneous,'safe',()=>0.25));
  assert(C.begin(simultaneous));
  const porter=simultaneous.battle.units.find(u=>u.side==='ally'&&u.job==='porter');
  porter.pos=49;porter.hp=0;
  assert.equal(C.validate(simultaneous).ok,true,'fixture passes the live campaign save validator');
  assert(C.act(simultaneous,'guard',null),'complete the next action to run the battle outcome check');
  assert.equal(simultaneous.battle.resultKind,'defeat','Porter KO takes priority over far-edge breakthrough');
  assert.equal(simultaneous.battle.failure,'porter');
  assert.equal(C.validate(simultaneous).ok,true,'resolved defeat remains a valid campaign state');
}

console.log('PASS simultaneous KO priority');
