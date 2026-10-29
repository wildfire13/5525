'use strict';
// Historical-ID fixtures retain the old roster; new-game/one-time migration
// behavior is tested separately in test_updateplan_roster.cjs.
const assert=require('node:assert/strict'),C=require('./campaign.js');
const clone=x=>JSON.parse(JSON.stringify(x));
let passed=0;
function test(name,fn){fn();console.log('PASS '+name);passed++;}
function okay(s){assert.equal(C.validate(s).ok,true,C.validate(s).error);assert.deepEqual(C.deserialize(C.serialize(s)),clone(s));}
function prep(){const s=require('./test-current-fixture.cjs')();assert(C.select(s,C.view(s).roster.map(u=>u.id).slice(0,12)));assert(C.depart(s,'east'));assert(C.travel(s,'safe',()=>.2));okay(s);return s;}
function reject(s,id,pos){const old=structuredClone(s);assert.equal(C.deployment_assign(s,id,pos),false);assert.deepEqual(s,old);}
test('twelve real travellers, twelve cap, five combat slots and strict legacy saves',()=>{
 const s=prep(),v=C.view(s);assert.equal(s.selected.length,12);assert.equal(v.partyLimit,12);assert.equal(v.battleLimit,5);assert.equal(v.deploymentRoster.remaining,0);assert.equal(v.deploymentRoster.reserves.length,7);
 const legacy=require('./test-current-fixture.cjs')();assert(!Object.hasOwn(legacy,'battleSelected'));okay(legacy);C.depart(legacy,'east');C.travel(legacy,'safe',()=>.2);legacy.battle.units=legacy.battle.units.filter(u=>u.id!=='guard');assert.equal(C.validate(legacy).ok,false);
 const before=structuredClone(s);assert.equal(C.select(s,[]),false);assert.deepEqual(s,before);
 // Cap-only boundary uses temporary synthetic templates, restored in finally;
 // the product roster remains eleven members.
 const B=require('./campaign-battle.js'),length=B.roster.length;
 try{for(const id of ['synthetic-12','synthetic-13'])B.roster.push({...B.roster[0],id});
  const town=require('./test-current-fixture.cjs')(),ids=B.roster.map(u=>u.id);assert(C.select(town,ids.slice(0,12)));okay(town);
  const before=structuredClone(town);assert.equal(C.select(town,ids),false);assert.deepEqual(town,before);
 }finally{B.roster.length=length;}

});
test('full replacement, addition, move/swap and rejected drops are atomic',()=>{
 const s=prep();reject(s,'warrior',0);reject(s,'warrior',49);reject(s,'bogus',23);reject(s,'warrior',1.5);reject(s,'warrior',null);
 const out=s.battle.units.find(u=>u.id==='guard'),pos=out.pos;assert(C.deployment_assign(s,'warrior',pos));assert(!s.battleSelected.includes('guard'));assert(s.battleSelected.includes('warrior'));okay(s);
 const mage=s.battle.units.find(u=>u.id==='mage'),old=mage.pos;assert(C.deployment_assign(s,'mage',pos));assert.equal(s.battle.units.find(u=>u.id==='warrior').pos,old);okay(s);
 assert(C.deployment_assign(s,'mage',null));assert(C.deployment_assign(s,'guard',old===pos?0:0));okay(s);
 const stale=clone(s);stale.battleSelected.push('guard');assert.equal(C.validate(stale).ok,false);
});
test('empty preparation persists, cannot start, reset/formation do not resurrect',()=>{
 let s=prep();for(const id of [...s.battleSelected])assert(C.deployment_assign(s,id,null));okay(s);const before=structuredClone(s);assert.equal(C.begin(s),false);assert.deepEqual(s,before);assert(C.chooseFormation(s,'flank'));assert(C.deployment_reset(s));assert.equal(s.battleSelected.length,0);s=C.deserialize(C.serialize(s));assert(C.deployment_assign(s,'warrior',23));assert(C.chooseFormation(s,'convoy'));assert(C.deployment_reset(s));okay(s);assert(C.begin(s));okay(s);reject(s,'guard',23);
});
test('reserves keep HP/MP/items; EXP and camp recovery retain travelling-party policy',()=>{
 const s=prep();const reserve=s.characters['guard-2'];reserve.hp-=20;reserve.mp=0;const inv=clone(reserve.inventory),hp=reserve.hp,xp=reserve.xp;
 assert(C.begin(s));for(const u of s.battle.units)if(u.side==='enemy')u.hp=0;s.battle.result='勝利';assert(C.finishBattle(s));assert.equal(reserve.hp,hp);assert.equal(reserve.mp,0);assert.deepEqual(reserve.inventory,inv);assert.equal(reserve.xp,xp+20);assert.equal(s.journey.party.length,12);okay(s);
 assert(C.rest(s));assert.equal(reserve.hp,Math.min(C.stats(reserve).max,hp+60));assert.equal(reserve.mp,Math.min(C.stats(reserve).maxMp,2));okay(s);assert(C.onward(s));assert(C.travel(s,'safe',()=>.2));assert.equal(s.battleSelected.length,5);okay(s);
});
test('porter acceptance and deployed-death failure unchanged; bench porter not mandatory',()=>{
 const s=prep();assert(C.deployment_assign(s,'porter',null));assert(C.begin(s));okay(s);
 const town=require('./test-current-fixture.cjs')();assert(C.select(town,['guard']));assert.equal(C.accept(town,C.board(town)[0].id,'guard'),false);
 const dead=require('./test-current-fixture.cjs')();dead.characters.porter.hp=0;assert.equal(C.depart(dead,'east'),false);
 const fail=prep();assert(C.begin(fail));fail.battle.units.find(u=>u.id==='porter').hp=0;fail.battle.failure=true;fail.battle.result='敗北';assert(C.finishBattle(fail));assert.equal(fail.result.outcome,'failed');okay(fail);
});


