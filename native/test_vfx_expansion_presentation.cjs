'use strict';
const assert=require('node:assert/strict');
const B=require('./campaign-battle.js'),P=require('./battle-presentation.cjs');
const clone=x=>JSON.parse(JSON.stringify(x));
let checks=0;
function fixture(skill){
 const s=B.create({ally:['guard','mage','porter'],enemy:['guard','archer'],deployment:true});
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
for(const skill of ['guard','defenseLine','porter']){
 const {s,a,b,p}=fixture(skill);
 if(skill==='defenseLine')p.pos=14;
 if(skill==='porter'){a.job='porter';a.pos=24;b.pos=13;p.pos=33;}
 const target=skill==='defenseLine'?[b.id,p.id]:skill==='porter'?a.id:b.id;
 const frames=parity(s,'skill',target),action=frames[0];
 assert.equal(action.resolved_support.length,skill==='defenseLine'?2:1);
 assert(action.resolved_support.every(row=>row.success&&row.status===({guard:'cover',defenseLine:'covers',porter:'boost'})[skill]));
 if(skill==='porter')assert.deepEqual(action.resolved.cells,action.state.units.filter(u=>u.hp>0&&u.side===a.side).map(u=>u.pos));
 // Reapplication has the same resolved success even if there is no value diff.
 s.actor=a.id;s.result=null;for(const u of s.units)u.next=1e6;a.next=0;
 const again=parity(s,'skill',target);assert(again[0].resolved_support.length);
}
for(const skill of ['manaGift','healingCross','archer','scout','poleVault','grapple','retreatSlash','knockback','splitShot','pincer','legSweep','stamp']){
 const {s,a,b,e,f}=fixture(skill);
 let target=e.id;
 if(skill==='manaGift'||skill==='healingCross')target=b.id;
 if(skill==='splitShot')target=[e.id,f.id];
 if(skill==='poleVault')target=22;
 if(skill==='grapple')e.pos=26;
 if(skill==='legSweep')target=a.id;
 if(skill==='stamp')target=25;
 if(skill==='scout'){e.pos=27;a.canInvade=true;}
 if(skill==='retreatSlash')b.pos=12;
 if(skill==='pincer')b.pos=15;
 const frames=parity(s,'skill',target);
 assert(frames.length>1,skill);assert(frames[0].resolved);assert(frames[0].attack_visual);
 if(skill==='healingCross')assert.deepEqual(frames[0].resolved.cells,B.crossCells(b.pos));
 if(skill==='manaGift'){const packet=frames.find(f=>f.phase==='resource');assert.equal(packet.resource,'mp');assert.equal(packet.skill_id,skill);assert.equal(packet.to-packet.from,2);assert.equal(packet.donor_amount,-2);assert.equal(packet.source_actor_id,a.id);assert.equal(packet.source_cell,24);}
 if(skill==='pincer'){assert.equal(frames[0].resolved.pincer_success,true);assert.equal(frames[0].resolved.pincer_helpers[0].unit_id,b.id);}
 if(['poleVault','scout','retreatSlash','knockback','grapple'].includes(skill))assert(frames.some(f=>f.phase==='move'&&f.source_skill===skill));
}
{
 const {s,a,e}=fixture('grapple');e.pos=26;s.units[1].pos=25;
 assert(!parity(s,'skill',e.id).some(f=>f.phase==='move'));
}
{
 const {s,a,e}=fixture('knockback');s.units[1].pos=26;
 assert(!parity(s,'skill',e.id).some(f=>f.phase==='move'));
}
for(const skill of ['guard','defenseLine','porter','manaGift','poleVault','grapple','legSweep']){
 const {s,a,b}=fixture(skill);a.mp=0;
 const before=clone(s),frames=parity(s,'skill',skill==='defenseLine'?[b.id]:skill==='poleVault'?22:skill==='legSweep'||skill==='porter'?a.id:b.id);
 assert.deepEqual(frames,[]);assert.deepEqual(s,before);
}
for(const effect of ['firstStride','loneWolf','victoryBreath']){
 const {s,a,b,p,e,f}=fixture('archer');a.effects=[effect];b.pos=10;p.pos=30;
 s.skillEventSequence=7;s.skillEvents=[{sequence:7,classification:'passive',actorId:a.id,skillId:effect}];
 if(effect==='victoryBreath'){f.hp=0;e.hp=1;a.mp=3;}
 const frames=parity(s,effect==='firstStride'?'move':'attack',effect==='firstStride'?23:e.id);
 const triggered=frames.flatMap(f=>f.triggered_passives||[]);
 assert.equal(triggered.length,1,effect);assert.equal(triggered[0].skillId,effect);assert.equal(triggered[0].sequence,8);
 assert.equal(frames[0].resolved_passives.length,1);
 if(effect==='firstStride')assert.equal(frames.find(f=>f.triggered_passives).unit_id,a.id,'swap trail belongs to the initiating mover, not the exchanged partner');
 assert.equal(frames.find(f=>f.triggered_passives)?.phase,({firstStride:'move',loneWolf:'hurt',victoryBreath:'resource'})[effect]);
}
{
 const {s,a,e,f}=fixture('archer');a.effects=['victoryBreath'];e.hp=1;f.hp=0;a.mp=a.maxMp;
 const frames=parity(s,'attack',e.id);
 assert(!frames.some(f=>f.phase==='resource'));
 assert.equal(frames.find(f=>f.triggered_passives).phase,'settled');
 assert.equal(frames.flatMap(f=>f.triggered_passives||[])[0].amount,0);
}
{
 const {s,a}=fixture('archer');a.effects=['firstStride','loneWolf'];const before=clone(s);
 B.damagePreview(s,a,'attack','enemy-guard');B.effectPreview(s,a,'move',22);
 assert.deepEqual(s,before);
 assert.deepEqual(P.capture(s,B,()=>false),{ok:false,frames:[]});assert.deepEqual(s,before);
 const p=new P.Presentation();assert(!p.start(s,B,()=>B.act(s,'skill','missing')));assert.deepEqual(s,before);
 assert(p.start(s,B,()=>B.act(s,'attack','enemy-guard')));const info=p.info();assert(!p.next(info.id,999));assert(p.finish(info.id));assert(!p.finish(info.id));
 assert(!JSON.stringify(s).includes('triggered_passives'));
}
{
 const {s}=fixture('manaGift'),before=clone(s);
 assert.throws(()=>P.capture(s,B,()=>{throw Error('cleanup');}));assert.deepEqual(s,before);
 for(const u of s.units)for(const k of Object.keys(u))assert.equal(Object.getOwnPropertyDescriptor(u,k).get,undefined);
}
{
 const {s,a}=fixture('guard');
 const frames=P.capture(s,B,()=>{delete a.cover;Object.defineProperty(a,'covers',{value:['mage'],writable:true,enumerable:true,configurable:true});return true;}).frames;
 assert(!Object.hasOwn(a,'cover'));assert.deepEqual(a.covers,['mage']);assert.equal(frames.length,1);
}
console.log(`PASS VFX expansion ${checks} canonical state/JSON/RNG parity cases; support reapplication, target/pincer, blocked movement, MP0, resource/passive timing, preview/cancel/cleanup and no replay`);
