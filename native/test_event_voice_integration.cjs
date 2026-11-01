'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),crypto=require('node:crypto'),path=require('node:path');
const map=require('./assets/event-voices/manifest.json');
const roster=require('./campaign-battle.js').roster.filter(c=>c.recruitRevision===1);
assert.equal(roster.length,24);assert.deepEqual(Object.keys(map.characters).sort(),roster.map(c=>c.id).sort());
for(const c of roster){
 const clips=map.characters[c.id];assert.deepEqual(Object.keys(clips).sort(),['attack','battle_win','damage','incapacitated','quest_clear'].sort());
 for(const v of Object.values(clips)){
  assert.equal(v.source_character,`${c.race}-${c.sex}-${c.job==='guard'?'warrior':c.job}`);
  assert(!v.source_character.endsWith('-02'));assert.equal(path.basename(v.file),v.file);
  assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(__dirname,'assets/event-voices',v.file))).digest('hex'),v.sha256);
 }
}
assert.equal(map.excluded_variants.length,5);
const P=require('./battle-presentation.cjs'),V=require('./voice-events.cjs');
const uid=roster[0].id;
function state(){return {actor:uid,units:[{id:uid,name:'test',side:'ally',hp:10,mp:3,pos:0}]};}
const engine={activeSkill:()=> 'guard',skillName:()=> 'かばう'};
let s=state();let result=P.capture(s,engine,()=>{P.mark(s,s.units[0],'skill',null,engine);s.units[0].hp=0;s.units[0].hp=-1;return true;});
assert.deepEqual(result.frames.flatMap(f=>f.voiceEvents).map(e=>e.cue),['skill:guard','hurt','incapacitated']);
s=state();result=P.capture(s,engine,()=>{P.mark(s,s.units[0],'attack',null,engine);s.units[0].hp=10;return true;});
assert.deepEqual(result.frames.flatMap(f=>f.voiceEvents).map(e=>e.cue),['attack']);
s=state();result=P.capture(s,engine,()=>{s.units[0].hp=12;return true;});assert.equal(result.frames.flatMap(f=>f.voiceEvents).length,0);
s=state();result=P.capture(s,engine,()=>{P.mark(s,s.units[0],'cast',null,engine);return true;});assert.equal(result.frames.flatMap(f=>f.voiceEvents).length,0);
s=state();result=P.capture(s,engine,()=>{s.units[0].hp=0;return false;});assert.equal(result.frames.length,0);
s=state();result=V.capture(s,engine,'attack',()=>{s.units[0].hp=0;return true;});assert.deepEqual(result.events.map(e=>e.cue),['attack','hurt','incapacitated']);
console.log('PASS 24 exact recruit mappings / 120 MP3 SHA256 / no 02 fallback / attack+skill event / cast silence / real HP damage / incap transition once / healing+rejection silent');
