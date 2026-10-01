import {spawn} from 'node:child_process';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import path from 'node:path';
import {createRequire} from 'node:module';
const playMirror=createRequire(import.meta.url)('./playtest-mirror.cjs');
const profile=path.join(process.env.TEMP,'opencode',`5525-qa-${Date.now()}`);
const child=spawn('C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',['--headless=new','--mute-audio','--enable-automation','--remote-debugging-port=9341',`--user-data-dir=${profile}`,'--no-first-run','about:blank'],{stdio:'ignore'});
const wait=ms=>new Promise(r=>setTimeout(r,ms));
let ws,send;
try {
 let tab;for(let i=0;i<60&&!tab;i++){try{tab=(await(await fetch('http://127.0.0.1:9341/json')).json()).find(t=>t.type==='page');}catch{}if(!tab)await wait(200);}
 assert.ok(tab);ws=new WebSocket(tab.webSocketDebuggerUrl);await new Promise(r=>ws.addEventListener('open',r,{once:true}));
 let seq=0;const pending=new Map(),errors=[];
 ws.addEventListener('message',e=>{const m=JSON.parse(e.data);if(m.id){pending.get(m.id)?.(m);pending.delete(m.id);}if(m.method==='Runtime.exceptionThrown')errors.push(m.params);});
 send=(method,params={})=>new Promise(r=>{pending.set(++seq,r);ws.send(JSON.stringify({id:seq,method,params}));});
 const run=async expression=>{const r=await send('Runtime.evaluate',{expression,returnByValue:true});assert.ok(!r.result.exceptionDetails,JSON.stringify(r));return r.result.result.value;};
 assert.ok((await send('Browser.getBrowserCommandLine')).result.arguments.includes('--mute-audio'));
 await send('Runtime.enable');await send('Page.enable');await send('Emulation.setDeviceMetricsOverride',{width:1440,height:1080,deviceScaleFactor:1,mobile:false});
  await send('Page.navigate',{url:pathToFileURL(path.resolve('battle.html')).href});
 for(let i=0;i<50;i++){if(await run('document.querySelectorAll(".cell").length===50'))break;await wait(100);}
 assert.equal(await run('document.querySelectorAll(".cell").length'),50);
  for(let i=0;i<50;i++){if(await run('[...document.querySelectorAll("img")].every(i=>i.complete&&i.naturalWidth>0)'))break;await wait(100);}
  assert.equal(await run('document.querySelectorAll(".unit-image").length'),8);
   assert.ok(await run('[...document.querySelectorAll("img")].every(i=>i.complete&&i.naturalWidth>0)'),JSON.stringify(await run('[...document.querySelectorAll("img")].filter(i=>!i.complete||!i.naturalWidth).map(i=>({src:i.src,complete:i.complete}))')));
  assert.equal(await run('document.querySelectorAll("#enemies img").length'),4);
 assert.ok(await run('document.querySelectorAll("#timeline .enemy").length>0'));
 const initial=await run('JSON.stringify(state)');
  await run('document.querySelectorAll("#commands button")[2].click();document.querySelectorAll("#allies button")[9].click()');
  assert.equal(await run('previewPos'),14);
 assert.equal(await run('JSON.stringify(state)'),initial,'preview does not change the battle');
 await fs.mkdir('qa',{recursive:true});
 const previewShot=await send('Page.captureScreenshot',{format:'png'});await fs.writeFile('qa/move-preview.png',Buffer.from(previewShot.result.data,'base64'));
 await run('document.querySelector("#previewSkill").click()');
 assert.equal(await run('JSON.stringify(state)'),initial);
 await run('document.querySelector("#cancelMove").click()');
 assert.equal(await run('previewPos'),null);
 assert.equal(await run('JSON.stringify(state)'),initial);
  await run('document.querySelectorAll("#allies button")[9].click();document.querySelector("#confirmMove").click()');
  assert.equal(await run('state.units.find(u=>u.id==="archer").pos'),14);
 assert.equal(await run('state.actions'),1);
 await run('document.querySelector("#restart").click()');
  // Controlled scout turn: preview/cancel/confirm uses actual UI, without enemy interruption.
  await run('state.actor="scout";state.units.find(u=>u.id==="scout").next=0;state.units.find(u=>u.id==="scout").pos=34;mode="skill";render()');
  const preRush=await run('JSON.stringify(state)');
  await run('document.querySelectorAll("#enemies button")[16].click()');
  assert.equal(await run('rushTarget'),'enemy-mage');
  assert.equal(await run('JSON.stringify(state)'),preRush);
  await run('document.querySelector("#cancelMove").click()');
  assert.equal(await run('JSON.stringify(state)'),preRush);
  await run('document.querySelectorAll("#enemies button")[16].click();document.querySelector("#confirmMove").click()');
  assert.equal(await run('Battle.boardOf(state.units.find(u=>u.id==="scout").pos)'),'enemy');
  assert.equal(await run('state.units.find(u=>u.id==="scout").mp'),4);
  assert.ok(await run('document.querySelector("#enemies .ally-unit img")!==null'));
  await run('document.querySelector("#restart").click();state.actor="mage";state.units.find(u=>u.id==="mage").next=0;render()');
 await run('document.querySelectorAll("#commands button")[3].click()');
  assert.equal(await run('document.querySelectorAll(".enemy-unit.valid").length'),0);
 assert.ok(await run('document.querySelectorAll("#allies .in-range").length>0'));
 // UI exercise with a controlled injured ally, then naturally proceed to shield turn.
  await run('state.units.find(u=>u.id==="mage").hp=40;render();document.querySelectorAll("#allies button")[18].click()');
 assert.equal(await run('state.units.find(u=>u.id==="mage").hp'),100);
 await run('document.querySelector("#restart").click()');
 await fs.mkdir('qa',{recursive:true});
 const shot=await send('Page.captureScreenshot',{format:'png'});await fs.writeFile('qa/battle-desktop.png',Buffer.from(shot.result.data,'base64'));
 // Position-aware policy: heal, cover a threatened adjacent ally, attack, otherwise approach.
 const result=await run(`(()=>{
 for(let i=0;i<250&&!state.result;i++){
 const a=state.units.find(u=>u.id===state.actor), friends=state.units.filter(u=>u.side==='ally'&&u.hp>0),enemies=state.units.filter(u=>u.side==='enemy'&&u.hp>0);
  const click=(k,id)=>{mode=k;render();const u=state.units.find(u=>u.id===id);document.querySelector('[data-pos="'+u.pos+'"]').click();if(rushTarget)document.querySelector('#confirmMove').click();};
 let t=a.id==='mage'?friends.find(u=>u.max-u.hp>=35&&Battle.legal(state,'skill',u.id)):null;
  if(t){click('skill',t.id);continue;}
  t=a.job==='scout'?enemies.find(u=>Battle.legal(state,'skill',u.id)):null;
  if(t){click('skill',t.id);continue;}
 t=enemies.find(u=>Battle.legal(state,'attack',u.id));
 if(t){click(a.id==='archer'&&Battle.legal(state,'skill',t.id)?'skill':'attack',t.id);continue;}
  const cells=Array.from({length:50},(_,p)=>p).filter(p=>Battle.legal(state,'move',p));
 cells.sort((p,q)=>Math.min(...enemies.map(e=>Battle.range({...a,pos:p},e)))-Math.min(...enemies.map(e=>Battle.range({...a,pos:q},e))));
  if(cells.length){mode='move';render();document.querySelector('[data-pos="'+cells[0]+'"]').click();document.querySelector('#confirmMove').click();}else document.querySelectorAll('#commands button')[1].click();
 }
 return {result:state.result,actions:state.actions,party:state.units.filter(u=>u.side==='ally').map(u=>({name:u.name,hp:u.hp})),log:state.log};})()`);
  assert.ok(result.result,'battle terminates');await fs.writeFile('qa/playtest-v07.json',JSON.stringify(result,null,2));console.log(JSON.stringify({result:result.result,actions:result.actions,party:result.party}));
  await run('document.querySelector("#restart").click()');assert.equal(await run('state.actions'),0);assert.deepEqual(errors,[]);
  if(process.argv.includes('--playtest')) {
   const comparisons=[];
   for(const policy of ['front-focus','healer-rush','intercept','home-only','escort','line-setup']) {
    await run('document.querySelector("#restart").click()');
    const comparison=await run(`(${playMirror.toString()})(Battle,${JSON.stringify(policy)},state,(kind,target)=>{
      mode=kind;render();
      if(kind==='guard'){document.querySelectorAll('#commands button')[1].click();return;}
      const pos=kind==='move'?target:state.units.find(u=>u.id===target).pos;
      const button=document.querySelector('[data-pos="'+pos+'"]');
      if(button.disabled)throw Error('Illegal UI target '+kind+' '+target);
      button.click();
      if(previewPos!==null)document.querySelector('#confirmMove').click();
    })`);
    comparisons.push(comparison);
   }
   assert.deepEqual(errors,[]);
   await fs.writeFile('qa/mirror-comparison-v07.json',JSON.stringify(comparisons,null,2));
   console.log(JSON.stringify(comparisons.map(({trace,log,...r})=>r),null,2));
  }
  console.log('Browser passed: images, movement preview, ambush cancel/confirm/invasion, healing, mirror completion, reset.');
} finally {if(ws?.readyState===1){ws.send(JSON.stringify({id:99999,method:'Browser.close'}));ws.close();}child.kill();}
