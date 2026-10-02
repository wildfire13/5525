'use strict';

const assert = require('node:assert/strict');
const B = require('../src/battle.js');
const J = require('../src/journey.js');
const unit = (s, id) => s.units.find(u => u.id === id);
const originalJobs = ['guard', 'archer', 'mage', 'scout'];

// Use deployment creation and an explicit ally turn so assertions never depend on
// an AI turn, initiative ties, or a formation accidentally present at startup.
function fixture(actor = 'warrior') {
  const s = B.create({
    ally: ['warrior', 'archer', 'guard', 'mage', 'scout'],
    enemy: originalJobs,
    deployment: true,
  });
  s.deploying = false;
  const positions = {warrior: 24, archer: 0, guard: 1, mage: 2, scout: 3,
    'enemy-guard': 49, 'enemy-archer': 48, 'enemy-mage': 47, 'enemy-scout': 46};
  for (const u of s.units) u.pos = positions[u.id];
  turn(s, actor);
  return s;
}
function turn(s, id) {
  s.actor = id;
  s.units.forEach(u => { u.next = 100; });
  unit(s, id).next = 0;
  s.units.find(u => u.side === 'ally' && u.id !== id).next = 1;
}
function hp(s) { return Object.fromEntries(s.units.map(u => [u.id, u.hp])); }
function rejectWithoutMutation(s, kind, target, message) {
  const before = JSON.stringify(s);
  assert.equal(B.act(s, kind, target), false, message);
  assert.equal(JSON.stringify(s), before, `${message}: rejection must not consume resources or alter state`);
}
function runEnemyIntent(s, id) {
  // A single harmless ally action releases exactly one enemy action, then stops
  // at another ally. The enemy's intent must already be planned by the caller.
  s.units.forEach(u => { u.next = 100; });
  s.actor = 'guard';
  unit(s, 'guard').next = 0;
  unit(s, id).next = 1;
  unit(s, 'mage').next = 2;
  assert.ok(B.act(s, 'guard'));
  assert.equal(s.actor, 'mage');
  assert.equal(s.recentEnemies.length, 1, 'fixture permits exactly one enemy action');
}

// The temporary warrior is one selectable hammer user, while mirror defaults
// and randomly generated opponents retain the four existing combat roles.
const warriors = B.roster.filter(u => u.job === 'warrior');
assert.equal(warriors.length, 1, 'one warrior, with no duplicate warrior-2');
const warrior = warriors[0];
assert.equal(warrior.id, 'warrior');
assert.equal(warrior.weapon, 'hammer');
for (const [key, value] of Object.entries({max: 180, atk: 26, agi: 10, reach: 1, mp: 6})) {
  assert.equal(warrior[key], value, `provisional warrior ${key}`);
}
assert.equal(B.roster.length, 11);
const journey = J.create();
assert.ok(J.accept(journey, 'medicine'));
assert.ok(J.select(journey, ['warrior', 'porter', 'archer', 'mage', 'scout']));
assert.equal(J.select(journey, ['warrior', 'warrior-2', 'porter']), false);
const mirror = B.create({deployment: true});
for (const side of ['ally', 'enemy']) {
  assert.deepEqual(mirror.units.filter(u => u.side === side).map(u => u.job).sort(), [...originalJobs].sort());
}
let seed = 12345;
const random = () => ((seed = (seed * 1664525 + 1013904223) >>> 0) / 4294967296);
for (let i = 0; i < 100; i++) {
  const enemies = J.randomEnemies(4, random);
  assert.equal(enemies.length, 4);
  assert.equal(new Set(enemies).size, 4);
  for (const id of enemies) {
    assert.ok(originalJobs.includes(B.roster.find(u => u.id === id)?.job), `original enemy role: ${id}`);
  }
}

