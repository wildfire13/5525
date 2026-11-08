'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const C=require('./campaign.js');
const B=require('./campaign-battle.js');

// Rule checks use synthetic combat state, independent of any player save.
{
  const battle=B.create({ally:['porter','porter-2','guard','archer','mage'],enemy:['guard','archer','mage'],deployment:true});
  battle.deploying=false;
  const guard=battle.units.find(u=>u.id==='guard');
  guard.pos=44;battle.actor=guard.id;
  assert.equal(B.legalFor(battle,guard,'move',45),true,'every combatant may move into the enemy half');
  assert.deepEqual(B.formationSlots(battle,'ally'),[24,13,33],'formation cells follow the allied porter');
  const secondPorter=battle.units.find(u=>u.id==='porter-2');
  assert.ok(secondPorter);
  secondPorter.pos=24;
  for(const [id,pos] of [['guard',13],['archer',33]])battle.units.find(u=>u.id===id).pos=pos;
  assert.equal(B.formation(battle,'ally'),false,'a second Porter cannot fill a guard slot');
  secondPorter.pos=14;
  battle.units.find(u=>u.id==='mage').pos=24;
  assert.equal(B.formation(battle,'ally'),true,'three living non-Porters complete the formation');
  assert.ok(battle.units.filter(u=>u.side==='enemy').every(u=>u.intent===undefined),'enemy actions are not stored as telegraphs');
  const enemy=battle.units.find(u=>u.id==='enemy-archer');
  const currentTarget=battle.units.find(u=>u.id==='guard');
  enemy.pos=14;enemy.mp=0;
  currentTarget.pos=13;
  battle.units.find(u=>u.id==='archer').pos=2;
  assert.equal(B.chooseAction(battle,enemy).target,'porter','enemy chooses the Porter from the current board');
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
  const fallen=simultaneous.battle.units.filter(u=>u.side==='ally'&&u.startedAlive&&u.hp<=0);
  const survivors=simultaneous.battle.partyAliveInitial-fallen.length;
  const share=survivors>0?(simultaneous.battle.initialDownWeight+fallen.reduce((n,u)=>n+(u.carriedWeight||0),0))/survivors:0;
  for(const u of simultaneous.battle.units.filter(u=>u.side==='ally')){
    u.fallenWeightShare=u.hp>0?share:0;
    u.overburdened=u.hp>0&&survivors>0&&u.carriedWeight+share>u.weightLimit;
    u.agi=u.baseAgi*(u.overburdened?0.5:1);
  }
  assert.equal(C.validate(simultaneous).ok,true,'fixture passes the live campaign save validator');
  assert(C.act(simultaneous,'guard',null),'complete the next action to run the battle outcome check');
  assert.equal(simultaneous.battle.resultKind,'defeat','Porter KO takes priority over far-edge breakthrough');
  assert.equal(simultaneous.battle.failure,'porter');
  assert.equal(C.validate(simultaneous).ok,true,'resolved defeat remains a valid campaign state');
}

// Synthetic, checked-in v1 test fixture only. Never reads or writes a player save.
const source=JSON.parse(fs.readFileSync(require.resolve('./test_fixtures/campaign-a51a773-battle.json'),'utf8'));
const before=JSON.stringify(source);
const expectedInventory={...source.state.inventory};
const restored=C.deserialize(source);

assert.equal(JSON.stringify(source),before,'migration does not mutate source save data');
assert.equal(restored.location,'astaris');
assert.equal(restored.phase,'town');
assert.equal(restored.version,C.VERSION);
assert.equal(restored.battle,null);
assert.equal(restored.journey,null);
assert.equal(restored.result,null);
assert.equal(restored.activeQuest,null);
assert.equal(restored.rollback,null);
assert.deepEqual(C.view(restored).inventory,expectedInventory,'personal inventories remain conserved');
assert.equal(C.validate(restored).ok,true);
assert.doesNotThrow(()=>C.serialize(restored));

