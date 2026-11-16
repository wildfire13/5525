'use strict';
const assert=require('node:assert/strict'),B=require('./campaign-battle.js'),C=require('./campaign.js'),E=require('./equipment-skills.js');
let count=0;const test=(name,fn)=>{fn();count++;console.log('PASS '+name);};
const clone=x=>JSON.parse(JSON.stringify(x));
function transferInventory(s,from,to){
 for(const [id,amount] of Object.entries(s.characters[from].inventory))assert(C.inventoryAction(s,from,id,'transfer',to,amount,null,C.inventoryToken(s)),id);
}
function scene(skill='skill_retreat_slash'){
 const s=B.create({ally:["character_mirei","character_kyle","character_merina","character_yuno"],enemy:['guard','archer'],enemyPotions:0,deployment:true,skillStage:1});
 const [a,f,g,p,e,e2]=s.units;a.pos=24;f.pos=14;g.pos=34;p.pos=2;e.pos=25;e2.pos=15;
 a.equippedSkill=skill;a.atk=40;a.mp=a.maxMp=8;a.reach=3;
 for(const u of s.units)u.next=1e6;a.next=10;s.deploying=false;s.actor=a.id;
 return {s,a,f,g,p,e,e2};
}
const once=(s,a,k,t)=>{s.actor=a.id;a.next=10;for(const u of s.units)if(u!==a)u.next=1e6;assert.equal(B.act(s,k,t),true);};
test('retreat slash: damage, fixed rear, blocker, edge, MP, rejected atomicity',()=>{
 const {s,a,f,e}=scene();f.pos=23;const before=clone(s);assert.equal(B.act(s,'action_skill',e.id),false);assert.deepEqual(s,before);
 f.pos=14;once(s,a, 'action_skill',e.id);assert.equal(a.pos,23);assert.equal(e.hp,e.max-28);assert.equal(a.mp,7);
 a.pos=20;e.pos=21;assert.equal(B.legal(s,'action_skill',e.id),false);
 a.pos=24;e.pos=25;a.mp=0;assert.equal(B.legal(s,'action_skill',e.id),false);
});
test('skill_knockback: empty, occupied, edge, lethal and forced side boundary',()=>{
 for(const blocked of [false,true]){const {s,a,e,e2}=scene('skill_knockback');e2.pos=blocked?26:15;once(s,a, 'action_skill',e.id);assert.equal(e.pos,blocked?25:26);assert.equal(e.hp,e.max-40);}
 const {s,a,e}=scene('skill_knockback');a.pos=28;e.pos=29;once(s,a, 'action_skill',e.id);assert.equal(e.pos,29);
 a.pos=24;e.pos=25;e.hp=1;once(s,a, 'action_skill',e.id);assert.equal(e.hp,0);assert.equal(e.pos,25);
 const t=scene('skill_knockback');t.a.pos=25;t.e.pos=24;once(t.s,t.a, 'action_skill',t.e.id);assert.equal(t.e.pos,23);
});
test('split shot: two distinct selected enemies, reach3, 60%, one cost, reject duplicate/dead/single',()=>{
 const {s,a,e,e2}=scene('skill_split_shot');
 for(const target of [[e.id,e.id],[e.id],e.id,[e.id,'skill_heal']]){const old=clone(s);assert.equal(B.act(s,'action_skill',target),false);assert.deepEqual(s,old);}
 e2.pos=28;assert.equal(B.legal(s,'action_skill',[e.id,e2.id]),false);e2.pos=15;
 once(s,a, 'action_skill',[e.id,e2.id]);assert.equal(e.hp,e.max-24);assert.equal(e2.hp,e2.max-24);assert.equal(a.mp,7);
 e2.hp=0;assert.equal(B.legal(s,'action_skill',[e.id,e2.id]),false);
});
test('skill_pincer: allied adjacency to target, no diagonal/dead ally bonus',()=>{
 for(const [pos,hp,damage] of [[15,100,60],[14,100,40],[15,0,40]]){const {s,a,f,e,e2}=scene('skill_pincer');e2.pos=35;f.pos=pos;f.hp=hp;once(s,a, 'action_skill',e.id);assert.equal(e.hp,e.max-damage);}
});
test('healing cross: self or ally center, clipped grid, allies only, injured area, MP2',()=>{
 const {s,a,f,g,e}=scene('skill_healing_cross');a.hp-=40;f.hp-=20;g.hp-=60;e.hp-=50;
 assert.equal(B.legal(s,'action_skill',a.id),true);once(s,a, 'action_skill',a.id);assert.equal(a.hp,a.max-10);assert.equal(f.hp,f.max);assert.equal(g.hp,g.max-30);assert.equal(e.hp,e.max-50);assert.equal(a.mp,6);
 assert.deepEqual(B.crossCells(0),[0,1,10]);assert.equal(B.crossCells(9).includes(10),false);
 a.mp=1;assert.equal(B.legal(s,'action_skill',a.id),false);
});
test('defense line: two protected, deterministic nonrecursive cover, expiration and death',()=>{
 const {s,a,f,g}=scene('skill_defense_line');
 assert.equal(B.legal(s,'action_skill',[f.id,f.id]),false);assert.equal(B.legal(s,'action_skill',[a.id]),false);
 // Keep another ally ahead so the caster does not immediately start its next turn.
 f.next=11;assert.equal(B.act(s,'action_skill',[f.id,g.id]),true);assert.deepEqual(a.covers,[f.id,g.id]);
 let hp=a.hp;B.receive(s,f,20,false);B.receive(s,g,20,false);assert.equal(a.hp,hp-40);assert.equal(f.hp,f.max);assert.equal(g.hp,g.max);
 g.covers=[f.id];B.receive(s,f,10,false);assert.equal(a.hp,hp-50);assert.equal(g.hp,g.max);
 a.next=11;f.next=10;s.actor=f.id;assert.equal(B.act(s,'action_defend'),true);assert.deepEqual(a.covers,[]);
 a.covers=[f.id];a.hp=1;B.receive(s,f,5,false);assert.equal(a.hp,0);assert.deepEqual(a.covers,[]);g.covers=[];f.guard=false;hp=f.hp;B.receive(s,f,5,false);assert.equal(f.hp,hp-5);
});
test('MP transfer conserves total, capacity clipped, no self or empty transfer',()=>{
 const {s,a,f}=scene('skill_mana_gift');a.mp=3;f.mp=f.maxMp-1;const sum=a.mp+f.mp;once(s,a, 'action_skill',f.id);assert.equal(a.mp,2);assert.equal(f.mp,f.maxMp);assert.equal(a.mp+f.mp,sum);
 assert.equal(B.legal(s,'action_skill',f.id),false);assert.equal(B.legal(s,'action_skill',a.id),false);f.mp=0;a.mp=0;assert.equal(B.legal(s,'action_skill',f.id),false);
 a.mp=1;once(s,a, 'action_skill',f.id);assert.equal(a.mp,0);assert.equal(f.mp,1);
});
test('return: exact home cell, occupancy, 1/battle, zero MP, second slot invasion',()=>{
 const {s,a,f}=scene();a.effects=['skill_return_home'];a.mp=0;a.pos=27;
 for(const p of [27,25,f.pos,-1,50,'3'])assert.equal(B.legal(s,'action_return',p),false);
 once(s,a, 'action_return',3);assert.equal(a.pos,3);assert.equal(a.mp,0);assert.equal(a.returnUsed,true);assert.equal(B.legal(s,'action_return',4),false);
 const c=require('./test-current-fixture.cjs')();c.gold=5000;c.location='north';c.characters['character_rio'].accessory1='invasion-charm-1';
 assert.equal(C.buyGear(c,"character_rio",'return-ring-2','accessory2'),true);assert(C.stats(c.characters["character_rio"]).effects.includes('skill_invasion'));assert(C.stats(c.characters["character_rio"]).effects.includes('skill_return_home'));
 assert.equal(C.buyGear(c,"character_rio",'empty-accessory1','accessory1'),true);assert(!C.stats(c.characters["character_rio"]).effects.includes('skill_invasion'));assert(C.stats(c.characters["character_rio"]).effects.includes('skill_return_home'));
});
test('lone wolf: living orthogonal friend suppresses; duplicate effect no stacking',()=>{
 for(const [pos,hp,damage] of [[14,100,40],[13,100,40],[13,0,40]]){
  const {s,a,f,g,e}=scene();a.effects=['skill_lone_wolf','skill_lone_wolf'];f.pos=pos;f.hp=hp;g.pos=34;once(s,a, 'action_attack',e.id);assert.equal(e.hp,e.max-damage);
 }
 const {s,a,f,g,e}=scene();a.effects=['skill_lone_wolf','skill_lone_wolf'];f.pos=13;g.pos=32;once(s,a, 'action_attack',e.id);assert.equal(e.hp,e.max-50);assert.equal(s.skillEvents.filter(x=>x.skillId==='skill_lone_wolf').length,1);
});
test('first stride: actual BFS +1 once, no invasion, failed action does not consume, porter swap',()=>{
 const {s,a,f,g}=scene();a.effects=['skill_first_stride'];a.pos=20;f.pos=4;g.pos=34;
 assert.equal(B.legal(s,'action_move',23),true);assert.equal(B.legal(s,'action_move',25),false);assert.equal(B.act(s,'action_move',25),false);assert.equal(a.firstMoveUsed,undefined);
 once(s,a, 'action_move',21);assert.equal(a.firstMoveUsed,true);assert.equal(B.moveReach(a),2);assert.equal(B.legal(s,'action_move',24),false);
 const t=scene();t.p.effects=['skill_first_stride'];t.p.pos=0;t.f.pos=3;t.s.actor=t.p.id;assert.equal(B.legal(t.s,'action_move',3),true);once(t.s,t.p, 'action_move',3);assert.equal(t.f.pos,0);assert.equal(t.p.firstMoveUsed,true);
});
test('victory breath: once, capped, living only; defeat and retreat have no reward',()=>{
 const {s,a,f,e,e2}=scene();a.effects=['skill_victory_breath','skill_victory_breath'];f.effects=['skill_victory_breath'];a.mp=7;f.mp=0;f.hp=0;e.hp=1;e2.hp=0;
 once(s,a, 'action_attack',e.id);assert.ok(s.result);assert.equal(a.mp,8);assert.equal(f.mp,0);assert.equal(s.skillEvents.filter(x=>x.skillId==='skill_victory_breath').length,1);assert.equal(B.act(s,'action_defend'),false);assert.equal(a.mp,8);
 const t=scene();t.a.effects=['skill_victory_breath'];t.a.mp=1;t.p.hp=0;once(t.s,t.a, 'action_defend');assert.equal(t.s.failure,'porter');assert.equal(t.a.mp,1);
});
test('passive trial works for melee/ranged and porter keeps attack ban',()=>{
 for(const id of ['character_mirei','character_grant','character_merina','character_yuno']){
  const s=C.create();s.location='north';s.selected=[id,...["character_yuno","character_mirei"].filter(x=>x!==id)];
  const before=C.serialize(s),t=C.trial(s,id,'victory-earring-1');assert.ok(t,id);
  const hero=t.battle.units.find(u=>u.id===id),dummy=t.battle.units.find(u=>u.side==='enemy');
  assert.equal(t.battle.units.filter(u=>u.side==='enemy').length,1);
  const mp=hero.mp;
  if(hero.job==='job_porter'){
   assert.equal(B.legal(t.battle,'action_attack',dummy.id),false);
   assert.equal(C.trialAct(t, 'action_defend'),true);
  }else assert.equal(C.trialAct(t, 'action_attack',dummy.id),true);
  assert.ok(t.battle.result,id);assert.equal(hero.mp,mp+2,id);
  assert.equal(t.battle.skillEvents.filter(e=>e.actorId===id&&e.skillId==='skill_victory_breath').length,1);
  assert.equal(C.serialize(s),before);
  const lone=C.trial(s,id,'lone-ring-1');assert.ok(lone,id);
  const a=lone.battle.units.find(u=>u.id===id),target=lone.battle.units.find(u=>u.side==='enemy');
  if(a.job==='job_porter'){
   assert.equal(B.legal(lone.battle,'action_attack',target.id),false);
   assert.equal(C.trialAct(lone, 'action_defend'),true);
   assert.equal((lone.battle.skillEvents||[]).some(e=>e.skillId==='skill_lone_wolf'),false);
  }else{
   assert.equal(lone.battle.units.some(u=>u.side==='ally'&&u!==a&&B.range(a,u)===1),false);
   const hp=target.hp;assert.equal(C.trialAct(lone, 'action_attack',target.id),true);
   assert.equal(hp-target.hp,Math.max(0,Math.round(a.atk*1.25-target.def)));
   assert.ok(lone.battle.skillEvents.some(e=>e.skillId==='skill_lone_wolf'&&e.actorId===id));
  }
  assert.equal(C.serialize(s),before);
 }
});
test('purchase and trial all eleven; actual actions isolated from campaign',()=>{
 const rows=E.gear.filter(g=>g.slot==='weapon'||g.slot==='accessory1'&&g.effect&&g.effect!=='skill_invasion');
 assert.equal(rows.length,11);
 for(const gear of rows){
  // The shared fixture supplies inventory capacity for the commerce roundtrip.
  const s=require('./test-current-fixture.cjs')();assert(C.select(s,[...s.selected,'character_kyle']));s.characters['character_kyle'].weapon='bow-wood';s.location=gear.slot==='weapon'?'east':'north';s.gold=5000;
  const id=gear.skill==='skill_split_shot'||gear.skill==='skill_pincer'?'character_kyle':'character_merina';
  const before=C.serialize(s),t=C.trial(s,id,gear.id);assert.ok(t,gear.id);assert.equal(C.serialize(s),before);
  const a=t.battle.units.find(u=>u.id===id),sid=B.activeSkill(a);
  if(gear.skill){const targets=B.skillTargets(t.battle,a);assert.ok(targets.length,gear.id);assert.equal(C.trialAct(t, 'action_skill',targets[0]),true);}
  else if(gear.effect==='skill_return_home')assert.equal(C.trialAct(t, 'action_return',3),true);
  else if(gear.effect==='skill_first_stride')assert.equal(C.trialAct(t, 'action_move',23),true);
  else if(gear.effect==='skill_lone_wolf'){assert.equal(C.trialAct(t, 'action_move',23),true);assert.equal(C.trialAct(t, 'action_attack','enemy-guard'),true);assert.ok(t.battle.skillEvents.some(e=>e.skillId==='skill_lone_wolf'));}
  else if(gear.effect==='skill_victory_breath'){
   for(const u of t.battle.units.filter(u=>u.side==='enemy')){if(!B.legal(t.battle,'action_attack',u.id)){const moves=[...B.paths(t.battle,a,2).keys()].filter(p=>B.legal(t.battle,'action_move',p)&&B.range({pos:p},u)<=a.reach);assert.ok(moves.length);assert.equal(C.trialAct(t, 'action_move',moves[0]),true);}assert.equal(C.trialAct(t, 'action_attack',u.id),true);}
   assert.ok(t.battle.result);assert.ok(t.battle.skillEvents.some(e=>e.skillId==='skill_victory_breath'));
  }
  assert.equal(C.serialize(s),before);assert.equal(C.buyGear(s,id,gear.id),true);assert.equal(s.characters[id][gear.slot],gear.id);assert.deepEqual(C.deserialize(C.serialize(s)),s);
 }
});
test('save/load battle flags, effects and covers; malformed extension rejected',()=>{
  const s=require('./test-current-fixture.cjs')();s.gold=1000;s.location='east';assert(C.buyGear(s,"character_mirei",'battleline-shield'));s.location='north';assert(C.buyGear(s,"character_mirei",'return-ring-1'));assert(C.buyGear(s,"character_mirei",'pioneer-gloves-2'));
 // Both accessories are under test, so the replaced capacity pouch and other
 // carried supplies move to the porter before departure.
 transferInventory(s,"character_mirei","character_yuno");assert(C.depart(s,'astaris'));assert(C.travel(s,'safe',()=>.2));assert(C.begin(s));
  const a=s.battle.units.find(u=>u.id==="character_mirei");a.returnUsed=true;a.firstMoveUsed=true;a.covers=["character_rio","character_merina"];
 const saved=C.serialize(s),loaded=C.deserialize(saved),expected=clone(s);
 expected.battle.units.find(u=>u.id==="character_mirei").returnUsedGrants=Object.fromEntries(B.returnSkillOptions(a).map(o=>[o.key,true]));
 assert.deepEqual(loaded,expected);assert.equal(B.legalFor(loaded.battle,loaded.battle.units.find(u=>u.id==="character_mirei"), 'action_return',0),false);
 for(const change of [u=>u.returnUsed='no',u=>u.firstMoveUsed=1,u=>u.effects=['skill_lone_wolf'],u=>u.covers=['missing'],u=>u.covers=["character_merina","character_merina"]]){const bad=JSON.parse(saved);change(bad.state.battle.units.find(u=>u.id==="character_mirei"));assert.throws(()=>C.deserialize(bad));}
 assert.equal(C.retreat(loaded),true);assert.equal(loaded.result.outcome,'failed');assert.equal(loaded.battle,null);
});
test('porter never attacks or gains offensive weapon skill; separate return remains usable',()=>{
  const s=C.create();s.location='east';s.gold=500;assert(C.buyGear(s,"character_yuno",'breaker-hammer','leftHand'));
  s.location='north';assert(C.buyGear(s,"character_yuno",'return-ring-1','accessory1'));
  transferInventory(s,"character_yuno","character_mirei");
  const before=C.serialize(s);
  assert.equal(C.buyGear(s,"character_yuno",'invasion-charm-2','accessory2'),false);
  assert.equal(C.serialize(s),before);assert.equal(s.characters["character_yuno"].accessory2,'porter-bag');
  assert(C.depart(s,'astaris'));assert(C.travel(s,'safe',()=>.2));assert(C.begin(s));
  const p=s.battle.units.find(u=>u.id==="character_yuno");assert.equal(B.activeSkill(p),'skill_formation_boost');assert.equal(p.atk,0);assert.equal(p.canDeployEnemySide,false);assert.equal(B.legalFor(s.battle,p,'action_attack','enemy-guard'),false);assert.equal(B.legalFor(s.battle,p,'action_return',0),true);
  assert(C.retreat(s));assert(C.acknowledge(s));
  assert(C.buyGear(s,"character_yuno",'invasion-charm-1','accessory1'));
  assert(C.depart(s,'astaris'));assert(C.travel(s,'safe',()=>.2));assert(C.begin(s));
  const invader=s.battle.units.find(u=>u.id==="character_yuno");
  assert.equal(invader.canDeployEnemySide,true);assert.equal(B.activeSkill(invader),'skill_formation_boost');assert.equal(invader.atk,0);
  assert.equal(B.legalFor(s.battle,invader,'action_attack','enemy-guard'),false);assert.equal(B.legalFor(s.battle,invader,'action_return',0),false);
});
test('public battle actions save real once-per-battle flags and retreat resets next encounter',()=>{
  const s=require('./test-current-fixture.cjs')();s.location='north';C.buyGear(s,"character_mirei",'return-ring-1');C.buyGear(s,"character_mirei",'pioneer-gloves-2');
 transferInventory(s,"character_mirei","character_yuno");assert(C.depart(s,'astaris'));assert(C.travel(s,'safe',()=>.2));assert(C.begin(s));
 function guardTurn(){for(let i=0;i<30&&s.battle.actor!=="character_mirei"&&!s.battle.result;i++)assert.equal(C.act(s,'action_defend'),true);assert.equal(s.battle.actor,"character_mirei");}
 guardTurn();assert.equal(C.act(s,'action_return',0),true);guardTurn();assert.equal(C.act(s,'action_move',1),true);
 const loaded=C.deserialize(C.serialize(s)),hero=loaded.battle.units.find(u=>u.id==="character_mirei");assert.ok(B.returnSkillOptions(hero).every(o=>o.used));assert.equal(Object.keys(hero.returnUsedGrants).length,1);assert.equal(hero.firstMoveUsed,true);
 assert.deepEqual(loaded.battle.skillEvents.map(e=>e.skillId),['skill_return_home','skill_first_stride']);
 assert.equal(C.retreat(s),true);C.acknowledge(s);C.depart(s,'astaris');C.travel(s,'safe',()=>.2);
 const fresh=s.battle.units.find(u=>u.id==="character_mirei");assert.equal(fresh.returnUsed,undefined);assert.equal(fresh.returnUsedGrants,undefined);assert.equal(fresh.firstMoveUsed,undefined);assert.equal(B.moveReach(fresh),3);
});
test('victory reward passes into campaign party once and survives reload',()=>{
 const s=require('./test-current-fixture.cjs')();s.location='north';C.buyGear(s,"character_mirei",'victory-earring-1');C.depart(s,'astaris');C.travel(s,'safe',()=>.2);C.begin(s);
 for(let i=0;i<250&&!s.battle.result;i++){const copy=clone(s.battle),a=copy.units.find(u=>u.id===copy.actor);const action=B.chooseAction(copy,a);assert.equal(C.act(s,action.kind,action.target),true);}
 assert.ok(s.battle.result);assert.equal(s.battle.failure,undefined);
 const hero=s.battle.units.find(u=>u.id==="character_mirei");assert.ok(hero.hp>0);const mp=hero.mp;
 assert.equal(s.battle.skillEvents.filter(e=>e.skillId==='skill_victory_breath').length,1);
 const loaded=C.deserialize(C.serialize(s));assert.equal(C.finishBattle(loaded),true);assert.equal(loaded.characters["character_mirei"].mp,mp);assert.equal(loaded.journey.party.find(u=>u.id==="character_mirei").mp,mp);assert.equal(C.finishBattle(loaded),false);
 assert.equal(C.deserialize(C.serialize(loaded)).characters["character_mirei"].mp,mp);
});
console.log(`PASS ${count} equipment-skill groups`);
