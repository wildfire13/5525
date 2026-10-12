'use strict';
// R04/R07/R08/R09: behavior checks, including rejection without partial writes.
const assert=require('node:assert/strict');
const C=require('./campaign.js'),B=require('./campaign-battle.js');
let checks=0;
function check(name,fn){fn();checks++;console.log('PASS '+name);}
const copy=x=>JSON.parse(JSON.stringify(x));
function valid(s){assert.equal(C.validate(s).ok,true,C.validate(s).error);}
check('R08 villages have center plus exactly two adjacent villages; unchanged offer numbers',()=>{
  const s=C.create();
  for(const [id,expected] of Object.entries({east:['north','astaris','south'],north:['east','astaris','west'],west:['north','astaris','south'],south:['east','astaris','west']})){
    s.location=id;assert.deepEqual(C.destinations(s).map(p=>p.id),expected);
    for(const round of [0,1]){s.boardRound=round;const offers=C.board(s);assert.deepEqual(offers.map(q=>q.to),expected);assert.equal(new Set(offers.map(q=>q.id)).size,3);
      for(const q of offers){assert.deepEqual([q.reward,q.deadline,q.weight,q.xp],round%2?[150,10,5,100]:[180,6,3,100]);assert(C.destinations({...s,location:q.to}).some(p=>p.id===id));}}
  }
  s.location='astaris';assert.equal(C.board(s).length,2);assert.equal(C.destinations(s).length,4);
});
check('R09 shops and retained unequipped gear; R10 two slots remain',()=>{
  const s=C.create();s.location='west';assert(!C.shop(s).some(g=>g.type==='accessory'));
  s.location='north';assert(C.shop(s).length>0);assert(C.shop(s).every(g=>['accessory1','accessory2'].includes(g.slot)));
  assert(C.buyGear(s,'guard','return-ring-1','accessory1'));assert(C.buyGear(s,'guard','lone-ring-2','accessory2'));
  const gold=s.gold;assert.equal(C.quote(s,'guard','empty-accessory1','accessory1').cost,0);assert(C.buyGear(s,'guard','empty-accessory1','accessory1'));assert.equal(s.gold,gold);assert.equal(s.characters.guard.inventory['return-ring-1'],1);
  assert.equal(C.equipment(s.characters.guard).accessory2,'lone-ring-2');valid(s);
});
check('R07 one atomic partial allocation, clamp/replay/stale-load rejection',()=>{
  const s=C.create(),c=s.characters.guard;c.xp=300;c.level=4;c.statPoints=6;c.skillPoints=3;valid(s);
  const token=C.allocationToken(s,'guard'),old=copy(c);assert(C.allocateBatch(s,'guard',{str:2,int:1,agi:0},token));
  assert.equal(s.characters.guard.statPoints,3);assert.deepEqual(s.characters.guard.allocations,{str:2,int:1,agi:0});assert.equal(s.characters.guard.hp,old.hp+6);
  const after=JSON.stringify(s);assert(!C.allocateBatch(s,'guard',{str:2,int:1,agi:0},token));assert.equal(JSON.stringify(s),after);
  for(const delta of [{str:-1,int:1,agi:0},{str:0,int:0,agi:0},{str:4,int:0,agi:0},{str:0.5,int:0,agi:0},{str:1,int:0,agi:0,extra:1}]){
    assert(!C.allocateBatch(s,'guard',delta,C.allocationToken(s,'guard')));assert.equal(JSON.stringify(s),after);}
  const loadToken=C.allocationToken(s,'guard'),loaded=C.deserialize(C.serialize(s));assert(!C.allocateBatch(loaded,'guard',{str:1,int:0,agi:0},loadToken));valid(loaded);
});
check('R04 condition cells, independent positions, preset/reset, phase restrictions',()=>{
  const s=C.create();assert(C.depart(s,'east'));assert(C.travel(s,'short',()=>0));valid(s);
  assert.deepEqual(B.formationSlots(s.battle),{ally:[23,12,32],enemy:[25,16,36]});
  assert.equal(s.battle.units.find(u=>u.id==='guard').pos,24);const positions=copy(s.battle.units.map(u=>u.pos));B.formation(s.battle);assert.deepEqual(s.battle.units.map(u=>u.pos),positions);
  assert(C.chooseFormation(s,'flank'));assert.equal(s.journey.formation,'flank');assert.deepEqual(B.formationSlots(s.battle).ally,[24,13,33]);assert.equal(s.battle.units.find(u=>u.id==='scout').pos,14);
  assert(C.deploy(s,'guard',2));assert(C.deployment_reset(s));assert.equal(s.battle.units.find(u=>u.id==='guard').pos,24);
  assert(C.begin(s));assert(!C.chooseFormation(s,'convoy'));valid(s);
});
check('R04 started legacy save preserves old conditions and intents; deployment adopts new',()=>{
  for(const started of [false,true]){
    const s=C.create();C.depart(s,'east');C.travel(s,'safe',()=>0);if(started)C.begin(s);
    delete s.battle.formationVersion;delete s.battle.formationKind;const raw=C.serialize(s);const before=copy(s.battle.units);
    const loaded=C.deserialize(raw);assert.equal(loaded.battle.formationVersion,started?1:2);assert.deepEqual(loaded.battle.units,before);
    assert.deepEqual(B.formationSlots(loaded.battle).ally,started?[24,13,33]:[23,12,32]);assert.equal(C.deserialize(C.serialize(loaded)).battle.formationVersion,started?1:2);valid(loaded);
  }
});
check('R08 every ring route supports accepted and questless saves and rollback',()=>{
  for(const origin of ['east','north','west','south'])for(const destination of C.destinations({location:origin}).map(p=>p.id).filter(id=>id!=='astaris'))for(const accepted of [false,true]){
    const s=C.create();s.location=origin;const before=copy(s);
    if(accepted)assert(C.accept(s,C.board(s).find(q=>q.to===destination).id));
    assert(C.depart(s,destination));valid(C.deserialize(C.serialize(s)));assert(C.travel(s,'safe',()=>0));assert(C.begin(s));assert(C.retreat(s));assert.equal(s.result.restored,true);assert.deepEqual(s.characters,before.characters);assert.equal(s.location,origin);valid(s);
  }
});
check('R08 all eight directed ring journeys finish two real battles, reload, deliver once; R04 formation persists',()=>{
  for(const origin of ['east','north','west','south'])for(const destination of C.destinations({location:origin}).map(p=>p.id).filter(id=>id!=='astaris'))for(const accepted of [false,true]){
    let s=C.create();s.location=origin;
    if(accepted)assert(C.accept(s,C.board(s).find(q=>q.to===destination).id));
    assert(C.depart(s,destination));
    for(let stage=0;stage<2;stage++){
      assert(C.travel(s,'safe',()=>0));
      if(stage===0)assert(C.chooseFormation(s,'flank'));
      assert.equal(s.battle.formationKind,'flank');assert.deepEqual(B.formationSlots(s.battle).ally,[24,13,33]);
      s=C.deserialize(C.serialize(s));assert(C.begin(s));
      for(let n=0;n<300&&!s.battle.result;n++){
        const battle=copy(s.battle),actor=battle.units.find(u=>u.id===battle.actor);B.plan(battle,actor);let {kind,target}=actor.intent;
        if(actor.job==='porter'){
          const hurt=battle.units.filter(u=>u.side==='ally'&&u.hp>0&&u.hp<30).sort((a,b)=>a.hp-b.hp).find(u=>B.legal(battle,'item',u.id));
          if(hurt){kind='item';target=hurt.id;}else{kind=B.legal(battle,'skill',actor.id)?'skill':'guard';target=kind==='skill'?actor.id:null;}
        }
        assert(C.act(s,kind,target));
      }
      assert(s.battle.result);assert(!s.battle.failure);assert(C.finishBattle(s));valid(s);
      s=C.deserialize(C.serialize(s));if(stage===0)assert(C.onward(s));
    }
    assert.equal(s.phase,'arrival');assert(C.arrive(s));assert.equal(s.location,destination);assert.equal(s.result.hours,10); // Existing departure/delivery time plus two safe legs.
    assert.equal(s.result.gold,accepted?117:0);assert.equal(s.completed,accepted?1:0);assert(!C.arrive(s));valid(s);
  }
});
check('R02 exact effect prediction does not consume inventory, MP, actions or history',()=>{
  const s=C.create();assert(C.inventoryAction(s,'guard','potion','transfer','archer',1,null,C.inventoryToken(s)));C.depart(s,'east');C.travel(s,'safe',()=>0);C.begin(s);
  const a=s.battle.units.find(u=>u.id===s.battle.actor),friend=s.battle.units.find(u=>u.side==='ally'&&u.id!==a.id);friend.hp-=10;
  const before=JSON.stringify(s);const effect=B.effectPreview(s.battle,a,'item',friend.id);assert.equal(effect.find(e=>e.id===friend.id).hp,10);assert.equal(JSON.stringify(s),before);
});
console.log(`UI feedback shared rules: ${checks} groups passed`);
