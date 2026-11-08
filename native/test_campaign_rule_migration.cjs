'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const C=require('./campaign.js');
const B=require('./campaign-battle.js');

// Rule checks use synthetic combat state, independent of any player save.
{
  const battle=B.create({ally:['porter','guard','archer'],enemy:['porter','guard','archer'],deployment:true});
  battle.deploying=false;
  const guard=battle.units.find(u=>u.id==='guard');
  guard.pos=44;battle.actor=guard.id;
  assert.equal(B.legalFor(battle,guard,'move',45),true,'every combatant may move into the enemy half');
  assert.deepEqual(B.formationSlots(battle,'ally'),[24,13,33],'formation cells follow the allied porter');
  assert.ok(battle.units.filter(u=>u.side==='enemy').every(u=>u.intent===undefined),'enemy actions are not stored as telegraphs');
  const enemy=battle.units.find(u=>u.id==='enemy-archer');
  const currentTarget=battle.units.find(u=>u.id==='guard');
  enemy.pos=14;enemy.mp=0;
  currentTarget.pos=13;
  battle.units.find(u=>u.id==='archer').pos=2;
  assert.equal(B.chooseAction(battle,enemy).target,'porter','enemy chooses the Porter from the current board');
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
assert.equal(C.depart(current,'north'),true);
assert.equal(C.travel(current,'safe',rng),true);
assert.equal(C.begin(current),true);
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
assert.deepEqual(C.view(restoredV2).inventory,C.view(current).inventory);
assert.equal(C.validate(restoredV2).ok,true);
console.log('PASS legacy in-battle save returns to Astaris with inventory preserved and source unchanged');
