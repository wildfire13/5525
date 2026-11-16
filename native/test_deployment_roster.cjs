'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js'),B=require('./campaign-battle.js');
const clone=x=>JSON.parse(JSON.stringify(x));
let passed=0;
function test(name,fn){fn();console.log('PASS '+name);passed++;}
function okay(s){assert.equal(C.validate(s).ok,true,C.validate(s).error);assert.deepEqual(C.deserialize(C.serialize(s)),clone(s));}
function prep(inventories={}){const s=require('./test-current-fixture.cjs')();const ids=[...s.selected,'character_sera','character_grant','character_roze','character_lucia','character_teo','character_gareth','character_orm'];assert(C.select(s,ids));for(const [id,stock] of Object.entries(inventories))s.characters[id].inventory=structuredClone(stock);assert(C.depart(s,'east'));assert(C.travel(s,'safe',()=>.2));okay(s);return s;}
function reject(s,id,pos){const old=structuredClone(s);assert.equal(C.deployment_assign(s,id,pos),false);assert.deepEqual(s,old);}
test('twelve real travellers, twelve cap, five combat slots and invalid deployment detection',()=>{
 const s=prep(),v=C.view(s);assert.equal(s.selected.length,12);assert.equal(v.partyLimit,12);assert.equal(v.battleLimit,5);assert.equal(v.deploymentRoster.remaining,0);assert.equal(v.deploymentRoster.reserves.length,7);
 const legacy=require('./test-current-fixture.cjs')();assert(!Object.hasOwn(legacy,'battleSelected'));okay(legacy);C.depart(legacy,'east');C.travel(legacy,'safe',()=>.2);legacy.battle.units=legacy.battle.units.filter(u=>u.id!=="character_mirei");assert.equal(C.validate(legacy).ok,false);
 const before=structuredClone(s);assert.equal(C.select(s,[]),false);assert.deepEqual(s,before);
  // The real 24-person roster supplies both sides of the 12-person boundary.
  {
   const town=require('./test-current-fixture.cjs')(),ids=C.view(town).roster.map(u=>u.id);assert.equal(ids.length,24);assert(C.select(town,ids.slice(0,12)));okay(town);
   const before=structuredClone(town);assert.equal(C.select(town,ids),false);assert.deepEqual(town,before);
  }

});
test('invasion permits enemy-side deployment by active and reserve Scouts only',()=>{
 const s=require('./test-current-fixture.cjs')();
 const selected=["character_mirei","character_kyle","character_merina","character_rio","character_yuno","character_sera","character_roze","character_lucia"];
 for(const id of ['character_rio','character_lucia'])s.characters[id].accessory1='invasion-charm-1';
 assert(C.select(s,selected));assert(C.depart(s,'east'));assert(C.travel(s,'safe',()=>0));okay(s);
 const before=structuredClone(s);assert.equal(C.deployment_assign(s,"character_mirei",7),false);assert.deepEqual(s,before,'non-invader enemy-side rejection is atomic');
 const initialScoutCell=s.battle.units.find(u=>u.id==='character_rio').pos;
 assert.equal(C.deployment_assign(s,"character_rio",6),true,'deployed Scout may enter the enemy side');assert.equal(s.battle.units.find(u=>u.id==="character_rio").pos,6);okay(s);
 assert.equal(C.deployment_assign(s,"character_rio",initialScoutCell),true,'deployed Scout may return to the ally side');
 assert.equal(C.deployment_assign(s,"character_mirei",null),true,'free one combat slot for reserve');
 assert.equal(C.deployment_assign(s,"character_lucia",7),true,'reserve Scout may be added directly to the enemy side');
 assert.equal(s.battle.units.find(u=>u.id==="character_lucia").pos,7);assert.equal(s.battle.units.find(u=>u.id==="character_mirei"),undefined);okay(s);
});
test('full replacement, addition, move/swap and rejected drops are atomic',()=>{
 const s=prep();reject(s,"character_grant",0);reject(s,"character_grant",49);reject(s,'bogus',23);reject(s,"character_grant",1.5);reject(s,"character_grant",null);
 const out=s.battle.units.find(u=>u.id==="character_mirei"),pos=out.pos;assert(C.deployment_assign(s,"character_grant",pos));assert(!s.battleSelected.includes("character_mirei"));assert(s.battleSelected.includes("character_grant"));okay(s);
 const mage=s.battle.units.find(u=>u.id==="character_merina"),old=mage.pos;assert(C.deployment_assign(s,"character_merina",pos));assert.equal(s.battle.units.find(u=>u.id==="character_grant").pos,old);okay(s);
 assert(C.deployment_assign(s,"character_merina",null));assert(C.deployment_assign(s,"character_mirei",old===pos?0:0));okay(s);
 const stale=clone(s);stale.battleSelected.push("character_mirei");assert.equal(C.validate(stale).ok,false);
});
test('empty preparation persists, cannot start, reset/formation do not resurrect',()=>{
 let s=prep();for(const id of [...s.battleSelected])assert(C.deployment_assign(s,id,null));okay(s);const before=structuredClone(s);assert.equal(C.begin(s),false);assert.deepEqual(s,before);assert(C.chooseFormation(s,'flank'));assert(C.deployment_reset(s));assert.equal(s.battleSelected.length,0);s=C.deserialize(C.serialize(s));assert(C.deployment_assign(s,"character_grant",23));assert(C.chooseFormation(s,'convoy'));assert(C.deployment_reset(s));okay(s);assert(C.begin(s));okay(s);reject(s,"character_mirei",23);
});
test('reserves keep HP/MP/items; EXP and camp recovery retain travelling-party policy',()=>{
 const s=prep();const reserve=s.characters["character_sera"];reserve.hp-=20;reserve.mp=0;const inv=clone(reserve.inventory),hp=reserve.hp,xp=reserve.xp;
 assert(C.begin(s));for(const u of s.battle.units)if(u.side==='enemy')u.hp=0;s.battle.result='勝利';assert(C.finishBattle(s));assert.equal(reserve.hp,hp);assert.equal(reserve.mp,0);assert.deepEqual(reserve.inventory,inv);assert.equal(reserve.xp,xp+20);assert.equal(s.journey.party.length,12);okay(s);
 assert(C.rest(s));assert.equal(reserve.hp,Math.min(C.stats(reserve).max,hp+60));assert.equal(reserve.mp,Math.min(C.stats(reserve).maxMp,2));okay(s);assert(C.onward(s));assert(C.travel(s,'safe',()=>.2));assert.equal(s.battleSelected.length,5);okay(s);
});
test('porter acceptance and deployed-death failure unchanged; bench porter not mandatory',()=>{
 const s=prep();assert(C.deployment_assign(s,"character_yuno",null));assert(C.begin(s));okay(s);
 const town=require('./test-current-fixture.cjs')();assert(C.select(town,["character_mirei"]));assert.equal(C.accept(town,C.board(town)[0].id,"character_mirei"),false);
 const dead=require('./test-current-fixture.cjs')();dead.characters["character_yuno"].hp=0;assert.equal(C.depart(dead,'east'),false);
 const fail=prep();assert(C.begin(fail));fail.battle.units.find(u=>u.id==="character_yuno").hp=0;fail.battle.failure=true;fail.battle.result='敗北';assert(C.finishBattle(fail));assert.equal(fail.result.outcome,'failed');okay(fail);
});


