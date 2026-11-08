'use strict';
// Writes synthetic, validator-checked fixtures for Windows QA. Never opens a
// player save or reads a profile path.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const C=require('./campaign.js');
const B=require('./campaign-battle.js');
const dir=path.join(__dirname,'test_fixtures');
const write=(name,value)=>fs.writeFileSync(path.join(dir,name),JSON.stringify(value,null,2)+'\n');
let seed=7;
const rng=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/4294967296);

// A second Porter occupies one of the first Porter's three guard slots.
const formation=require('./test-current-fixture.cjs')();
assert(C.select(formation,['porter','porter-2','guard','archer','mage']));
const formationQuest=C.view(formation).board[0];
assert(C.accept(formation,formationQuest.id,'porter'));
assert(C.depart(formation,formationQuest.to));
assert(C.travel(formation,'safe',rng));
assert.equal(formation.phase,'deployment');
assert.deepEqual(B.formationSlots(formation.battle,'ally'),[24,13,33]);
assert.equal(B.formation(formation.battle,'ally'),false);
assert.equal(C.validate(formation).ok,true);
write('porter-formation-two-porters.json',JSON.parse(C.serialize(formation)));

// A battle can be loaded with the Porter down at the far edge. The next
// accepted action must resolve defeat before breakthrough.
const priority=C.create();
assert(C.depart(priority,'north'));
assert(C.travel(priority,'safe',()=>0.25));
assert(C.begin(priority));
const down=priority.battle.units.find(u=>u.side==='ally'&&u.job==='porter');
down.pos=49;down.hp=0;
const fallen=priority.battle.units.filter(u=>u.side==='ally'&&u.startedAlive&&u.hp<=0);
const survivors=priority.battle.partyAliveInitial-fallen.length;
const share=survivors>0?(priority.battle.initialDownWeight+fallen.reduce((n,u)=>n+(u.carriedWeight||0),0))/survivors:0;
for(const u of priority.battle.units.filter(u=>u.side==='ally')){
  u.fallenWeightShare=u.hp>0?share:0;
  u.overburdened=u.hp>0&&survivors>0&&u.carriedWeight+share>u.weightLimit;
  u.agi=u.baseAgi*(u.overburdened?0.5:1);
}
assert.equal(C.validate(priority).ok,true);
write('porter-breakthrough-ko-priority.json',JSON.parse(C.serialize(priority)));

// An old in-battle envelope with an accepted delivery and a spent potion.
const legacy=C.create();
const carrier=legacy.selected.find(id=>id.includes('porter'));
legacy.characters[carrier].inventory.potion=1;
const quest=C.view(legacy).board[0];
assert(C.accept(legacy,quest.id,carrier));
assert(C.depart(legacy,quest.to));
assert(C.travel(legacy,'safe',rng));
assert(C.begin(legacy));
const actor=legacy.battle.units.find(u=>u.side==='ally');
actor.hp--;actor.mp=Math.max(0,actor.mp-1);
legacy.battle.itemInventories[carrier].potion--;
legacy.battle.potions.ally--;
assert.equal(C.validate(legacy).ok,true);
const old=JSON.parse(C.serialize(legacy));
old.version=2;old.state.version=2;old.state.rollback.version=2;
old.state.battle.formationVersion=2;delete old.state.battle.formationBasis;
for(const unit of old.state.battle.units){
  delete unit.canDeployEnemySide;
  if(unit.side==='ally')unit.canInvade=unit.job!=='porter'&&C.stats(legacy.characters[unit.id]).effects.includes('invasion');
}
for(const unit of old.state.battle.units.filter(u=>u.side==='enemy'&&u.hp>0))
  unit.intent={kind:'guard',target:null,cells:[],name:'防御',reason:'旧戦闘セーブの移行検証'};
assert.equal(C.deserialize(old).activeQuest?.id,legacy.activeQuest.id);
write('legacy-v2-active-quest-battle.json',old);
console.log('Wrote three synthetic, validator-checked Porter QA fixtures.');
