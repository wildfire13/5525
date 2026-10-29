'use strict';
// Synthetic, validated campaign boundaries for presentation-only skill effects.
// These are not evidence of playing every preceding turn. No personal saves,
// game rules, bridge APIs, production randomness or files are changed here.
const assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const {createHash}=require('node:crypto');
const C=require('../../native/campaign.js');
const B=require('../../native/campaign-battle.js');
const {Presentation}=require('../../native/battle-presentation.cjs');
const clone=value=>JSON.parse(JSON.stringify(value));
const validate=(state,label)=>assert(C.validate(state).ok,`${label}: ${C.validate(state).error}`);

function campaign(kind){
  const s=require('../../native/test-current-fixture.cjs')(),guard=s.characters.guard;
  if(kind.startsWith('sweep'))guard.lowerBody=kind==='sweep100'?'kungfu-pants-3':'kungfu-pants';
  if(kind.startsWith('stamp'))guard.weapon='hammer-wood';
  assert(C.depart(s,'east'));assert(C.travel(s,'short',()=>0));assert(C.begin(s));
  const b=s.battle;
  const positions={guard:24,archer:12,mage:13,scout:4,porter:32};
  for(const u of b.units){
    u.hp=u.max;u.mp=u.maxMp;u.next=10000;u.guard=false;u.cover=null;u.boost=false;
    if(u.side==='ally')u.pos=positions[u.id];
  }
  const enemies=b.units.filter(u=>u.side==='enemy');
  enemies.forEach((u,i)=>{u.pos=[25,15,35][i];});
  const actor=b.units.find(u=>u.id===(kind.startsWith('heal')?'mage':kind==='attackRanged'?'archer':'guard'));
  actor.next=1;b.actor=actor.id;
  if(kind.startsWith('sweep')||kind.startsWith('stamp')||kind.startsWith('heal'))actor.selectedSkill=kind.startsWith('sweep')?'legSweep':kind.startsWith('stamp')?'stamp':'mage';
  let target=kind.startsWith('sweep')?actor.id:kind.startsWith('stamp')?25:kind.startsWith('attack')?enemies[0].id:'guard';
  let actionKind=kind.startsWith('attack')?'attack':kind==='guard'?'guard':'skill';
  if(kind==='attackRanged')actor.pos=23;
  if(['attackGuarded','attackGuardFloor'].includes(kind))enemies[0].guard=true;
  if(kind==='attackGuardFloor')enemies[0].def=25; // Controlled round/min1 boundary, not a new enemy stat rule.
  if(kind==='guard'){target=null;b.units.find(u=>u.id==='archer').next=2;}
  if(kind==='attackFixedMiss'){
    actionKind='guard';target=null;actor.pos=23;enemies[0].next=2;b.units.find(u=>u.id==='archer').next=3;
  }
  if(kind==='attackSequence'){
    enemies[0].next=2;enemies[1].next=3;b.units.find(u=>u.id==='archer').next=4;
  }
  if(kind==='sweepEmpty')enemies.forEach((u,i)=>{u.pos=[29,19,39][i];});
  if(kind==='sweepEdge')actor.pos=0;
  if(kind==='sweepAlreadySet')enemies[0].skipNextTurn=true;
  if(kind==='stampMiss'){actor.pos=22;target=23;} // Fixed right-hand column contains no enemies.
  if(kind==='stampEdge'){actor.pos=0;target=1;}
  if(['stampCover','attackCover','attackCoverGuarded'].includes(kind)){
    enemies.forEach((u,i)=>{u.pos=[26,25,36][i];});
    enemies[0].cover=enemies[1].id; // Legal adjacent guard outside the ground AoE.
    if(kind.startsWith('attack'))target=enemies[1].id;
    if(kind==='attackCoverGuarded')enemies[0].guard=true;
  }
  if(kind==='stampNextActor')b.units.find(u=>u.id==='archer').next=2;
  if(kind.startsWith('heal')){
    const friend=b.units.find(u=>u.id==='guard');friend.hp=friend.max-(kind==='healCapped'?8:kind==='healFull'?0:80);
    if(kind==='healSelf'){actor.hp=actor.max-12;target=actor.id;}
  }
  for(const e of enemies)B.plan(b,e);
  if(kind==='attackFixedMiss')enemies[0].intent={kind:'attack',target:'guard',name:'攻撃',reason:'固定セルが空になった確認用',cells:[24]};
  validate(s,kind);
  return {state:s,request:{op:'act',kind:actionKind,target,presentation:true},randomValue:0.99};
}

