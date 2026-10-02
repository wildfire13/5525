'use strict';
const assert = require('node:assert/strict');
const {createHarness, Event} = require('./helpers/dom-harness.cjs');
const playMirror = require('./playtest-mirror.cjs');
const snapshot = harness => harness.run('JSON.stringify(state)');
const unit = (harness, id) => harness.run(`state.units.find(u=>u.id===${JSON.stringify(id)})`);
const json = value => JSON.stringify(value);

function prepare(harness, job = 'parts') {
  harness.click(`[data-job=${job}]`);
  assert.equal(harness.run('journey.phase'), 'prepare');
  assert.equal(harness.document.querySelectorAll('[data-member]').length, 11);
}
function start(harness) {
  harness.click('#depart');
  assert.equal(harness.run('journey.phase'), 'road');
  harness.click('[data-route=short]');
  assert.equal(harness.run('journey.phase'), 'deployment');
  harness.click('#begin-battle');
  assert.equal(harness.run('journey.phase'), 'battle');
}
function drag(harness, id, pos) {
  const image = harness.document.querySelector(`[data-drag-unit=${id}]`);
  const target = harness.document.querySelector(`[data-deploy-pos="${pos}"]`);
  const dataTransfer = {setData() {}, effectAllowed: '', dropEffect: ''};
  assert.ok(image && target);
  image.dispatchEvent(new Event('dragstart', {dataTransfer}));
  target.dispatchEvent(new Event('dragover', {dataTransfer}));
  target.dispatchEvent(new Event('drop', {dataTransfer}));
  image.dispatchEvent(new Event('dragend', {dataTransfer}));
}
function playThroughUI(harness) {
  const state = harness.run('state'), Battle = harness.run('Battle');
  const commands = ['attack', 'guard', 'move', 'skill', 'item'];
  return playMirror(Battle, 'front-focus', state, (kind, target) => {
    const actions = state.actions;
    const button = harness.document.querySelectorAll('#commands button')[commands.indexOf(kind)];
    assert.ok(button && !button.disabled && !button.hidden, `command must be usable: ${kind}`);
    button.click();
    if (kind !== 'guard') {
      const pos = kind === 'move' ? target : state.units.find(unit => unit.id === target).pos;
      harness.click(`[data-pos="${pos}"]`);
      if (harness.run('previewPos !== null')) harness.click('#confirmMove');
    }
    assert.equal(state.actions, actions + 1, `UI ${kind} must commit exactly one action`);
  });
}
async function exportLog(harness) {
  const before = harness.document.downloads.length;
  harness.click('#export-play-log');
  assert.equal(harness.document.downloads.length, before + 1);
  const download = harness.document.downloads.at(-1);
  assert.match(download.filename, /^5525-(journey|battle)-.*\.json$/);
  assert.ok(download.blob instanceof Blob);
  assert.equal(download.blob.type, 'application/json;charset=utf-8');
  const parsed = JSON.parse(await download.blob.text());
  assert.equal(parsed.schemaVersion, 1);
  assert.equal(parsed.events.at(-1).type, 'log.export.requested');
  assert.equal(download.element.parentElement, null, 'temporary anchor is removed');
  harness.flushTimers();
  assert.equal(harness.document.objectURLs.size, 0, 'temporary object URL is released');
  return parsed;
}

