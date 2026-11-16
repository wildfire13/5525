'use strict';
const assert=require('node:assert/strict');
const B=require('./campaign-battle.js'),P=require('./battle-presentation.cjs');
const clone=x=>JSON.parse(JSON.stringify(x));
let checks=0;
function fixture(skill){
 const s=B.create({ally:["character_mirei","character_merina","character_yuno"],enemy:['guard','archer'],deployment:true});
 const [a,b,p,e,f]=s.units;
 a.pos=24;b.pos=23;p.pos=13;e.pos=25;f.pos=15;
 for(const u of s.units)u.next=1e6;
 a.next=0;a.equippedSkill=skill;a.mp=a.maxMp=6;a.reach=3;b.mp=0;b.hp-=40;
 s.deploying=false;s.actor=a.id;
 return {s,a,b,p,e,f};
}
function parity(s,kind,target,randomValue=.2){
 const direct=clone(s);let n=0,m=0;
 const ok=B.act(direct,kind,target,()=>{n++;return randomValue;});
 const result=P.capture(s,B,()=>B.act(s,kind,target,()=>{m++;return randomValue;}));
 assert.equal(result.ok,ok);assert.equal(n,m);assert.deepEqual(s,direct);assert.equal(JSON.stringify(s),JSON.stringify(direct));
 for(const u of s.units)for(const key of Object.keys(u))assert.equal(Object.getOwnPropertyDescriptor(u,key).get,undefined);
 for(const frame of result.frames)assert(!JSON.stringify(frame.state).includes('resolved_support'));
 checks++;return result.frames;
}
for(const skill of ['skill_cover','skill_defense_line','skill_formation_boost']){
 const {s,a,b,p}=fixture(skill);
 if(skill==='skill_defense_line')p.pos=14;
 if(skill==='skill_formation_boost'){a.job='job_porter';a.pos=22;b.pos=24;p.pos=14;s.units.push({...structuredClone(a),id:'ally-extra',job:'job_warrior',pos:33,side:'ally',hp:100,max:100},{...structuredClone(a),id:'ally-slot2',job:'job_warrior',pos:13,side:'ally',hp:100,max:100});}
 const target=skill==='skill_defense_line'?[b.id,p.id]:skill==='skill_formation_boost'?a.id:b.id;
 const frames=parity(s, 'action_skill',target),action=frames[0];
 assert.equal(action.resolved_support.length,skill==='skill_defense_line'?2:1);
 assert(action.resolved_support.every(row=>row.success&&row.status===({skill_cover:'cover',skill_defense_line:'covers',skill_formation_boost:'boost'})[skill]));
 if(skill==='skill_formation_boost')assert.deepEqual(action.resolved.cells,action.state.units.filter(u=>u.hp>0&&u.side===a.side).map(u=>u.pos));
 // Reapplication has the same resolved success even if there is no value diff.
 s.actor=a.id;s.result=null;for(const u of s.units)u.next=1e6;a.next=0;
 const again=parity(s, 'action_skill',target);assert(again[0].resolved_support.length);
}
for(const skill of ['skill_mana_gift','skill_healing_cross','skill_snipe','skill_ambush','skill_pole_vault','skill_grapple','skill_retreat_slash','skill_knockback','skill_split_shot','skill_pincer','skill_leg_sweep','skill_stamp']){
 const {s,a,b,e,f}=fixture(skill);
 let target=e.id;
 if(skill==='skill_mana_gift'||skill==='skill_healing_cross')target=b.id;
 if(skill==='skill_split_shot')target=[e.id,f.id];
 if(skill==='skill_pole_vault')target=22;
 if(skill==='skill_grapple')e.pos=26;
 if(skill==='skill_leg_sweep')target=a.id;
 if(skill==='skill_stamp')target=25;
 if(skill==='skill_ambush'){e.pos=27;}
 if(skill==='skill_retreat_slash')b.pos=12;
 if(skill==='skill_pincer')b.pos=15;
 const frames=parity(s, 'action_skill',target);
 assert(frames.length>1,skill);assert(frames[0].resolved);if(skill==='skill_stamp'){assert.equal(frames[0].kind, 'action_cast');assert(!frames[0].attack_visual);assert(frames.some(f=>f.kind==='action_skill'&&f.attack_visual));}else assert(frames[0].attack_visual);
 if(skill==='skill_healing_cross')assert.deepEqual(frames[0].resolved.cells,B.crossCells(b.pos));
 if(skill==='skill_mana_gift'){const packet=frames.find(f=>f.phase==='resource');assert.equal(packet.resource,'mp');assert.equal(packet.skill_id,skill);assert.equal(packet.to-packet.from,2);assert.equal(packet.donor_amount,-2);assert.equal(packet.source_actor_id,a.id);assert.equal(packet.source_cell,24);}
 if(skill==='skill_pincer'){assert.equal(frames[0].resolved.pincer_success,true);assert.equal(frames[0].resolved.pincer_helpers[0].unit_id,b.id);}
 if(['skill_pole_vault','skill_ambush','skill_retreat_slash','skill_knockback','skill_grapple'].includes(skill))assert(frames.some(f=>f.phase==='move'&&f.source_skill===skill));
}
{
 const {s,a,e}=fixture('skill_grapple');e.pos=26;s.units[1].pos=25;
 assert(!parity(s, 'action_skill',e.id).some(f=>f.phase==='move'));
}
{
 const {s,a,e}=fixture('skill_knockback');s.units[1].pos=26;
 assert(!parity(s, 'action_skill',e.id).some(f=>f.phase==='move'));
}
for(const skill of ['skill_cover','skill_defense_line','skill_formation_boost','skill_mana_gift','skill_pole_vault','skill_grapple','skill_leg_sweep']){
 const {s,a,b}=fixture(skill);a.mp=0;
 const before=clone(s),frames=parity(s, 'action_skill',skill==='skill_defense_line'?[b.id]:skill==='skill_pole_vault'?22:skill==='skill_leg_sweep'||skill==='skill_formation_boost'?a.id:b.id);
 assert.deepEqual(frames,[]);assert.deepEqual(s,before);
}
for(const effect of ['skill_first_stride','skill_lone_wolf','skill_victory_breath']){
 const {s,a,b,p,e,f}=fixture('skill_snipe');a.effects=[effect];b.pos=10;p.pos=30;
 s.skillEventSequence=7;s.skillEvents=[{sequence:7,classification:'passive',actorId:a.id,skillId:effect}];
 if(effect==='skill_victory_breath'){f.hp=0;e.hp=1;a.mp=3;}
 const frames=parity(s,effect==='skill_first_stride'?'action_move':'action_attack',effect==='skill_first_stride'?23:e.id);
 const triggered=frames.flatMap(f=>f.triggered_passives||[]);
 assert.equal(triggered.length,1,effect);assert.equal(triggered[0].skillId,effect);assert.equal(triggered[0].sequence,8);
 assert.equal(frames[0].resolved_passives.length,1);
 if(effect==='skill_first_stride')assert.equal(frames.find(f=>f.triggered_passives).unit_id,a.id,'swap trail belongs to the initiating mover, not the exchanged partner');
 assert.equal(frames.find(f=>f.triggered_passives)?.phase,({skill_first_stride:'move',skill_lone_wolf:'hurt',skill_victory_breath:'resource'})[effect]);
}
{
 const {s,a,e,f}=fixture('skill_snipe');a.effects=['skill_victory_breath'];e.hp=1;f.hp=0;a.mp=a.maxMp;
 const frames=parity(s, 'action_attack',e.id);
 assert(!frames.some(f=>f.phase==='resource'));
 assert.equal(frames.find(f=>f.triggered_passives).phase,'settled');
 assert.equal(frames.flatMap(f=>f.triggered_passives||[])[0].amount,0);
}
{
 const {s,a}=fixture('skill_snipe');a.effects=['skill_first_stride','skill_lone_wolf'];const before=clone(s);
 B.damagePreview(s,a,'action_attack','enemy-guard');B.effectPreview(s,a,'action_move',22);
 assert.deepEqual(s,before);
 assert.deepEqual(P.capture(s,B,()=>false),{ok:false,frames:[]});assert.deepEqual(s,before);
 const p=new P.Presentation();assert(!p.start(s,B,()=>B.act(s,'action_skill','missing')));assert.deepEqual(s,before);
 assert(p.start(s,B,()=>B.act(s,'action_attack','enemy-guard')));const info=p.info();assert(!p.next(info.id,999));assert(p.finish(info.id));assert(!p.finish(info.id));
 assert(!JSON.stringify(s).includes('triggered_passives'));
}
{
 const {s}=fixture('skill_mana_gift'),before=clone(s);
 assert.throws(()=>P.capture(s,B,()=>{throw Error('cleanup');}));assert.deepEqual(s,before);
 for(const u of s.units)for(const k of Object.keys(u))assert.equal(Object.getOwnPropertyDescriptor(u,k).get,undefined);
}
{
 const {s,a}=fixture('skill_cover');
 const frames=P.capture(s,B,()=>{delete a.cover;Object.defineProperty(a,'covers',{value:['mage'],writable:true,enumerable:true,configurable:true});return true;}).frames;
 assert(!Object.hasOwn(a,'cover'));assert.deepEqual(a.covers,['mage']);assert.equal(frames.length,1);
}
console.log(`PASS VFX expansion ${checks} canonical state/JSON/RNG parity cases; support reapplication, target/pincer, blocked movement, MP0, resource/passive timing, preview/cancel/cleanup and no replay`);