// Stamp is a perpendicular three-cell line, selected by an adjacent position.
for (const [center, cells] of [[25, [15, 25, 35]], [14, [13, 14, 15]],
  [23, [13, 23, 33]], [34, [33, 34, 35]]]) {
  assert.deepEqual(B.stampCells({pos: 24, weapon: 'hammer'}, center), cells, `stamp direction at ${center}`);
}
for (const [pos, center, cells] of [[0, 1, [1, 11]], [0, 10, [10, 11]],
  [9, 8, [8, 18]], [9, 19, [18, 19]], [40, 41, [31, 41]],
  [40, 30, [30, 31]], [49, 48, [38, 48]], [49, 39, [38, 39]]]) {
  assert.deepEqual(B.stampCells({pos, weapon: 'hammer'}, center), cells, `stamp clipped at ${pos}/${center}`);
  for (const p of cells) assert.ok(Number.isInteger(p) && p >= 0 && p < 50);
}
for (const [pos, center] of [[9, 10], [10, 9], [0, -1], [40, 50],
  [24, 24], [24, 26], [24, 15], [24, '25'], [24, 25.5], [24, null],
  [24, undefined], [24, NaN], [24, Infinity]]) {
  assert.deepEqual(B.stampCells({pos, weapon: 'hammer'}, center), [], `invalid stamp center ${pos}/${String(center)}`);
}

// Weapon eligibility is intentionally not job-locked in this prototype.
for (const job of ['warrior', 'guard', 'archer', 'mage', 'scout', 'porter']) {
  const s = fixture(), a = unit(s, 'warrior');
  a.job = job;
  assert.equal(B.activeSkill(a), 'stamp', `hammer equips stamp on ${job}`);
  assert.equal(B.skillName(a), 'スタンプ');
  assert.ok(B.legalFor(s, a, 'skill', 25), `empty adjacent center legal for hammer ${job}`);
  const target = unit(s, 'enemy-guard');
  target.pos = 25;
  const before = target.hp, mp = a.mp;
  assert.ok(B.act(s, 'skill', 25), `hammer ${job} executes stamp instead of its job skill`);
  assert.equal(before - target.hp, a.atk);
  assert.equal(a.mp, mp - 1);
  assert.equal(s.actions, 1);
}
for (const job of ['guard', 'archer', 'mage', 'scout', 'porter', 'warrior']) {
  const s = fixture(), a = unit(s, 'warrior');
  a.job = job;
  delete a.weapon;
  assert.equal(B.activeSkill(a), job, `without hammer preserve ${job}`);
  rejectWithoutMutation(s, 'skill', 25, `${job} without hammer cannot select stamp cells`);
}