const {spawnSync}=require('node:child_process');
test('bridge exposes canonical deployment action and view after save/load',()=>{
  const s=prep(),requests=[{op:'campaign_load',data:C.serialize(s)},{op:'campaign',action:'deployment_assign',args:['character_yuno',null]},{op:'campaign',action:'deployment_assign',args:['character_grant',23]},{op:'campaign_save'}];
 const run=spawnSync(process.execPath,['bridge.cjs'],{cwd:__dirname,input:requests.map(x=>JSON.stringify(x)).join('\n')+'\n',encoding:'utf8',maxBuffer:8e6});assert.equal(run.status,0,run.stderr);
 const replies=run.stdout.trim().split('\n').map(JSON.parse);assert(replies.every(x=>x.ok));assert(replies[1].campaign.deploymentRoster.reserves.includes("character_yuno"));assert(replies[2].campaign.battleSelected.includes("character_grant"));okay(C.deserialize(replies[3].data));
});

test('repeat remove/add/load consumes no inventory or gameplay RNG; invalid begin is atomic',()=>{
 const guard='character_mirei',reserve='character_sera';
 const stocks={
  [guard]:{potion:3,ether:1},
  'character_merina':{potion:2,ether:4},
  [reserve]:{potion:7,ether:2}
 };
 let s=prep(stocks);const chars=structuredClone(s.characters),random=Math.random;let calls=0;
 function inventoryPreserved(){
  assert.deepEqual(s.characters,chars,'deployment preserves every owner and count, including reserves');
  for(const [id,stock] of Object.entries(stocks))assert.deepEqual(s.characters[id].inventory,stock);
  const allies=s.battle.units.filter(u=>u.side==='ally');
  for(const u of allies)for(const item of ['potion','ether'])
   assert.equal(s.battle.itemInventories[u.id][item],chars[u.id].inventory[item]??0,`${u.id} ${item}`);
  for(const [item,total] of [['potion',s.battle.potions.ally],['ether',s.battle.ethers]])
   assert.equal(total,allies.reduce((sum,u)=>sum+(chars[u.id].inventory[item]??0),0),`${item} deployed aggregate`);
  assert(s.battle.potions.ally>0);assert(s.battle.ethers>0);
 }
 inventoryPreserved();
 try{Math.random=()=>{calls++;throw Error('deployment consumed gameplay random');};
  for(let n=0;n<20;n++){
   assert(C.deployment_assign(s,guard,null));inventoryPreserved();
   assert(C.deployment_assign(s,reserve,23));inventoryPreserved();
   s=C.deserialize(C.serialize(s));inventoryPreserved();
   assert(C.deployment_assign(s,reserve,null));inventoryPreserved();
   assert(C.deployment_assign(s,guard,23));inventoryPreserved();
   s=C.deserialize(C.serialize(s));inventoryPreserved();
  }
  assert(C.chooseFormation(s,'flank'));assert(C.deployment_reset(s));assert(C.chooseFormation(s,'convoy'));assert(C.deployment_reset(s));
   assert.equal(calls,0);inventoryPreserved();
 }finally{Math.random=random;}
 const bad=structuredClone(s);bad.battleSelected=["character_mirei"];const before=structuredClone(bad);assert.equal(C.begin(bad),false);assert.deepEqual(bad,before);assert.equal(C.view(bad).deploymentRoster.canBegin,false);
 const dead=prep();for(const u of dead.battle.units)if(u.side==='ally')u.hp=0;const old=structuredClone(dead);assert.equal(C.begin(dead),false);assert.deepEqual(dead,old);
});