const {spawnSync}=require('node:child_process');
test('bridge exposes canonical deployment action and view after save/load',()=>{
 const s=prep(),requests=[{op:'campaign_load',data:C.serialize(s)},{op:'campaign',action:'deployment_assign',args:['porter',null]},{op:'campaign',action:'deployment_assign',args:['warrior',23]},{op:'campaign_save'}];
 const run=spawnSync(process.execPath,['bridge.cjs'],{cwd:__dirname,input:requests.map(x=>JSON.stringify(x)).join('\n')+'\n',encoding:'utf8',maxBuffer:8e6});assert.equal(run.status,0,run.stderr);
 const replies=run.stdout.trim().split('\n').map(JSON.parse);assert(replies.every(x=>x.ok));assert(replies[1].campaign.deploymentRoster.reserves.includes('porter'));assert(replies[2].campaign.battleSelected.includes('warrior'));okay(C.deserialize(replies[3].data));
});

test('repeat remove/add/load consumes no inventory or gameplay RNG; invalid begin is atomic',()=>{
 let s=prep();const chars=structuredClone(s.characters),random=Math.random;let calls=0;
 try{Math.random=()=>{calls++;throw Error('deployment consumed gameplay random');};
  for(let n=0;n<20;n++){assert(C.deployment_assign(s,'guard',null));assert(C.deployment_assign(s,'guard',23));s=C.deserialize(C.serialize(s));}
  assert(C.chooseFormation(s,'flank'));assert(C.deployment_reset(s));assert(C.chooseFormation(s,'convoy'));assert(C.deployment_reset(s));
  assert.equal(calls,0);assert.deepEqual(s.characters,chars);assert.equal(s.battle.itemInventories.guard.potion,3);assert.equal(s.battle.potions.ally,3);
 }finally{Math.random=random;}
 const bad=structuredClone(s);bad.battleSelected=['guard'];const before=structuredClone(bad);assert.equal(C.begin(bad),false);assert.deepEqual(bad,before);assert.equal(C.view(bad).deploymentRoster.canBegin,false);
 const dead=prep();for(const u of dead.battle.units)if(u.side==='ally')u.hp=0;const old=structuredClone(dead);assert.equal(C.begin(dead),false);assert.deepEqual(dead,old);
});