async function testDeploymentAndDeadlines() {
  const h = createHarness();
  assert.equal(h.run('journey.phase'), 'jobs');
  assert.equal(h.run('state'), null);
  prepare(h, 'medicine');
  h.click('[data-member=porter]');
  assert.equal(h.document.querySelector('#depart').disabled, true);
  h.click('[data-member=porter]');
  assert.equal(h.document.querySelector('#depart').disabled, false);
  assert.equal(h.document.querySelector('[data-member=porter-2]').disabled, true, 'five-person maximum is enforced by UI');
  h.click('#depart');
  const before = h.run('JSON.stringify(journey)');
  h.click('[data-route=safe]');
  assert.equal(h.document.querySelector('#deadline-dialog').open, true);
  assert.match(h.document.querySelector('#deadline-description').textContent, /8時間/);
  h.click('[data-route=safe]'); // A repeated choice must not queue a second action.
  h.click('#deadline-back');
  assert.equal(h.run('JSON.stringify(journey)'), before);
  h.click('[data-route=safe]'); h.cancelDialog();
  assert.equal(h.run('JSON.stringify(journey)'), before);
  assert.equal(h.run('deadlineAction'), null);
  h.click('[data-route=safe]'); h.click('#deadline-proceed');
  assert.equal(h.run('journey.hours'), 4);
  assert.equal(h.run('journey.phase'), 'deployment');
  const initial = snapshot(h), enemyPositions = h.snapshot('state.units.filter(u=>u.side==="enemy").map(({id,pos})=>({id,pos}))');
  h.click('[data-deploy-unit=scout]'); h.click('[data-deploy-pos="0"]'); h.click('[data-deploy-pos="22"]');
  assert.equal(unit(h, 'scout').pos, 22); assert.equal(unit(h, 'porter').pos, 0);
  assert.equal(h.run('journey.hours'), 4); assert.equal(h.run('state.actions'), 0);
  assert.deepEqual(h.snapshot('state.units.filter(u=>u.side==="enemy").map(({id,pos})=>({id,pos}))'), enemyPositions);
  assert.ok(h.document.querySelectorAll('[data-deploy-pos]').filter(button => Number(button.dataset.deployPos) % 10 >= 5).every(button => button.disabled));
  h.click('#reset-deployment'); assert.equal(snapshot(h), initial, 'reset restores deployment without rerolling or changing resources');
  drag(h, 'scout', 0); drag(h, 'scout', 22);
  assert.equal(unit(h, 'scout').pos, 22); assert.equal(unit(h, 'porter').pos, 0);
  const moved = snapshot(h); drag(h, 'scout', 25); assert.equal(snapshot(h), moved, 'enemy-board drop is ignored');
  assert.equal(h.run('deploymentDragging'), null);
  h.click('#reset-deployment'); assert.equal(snapshot(h), initial);
  h.click('#begin-battle');
  assert.equal(h.run('state.deploying'), false);
  assert.ok(h.document.body.classList.contains('in-battle'));
  // A focused fixture isolates the porter preview; the normal progression test
  // below never rewrites actor, HP, MP, positions, or enemy combat parameters.
  h.run("state.actor='porter';state.units.forEach(u=>u.next=100);state.units.find(u=>u.id==='porter').next=0;state.units.find(u=>u.id==='mage').next=1;mode='move';render()");
  assert.equal(h.document.querySelectorAll('#commands button')[0].hidden, true);
  const swapBefore = snapshot(h);
  h.click('[data-pos="24"]');
  assert.match(h.document.querySelector('#previewText').textContent, /位置を交換/);
  assert.equal(snapshot(h), swapBefore, 'preview consumes nothing');
  h.click('#cancelMove'); assert.equal(snapshot(h), swapBefore);
  h.click('[data-pos="24"]'); h.click('#confirmMove');
  assert.equal(unit(h, 'porter').pos, 24); assert.equal(unit(h, 'guard').pos, 22);
  assert.equal(h.run('state.actions'), 1);
  assert.equal(h.run('previewPos'), null);
  const log = await exportLog(h);
  for (const type of ['deadline.cancelled', 'deadline.confirmed', 'deployment.placed', 'deployment.reset', 'battle.started', 'battle.preview', 'battle.action']) {
    assert.ok(log.events.some(event => event.type === type), `missing diagnostic event ${type}`);
  }
  assert.equal(log.current.battle.actions, 1);
}