// All directions actually damage their selected line and leave outside cells
// untouched; the center is a position rather than a character ID.
for (const center of [25, 14, 23, 34]) {
  const s = fixture(), a = unit(s, 'warrior');
  const cells = B.stampCells(a, center);
  ['enemy-guard', 'enemy-archer', 'enemy-mage'].forEach((id, i) => { unit(s, id).pos = cells[i]; });
  const before = hp(s), mp = a.mp;
  assert.ok(B.legal(s, 'skill', center));
  assert.ok(B.act(s, 'skill', center));
  for (const id of ['enemy-guard', 'enemy-archer', 'enemy-mage']) {
    assert.equal(before[id] - unit(s, id).hp, a.atk, `one normal hit on ${id} facing ${center}`);
  }
  for (const id of ['warrior', 'archer', 'guard', 'mage', 'scout', 'enemy-scout']) {
    assert.equal(unit(s, id).hp, before[id], `outside/friendly ${id} unaffected facing ${center}`);
  }
  assert.equal(a.mp, mp - 1, 'one MP for the whole area');
  assert.equal(s.actions, 1, 'one action for the whole area');
  assert.equal(a.next, 100 / a.agi, 'one initiative cost');
  assert.equal(a.pos, 24, 'stamp does not move its user');
  assert.match(s.log.join('\n'), /スタンプ/);
}
{
  const s = fixture(), a = unit(s, 'warrior');
  unit(s, 'enemy-guard').pos = 15;
  unit(s, 'enemy-archer').pos = 35;
  const before = hp(s);
  assert.ok(!s.units.some(u => u.pos === 25), 'center is empty');
  assert.ok(B.act(s, 'skill', 25));
  assert.equal(before['enemy-guard'] - unit(s, 'enemy-guard').hp, a.atk);
  assert.equal(before['enemy-archer'] - unit(s, 'enemy-archer').hp, a.atk);
}
{
  const s = fixture(), a = unit(s, 'warrior'), before = hp(s), mp = a.mp;
  assert.ok(B.act(s, 'skill', 25), 'an entirely empty area can be fired');
  assert.deepEqual(hp(s), before);
  assert.equal(a.mp, mp - 1);
  assert.equal(s.actions, 1);
  assert.match(s.log.join('\n'), /スタンプ/);
}
{
  const s = fixture(), a = unit(s, 'warrior');
  unit(s, 'enemy-guard').pos = 15;
  unit(s, 'guard').pos = 25;
  unit(s, 'enemy-archer').pos = 35;
  const before = hp(s);
  assert.ok(B.act(s, 'skill', 25), 'friendly-occupied center remains a valid position');
  assert.equal(unit(s, 'guard').hp, before.guard, 'no friendly fire');
  assert.equal(before['enemy-guard'] - unit(s, 'enemy-guard').hp, a.atk);
  assert.equal(before['enemy-archer'] - unit(s, 'enemy-archer').hp, a.atk);
}
{
  const s = fixture();
  unit(s, 'enemy-guard').pos = 25;
  for (const target of [24, 26, 15, -1, 50, '25', 'enemy-guard', null, undefined, NaN, Infinity]) {
    rejectWithoutMutation(s, 'skill', target, `invalid stamp target ${String(target)}`);
  }
  const a = unit(s, 'warrior');
  a.mp = 0;
  rejectWithoutMutation(s, 'skill', 25, 'no MP');
  a.mp = 6;
  a.hp = 0;
  rejectWithoutMutation(s, 'skill', 25, 'fallen attacker');
  a.hp = a.max;
  s.deploying = true;
  rejectWithoutMutation(s, 'skill', 25, 'during deployment');
  s.deploying = false;
  s.result = 'finished';
  rejectWithoutMutation(s, 'skill', 25, 'after battle');
}
{
  const s = fixture(), a = unit(s, 'warrior'), target = unit(s, 'enemy-guard');
  target.pos = 35;
  assert.equal(B.legal(s, 'attack', target.id), false, 'normal hammer attack does not inherit stamp wings');
  assert.ok(B.legal(s, 'skill', 25));
  target.pos = 25;
  const before = target.hp, mp = a.mp;
  assert.ok(B.act(s, 'attack', target.id));
  assert.equal(before - target.hp, a.atk);
  assert.equal(a.mp, mp, 'normal attack costs no MP');
}

// Stamp must reuse the normal damage pipeline for formation, guarding and cover.
const modifierCases = [
  ['plain', () => {}],
  ['allied formation', s => { unit(s, 'archer').pos = 13; unit(s, 'mage').pos = 33; }],
  ['enemy formation', s => { unit(s, 'enemy-archer').pos = 16; unit(s, 'enemy-mage').pos = 36; }],
  ['both formations', s => {
    unit(s, 'archer').pos = 13; unit(s, 'mage').pos = 33;
    unit(s, 'enemy-archer').pos = 16; unit(s, 'enemy-mage').pos = 36;
  }],
  ['defender guard', s => { unit(s, 'enemy-guard').guard = true; }],
  ['cover', s => { unit(s, 'enemy-mage').cover = 'enemy-guard'; }],
  ['guarded cover', s => { unit(s, 'enemy-mage').cover = 'enemy-guard'; unit(s, 'enemy-mage').guard = true; }],
  ['boosted attacker', s => {
    unit(s, 'archer').pos = 13; unit(s, 'mage').pos = 33;
    const porter = unit(s, 'scout'); porter.job = 'porter'; porter.boost = true;
  }],
];
for (const [label, setup] of modifierCases) {
  const attack = fixture();
  unit(attack, 'enemy-guard').pos = 25;
  setup(attack);
  const stamp = JSON.parse(JSON.stringify(attack));
  assert.ok(B.act(attack, 'attack', 'enemy-guard'));
  assert.ok(B.act(stamp, 'skill', 25));
  assert.deepEqual(hp(stamp), hp(attack), `stamp preserves normal damage handling: ${label}`);
}

