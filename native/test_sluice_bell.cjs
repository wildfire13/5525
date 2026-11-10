'use strict';
const assert = require('node:assert/strict');
const C = require('./campaign.js');
const B = require('./campaign-battle.js');

function acceptContract() {
  const s = C.create();
  const party = s.selected.filter(id => id !== 'recruit-scout-elf-male');
  const porter = party.find(id => B.roster.find(u => u.id === id).job === 'porter');
  assert(C.select(s, party));
  assert(C.accept(s, 'sluice-bell', porter));
  assert(C.depart(s, 'east'));
  return s;
}

function roundtrip(s) {
  assert.deepEqual(C.deserialize(C.serialize(s)), JSON.parse(JSON.stringify(s)));
}

function escortAction(battle) {
  const actor = battle.units.find(u => u.id === battle.actor);
  const gate = battle.sluice;
  if (actor.job !== 'porter' && !gate.open && B.legal(battle, 'move', gate.lever)) {
    return {kind:'move', target:gate.lever};
  }
  const fallback = B.chooseAction(battle, actor);
  if (actor.job === 'porter') {
    const path = B.paths(battle, actor).get(gate.exit) || [];
    const next = path.filter(p => p !== gate.lever && (gate.open || p !== gate.exit) && B.legal(battle, 'move', p)).at(-1);
    if (next !== undefined) return {kind:'move', target:next};
  } else if (fallback.kind === 'move') {
    return {kind:'guard', target:null};
  }
  return fallback;
}

for (const firstRoute of ['short', 'safe']) {
  const s = acceptContract();
  for (let stage = 0; stage < 2; stage++) {
    const route = stage === 0 ? firstRoute : 'safe';
    assert(C.travel(s, route));
    const b = s.battle;
    assert.equal(b.sluice.open, false);
    const expectedExit = stage === 1 && firstRoute === 'safe' ? 45 : route === 'safe' ? 37 : 17;
    assert.equal(b.sluice.exit, expectedExit);
    roundtrip(s);
    assert(C.begin(s));
    for (let i = 0; !b.result && i < 100; i++) {
      const action = escortAction(b);
      const wasOpen = b.sluice.open;
      assert(C.act(s, action.kind, action.target));
      if (!wasOpen && b.sluice.open) roundtrip(s);
    }
    assert.equal(b.resultKind, 'breakthrough');
    assert(b.units.some(u => u.side === 'enemy' && u.hp > 0));
    assert(b.units.some(u => u.job === 'porter' && u.pos === b.sluice.exit));
    roundtrip(s);
    assert(C.finishBattle(s));
    if (stage === 0) {
      assert(C.rest(s));
      assert(C.onward(s));
    }
  }
  assert(C.arrive(s));
  for(const [hours,outcome,gold,rp,line] of [[8,'success',260,100,'石段'],[9,'late',169,60,'櫂']]){
    const delivery=C.deserialize(C.serialize(s));
    delivery.activeQuest.elapsedHours=hours;
    // Saves from before the narrative update still produce the new ending.
    delete delivery.activeQuest.story;
    assert(C.completeQuest(delivery));
    assert.deepEqual([delivery.result.outcome,delivery.result.gold,delivery.result.rp],[outcome,gold,rp]);
    assert.equal(delivery.result.storyId,'sluice-bell');
    assert(delivery.result.story[0][1].includes(line));
    roundtrip(delivery);
  }
  assert(C.completeQuest(s));
  roundtrip(s);
}

// Freeze enemy turns to isolate the consequences of two successive guard moves.
const s = acceptContract();
assert(C.travel(s, 'short'));
assert(C.begin(s));
const b = s.battle;
const guard = b.units.find(u => u.side === 'ally' && u.pos === 13);
const archer = b.units.find(u => u.id === 'enemy-archer');
assert(B.formation(b));
assert.equal(B.chooseAction(b, archer).kind, 'guard');
for (const unit of b.units) unit.next = unit === guard ? 0 : 10000;
b.actor = guard.id;
assert(B.act(b, 'move', b.sluice.lever));
assert.equal(b.sluice.open, true);
assert.equal(B.formation(b), false);
assert.equal(B.chooseAction(b, archer).target, guard.id);
assert(B.act(b, 'move', 13));
assert.equal(b.sluice.open, false);
assert(B.formation(b));
b.sluice.open = true;
assert.equal(C.validate(s).ok, false);