async function testRealDelivery(job, rest) {
  const h = createHarness();
  const initial = await exportLog(h);
  assert.equal(initial.current.journey.phase, 'jobs');
  assert.equal(initial.current.battle, null);
  prepare(h, job);
  h.run("Journey.randomEnemies=count=>['scout','mage','archer','guard'].slice(0,count)");
  h.click('#depart');
  const actions = [];
  for (let leg = 0; leg < 2; leg++) {
    h.click('[data-route=short]');
    if (h.document.querySelector('#deadline-dialog').open) h.click('#deadline-proceed');
    assert.equal(h.run('journey.phase'), 'deployment');
    if (leg) assert.deepEqual(h.snapshot('state.units.filter(u=>u.side==="ally").map(({id,hp,mp})=>({id,hp,mp}))'), h.snapshot('journey.party.map(({id,hp,mp})=>({id,hp,mp}))'));
    h.click('#begin-battle');
    const result = playThroughUI(h);
    assert.match(result.result, /^勝利/);
    actions.push(result.actions);
    assert.equal(h.document.querySelector('#battle-return').hidden, false);
    h.click('#battle-return');
    const returned = h.run('JSON.stringify(journey)');
    h.document.querySelector('#battle-return').click();
    assert.equal(h.run('JSON.stringify(journey)'), returned, 'repeated battle-return cannot charge time twice');
    if (leg === 0) {
      assert.equal(h.run('journey.phase'), 'camp');
      if (rest) {
        h.click('#rest');
        if (job === 'medicine') {
          const before = h.run('JSON.stringify(journey)');
          assert.equal(h.document.querySelector('#deadline-dialog').open, true);
          h.click('#deadline-back'); assert.equal(h.run('JSON.stringify(journey)'), before);
          h.click('#rest'); h.click('#deadline-proceed');
        }
        assert.equal(h.run('journey.hours'), 5);
        assert.equal(h.document.querySelector('#rest').disabled, true);
      }
      h.click('#onward');
    }
  }
  assert.equal(h.run('journey.phase'), 'delivery');
  const deliverButton = h.document.querySelector('#deliver');
  deliverButton.click();
  const delivered = h.run('JSON.stringify(journey)');
  deliverButton.click();
  assert.equal(h.run('JSON.stringify(journey)'), delivered, 'repeated delivery callback cannot award twice');
  assert.ok(h.document.querySelector('.completion-scene'));
  assert.equal(h.document.querySelector('#new-trip'), null);
  h.click('#show-rewards');
  assert.equal(h.document.querySelector('.completion-scene'), null);
  assert.ok(h.document.querySelector('#new-trip'));
  const late = job === 'medicine' && rest;
  assert.equal(h.run('journey.outcome'), late ? 'late' : 'success');
  assert.equal(h.run('journey.gold'), late ? 117 : job === 'medicine' ? 180 : 150);
  assert.equal(h.run('journey.level'), late ? 1 : 2);
  const completed = await exportLog(h);
  assert.equal(completed.current.journey.outcome, late ? 'late' : 'success');
  assert.equal(completed.events.filter(event => event.type === 'battle.action').length, actions.reduce((sum, value) => sum + value, 0));
  assert.equal(completed.events.filter(event => event.type === 'battle.finished').length, 2);
  assert.ok(completed.events.some(event => event.type === 'journey.deliver'));
  h.click('#new-trip');
  assert.deepEqual(h.snapshot('journey'), h.snapshot('Journey.create()'));
  assert.equal(h.run('state'), null);
  assert.equal(h.run('previewPos'), null); assert.equal(h.run('rushTarget'), null);
  assert.equal(h.run('previewKind'), 'attack'); assert.equal(h.run('mode'), 'attack');
  assert.equal(h.run('deploymentDragging'), null); assert.equal(h.run('deadlineChoice'), null);
  assert.equal(h.run('deploymentSelected'), null); assert.deepEqual(h.snapshot('deploymentInitial'), []);
  assert.equal(h.run('deadlineAction'), null);
  assert.equal(h.document.querySelector('#battle-return').hidden, true);
  assert.equal(h.document.querySelector('#battle-trip').hidden, true);
  assert.equal(h.document.body.classList.contains('in-battle'), false);
  const restarted = await exportLog(h);
  assert.equal(restarted.run, completed.run + 1);
  assert.equal(restarted.current.battle, null);
  assert.equal(restarted.current.journey.gold, 0);
  assert.ok(restarted.events.some(event => event.run === completed.run && event.type === 'journey.deliver'), 'restart preserves bounded previous diagnostics');
  prepare(h); start(h);
  assert.equal(h.run('state.actions'), 0, 'new trip starts a fresh battle');
  assert.equal(h.run('state.units.filter(u=>u.side==="ally").every(u=>u.hp===u.max)'), true);
  return {job, rest, actions};
}