for (const [label, setup] of modifierCases) {
  const attack = fixture('archer');
  unit(attack, 'archer').pos = 22;
  unit(attack, 'enemy-guard').pos = 25;
  setup(attack);
  const snipe = JSON.parse(JSON.stringify(attack));
  assert.ok(B.act(attack, 'attack', 'enemy-guard'));
  assert.ok(B.act(snipe, 'skill', 'enemy-guard'));
  assert.deepEqual(hp(snipe), hp(attack), `snipe preserves normal damage handling: ${label}`);
}

// Snipe gains exactly one Manhattan tile over the archer's normal reach, with
// no former Strong Shot damage multiplier and no change to normal attacks.
{
  const s = fixture('archer'), a = unit(s, 'archer'), target = unit(s, 'enemy-guard');
  a.pos = 22;
  assert.equal(B.activeSkill(a), 'archer');
  assert.equal(B.skillName(a), 'スナイプ');
  for (const [pos, normal, skill] of [[25, true, true], [26, false, true],
    [27, false, false], [44, false, true], [45, false, false]]) {
    target.pos = pos;
    assert.equal(B.legal(s, 'attack', target.id), normal, `normal reach boundary ${pos}`);
    assert.equal(B.legal(s, 'skill', target.id), skill, `snipe reach boundary ${pos}`);
    assert.equal(B.inRange(a, 'enemy', pos, 'attack', s), normal);
    assert.equal(B.inRange(a, 'enemy', pos, 'skill', s), skill);
  }
  target.pos = 26;
  assert.equal(B.legal(s, 'skill', 'warrior'), false, 'snipe excludes allies');
  a.mp = 0;
  rejectWithoutMutation(s, 'skill', target.id, 'snipe without MP');
  a.mp = 4;
  target.hp = 0;
  rejectWithoutMutation(s, 'skill', target.id, 'snipe cannot hit a fallen target');
  target.hp = target.max;
  a.reach = 5;
  target.pos = 28;
  assert.equal(B.legal(s, 'attack', target.id), false);
  assert.ok(B.legal(s, 'skill', target.id), 'snipe follows actor.reach + 1, not hard-coded range four');
}
{
  const s = fixture('archer'), a = unit(s, 'archer'), target = unit(s, 'enemy-guard');
  a.pos = 22;
  target.pos = 26;
  const before = target.hp, mp = a.mp;
  assert.ok(B.act(s, 'skill', target.id));
  assert.equal(before - target.hp, a.atk, 'snipe deals normal damage, not 1.7x');
  assert.equal(a.mp, mp - 1);
  assert.equal(s.actions, 1);
  assert.equal(a.next, 100 / a.agi);
  assert.equal(a.pos, 22);
  assert.match(s.log.join('\n'), /スナイプ/);
  assert.doesNotMatch(s.log.join('\n'), /強撃/);
}
{
  const s = fixture('archer'), a = unit(s, 'archer'), target = unit(s, 'enemy-guard');
  a.pos = 22;
  target.pos = 25;
  const before = target.hp, mp = a.mp;
  assert.ok(B.act(s, 'attack', target.id));
  assert.equal(before - target.hp, a.atk);
  assert.equal(a.mp, mp);
  assert.match(s.log.join('\n'), /の攻撃/);
  assert.doesNotMatch(s.log.join('\n'), /スナイプ|強撃/);
}