// Build a v2 battle envelope from fresh synthetic data to cover both supported legacy versions.
let seed=7;
const rng=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/4294967296);
const current=C.create();
const quest=C.view(current).board[0];
const carrier=current.selected.find(id=>id.includes('porter'));
current.characters[carrier].inventory.potion=1;
assert.equal(C.accept(current,quest.id,carrier),true,'build an active-quest legacy fixture');
const questCargo=current.activeQuest.cargoItemId;
assert.equal(C.depart(current,quest.to),true);
assert.equal(C.travel(current,'safe',rng),true);
assert.equal(C.begin(current),true);
const spent=current.battle.units.find(u=>u.side==='ally');
assert.ok(spent,'active-quest fixture has a battle participant');
spent.hp-=1;
spent.mp=Math.max(0,spent.mp-1);
assert.equal(current.battle.itemInventories[carrier].potion,1);
current.battle.itemInventories[carrier].potion=0;
current.battle.potions.ally--;
assert.equal(C.validate(current).ok,true,'current in-progress quest/battle is a valid fixture');
const originalQuest=structuredClone(current.activeQuest),originalRollback=structuredClone(current.rollback);
const legacyV2=JSON.parse(C.serialize(current));
legacyV2.version=2;
legacyV2.state.version=2;
legacyV2.state.rollback.version=2;
legacyV2.state.battle.formationVersion=2;
delete legacyV2.state.battle.formationBasis;
for(const unit of legacyV2.state.battle.units){
  delete unit.canDeployEnemySide;
  if(unit.side==='ally')unit.canInvade=unit.job!=='porter'&&C.stats(current.characters[unit.id]).effects.includes('invasion');
}
for(const unit of legacyV2.state.battle.units.filter(u=>u.side==='enemy'&&u.hp>0))
  unit.intent={kind:'guard',target:null,cells:[],name:'防御',reason:'旧戦闘セーブの移行検証'};
const v2before=JSON.stringify(legacyV2),restoredV2=C.deserialize(legacyV2);
assert.equal(JSON.stringify(legacyV2),v2before,'v2 migration does not mutate its input');
assert.equal(restoredV2.location,'astaris');
assert.equal(restoredV2.phase,'town');
assert.equal(restoredV2.version,C.VERSION);
assert.equal(restoredV2.battle,null);
assert.deepEqual(restoredV2.activeQuest,originalQuest,'accepted quest remains active after old-battle recovery');
assert.equal(restoredV2.characters[carrier].inventory[questCargo],1,'the accepted cargo remains with its Porter');
assert.equal(restoredV2.rollback.activeQuest,null,'pre-quest rollback remains available');
assert.equal(restoredV2.rollback.location,originalRollback.location);
assert.equal(restoredV2.characters[spent.id].hp,spent.hp,'battle HP state is preserved without awarding a result');
assert.equal(restoredV2.characters[spent.id].mp,spent.mp,'battle MP state is preserved without awarding a result');
assert.equal(restoredV2.characters[carrier].inventory.potion,undefined,'an already spent battle potion stays spent');
const questExpectedInventory={...C.view(current).inventory,potion:C.view(current).inventory.potion-1};
assert.deepEqual(C.view(restoredV2).inventory,questExpectedInventory,'personal inventories remain conserved apart from recorded combat use');
assert.equal(restoredV2.gold,current.gold,'discarding battle does not grant loot');
assert.equal(restoredV2.characters[carrier].xp,current.characters[carrier].xp,'discarding battle does not grant experience');
assert.equal(restoredV2.result,null,'recovery does not manufacture a battle result');
assert.equal(C.validate(restoredV2).ok,true);
assert.equal(JSON.stringify(legacyV2),v2before,'active-quest legacy source remains unchanged');
console.log('PASS legacy in-battle save returns to Astaris, retaining the active quest and cargo and reconciling spent resources without rewards');

// Checked-in synthetic saves are the same boundary fixtures used by Windows QA.
const priorityFixture=JSON.parse(fs.readFileSync(require.resolve('./test_fixtures/porter-breakthrough-ko-priority.json'),'utf8'));
const priorityBefore=JSON.stringify(priorityFixture),priorityState=C.deserialize(priorityFixture);
assert.equal(JSON.stringify(priorityFixture),priorityBefore,'priority fixture is not mutated during load');
assert.equal(C.validate(priorityState).ok,true,'priority fixture is a valid current campaign save');
assert.equal(priorityState.battle.units.find(u=>u.side==='ally'&&u.job==='porter').pos%10,9);
assert(C.act(priorityState,'guard',null));
assert.equal(priorityState.battle.resultKind,'defeat');
assert.equal(C.validate(priorityState).ok,true);
const questFixture=JSON.parse(fs.readFileSync(require.resolve('./test_fixtures/legacy-v2-active-quest-battle.json'),'utf8'));
const fixtureQuest=questFixture.state.activeQuest,fixtureCarrier=fixtureQuest.cargoOwnerId;
const fixtureCargo=fixtureQuest.cargoItemId,fixtureBefore=JSON.stringify(questFixture);
const recoveredFixture=C.deserialize(questFixture);
assert.equal(JSON.stringify(questFixture),fixtureBefore,'legacy quest fixture is not mutated during migration');
assert.equal(recoveredFixture.location,'astaris');assert.equal(recoveredFixture.phase,'town');
assert.equal(recoveredFixture.activeQuest.id,fixtureQuest.id);
assert.equal(recoveredFixture.characters[fixtureCarrier].inventory[fixtureCargo],1);
assert.equal(C.validate(recoveredFixture).ok,true);
console.log('PASS checked-in Windows fixtures: simultaneous KO priority and active-quest legacy migration');
