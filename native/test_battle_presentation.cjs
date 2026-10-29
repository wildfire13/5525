'use strict';
// Historical-ID fixtures retain the old roster; new-game/one-time migration
// behavior is tested separately in test_updateplan_roster.cjs.
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
 assert.equal(frames[0].phase,'action');assert.equal(frames.filter(f=>f.phase==='action').length,skill==='stamp'?2:1);
 if(skill==='stamp'){assert.equal(frames[0].kind,'cast');assert.equal(frames.filter(f=>f.phase==='action')[1].kind,'skill');}
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
 if(skill==='stamp')assert.deepEqual(preview,[],'cast reservation does not preview immediate damage');
 else assert.deepEqual(hits.map(x=>x.from-x.to),preview.map(x=>x.hpLoss));
 assert(hits.every(x=>x.actor_id==='guard'));
 assert.equal(new Set(hits.map(x=>x.action_id)).size,1);
 assert.equal(frames[0].skill_id,skill);assert.deepEqual(frames[0].voiceEvents,skill==='stamp'?[]:[{character_id:'guard',cue:'skill:'+skill}]);
 if(skill==='stamp')assert.deepEqual(frames.find(f=>f.phase==='action'&&f.kind==='skill').resolved.cells,[15,25,35]);
 assert.equal(s.units.find(u=>u.id==='guard').mp,7);assert.equal(s.actions,skill==='stamp'?2:1);
}