function geometry(b){
  const actor=b.units.find(u=>u.id===b.actor);
  if(!actor)return {ranges:{skill:[]},choices:{skill:[]},stampAreas:{},sweepCells:[]};
  const skill=B.activeSkill(actor),support=['mage','guard','porter','healingCross','defenseLine','manaGift'].includes(skill);
  const choices=B.skillTargets(b,actor);
  return {
    ranges:{skill:Array.from({length:50},(_,p)=>p).filter(p=>{
      const target=b.units.find(u=>u.hp>0&&u.pos===p);
      return B.inRange(actor,target?.side||(support?'ally':'enemy'),p,'skill',b);
    })},
    choices:{skill:choices},
    stampAreas:skill==='stamp'?Object.fromEntries(choices.map(p=>[p,B.stampCells(actor,p)])):{},
    sweepCells:skill==='legSweep'?B.sweepCells(actor):[],
  };
}

function observe(name){
  const {state,request,randomValue}=campaign(name),save=JSON.parse(C.serialize(state));
  assert.deepEqual(JSON.parse(C.serialize(C.deserialize(JSON.stringify(save)))),save,`${name} save roundtrip`);
  const initial=clone(state.battle),g=geometry(initial);
  const copy=C.deserialize(JSON.stringify(save));
  let directRandomCalls=0;
  const accepted=B.act(copy.battle,request.kind,request.target,()=>{directRandomCalls++;return randomValue;});
  validate(copy,`${name} direct final`);
  let observedRandomCalls=0;
  const observed=C.deserialize(JSON.stringify(save)),p=new Presentation();
  const began=p.start(observed.battle,B,()=>B.act(observed.battle,request.kind,request.target,()=>{observedRandomCalls++;return randomValue;}));
  assert.equal(began,accepted,`${name} accepted parity`);
  const frames=[];
  while(p.pending){
    const presentation=p.info();frames.push({presentation:clone(presentation),state:clone(p.pending.state)});
    assert(p.next(presentation.id,presentation.index));
  }
  validate(observed,`${name} observed final`);
  assert.deepEqual(JSON.parse(C.serialize(observed)),JSON.parse(C.serialize(copy)),`${name} observation changes no save result`);
  assert.equal(observedRandomCalls,directRandomCalls,`${name} observation consumes no extra random calls`);
  assert.deepEqual(clone(state.battle),initial,`${name} start boundary remains unmodified`);
  const impacts=frames.filter(f=>['hurt','heal'].includes(f.presentation.phase)).map(f=>{
    const phase=f.presentation;
    assert.equal(typeof phase.from,'number');assert.equal(typeof phase.to,'number');
    assert(phase.phase==='heal'?phase.to>phase.from:phase.to<phase.from);
    const action=frames.find(row=>row.presentation.phase==='action'&&row.presentation.action_id===phase.action_id)?.presentation;
    const recipient=f.state.units.find(u=>u.id===phase.unit_id);
    return {phase:phase.phase,unit_id:phase.unit_id,from:phase.from,to:phase.to,delta:phase.to-phase.from,actor_id:phase.actor_id,action_id:phase.action_id,guarding:!!recipient.guard,redirected:action?.kind==='attack'&&typeof action.target==='string'&&action.target!==phase.unit_id};
  });
  const settled=frames.find(f=>f.presentation.phase==='settled');
  const newSkips=settled?settled.state.units.filter(u=>u.skipNextTurn&&!initial.units.find(old=>old.id===u.id).skipNextTurn).map(u=>u.id):[];
  const expected={accepted,kind:request.kind,skill_id:request.kind==='skill'?B.activeSkill(initial.units.find(u=>u.id===initial.actor)):null,actor_id:initial.actor,target:request.target,
    cells:name.startsWith('sweep')?g.sweepCells:name.startsWith('stamp')?g.stampAreas[request.target]:[],impacts,new_skips:newSkips,
    random_calls:observedRandomCalls,final_actor:observed.battle.actor,frame_phases:frames.map(f=>f.presentation.phase),
    final_save_sha256:createHash('sha256').update(C.serialize(observed)).digest('hex')};
  if(accepted){
    assert.equal(frames[0].presentation.phase,'action');assert.equal(frames[0].presentation.skill_id,expected.skill_id);
    assert(frames.filter(f=>f.presentation.phase!=='action').every(f=>f.presentation.skill_id===undefined),`${name} skill_id belongs only to action`);
    if(name.startsWith('stamp')){
      const actions=frames.filter(f=>f.presentation.phase==='action');
      assert.deepEqual(actions.map(f=>f.presentation.kind),name==='stampNextActor'?['cast']:['cast','skill'],`${name} reservation precedes personal-opportunity resolution`);
      assert.equal(new Set(actions.map(f=>f.presentation.action_id)).size,actions.length,`${name} distinct reservation and resolution identities`);
      assert.equal(initial.units.find(u=>u.id===initial.actor).mp-observed.battle.units.find(u=>u.id===initial.actor).mp,1,`${name} reservation is charged once`);
    }else if(!['attackFixedMiss','attackSequence'].includes(name))assert.equal(new Set(frames.map(f=>f.presentation.action_id)).size,1,`${name} one causal action id`);
  }else{assert.equal(frames.length,0);assert.deepEqual(JSON.parse(C.serialize(observed)),save);}
  if(name==='sweep50')assert.deepEqual(newSkips,[]);
  if(name==='sweep100')assert.equal(newSkips.length,3);
  if(name==='sweepEmpty')assert.equal(observedRandomCalls,0);
  if(name==='sweepAlreadySet')assert.deepEqual(newSkips,[]);
  if(name==='sweepEdge')assert.deepEqual(expected.cells,[1,10,11]);
  if(name.startsWith('sweep'))assert.equal(impacts.length,0,`${name} no fabricated damage or healing`);
  if(name==='heal')assert.deepEqual(impacts.map(x=>[x.phase,x.unit_id,x.delta]),[['heal','guard',60]]);
  if(name==='healCapped')assert.deepEqual(impacts.map(x=>[x.phase,x.unit_id,x.delta]),[['heal','guard',8]]);
  if(name==='healSelf')assert.deepEqual(impacts.map(x=>[x.phase,x.unit_id,x.delta]),[['heal','mage',12]]);
  if(name==='healFull')assert.equal(accepted,false);
  if(name==='stamp')assert.equal(impacts.length,3);
  if(name==='stampMiss')assert.equal(impacts.length,0);
  if(name==='stampCover'){
    const protector=initial.units.find(u=>u.cover);
    assert.deepEqual(impacts.map(x=>x.unit_id),[protector.id]);
    assert(!expected.cells.includes(protector.pos),`${name} hurt recipient is outside ground cells`);
  }
  if(name==='stampEdge')assert.deepEqual(expected.cells,[1,11]);
  if(name==='stampNextActor'){
    assert.equal(expected.final_actor,'archer');assert.deepEqual(geometry(observed.battle).stampAreas,{});
    assert.equal(impacts.length,0);assert(observed.battle.units.find(u=>u.id===initial.actor).pendingStamp);
  }
  const actions=frames.filter(f=>f.presentation.phase==='action');
  expected.actions=actions.map(f=>({action_id:f.presentation.action_id,kind:f.presentation.kind,skill_id:f.presentation.skill_id,actor_id:f.presentation.actor_id,target:f.presentation.target}));
  expected.attack_misses=expected.actions.filter(action=>action.kind==='attack'&&!impacts.some(hit=>hit.action_id===action.action_id)).map(action=>action.action_id);
  if(name==='attackMelee')assert.deepEqual(impacts.map(hit=>hit.delta),[-26]);
  if(name==='attackRanged')assert.deepEqual(impacts.map(hit=>hit.delta),[-25]);
  if(name==='attackGuarded')assert.deepEqual(impacts.map(hit=>[hit.delta,hit.guarding]),[[-13,true]]);
  if(name==='attackGuardFloor'){
    assert.deepEqual(impacts.map(hit=>[hit.delta,hit.guarding]),[[-1,true]]);
    const target=initial.units.find(u=>u.id===request.target);const withoutGuard=clone(initial);withoutGuard.units.find(u=>u.id===target.id).guard=false;
    const withHit=B.attackPreview(initial,initial.units.find(u=>u.id===initial.actor),target).damage,withoutHit=B.attackPreview(withoutGuard,withoutGuard.units.find(u=>u.id===initial.actor),withoutGuard.units.find(u=>u.id===target.id)).damage;
    assert.equal(withHit,1);assert.equal(withoutHit,1);
    expected.rounding_boundary={guarded_hit:withHit,unguarded_hit:withoutHit,delta:0,validation_only:true};
  }
  if(name==='guard'){assert.equal(impacts.length,0);assert.equal(observed.battle.units.find(u=>u.id==='guard').guard,true);}
  if(name==='attackFixedMiss'){
    assert.equal(expected.attack_misses.length,1);assert.equal(impacts.length,0);
    const enemy=initial.units.find(u=>u.side==='enemy');
    assert(B.inRange(enemy,'ally',24,'attack',initial));assert(!initial.units.some(u=>u.hp>0&&u.pos===24));
  }
  if(name.startsWith('attackCover')){assert.equal(impacts.length,1);assert(impacts[0].redirected);assert.notEqual(request.target,impacts[0].unit_id);}
  if(name==='attackCoverGuarded')assert(impacts[0].guarding);
  if(name==='attackSequence'){assert(expected.actions.length>=3);assert(impacts.length>=3);assert(new Set(impacts.map(hit=>hit.action_id)).size>=3);}
  return {save,request,geometry:g,frames,expected};
}