function testPorterDefeat() {
  for (const porter of ['porter', 'porter-2']) {
    const h = createHarness(); prepare(h);
    h.click('[data-member=scout]'); h.click('[data-member=porter-2]');
    h.run("Journey.randomEnemies=()=>['scout']"); start(h);
    // A focused low-HP fixture tests either porter dying during a real enemy turn.
    h.run(`(()=>{state.actor='guard';state.units.forEach(u=>u.next=100);state.units.find(u=>u.id==='guard').next=0;const p=state.units.find(u=>u.id===${json(porter)});p.hp=1;const enemy=state.units.find(u=>u.side==='enemy');enemy.pos=p.pos+1;enemy.next=1;enemy.intent={kind:'attack',name:'攻撃',cells:[p.pos],target:p.id};mode='guard';render();})()`);
    h.document.querySelectorAll('#commands button')[1].click();
    assert.equal(h.run('state.failure'), 'porter');
    assert.equal(h.run('state.actor'), null);
    assert.equal(h.run('state.units.some(u=>u.side==="ally"&&u.hp>0)'), true);
    assert.equal(h.document.querySelector('#battle-return').hidden, false);
    h.click('#battle-return');
    assert.equal(h.run('journey.outcome'), 'failed');
    assert.equal(h.run('journey.stage'), 0);
    assert.equal(h.run('journey.gold'), 0);
    assert.equal(h.document.querySelector('.completion-scene'), null);
    assert.match(h.document.querySelector('#journey-content').textContent, /戦闘不能/);
    h.click('#new-trip'); assert.equal(h.run('journey.phase'), 'jobs'); assert.equal(h.run('state'), null);
  }
}
async function testExportFailureAndInterruptedReset() {
  const h = createHarness(); prepare(h, 'medicine'); h.click('#depart'); h.click('[data-route=safe]');
  assert.equal(h.document.querySelector('#deadline-dialog').open, true);
  // Exercise the reset helper with stale UI state and a pending callback. This is
  // an interrupted-state fixture, not a claim that a restart control is visible here.
  h.run("previewPos=24;previewKind='skill';rushTarget='enemy-scout';deploymentSelected='porter';deploymentDragging='porter';deploymentInitial=[{id:'porter',pos:22}];restartJourney()");
  assert.equal(h.document.querySelector('#deadline-dialog').open, false);
  const reset = h.run('JSON.stringify(journey)');
  h.document.querySelector('#deadline-proceed').click();
  assert.equal(h.run('JSON.stringify(journey)'), reset, 'stale deadline confirmation cannot start an old route');
  assert.equal(h.run('state'), null); assert.equal(h.run('previewPos'), null); assert.equal(h.run('rushTarget'), null);
  assert.equal(h.run('previewKind'), 'attack'); assert.equal(h.run('mode'), 'attack');
  assert.equal(h.run('deploymentSelected'), null); assert.equal(h.run('deploymentDragging'), null);
  assert.deepEqual(h.snapshot('deploymentInitial'), []);
  assert.equal(h.run('deadlineChoice'), null); assert.equal(h.run('deadlineAction'), null);
  const createElement = h.document.createElement;
  h.document.createElement = tag => {
    const element = createElement(tag);
    if (tag === 'a') element.click = () => { throw Error('Simulated blocked download'); };
    return element;
  };
  const anchorCount = h.document.querySelectorAll('a').length;
  h.click('#export-play-log');
  assert.equal(h.document.downloads.length, 0);
  assert.match(h.document.querySelector('#play-log-status').textContent, /保存できません/);
  assert.equal(h.document.querySelectorAll('a').length, anchorCount, 'failed download removes temporary anchor');
  h.flushTimers(); assert.equal(h.document.objectURLs.size, 0, 'failed download releases object URL');
  h.document.createElement = createElement;
  await exportLog(h); // A failed export must not poison the next attempt.
  assert.match(h.document.querySelector('#play-log-status').textContent, /開始しました/);
}
async function testStandalone() {
  const h = createHarness('battle.html');
  assert.ok(h.run('state.actor'));
  const initial = snapshot(h);
  h.document.querySelectorAll('#commands button')[1].click();
  assert.equal(h.run('state.actions'), 1);
  h.click('#restart'); assert.equal(snapshot(h), initial);
  const log = await exportLog(h);
  assert.equal(log.mode, 'battle'); assert.equal(log.current.journey, null); assert.equal(log.current.battle.actions, 0);
}
(async () => {
  await testDeploymentAndDeadlines();
  const deliveries = [await testRealDelivery('parts', true), await testRealDelivery('medicine', true)];
  testPorterDefeat(); await testStandalone(); await testExportFailureAndInterruptedReset();
  console.log('Simulated-DOM wiring passed: party gates, deadline cancel/confirm, deployment click/drag/reset, porter preview/swap, two complete real-combat deliveries, rewards/restart, either porter defeat, JSON download and standalone restart.');
  console.log(JSON.stringify(deliveries));
  console.log('Not browser QA: no CSS/layout, WebGL, images, native input, or real download behavior was verified.');
})().catch(error => { console.error(error); process.exitCode = 1; });
