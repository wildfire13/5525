import {spawn} from 'node:child_process';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {createRequire} from 'node:module';
const play=createRequire(import.meta.url)('./playtest-mirror.cjs');
const profile=path.join(process.env.TEMP,'opencode',`5525-cycle-${Date.now()}`);
const child=spawn('C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',['--headless=new','--mute-audio','--remote-debugging-port=9342',`--user-data-dir=${profile}`,'--no-first-run','about:blank'],{stdio:'ignore'});
const wait=ms=>new Promise(r=>setTimeout(r,ms));let ws;
try{
 let tab;for(let i=0;i<60&&!tab;i++){try{tab=(await(await fetch('http://127.0.0.1:9342/json')).json()).find(t=>t.type==='page');}catch{}if(!tab)await wait(200);}assert.ok(tab);
 ws=new WebSocket(tab.webSocketDebuggerUrl);await new Promise(r=>ws.addEventListener('open',r,{once:true}));let seq=0;const pending=new Map(),errors=[];
 ws.addEventListener('message',e=>{const m=JSON.parse(e.data);if(m.id){pending.get(m.id)(m);pending.delete(m.id);}if(m.method==='Runtime.exceptionThrown')errors.push(m.params);});
 const send=(method,params={})=>new Promise(r=>{pending.set(++seq,r);ws.send(JSON.stringify({id:seq,method,params}));});
 const run=async expression=>{const r=await send('Runtime.evaluate',{expression,returnByValue:true});assert.ok(!r.result.exceptionDetails,JSON.stringify(r));return r.result.result.value;};
 await send('Runtime.enable');await send('Page.enable');await send('Emulation.setDeviceMetricsOverride',{width:1440,height:1080,deviceScaleFactor:1,mobile:false});await send('Page.navigate',{url:pathToFileURL(path.resolve('index.html')).href});
 for(let i=0;i<80;i++){if(await run('!!document.querySelector("[data-job]")'))break;await wait(100);}
 assert.ok(await run('World.ready()'));await wait(500);
 await fs.mkdir('qa',{recursive:true});let shot=await send('Page.captureScreenshot',{format:'png'});await fs.writeFile('qa/cycle-jobs.png',Buffer.from(shot.result.data,'base64'));
 await run('document.querySelector("[data-job=medicine]").click()');
 assert.equal(await run('document.querySelectorAll("[data-member]").length'),10);
 for(let i=0;i<50;i++){if(await run('[...document.querySelectorAll(".member-choice img")].every(i=>i.complete&&i.naturalWidth>0)'))break;await wait(100);}
 assert.ok(await run('[...document.querySelectorAll(".member-choice img")].every(i=>i.complete&&i.naturalWidth>0)'));
 shot=await send('Page.captureScreenshot',{format:'png'});await fs.writeFile('qa/porter-party.png',Buffer.from(shot.result.data,'base64'));
 await run('document.querySelector("[data-member=porter]").click()');assert.equal(await run('document.querySelector("#depart").disabled'),true);await run('document.querySelector("[data-member=porter]").click()');
 await run('document.querySelector("[data-member=archer]").click();document.querySelector("[data-member=guard-2]").click()');
 assert.deepEqual(await run('journey.selected'),['guard','guard-2','mage','scout','porter']);
 assert.equal(await run('document.querySelector("[data-member=archer]").disabled'),true);
 await run('document.querySelector("#depart").click();window.confirm=()=>{throw Error("Native confirm must not be used")};document.querySelector("[data-route=safe]").click()');
 assert.equal(await run('journey.phase'),'road');assert.equal(await run('journey.hours'),0);assert.ok((await run('document.querySelector("#deadline-description").textContent')).includes('8時間'));
 assert.equal(await run('document.querySelector("#deadline-dialog").open'),true);assert.equal(await run('document.activeElement.id'),'deadline-back');
 shot=await send('Page.captureScreenshot',{format:'png'});await fs.writeFile('qa/deadline-dialog.png',Buffer.from(shot.result.data,'base64'));
 await run('document.querySelector("#deadline-back").click()');assert.equal(await run('journey.hours'),0);assert.equal(await run('document.querySelector("#deadline-dialog").open'),false);
 await run('document.querySelector("[data-route=safe]").click()');await send('Input.dispatchKeyEvent',{type:'keyDown',key:'Escape',code:'Escape',windowsVirtualKeyCode:27});await send('Input.dispatchKeyEvent',{type:'keyUp',key:'Escape',code:'Escape',windowsVirtualKeyCode:27});assert.equal(await run('document.querySelector("#deadline-dialog").open'),false);assert.equal(await run('journey.hours'),0);
 await run('document.querySelector("[data-route=safe]").click();document.querySelector("#deadline-proceed").click()');assert.equal(await run('journey.hours'),4);assert.equal(await run('state.units.filter(u=>u.side==="ally"&&u.job==="guard").length'),2);
 assert.equal(await run('journey.phase'),'deployment');assert.equal(await run('state.actor'),null);assert.equal(await run('state.actions'),0);
 const setupBefore=await run('JSON.stringify(state)');
 const drag=async(id,pos)=>{
  const points=await run(`(()=>{const a=document.querySelector('[data-drag-unit="${id}"]').getBoundingClientRect(),b=document.querySelector('[data-deploy-pos="${pos}"]').getBoundingClientRect();return {x:a.x+a.width/2,y:a.y+a.height/2,tx:b.x+b.width/2,ty:b.y+b.height/2}})()`);
  await send('Input.dispatchMouseEvent',{type:'mouseMoved',x:points.x,y:points.y});
  await send('Input.dispatchMouseEvent',{type:'mousePressed',x:points.x,y:points.y,button:'left',buttons:1,clickCount:1});
  for(let i=1;i<=10;i++)await send('Input.dispatchMouseEvent',{type:'mouseMoved',x:points.x+(points.tx-points.x)*i/10,y:points.y+(points.ty-points.y)*i/10,button:'left',buttons:1});
  await send('Input.dispatchMouseEvent',{type:'mouseReleased',x:points.tx,y:points.ty,button:'left',clickCount:1});
 };
 await drag('scout',0);assert.equal(await run('state.units.find(u=>u.id==="scout").pos'),0);
 await drag('scout',22);assert.equal(await run('state.units.find(u=>u.id==="scout").pos'),22);assert.equal(await run('state.units.find(u=>u.id==="porter").pos'),0);
 const afterDrag=await run('JSON.stringify(state)');await drag('scout',25);assert.equal(await run('JSON.stringify(state)'),afterDrag);
 await run('document.querySelector("#reset-deployment").click()');assert.equal(await run('JSON.stringify(state)'),setupBefore);
 await run(`document.querySelector('[data-deploy-unit="scout"]').click();document.querySelector('[data-deploy-pos="0"]').click();document.querySelector('[data-deploy-pos="22"]').click()`);
 assert.equal(await run('state.units.find(u=>u.id==="scout").pos'),22);assert.equal(await run('state.units.find(u=>u.id==="porter").pos'),0);assert.equal(await run('journey.hours'),4);
 assert.ok(await run('[...document.querySelectorAll("[data-deploy-pos]")].filter(b=>Number(b.dataset.deployPos)%10>=5).every(b=>b.disabled)'));
 await run('document.querySelector("#reset-deployment").click()');assert.equal(await run('JSON.stringify(state)'),setupBefore);
 shot=await send('Page.captureScreenshot',{format:'png'});await fs.writeFile('qa/deployment.png',Buffer.from(shot.result.data,'base64'));
 await run('document.querySelector("#begin-battle").click()');assert.equal(await run('journey.phase'),'battle');assert.equal(await run('state.deploying'),false);
 await run('state.actor="porter";state.units.forEach(u=>u.next=100);state.units.find(u=>u.id==="porter").next=0;state.units.find(u=>u.id==="mage").next=1;mode="move";render()');
 assert.equal(await run('document.querySelectorAll("#commands button")[0].hidden'),true);
 const beforeSwap=await run('JSON.stringify(state)');await run(`document.querySelector('[data-pos="24"]').click()`);assert.ok((await run('document.querySelector("#previewText").textContent')).includes('位置を交換'));assert.equal(await run('JSON.stringify(state)'),beforeSwap);assert.ok((await run(`document.querySelector('[data-pos="22"]').textContent`)).includes('ガロ'));
 await run('document.querySelector("#cancelMove").click()');assert.equal(await run('JSON.stringify(state)'),beforeSwap);
 await run(`document.querySelector('[data-pos="24"]').click();document.querySelector('#confirmMove').click()`);assert.equal(await run('state.units.find(u=>u.id==="porter").pos'),24);assert.equal(await run('state.units.find(u=>u.id==="guard").pos'),22);
 await run('journey.phase="camp";journey.stage=1;journey.hours=3;journey.party=state.units.filter(u=>u.side==="ally");cycleRender();document.querySelector("#rest").click()');assert.equal(await run('journey.hours'),3);assert.equal(await run('journey.rested'),false);
 await run('document.querySelector("#deadline-back").click()');assert.equal(await run('journey.rested'),false);
 await run('document.querySelector("#rest").click();document.querySelector("#deadline-proceed").click()');assert.equal(await run('journey.hours'),5);assert.equal(await run('journey.rested'),true);
 await run(`journey.phase='battle';state=Battle.create({ally:['guard','archer','mage','porter','porter-2'],enemy:['scout']});state.actor='porter';state.units.forEach(u=>u.next=100);state.units.find(u=>u.id==='porter').next=0;state.units.find(u=>u.id==='archer').next=1;mode='skill';render();document.body.classList.add('in-battle');document.querySelector('[data-pos="22"]').click()`);
 assert.equal(await run('Battle.boosted(state)'),true);assert.ok((await run('document.querySelector("#formation").textContent')).includes('強化中'));
 await run(`state.actor='guard';state.units.forEach(u=>u.next=100);state.units.find(u=>u.id==='guard').next=0;const p=state.units.find(u=>u.id==='porter-2');p.hp=1;const enemy=state.units.find(u=>u.side==='enemy');enemy.pos=p.pos+1;enemy.next=1;enemy.intent={kind:'attack',name:'攻撃',cells:[p.pos],target:p.id};mode='guard';render();document.querySelectorAll('#commands button')[1].click()`);
 assert.equal(await run('state.failure'),'porter');assert.ok((await run('document.querySelector("#turn").textContent')).includes('クエスト失敗'));await run('document.querySelector("#battle-return").click()');assert.equal(await run('journey.outcome'),'failed');assert.equal(await run('document.querySelector(".completion-scene")'),null);
 await run('journey=Journey.create();cycleRender();document.querySelector("[data-job=parts]").click();document.querySelector("#depart").click();Journey.randomEnemies=count=>["scout","mage","archer","guard"].slice(0,count)');
 if(process.argv.includes('--two-porters'))await run(`journey=Journey.create();cycleRender();document.querySelector('[data-job=parts]').click();document.querySelector('[data-member=scout]').click();document.querySelector('[data-member=porter-2]').click();document.querySelector('#depart').click()`);
 if(process.argv.includes('--party-playtest'))await run(`journey=Journey.create();cycleRender();document.querySelector('[data-job=medicine]').click();document.querySelector('[data-member=scout]').click();document.querySelector('[data-member=archer-2]').click();document.querySelector('#depart').click();let playSeed=7;Journey.randomEnemies=count=>{const pool=Battle.roster.filter(u=>u.job!=='porter').map(u=>u.id);for(let i=pool.length-1;i>0;i--){playSeed=(playSeed*1664525+1013904223)>>>0;const j=Math.floor(playSeed/4294967296*(i+1));[pool[i],pool[j]]=[pool[j],pool[i]];}return pool.slice(0,count);}`);
 const results=[];
 for(let leg=0;leg<2;leg++){
  await run('document.querySelector("[data-route=short]").click()');assert.equal(await run('journey.phase'),'deployment');await run('document.querySelector("#begin-battle").click()');assert.equal(await run('journey.phase'),'battle');
  const r=await run(`(${play.toString()})(Battle,'front-focus',state,(k,t)=>{
   mode=k;render();if(k==='guard'){document.querySelectorAll('#commands button')[1].click();return;}
   const p=k==='move'?t:state.units.find(u=>u.id===t).pos,b=document.querySelector('[data-pos="'+p+'"]');
   if(b.disabled)throw Error('Invalid UI action '+k);b.click();if(previewPos!==null)document.querySelector('#confirmMove').click();
  })`);results.push(r);assert.ok(r.result.startsWith('勝利'),JSON.stringify(r));
  assert.equal(await run('document.querySelector("#battle-return").hidden'),false);await run('document.querySelector("#battle-return").click()');
  if(leg===0){assert.equal(await run('journey.phase'),'camp');if(!process.argv.includes('--party-playtest'))await run('document.querySelector("#rest").click()');await run('document.querySelector("#onward").click()');}
 }
 assert.equal(await run('journey.phase'),'delivery');await run('document.querySelector("#deliver").click()');assert.equal(await run('journey.level'),2);assert.equal(await run('journey.gold'),process.argv.includes('--party-playtest')?180:150);
 assert.ok(await run('!!document.querySelector(".completion-scene")'));assert.equal(await run('document.querySelector("#new-trip")'),null);
 await wait(800);assert.equal(await run('journey.phase'),'result');
 shot=await send('Page.captureScreenshot',{format:'png'});await fs.writeFile('qa/cycle-completion.png',Buffer.from(shot.result.data,'base64'));
 await run('document.querySelector("#show-rewards").click()');assert.equal(await run('document.querySelector(".completion-scene")'),null);
 shot=await send('Page.captureScreenshot',{format:'png'});await fs.writeFile('qa/cycle-result.png',Buffer.from(shot.result.data,'base64'));await fs.writeFile(process.argv.includes('--two-porters')?'qa/two-porters-ui-playtest.json':process.argv.includes('--party-playtest')?'qa/party-cycle-ui-playtest.json':'qa/cycle-playtest.json',JSON.stringify({journey:await run('journey'),battles:results},null,2));
 await run('document.querySelector("#new-trip").click()');assert.equal(await run('journey.phase'),'jobs');assert.deepEqual(errors,[]);console.log('Cycle browser passed: Three.js, job selection, setup, two victories, camp/rest, delivery, growth, replay.');
}finally{ws?.close();child.kill();await wait(500);await fs.rm(profile,{recursive:true,force:true}).catch(()=>{});}
