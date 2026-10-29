'use strict';
// Current production start and public-operation long battle; not GUI evidence.
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {spawnSync}=require('node:child_process');
const C=require('./campaign.js'),B=require('./campaign-battle.js'),P=require('./play-log.js');
const clone=x=>JSON.parse(JSON.stringify(x));
const gameplay=b=>{const copy=clone(b);delete copy.log;delete copy.logDropped;return copy;};
function stalled(){return require('./test-stalemate-fixture.cjs')();}
let s=stalled();
// Same engine with only retention disabled is the control. No unit edits.
const sandbox={module:{exports:{}},require};
vm.runInNewContext(fs.readFileSync(require.resolve('./campaign-battle.js'),'utf8').replace('const MAX_LOG_LINES = 1000;','const MAX_LOG_LINES = Infinity;'),sandbox);
const unbounded=sandbox.module.exports,control=clone(s.battle);
let untrimmedSave;
for(let n=0;n<1600;n++){
  assert(C.act(s,'guard',null));assert(unbounded.act(control,'guard',null));
  assert.deepEqual(gameplay(s.battle),gameplay(control));
  assert(s.battle.log.length<=B.MAX_LOG_LINES);
  assert.deepEqual(s.battle.log,control.log.slice(-B.MAX_LOG_LINES));
  assert.equal(s.battle.logDropped||0,control.log.length-s.battle.log.length);
  if(!untrimmedSave&&control.log.length>1500){
    untrimmedSave=JSON.parse(C.serialize(s));untrimmedSave.state.battle=clone(control);
  }
  if(n%100===0){const before=clone(s);s=C.deserialize(C.serialize(s));assert.deepEqual(s,before);}
}
assert(control.log.length>4000);assert.equal(s.battle.result,null);
assert.equal(C.validate(s).ok,true);assert.deepEqual(C.deserialize(C.serialize(s)),clone(s));
console.log(`PASS long battle: ${s.battle.actions} actions, ${control.log.length} real lines, ${s.battle.log.length} retained, ${s.battle.logDropped} dropped; every gameplay field matches control`);
// An old save inside the existing schema limit is normalized only after validation.
for(const input of [untrimmedSave,JSON.stringify(untrimmedSave)]){
  const loaded=C.deserialize(input);assert.equal(loaded.battle.log.length,B.MAX_LOG_LINES);
  assert.deepEqual(gameplay(loaded.battle),gameplay(untrimmedSave.state.battle));
  assert.equal(loaded.battle.logDropped,untrimmedSave.state.battle.log.length-B.MAX_LOG_LINES);
  assert.deepEqual(C.deserialize(C.serialize(loaded)),loaded);
}
assert.equal(untrimmedSave.state.battle.logDropped,undefined,'input is untouched');
for(const mutate of [x=>x.state.battle.log.push(...Array(2001).fill('line')),x=>x.state.battle.log[0]={bad:true},x=>x.state.battle.log[0]='x'.repeat(4001),x=>x.state.battle.logDropped=-1,x=>x.state.battle.logDropped=.5,x=>x.state.battle.units[0].hp=-1]){
  const bad=clone(untrimmedSave);mutate(bad);assert.throws(()=>C.deserialize(bad));assert.throws(()=>C.deserialize(JSON.stringify(bad)));
}
console.log('PASS legacy normalization and strict rejection before truncation');
// Production bridge must keep new action messages after the display cap is full.
const requests=[{op:'campaign_load',data:JSON.parse(C.serialize(s))},{op:'act',kind:'guard',target:null},{op:'campaign_save'},{op:'export'}];
const run=spawnSync(process.execPath,['bridge.cjs'],{cwd:__dirname,input:requests.map(x=>JSON.stringify(x)).join('\n')+'\n',encoding:'utf8',maxBuffer:5*1024*1024});
assert.equal(run.status,0,run.stderr);const replies=run.stdout.trim().split('\n').map(JSON.parse);assert(replies.every(r=>r.ok));
const action=replies[3].data.events.find(e=>e.type==='battle.action');assert(action.details.messages.length>0);assert(action.details.messages.some(m=>m.includes(C.view(s).roster.find(c=>c.id===s.selected[0]).name)));
assert.equal(replies[3].data.retention.droppedEvents,0);
assert.deepEqual(C.deserialize(replies[2].data).battle,replies[1].state);
const diagnostics=P.create();for(let i=0;i<605;i++)diagnostics.record('test',{}, {battle:s.battle});
const exported=diagnostics.export();assert.equal(exported.events.length,600);assert.equal(exported.retention.droppedEvents,5);assert.equal(s.battle.log.length,1000);
console.log('PASS real bridge action messages, save/load, independent 600-event diagnostic cap and honest dropped counts');