// Resolved status metadata is presentation-only. The native success assignment
// is the source of truth, including true -> true and a later consumed status.
{
 const C=require('./campaign.js');
 const {mark}=require('./battle-presentation.cjs');
 function sweep(level=1,already=false,consume=false){
  const campaign=C.deserialize(C.serialize(C.createLegacy()));for(const c of Object.values(campaign.characters))c.inventory={};campaign.characters.guard.lowerBody=level===1?'kungfu-pants':`kungfu-pants-${level}`;
  assert(C.depart(campaign,'east'));assert(C.travel(campaign,'short',()=>0));assert(C.begin(campaign));
  const b=campaign.battle,positions={guard:24,archer:12,mage:13,scout:4,porter:32};
  for(const u of b.units){u.next=10000;if(u.side==='ally')u.pos=positions[u.id];}
  const actor=b.units.find(u=>u.id==='guard');actor.next=1;actor.selectedSkill='legSweep';b.actor=actor.id;
  const enemies=b.units.filter(u=>u.side==='enemy');enemies.forEach((u,i)=>{u.pos=[25,15,35][i];});
  if(already)enemies[0].skipNextTurn=true;
  if(consume){enemies[0].next=2;b.units.find(u=>u.id==='archer').next=3;}
  assert(C.validate(campaign).ok,C.validate(campaign).error);
  return campaign;
 }
 function rng(values,counter){return ()=>{const next=values[counter.count++];assert.notEqual(next,undefined,'no extra random roll');return next;};}
 function noAccessors(b){
  for(const u of b.units)for(const key of ['hp','pos','skipNextTurn']){
   const d=Object.getOwnPropertyDescriptor(u,key);assert(!d||!d.get&&!d.set,'observer descriptor removed');
  }
 }
 const cases=[
  {name:'all failure',level:1,already:false,values:[.99,.99,.99],success:[false,false,false]},
  {name:'mixed',level:1,already:false,values:[.1,.8,.2],success:[true,false,true]},
  {name:'level two mixed',level:2,already:false,values:[.6,.8,.74],success:[true,false,true]},
  {name:'all success',level:3,already:false,values:[.99,.99,.99],success:[true,true,true]},
  {name:'already true reapplication succeeds',level:1,already:true,values:[.1,.99,.99],success:[true,false,false]},
  {name:'already true reapplication fails',level:1,already:true,values:[.99,.99,.99],success:[false,false,false]},
  {name:'success immediately consumed by turn advance',level:1,already:false,consume:true,values:[.1,.99,.99],success:[true,false,false]},
  {name:'existing status consumed after failed reapplication',level:1,already:true,consume:true,values:[.99,.99,.99],success:[false,false,false]},
 ];
 for(const item of cases){
  const source=sweep(item.level,item.already,item.consume),expected=C.deserialize(C.serialize(source)),observed=C.deserialize(C.serialize(source));
  const candidates=B.sweepTargets(source.battle,source.battle.units.find(u=>u.id==='guard'));
  const directCalls={count:0},observedCalls={count:0};
  assert(B.act(expected.battle,'skill','guard',rng(item.values,directCalls)),item.name);
  const p=new Presentation();assert(p.start(observed.battle,B,()=>B.act(observed.battle,'skill','guard',rng(item.values,observedCalls))),item.name);
  const first=p.info();assert.equal(first.phase,'action');
  assert.deepEqual(first.resolved_status,candidates.map((unit,i)=>({unit_id:unit.id,cell:unit.pos,status:'skipNextTurn',success:item.success[i],already_active:i===0&&item.already})),item.name);
  const results=clone(first.resolved_status);const frames=drain(p);
  assert.deepEqual(frames[0].resolved_status,results,item.name+' metadata stable through playback');
  assert(frames.every(f=>['action','settled'].includes(f.phase)),item.name+' no new phase or fake damage');
  assert(frames.slice(1).every(f=>f.resolved_status===undefined),item.name+' results not replayed on later phases');
  assert.equal(directCalls.count,3);assert.equal(observedCalls.count,directCalls.count);
  assert.equal(C.serialize(observed),C.serialize(expected),item.name+' exact save parity');
  noAccessors(observed.battle);noAccessors(expected.battle);
  assert(C.validate(observed).ok,C.validate(observed).error);
  assert(!C.serialize(observed).includes('resolved_status'),item.name+' metadata absent from save');
  if(item.consume)assert(!Object.hasOwn(observed.battle.units.find(u=>u.id===candidates[0].id),'skipNextTurn'),'consumed status remains deleted');
 }

 // An empty legal sweep has no successful recipients and consumes no roll.
 const empty=sweep(),emptyDirect=structuredClone(empty);
 for(const candidate of [empty,emptyDirect])candidate.battle.units.filter(u=>u.side==='enemy').forEach((u,i)=>{u.pos=[29,19,39][i];});
 const emptyP=new Presentation();let emptyCalls=0;
 assert(B.act(emptyDirect.battle,'skill','guard',()=>{emptyCalls++;throw Error('empty sweep must not roll');}));
 assert(emptyP.start(empty.battle,B,()=>B.act(empty.battle,'skill','guard',()=>{emptyCalls++;throw Error('empty sweep must not roll');})));
 assert.deepEqual(emptyP.info().resolved_status,[]);assert(emptyP.finish(emptyP.info().id));
 assert.equal(emptyCalls,0);assert.equal(C.serialize(empty),C.serialize(emptyDirect));

 // Reuse the same Presentation, then save/reload it, without leaking old results.
 const campaign=sweep(),direct=C.deserialize(C.serialize(campaign)),p=new Presentation();let earlier;
 for(const values of [[.1,.1,.1],[.99,.99,.99]]){
  if(earlier){assert(!B.legal(direct.battle,'skill','guard'));assert(B.act(direct.battle,'guard'));assert(B.act(campaign.battle,'guard'));}
  const a={count:0},b={count:0};assert(B.act(direct.battle,'skill','guard',rng(values,a)));
  assert(p.start(campaign.battle,B,()=>B.act(campaign.battle,'skill','guard',rng(values,b))));
  const info=p.info();
  if(earlier){assert.equal(info.id,earlier.id+1);assert(info.resolved_status.every(x=>!x.success&&x.already_active));assert(earlier.results.every(x=>x.success&&!x.already_active));}
  earlier={id:info.id,results:clone(info.resolved_status)};
  assert(p.finish(info.id));assert(!p.finish(info.id),'repeated finish cannot run accepted action twice');
  assert.equal(C.serialize(campaign),C.serialize(direct));assert.equal(a.count,b.count);
 }
 const loaded=C.deserialize(C.serialize(campaign)),loadedDirect=C.deserialize(C.serialize(campaign));
 assert.deepEqual(loaded,campaign,'save/load restores ordinary status fields, not observation metadata');
 assert(!B.legal(loaded.battle,'skill','guard'));assert(B.act(loaded.battle,'guard'));assert(B.act(loadedDirect.battle,'guard'));
 const loadedP=new Presentation(),a={count:0},b={count:0};assert(B.act(loadedDirect.battle,'skill','guard',rng([.1,.1,.1],a)));
 assert(loadedP.start(loaded.battle,B,()=>B.act(loaded.battle,'skill','guard',rng([.1,.1,.1],b))));
 assert(loadedP.info().resolved_status.every(x=>x.success&&x.already_active));assert(loadedP.finish(loadedP.info().id));
 assert.equal(C.serialize(loaded),C.serialize(loadedDirect));assert.equal(a.count,b.count);
 // Rejected and throwing actions clean up even absent status properties.
 const rejected=sweep(),before=C.serialize(rejected),rejectP=new Presentation();
 assert(!rejectP.start(rejected.battle,B,()=>B.act(rejected.battle,'skill','missing')));assert.equal(C.serialize(rejected),before);noAccessors(rejected.battle);
 assert.throws(()=>rejectP.start(rejected.battle,B,()=>{
  const actor=rejected.battle.units.find(u=>u.id==='guard');mark(rejected.battle,actor,'skill','guard',B);
  B.sweepTargets(rejected.battle,actor)[0].skipNextTurn=true;throw Error('status observation rollback');
 }),/status observation rollback/);
 assert.equal(C.serialize(rejected),before);assert.equal(rejectP.pending,null);noAccessors(rejected.battle);
 const bare=sweep();const original=structuredClone(bare.battle);
 const untouched=capture(bare.battle,B,()=>true);assert(untouched.ok);assert.deepEqual(bare.battle,original,'read-only capture does not create undefined own status fields');noAccessors(bare.battle);
 for(const u of bare.battle.units)assert(!Object.hasOwn(u,'skipNextTurn'));
 console.log('PASS resolved legSweep status outcomes: mixed/failure/reapplication/consumption, strict state/save/RNG parity, finish/reload/rollback and descriptor cleanup');
}