const names=['sweep50','sweep100','sweepEmpty','sweepEdge','sweepAlreadySet','heal','healCapped','healSelf','healFull','stamp','stampMiss','stampCover','stampEdge','stampNextActor','attackMelee','attackRanged','attackGuarded','attackGuardFloor','attackCover','attackCoverGuarded','attackFixedMiss','attackSequence','guard'];
const cases=Object.fromEntries(names.map(name=>[name,observe(name)]));

function verifyBridge(){
  const rows=[];
  for(const [name,c] of Object.entries(cases)){
    const requests=[{op:'campaign_load',data:c.save},{op:'preview',kind:c.request.kind,target:c.request.target},{op:'campaign_save'}];
    const child=spawnSync(process.execPath,[require.resolve('../../native/bridge.cjs')],{input:requests.map(x=>JSON.stringify(x)).join('\n')+'\n',encoding:'utf8',timeout:15000,maxBuffer:16*1024*1024});
    assert.equal(child.status,0,`${name} bridge exits`);assert(!child.error,`${name} bridge transport`);
    const replies=child.stdout.trim().split(/\r?\n/).map(line=>JSON.parse(line));assert.equal(replies.length,3);
    const [loaded,preview,saved]=replies;assert(loaded.ok,`${name} actual bridge loads canonical save`);
    assert.equal(preview.presentation,undefined,`${name} preview never starts presentation`);
    assert.deepEqual(loaded.ranges.skill,c.geometry.ranges.skill,`${name} actual bridge ranges`);
    assert.deepEqual(loaded.choices.skill,c.geometry.choices.skill,`${name} actual bridge choices`);
    assert.deepEqual(loaded.stampAreas,c.geometry.stampAreas,`${name} actual bridge stampAreas`);
    assert.equal(preview.ok,c.expected.accepted,`${name} actual preview legality`);
    if(c.expected.accepted&&c.expected.cells.length)assert.deepEqual(preview.preview.cells,c.expected.cells,`${name} actual preview cells`);
    assert.deepEqual(saved.data,c.save,`${name} preview/inspection keeps exact save`);
    rows.push({name,passed:true,ranges:c.geometry.ranges.skill.length,cells:c.expected.cells.length,impacts:c.expected.impacts.length,new_skips:c.expected.new_skips.length});
  }
  return rows;
}

const meta={base:'3482e809b6160b0314eaf4bf2a735a71c7a9d885',synthetic:true,validated:true,
  note:'Frames are existing Presentation observations. Lv1 failure uses only B.act existing random callback in this QA process; no bridge RNG override. Each fixture resets its local action-id serial.',
  random_injection:'0.99 through B.act random argument only; production Math.random unmodified',count:names.length};
if(require.main===module){
  if(process.argv.includes('--verify'))console.log(JSON.stringify({meta,checks:verifyBridge()},null,2));
  else console.log(JSON.stringify({cases,meta}).replace(/[^\x00-\x7f]/g,c=>'\\u'+c.charCodeAt(0).toString(16).padStart(4,'0')));
}
module.exports={cases,meta,verifyBridge};