const solo = acceptContract();
assert(C.travel(solo, 'short'));
const porter = solo.battle.units.find(u => u.side === 'ally' && u.job === 'porter');
assert(C.deploy(solo, porter.id, 14));
assert(C.begin(solo));
assert.equal(solo.battle.sluice.open, false, 'deployment does not operate the winch');
for (const unit of solo.battle.units) unit.next = unit === porter ? 0 : 10000;
solo.battle.actor = porter.id;
assert(B.act(solo.battle, 'move', 4));
assert(B.act(solo.battle, 'move', 14));
assert.equal(solo.battle.sluice.open, false, 'the porter cannot work the winch');

const river = acceptContract();
assert(C.travel(river, 'safe'));
const keeper = river.battle.units.find(u => u.id === 'enemy-guard');
const advance = B.chooseAction(river.battle, keeper);
assert.equal(advance.kind, 'move');
assert.equal(advance.target, river.battle.sluice.lever);

// Recreate the blocked two-step exit from the continuous playtest.
// The porter can decline the immediate move without getting a second signal.
const relay = acceptContract();
assert(C.travel(relay, 'short'));
assert(C.begin(relay));
const fight = relay.battle;
const runner = fight.units.find(u => u.side === 'ally' && u.job === 'porter');
const operator = fight.units.find(u => u.side === 'ally' && u.job === 'mage');
const obstruction = fight.units.find(u => u.id === 'enemy-archer');
runner.pos = 15;
operator.pos = fight.sluice.lever;
obstruction.pos = 16;
obstruction.hp = 1;
fight.sluice.open = true;
fight.actor = operator.id;
for (const unit of fight.units) unit.next = unit === operator ? 1 : unit === runner ? 120 : 100;
assert(!B.legalFor(fight, runner, 'move', fight.sluice.exit));
const alreadyUsed = C.deserialize(C.serialize(relay));
alreadyUsed.battle.sluice.relayUsed = true;
assert(C.act(alreadyUsed, 'attack', obstruction.id));
assert.notEqual(alreadyUsed.battle.actor, runner.id, 'no second signal when another blocker falls');
assert(C.act(relay, 'attack', obstruction.id));
assert.equal(fight.actor, runner.id);
assert.equal(fight.sluice.relayUsed, true);
assert(B.legal(fight, 'move', fight.sluice.exit));
roundtrip(relay);
assert(C.act(relay, 'guard', null));
assert.equal(fight.sluice.relayUsed, true);
assert(!fight.result);

for(const loss of ['retreat','porter','defeat']){
  const lost=acceptContract();
  assert(C.travel(lost,'short'));
  assert(C.begin(lost));
  if(loss==='retreat')assert(C.retreat(lost));
  else{
    const allies=lost.battle.units.filter(u=>u.side==='ally');
    for(const ally of allies)if(loss==='defeat'||ally.job==='porter')ally.hp=0;
    lost.battle.resultKind='defeat';lost.battle.result='敗北';lost.battle.failure='porter';
    assert(C.finishBattle(lost));
  }
  assert.equal(lost.result.outcome,'failed');
  assert.equal(lost.result.gold,0);
  assert.equal(lost.result.restored,true);
  assert.equal(lost.result.storyId,'sluice-bell');
  assert(lost.result.story[0][1].includes({retreat:'切り返した',porter:'膝',defeat:'最後の護衛'}[loss]));
  roundtrip(lost);
  assert(C.acknowledge(lost));
  assert(C.board(lost).some(q=>q.id==='sluice-bell'));
}
console.log('Sluice Bell: delivery, enemy tactics, gate saves and once-per-battle relay verified.');