// Trajectory equipment uses the same reach filter as combat. It is not a hit
// forecast: reserved enemy cells can be empty, and cover may receive the hit.
{
 const C=require('./campaign.js');
 function attackCampaign({mixed=false,actor='guard',targetCell=25,covered=false}={}){
  const s=C.deserialize(C.serialize(C.createLegacy()));for(const c of Object.values(s.characters))c.inventory={};if(mixed)s.characters.guard.leftHand='staff-wood';
  assert(C.depart(s,'east'));assert(C.travel(s,'short',()=>0));assert(C.begin(s));
  const positions={guard:actor==='archer'?22:24,archer:actor==='archer'?24:12,mage:13,scout:4,porter:32};
  const b=s.battle;for(const u of b.units){u.next=10000;if(u.side==='ally')u.pos=positions[u.id];}
  const enemies=b.units.filter(u=>u.side==='enemy');enemies.forEach((u,i)=>{u.pos=[targetCell,15,35][i];});
  const source=b.units.find(u=>u.id===actor);source.next=1;b.actor=source.id;
  if(covered)enemies[1].cover=enemies[0].id;
  assert(C.validate(s).ok,C.validate(s).error);return s;
 }
 const cases=[
  {name:'single melee sword',options:{},items:['sword-wood']},
  {name:'mixed hands near both contribute',options:{mixed:true},items:['sword-wood','staff-wood']},
  {name:'mixed hands far only staff contributes',options:{mixed:true,targetCell:26},items:['staff-wood']},
  {name:'two-handed ranged bow counted once',options:{actor:'archer',targetCell:27},items:['bow-wood']},
  {name:'cover does not retarget trajectory',options:{covered:true},items:['sword-wood']},
 ];
 for(const item of cases){
  const s=attackCampaign(item.options),before=C.serialize(s),direct=C.deserialize(before),observed=C.deserialize(before),actor=observed.battle.units.find(u=>u.id===observed.battle.actor),target=observed.battle.units.find(u=>u.side==='enemy');
  const expected=B.reachFilteredPower(actor,target,'attack');let directCalls=0,observedCalls=0;
  assert(B.act(direct.battle,'attack',target.id,()=>{directCalls++;return .5;}));
  const p=new Presentation();assert(p.start(observed.battle,B,()=>B.act(observed.battle,'attack',target.id,()=>{observedCalls++;return .5;})));
  const visual=clone(p.info().attack_visual);
  assert.deepEqual(visual,{source_cell:actor.pos,target_cell:target.pos,target_unit_id:target.id,targeting:'unit',weapons:expected.weapons,abstract:false},item.name);
  assert.deepEqual(visual.weapons.map(w=>w.itemId),item.items,item.name);
  assert(!visual.weapons.some(w=>Object.hasOwn(w,'type')),'no weapon-type guess added to canonical catalog data');
  const frames=drain(p);assert(frames.slice(1).every(f=>f.attack_visual===undefined),'trajectory only belongs to action packet');
  assert(frames.some(f=>f.phase==='hurt'),item.name+' canonical hit remains distinct');
  if(item.options.covered)assert(frames.find(f=>f.phase==='hurt').unit_id!==visual.target_unit_id,'cover hurt recipient differs from intended trajectory target');
  assert.equal(C.serialize(observed),C.serialize(direct),item.name+' exact final save parity');assert.equal(observedCalls,directCalls);assert.equal(observedCalls,0);
  assert(!C.serialize(observed).includes('attack_visual'),'trajectory metadata never enters save');assert(C.validate(observed).ok,C.validate(observed).error);
 }
 // Enemy intent reserves cell 24 even when its original named target moves.
 for(const occupied of [true,false]){
  const s=attackCampaign(),b=s.battle,enemy=b.units.find(u=>u.side==='enemy'),guard=b.units.find(u=>u.id==='guard'),archer=b.units.find(u=>u.id==='archer');
  guard.pos=23;if(occupied)archer.pos=24;
  guard.next=1;enemy.next=2;archer.next=3;enemy.intent={kind:'attack',target:guard.id,name:'攻撃',reason:'reserved-cell observation boundary',cells:[24]};
  assert(C.validate(s).ok,C.validate(s).error);
  const direct=C.deserialize(C.serialize(s)),observed=C.deserialize(C.serialize(s));
  assert(B.act(direct.battle,'guard',null));
  const p=new Presentation();assert(p.start(observed.battle,B,()=>B.act(observed.battle,'guard',null)));
  const frames=drain(p),attack=frames.find(f=>f.phase==='action'&&f.kind==='attack'&&f.actor_id===enemy.id);
  assert(attack,'canonical enemy step exposes reserved attack after player action');
  const visual=clone(attack.attack_visual);
  assert.deepEqual(visual,{source_cell:25,target_cell:24,target_unit_id:occupied?'archer':null,targeting:'reserved_cell',weapons:[],abstract:true});
  assert.notEqual(visual.target_cell,guard.pos,'never follows the old target id after it moved');
  const hits=frames.filter(f=>f.phase==='hurt');
  if(occupied)assert.equal(hits[0].unit_id,'archer');else assert.equal(hits.length,0,'empty reservation is a miss, never a success flash');
  assert.equal(C.serialize(observed),C.serialize(direct),'reserved-cell exact save parity');assert(C.validate(observed).ok,C.validate(observed).error);
 }

 // Legacy/template-only equipment remains abstract; no sword or bow guessed.
 for(const missingApi of [false,true]){
  const legacy=fixture(),direct=clone(legacy),p=new Presentation(),engine=missingApi?{...B,reachFilteredPower:undefined}:B;
  assert(B.act(direct,'attack','enemy-guard'));
  assert(p.start(legacy,engine,()=>B.act(legacy,'attack','enemy-guard')));
  assert.deepEqual(p.info().attack_visual,{source_cell:24,target_cell:25,target_unit_id:'enemy-guard',targeting:'unit',weapons:[],abstract:true});
  assert(p.finish(p.info().id));assert.deepEqual(clone(legacy),clone(direct));
 }

 // A rejected out-of-reach player attack has no packet or visual metadata.
 const invalid=attackCampaign({mixed:true,targetCell:27}),before=C.serialize(invalid),p=new Presentation();let calls=0;
 const id=invalid.battle.units.find(u=>u.side==='enemy').id;
 assert(!p.start(invalid.battle,B,()=>B.act(invalid.battle,'attack',id,()=>{calls++;return .5;})));
 assert.equal(p.info(),null);assert.equal(calls,0);assert.equal(C.serialize(invalid),before);
 // Metadata is a detached snapshot; a renderer cannot edit contributing gear.
 const isolated=attackCampaign({mixed:true}),q=new Presentation(),target=isolated.battle.units.find(u=>u.side==='enemy');
 assert(q.start(isolated.battle,B,()=>B.act(isolated.battle,'attack',target.id)));
 q.info().attack_visual.weapons[0].atk=99999;
 assert.notEqual(isolated.battle.units.find(u=>u.id==='guard').attackWeapons[0].atk,99999);assert(q.finish(q.info().id));
 console.log('PASS canonical attack trajectory metadata: mixed reach/two-hand bow, reserved-cell occupant/miss, cover, rejection and exact save/RNG parity');
}

console.log('PASS presentation causal phases, strict ACK, enemy deferral, close, rollback, cover/multi-hit/heal, AoE, movement, r3 target-filtered multiweapon damage and final-state parity');