test('same-job member tie uses canonical nonzero index after replace/remove/re-add/load',()=>{
 const B=require('./campaign-battle.js');let s=prep();
 function ties(){const expected=B.create({ally:s.battleSelected,enemy:[],deployment:true}).units;assert.deepEqual(s.battle.units.filter(u=>u.side==='ally').map(u=>[u.id,u.tie]),expected.map(u=>[u.id,u.tie]));}
 const guard=s.battle.units.find(u=>u.id==="character_mirei");assert(C.deployment_assign(s,"character_sera",guard.pos));ties();
 assert(C.deployment_assign(s,"character_yuno",null));assert(C.deployment_assign(s,"character_mirei",0));ties();
 const guards=s.battle.units.filter(u=>u.job==='job_warrior'&&u.side==='ally');assert.equal(guards.length,2);assert(guards.every(u=>s.battleSelected.indexOf(u.id)>0));assert(guards[0].tie<guards[1].tie,'existing same-job earlier member remains earlier');
 const ids=[...s.battleSelected],before=guards.map(u=>[u.id,u.tie]);assert(C.deployment_assign(s,"character_merina",1));assert.deepEqual(s.battleSelected,ids);assert.deepEqual(s.battle.units.filter(u=>u.job==='job_warrior'&&u.side==='ally').map(u=>[u.id,u.tie]),before);
 assert(C.deployment_assign(s,"character_sera",null));ties();assert(C.deployment_assign(s,"character_sera",2));ties();s=C.deserialize(C.serialize(s));ties();okay(s);
 assert(C.chooseFormation(s,'flank'));assert(C.deployment_reset(s));ties();assert(C.begin(s));okay(s);
});
test('dead non-porter occupies legacy slot but can be explicitly removed without revival',()=>{
 const s=require('./test-current-fixture.cjs')();assert(C.select(s,["character_mirei","character_kyle","character_merina","character_rio","character_grant","character_sera"]));s.characters["character_grant"].hp=0;assert(C.depart(s,'east'));assert(C.travel(s,'safe',()=>.2));
 assert(s.battleSelected.includes("character_grant"));assert.equal(s.battleSelected.length,5);okay(s);const chars=structuredClone(s.characters);reject(s,"character_sera",0);
 assert(C.deployment_assign(s,"character_grant",null));assert.equal(s.characters["character_grant"].hp,0);assert.equal(C.view(s).deploymentRoster.remaining,1);okay(s);
 assert(C.deployment_assign(s,"character_sera",0));assert.deepEqual(s.characters,chars);assert(C.begin(s));okay(s);
});


test('flank initial/reset collisions use the porter-relative formation',()=>{
  for(const ids of [['character_sera','character_rio','character_mirei','character_merina','character_kyle'],['character_lucia','character_rio','character_sera','character_yuno','character_grant']]){
  const s=require('./test-current-fixture.cjs')();assert(C.select(s,ids));assert(C.depart(s,'east','flank'));assert(C.travel(s,'safe',()=>.2));
  const positions=()=>s.battle.units.filter(u=>u.side==='ally').map(u=>u.pos);
  assert.equal(new Set(positions()).size,ids.length);assert.deepEqual(B.formationSlots(s.battle,'ally'),s.battle.units.some(u=>u.side==='ally'&&u.job==='job_porter')?[24,13,33]:[]);okay(s);
  assert(C.chooseFormation(s,'convoy'));assert(C.deployment_reset(s));okay(s);assert(C.chooseFormation(s,'flank'));assert(C.deployment_reset(s));okay(s);assert(C.begin(s));okay(s);
 }
});
console.log(`${passed} deployment roster tests passed`);