test('same-job member tie uses canonical nonzero index after replace/remove/re-add/load',()=>{
 const B=require('./campaign-battle.js');let s=prep();
 function ties(){const expected=B.create({ally:s.battleSelected,enemy:[],deployment:true}).units;assert.deepEqual(s.battle.units.filter(u=>u.side==='ally').map(u=>[u.id,u.tie]),expected.map(u=>[u.id,u.tie]));}
 const guard=s.battle.units.find(u=>u.id==='guard');assert(C.deployment_assign(s,'guard-2',guard.pos));ties();
 assert(C.deployment_assign(s,'porter',null));assert(C.deployment_assign(s,'guard',0));ties();
 const guards=s.battle.units.filter(u=>u.job==='guard'&&u.side==='ally');assert.equal(guards.length,2);assert(guards.every(u=>s.battleSelected.indexOf(u.id)>0));assert(guards[0].tie<guards[1].tie,'existing same-job earlier member remains earlier');
 const ids=[...s.battleSelected],before=guards.map(u=>[u.id,u.tie]);assert(C.deployment_assign(s,'mage',1));assert.deepEqual(s.battleSelected,ids);assert.deepEqual(s.battle.units.filter(u=>u.job==='guard'&&u.side==='ally').map(u=>[u.id,u.tie]),before);
 assert(C.deployment_assign(s,'guard-2',null));ties();assert(C.deployment_assign(s,'guard-2',2));ties();s=C.deserialize(C.serialize(s));ties();okay(s);
 assert(C.chooseFormation(s,'flank'));assert(C.deployment_reset(s));ties();assert(C.begin(s));okay(s);
});
test('dead non-porter occupies legacy slot but can be explicitly removed without revival',()=>{
 const s=require('./test-current-fixture.cjs')();assert(C.select(s,['guard','archer','mage','scout','warrior','guard-2']));s.characters.warrior.hp=0;assert(C.depart(s,'east'));assert(C.travel(s,'safe',()=>.2));
 assert(s.battleSelected.includes('warrior'));assert.equal(s.battleSelected.length,5);okay(s);const chars=structuredClone(s.characters);reject(s,'guard-2',0);
 assert(C.deployment_assign(s,'warrior',null));assert.equal(s.characters.warrior.hp,0);assert.equal(C.view(s).deploymentRoster.remaining,1);okay(s);
 assert(C.deployment_assign(s,'guard-2',0));assert.deepEqual(s.characters,chars);assert(C.begin(s));okay(s);
});


test('flank initial/reset collisions relocate only conflicting allies and keep scout anchor',()=>{
 for(const ids of [['guard-2','scout','guard','mage','archer'],['scout-2','scout','guard-2','porter','warrior']]){
  const s=require('./test-current-fixture.cjs')();assert(C.select(s,ids));assert(C.depart(s,'east','flank'));assert(C.travel(s,'safe',()=>.2));
  const positions=()=>s.battle.units.filter(u=>u.side==='ally').map(u=>u.pos);
  assert.equal(new Set(positions()).size,ids.length);assert.equal(s.battle.units.find(u=>u.job==='scout').pos,14);okay(s);
  assert(C.chooseFormation(s,'convoy'));assert(C.deployment_reset(s));okay(s);assert(C.chooseFormation(s,'flank'));assert(C.deployment_reset(s));okay(s);assert(C.begin(s));okay(s);
 }
});
console.log(`${passed} deployment roster tests passed`);