function enemySnipeFixture() {
  const s = fixture();
  unit(s, 'enemy-archer').pos = 25;
  unit(s, 'warrior').pos = 21;
  unit(s, 'warrior').hp = 90;
  unit(s, 'archer').pos = 0;
  unit(s, 'guard').pos = 1;
  unit(s, 'mage').pos = 2;
  unit(s, 'scout').pos = 40;
  B.plan(s, unit(s, 'enemy-archer'));
  return s;
}
{
  const s = enemySnipeFixture(), e = unit(s, 'enemy-archer'), target = unit(s, 'warrior');
  assert.equal(B.range(e, target), e.reach + 1);
  assert.equal(B.legalFor(s, e, 'attack', target.id), false);
  assert.ok(B.legalFor(s, e, 'skill', target.id));
  assert.equal(e.intent.kind, 'skill');
  assert.equal(e.intent.name, 'スナイプ');
  assert.deepEqual(e.intent.cells, [21]);
  const before = target.hp, mp = e.mp;
  runEnemyIntent(s, e.id);
  assert.equal(before - target.hp, e.atk, 'enemy snipe hits at its expanded range for normal damage');
  assert.equal(e.mp, mp - 1);
  assert.equal(s.recentEnemies[0].action, 'スナイプ');
  assert.doesNotMatch(s.log.join('\n'), /強撃/);
}
{
  const s = enemySnipeFixture(), e = unit(s, 'enemy-archer');
  const intent = JSON.stringify(e.intent);
  unit(s, 'warrior').pos = 22;
  unit(s, 'scout').pos = 24;
  const before = hp(s), mp = e.mp;
  assert.equal(JSON.stringify(e.intent), intent, 'moving a target does not mutate the telegraph');
  runEnemyIntent(s, e.id);
  assert.deepEqual(hp(s), before, 'empty fixed cell does not retarget the moved or nearest ally');
  assert.equal(e.mp, mp, 'preserve existing fixed-cell ranged miss behavior: no MP spent on an empty cell');
  assert.match(s.log.join('\n'), /スナイプ.*空振り/);
}
{
  const s = enemySnipeFixture(), e = unit(s, 'enemy-archer');
  unit(s, 'warrior').pos = 22;
  unit(s, 'scout').pos = 21;
  const before = hp(s), mp = e.mp;
  runEnemyIntent(s, e.id);
  assert.equal(unit(s, 'warrior').hp, before.warrior, 'does not track the original target');
  assert.equal(before.scout - unit(s, 'scout').hp, e.atk, 'hits a replacement enemy occupying the fixed cell');
  assert.equal(e.mp, mp - 1);
}
{
  const s = enemySnipeFixture(), e = unit(s, 'enemy-archer');
  unit(s, 'warrior').pos = 20;
  B.plan(s, e);
  assert.notEqual(e.intent.kind, 'skill', 'enemy cannot snipe beyond reach + 1');
  const noMp = enemySnipeFixture(), archer = unit(noMp, 'enemy-archer');
  archer.mp = 0;
  B.plan(noMp, archer);
  assert.notEqual(archer.intent.kind, 'skill', 'enemy cannot plan snipe without MP');
}

// Explicit enemy hammer fixture, without changing the production enemy pool.
for (const moved of [false, true]) {
  const s = fixture(), e = unit(s, 'enemy-guard');
  e.weapon = 'hammer'; e.pos = 25;
  unit(s, 'warrior').pos = 24; unit(s, 'archer').pos = 14;
  unit(s, 'mage').pos = 34; unit(s, 'guard').pos = 0;
  B.plan(s, e);
  assert.equal(e.intent.name, 'スタンプ');
  assert.equal(e.intent.target, 24);
  assert.deepEqual(e.intent.cells, [14, 24, 34]);
  if (moved) { unit(s, 'warrior').pos = 23; unit(s, 'scout').pos = 24; }
  const before = hp(s), mp = e.mp;
  runEnemyIntent(s, e.id);
  for (const id of ['archer', 'mage', moved ? 'scout' : 'warrior']) {
    assert.equal(before[id] - unit(s, id).hp, e.atk, 'enemy Stamp resolves fixed area with normal damage');
  }
  assert.equal(unit(s, moved ? 'warrior' : 'scout').hp, before[moved ? 'warrior' : 'scout']);
  assert.equal(e.mp, mp - 1);
  assert.equal(s.recentEnemies[0].action, 'スタンプ');
}

console.log('Stamp/Snipe passed: warrior roster/selectability/default pools; four directions and edges; empty and friendly cells; invalid/resource rejection; hammer eligibility; normal damage/formation/guard/cover; exact Snipe reach, MP, logs and fixed enemy intents.');
