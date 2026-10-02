'use strict';
const assert = require('node:assert/strict');
const {createHarness} = require('./helpers/dom-harness.cjs');
const playMirror = require('./playtest-mirror.cjs');
const command = (h, kind) => h.document.querySelectorAll('#commands button')[['attack','guard','move','skill','item'].indexOf(kind)];
const cell = (h, pos) => h.document.querySelector(`[data-pos="${pos}"]`);
const unit = (h, id) => h.run(`state.units.find(u=>u.id===${JSON.stringify(id)})`);

function fixture(h, ally, enemy, actor) {
  h.run(`state=Battle.create({ally:${JSON.stringify(ally)},enemy:${JSON.stringify(enemy)},deployment:true});state.deploying=false;state.actor=${JSON.stringify(actor)};state.units.forEach(u=>{u.next=100;u.intent={kind:'guard',name:'防御',cells:[]};});state.units.find(u=>u.id===state.actor).next=0;resetPreview();mode='attack';render();`);
}
async function testTargetingAndLog() {
  const h = createHarness('battle.html');
  fixture(h, ['warrior','scout'], ['guard','mage','archer'], 'warrior');
  h.run("state.units.find(u=>u.id==='enemy-guard').pos=15;state.units.find(u=>u.id==='enemy-mage').pos=35;state.units.find(u=>u.id==='enemy-archer').pos=49;render()");
  const initial = h.run('JSON.stringify(state)');
  assert.equal(command(h,'skill').textContent, 'スタンプ (6)');
  command(h,'skill').click();
  assert.equal(cell(h,25).disabled,false, 'empty center is selectable');
  assert.equal(cell(h,15).disabled,true, 'diagonal center is not selectable');
  assert.equal(cell(h,26).disabled,true, 'distant center is not selectable');
  cell(h,25).click();
  assert.equal(h.run('JSON.stringify(state)'),initial,'preview cannot consume resources or act');
  assert.deepEqual(h.document.querySelectorAll('.cell.in-range').map(e=>Number(e.dataset.pos)).sort((a,b)=>a-b),[15,25,35]);
  assert.match(h.document.querySelector('#previewText').textContent,/右方向・3マス/);
  assert.equal(h.document.querySelector('#confirmMove').textContent,'スタンプを確定');
  assert.equal(command(h,'skill').disabled,true);
  h.click('#cancelMove');
  assert.equal(h.run('JSON.stringify(state)'),initial,'cancel leaves entire battle unchanged');
  h.click('#confirmMove');assert.equal(h.run('JSON.stringify(state)'),initial,'stale confirm after cancel cannot act');
  command(h,'move').click();cell(h,23).click();h.click('#previewSkill');
  assert.equal(h.run('areaTarget'),null,'cancelled Stamp cannot leak into a movement preview');
  assert.equal(h.run('previewPos'),23);assert.equal(h.run('JSON.stringify(state)'),initial);
  h.click('#cancelMove');command(h,'skill').click();
  cell(h,25).click();h.click('#confirmMove');
  assert.equal(h.run('state.actions'),1);assert.equal(unit(h,'warrior').mp,5);
  assert.equal(unit(h,'enemy-guard').hp,154);assert.equal(unit(h,'enemy-mage').hp,74);
  assert.equal(h.run('areaTarget'),null);
  h.click('#confirmMove');assert.equal(h.run('state.actions'),1,'repeated confirm cannot cast twice');
  h.click('#export-play-log');
  const log=JSON.parse(await h.document.downloads.at(-1).blob.text());
  const action=log.events.find(e=>e.type==='battle.action');
  assert.equal(action.details.target,25,'position target is numeric in exported log');
  assert.ok(action.details.messages.some(m=>m.includes('スタンプ')));
  assert.equal(action.state.battle.units.find(u=>u.id==='warrior').weapon,'hammer');
  assert.ok(log.events.some(e=>e.type==='battle.preview.cancelled'&&e.details.target===25));
  assert.deepEqual(log.events.find(e=>e.type==='battle.preview').details.cells,[15,25,35]);
  // A pending area preview is cleared by restart; no old cast can leak into it.
  command(h,'skill').click();cell(h,25).click();h.click('#restart');
  assert.equal(h.run('areaTarget'),null);assert.equal(h.run('state.actions'),0);
  h.click('#confirmMove');assert.equal(h.run('state.actions'),0);

  fixture(h,['archer'],['guard','mage'],'archer');
  h.run("state.units.find(u=>u.id==='archer').pos=13;state.units.find(u=>u.id==='enemy-guard').pos=17;state.units.find(u=>u.id==='enemy-mage').pos=18;render()");
  assert.equal(cell(h,17).disabled,true,'normal attack does not gain Snipe reach');
  command(h,'skill').click();assert.equal(command(h,'skill').textContent,'スナイプ (4)');
  assert.match(h.document.querySelector('#hint').textContent,/その一撃だけ通常射程＋1/);
  assert.equal(cell(h,17).disabled,false);assert.equal(cell(h,18).disabled,true);
  cell(h,17).click();
  assert.equal(unit(h,'enemy-guard').hp,155);assert.equal(unit(h,'archer').mp,3);
  assert.equal(unit(h,'archer').reach,3);assert.equal(h.run('mode'),'attack');
  assert.equal(cell(h,17).disabled,true,'normal attack returns to original reach after Snipe');
  h.click('#export-play-log');
  const snipeLog=JSON.parse(await h.document.downloads.at(-1).blob.text());
  const shot=snipeLog.events.filter(e=>e.type==='battle.action').at(-1);
  assert.equal(shot.details.target,'enemy-guard');assert.ok(shot.details.messages.some(m=>m.includes('スナイプ')));
}
function testWarriorDelivery() {
  const h=createHarness();h.click('[data-job=parts]');
  assert.equal(h.document.querySelectorAll('[data-member]').length,11);
  assert.equal(h.document.querySelector('[data-member=warrior]').disabled,true);
  h.click('[data-member=guard]');h.click('[data-member=warrior]');
  assert.equal(h.run("journey.selected.includes('warrior')"),true);
  assert.match(h.document.querySelector('#journey-content').textContent,/槌戦士（仮）/);
  h.run("Journey.randomEnemies=count=>['scout','mage','archer','guard'].slice(0,count)");
  h.click('#depart');let stamps=0;const actions=[];
  for(let leg=0;leg<2;leg++) {
    h.click('[data-route=short]');
    assert.equal(h.run('journey.phase'),'deployment');
    const warrior=unit(h,'warrior');assert.equal(warrior.weapon,'hammer');
    if(leg)assert.deepEqual(h.snapshot("state.units.filter(u=>u.side==='ally').map(({id,hp,mp,weapon})=>({id,hp,mp,weapon}))"),h.snapshot('journey.party.map(({id,hp,mp,weapon})=>({id,hp,mp,weapon}))'));
    h.click('[data-deploy-unit=warrior]');h.click('[data-deploy-pos="14"]');
    assert.equal(unit(h,'warrior').pos,14);h.click('#reset-deployment');assert.equal(unit(h,'warrior').pos,24);
    h.click('#begin-battle');
    const battle=h.run('state'),B=h.run('Battle');
    const result=playMirror(B,'front-focus',battle,(kind,target)=>{
      const actor=battle.units.find(u=>u.id===battle.actor);
      if(actor.id==='warrior'&&['attack','move','guard'].includes(kind)) {
        const centers=Array.from({length:50},(_,p)=>p).filter(p=>B.legal(battle,'skill',p));
        const count=p=>battle.units.filter(u=>u.hp>0&&u.side==='enemy'&&B.stampCells(actor,p).includes(u.pos)).length;
        centers.sort((a,b)=>count(b)-count(a));
        if(centers.length&&count(centers[0])){kind='skill';target=centers[0];stamps++;}
      }
      const before=battle.actions;command(h,kind).click();
      if(kind!=='guard') {
        const pos=typeof target==='number'?target:battle.units.find(u=>u.id===target).pos;
        h.click(`[data-pos="${pos}"]`);
        if(h.run('previewPos!==null||areaTarget!==null'))h.click('#confirmMove');
      }
      assert.equal(battle.actions,before+1);
    });
    assert.match(result.result,/^勝利/);actions.push(result.actions);
    h.click('#battle-return');
    if(!leg){h.click('#rest');h.click('#onward');}
  }
  assert.ok(stamps>0,'real combat delivery uses Stamp through UI');
  assert.equal(h.run('journey.phase'),'delivery');h.click('#deliver');h.click('#show-rewards');
  assert.equal(h.run('journey.outcome'),'success');assert.equal(h.run('journey.gold'),150);
  h.click('#new-trip');assert.equal(h.run('areaTarget'),null);
  assert.deepEqual(h.snapshot('journey.selected'),['guard','archer','mage','scout','porter']);
  return {stamps,actions};
}
(async()=>{
  await testTargetingAndLog();
  console.log('Stamp/Snipe simulated-DOM passed: empty-center preview/cancel/confirm, one action/MP, range overlays, restart/stale confirms, normal damage, numeric target/weapon logs, party selection/deployment and real two-battle delivery.');
  console.log(JSON.stringify(testWarriorDelivery()));
  console.log('DOM simulation only; no browser rendering, image load, native input, or real download verified.');
})().catch(error=>{console.error(error);process.exitCode=1;});
