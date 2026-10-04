'use strict';
const assert=require('node:assert/strict');
const B=require('./campaign-battle.js'),{Presentation,capture}=require('./battle-presentation.cjs');
const clone=x=>JSON.parse(JSON.stringify(x));
function fixture(){
  const s=B.create({ally:['guard','porter'],enemy:['guard'],enemyPotions:0,deployment:true});
  const [a,p,e]=s.units;a.pos=24;p.pos=23;e.pos=25;a.next=0;p.next=100;e.next=1;
  s.deploying=false;s.actor=a.id;e.intent={kind:'attack',target:a.id,cells:[24],name:'攻撃'};
  return s;
}
function drain(p){const frames=[];while(p.pending){frames.push({...p.info(),state:clone(p.pending.state)});assert(p.next(p.info().id,p.info().index));}return frames;}
{
 const s=fixture(),expected=clone(s);B.act(expected,'attack','enemy-guard');
 const p=new Presentation();let completed=0;
 assert(p.start(s,B,()=>B.act(s,'attack','enemy-guard'),()=>completed++));
 assert.equal(s.units[0].hp,180);assert.equal(s.units[2].hp,180);
 assert.equal(s.actions,0);assert.throws(()=>p.start(s,B,()=>true));
 const token=p.info();assert(!p.next(token.id,999));assert.equal(s.actions,0);
 assert(p.next(token.id,token.index));assert(!p.next(token.id,token.index));
 assert.equal(s.units[0].hp,180);assert.equal(s.units[2].hp,154);
 const frames=drain(p);
 assert.deepEqual(frames.map(f=>[f.phase,f.actor_id,f.unit_id]),[
 ['hurt','guard','enemy-guard'],['settled','guard','guard'],['action','enemy-guard','enemy-guard'],
 ['hurt','enemy-guard','guard'],['settled','enemy-guard','enemy-guard']]);
 assert.equal(frames[2].state.units[0].hp,180);
 assert.deepEqual(frames[3].voiceEvents,[{character_id:'guard',cue:'hurt'}]);
 assert.deepEqual(clone(s),clone(expected));assert.equal(completed,1);assert(!p.finish(token.id));
}
{
 const s=fixture(),before=clone(s),p=new Presentation();assert(!p.start(s,B,()=>B.act(s,'attack','missing')));
 assert.deepEqual(s,before);assert.equal(p.pending,null);
 assert.throws(()=>p.start(s,B,()=>{s.units[0].hp=1;throw Error('test');}));assert.deepEqual(s,before);
}
{
 const s=fixture(),expected=clone(s),p=new Presentation();B.act(expected,'attack','enemy-guard');
 p.start(s,B,()=>B.act(s,'attack','enemy-guard'));assert(p.finish(p.info().id));assert.deepEqual(clone(s),clone(expected));
}
{
 const s=fixture();s.units[0].cover='porter';
 const result=capture(s,B,()=>{B.receive(s,s.units[1],20,false);B.receive(s,s.units[1],10,false);s.units[0].hp+=5;return true;});
 assert.deepEqual(result.frames.map(f=>[f.phase,f.unit_id]),[['hurt','guard'],['hurt','guard'],['heal','guard'],['settled',null]]);
 assert.deepEqual(result.frames.slice(0,3).map(f=>f.state.units[0].hp),[160,150,155]);
 assert.equal(result.frames[2].voiceEvents.length,0);
}
for(const skill of ['stamp','splitShot','healingCross','retreatSlash','knockback','scout']){
 const s=B.create({ally:[skill==='scout'?'scout':'guard','mage'],enemy:['guard','archer'],deployment:true});
 const [a,b,e,f]=s.units;a.equippedSkill=skill;a.pos=24;a.reach=3;b.pos=13;b.hp-=50;
 e.pos=skill==='scout'?27:25;f.pos=15;e.next=f.next=1e9;b.next=1e9;a.next=0;s.actor=a.id;s.deploying=false;
 const target=skill==='stamp'?25:skill==='splitShot'?[e.id,f.id]:skill==='healingCross'?b.id:e.id;
 const expected=clone(s);assert(B.act(expected,'skill',target),skill);
 const p=new Presentation();assert(p.start(s,B,()=>B.act(s,'skill',target)));const frames=drain(p);
 assert.equal(frames[0].phase,'action');assert.equal(frames.filter(f=>f.phase==='action').length,1);
 if(skill==='healingCross'){assert(frames.some(f=>f.phase==='heal'));assert(!frames.some(f=>f.phase==='hurt'));}
 if(['stamp','splitShot'].includes(skill))assert.equal(frames.filter(f=>f.phase==='hurt').length,2);
 if(['retreatSlash','knockback'].includes(skill))assert(frames.findIndex(f=>f.phase==='hurt')<frames.findIndex(f=>f.phase==='move'));
 if(skill==='scout')assert(frames.findIndex(f=>f.phase==='move')<frames.findIndex(f=>f.phase==='hurt'));
 assert.deepEqual(clone(s),clone(expected),skill);
}
{
 const s=fixture();s.units[2].intent.cells=[4];const p=new Presentation();
 p.start(s,B,()=>B.act(s,'attack','enemy-guard'));const frames=drain(p);
 assert(!frames.some(f=>f.phase==='hurt'&&f.actor_id==='enemy-guard'));
}
for(const [skill,positions,expected] of [['archer',[26],[40]],['archer',[27],[14]],['splitShot',[25,27],[31,15]],['stamp',[25,15],[55,29]]]){
 const s=B.create({ally:['guard','porter'],enemy:['guard','archer'],deployment:true});
 const [a,p,e,f]=s.units;a.pos=24;p.pos=10;e.pos=positions[0];f.pos=positions[1]||35;
 a.activeSkills=[skill];a.mp=8;a.attackBonus=0;
 a.attackWeapons=skill==='splitShot'?[{slot:'rightHand',atk:25,reach:3,skill},{slot:'leftHand',atk:26,reach:1}]:
 skill==='stamp'?[{slot:'rightHand',atk:29,reach:1,skill},{slot:'leftHand',atk:26,reach:1}]:
 [{slot:'rightHand',atk:26,reach:1},{slot:'leftHand',atk:14,reach:2}];
 for(const u of s.units){u.next=u===a?0:1e9;if(u.side==='enemy')u.hp=u.max=999;}
 s.actor=a.id;s.deploying=false;
 const target=skill==='splitShot'?[e.id,f.id]:skill==='stamp'?25:e.id;
 const preview=B.damagePreview(s,a,'skill',target),q=new Presentation();
 assert(q.start(s,B,()=>B.act(s,'skill',target)));const frames=drain(q),hits=frames.filter(x=>x.phase==='hurt');
 assert.deepEqual(hits.map(x=>x.from-x.to),expected,skill);
 assert.deepEqual(hits.map(x=>x.from-x.to),preview.map(x=>x.hpLoss));
 assert(hits.every(x=>x.actor_id==='guard'));
 assert.equal(new Set(hits.map(x=>x.action_id)).size,1);
 assert.equal(frames[0].skill_id,skill);assert.deepEqual(frames[0].voiceEvents,[{character_id:'guard',cue:'skill:'+skill}]);
 assert.equal(s.units.find(u=>u.id==='guard').mp,7);assert.equal(s.actions,1);
}
console.log('PASS presentation causal phases, strict ACK, enemy deferral, close, rollback, cover/multi-hit/heal, AoE, movement, r3 target-filtered multiweapon damage and final-state parity');
