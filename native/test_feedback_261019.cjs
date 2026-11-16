'use strict';
const assert=require('node:assert/strict');
const C=require('./campaign.js'),B=require('./campaign-battle.js');
let groups=0;
const test=(name,run)=>{run();groups++;console.log('PASS '+name);};
const clone=structuredClone;
function battle(skill='skill_grapple',level=1){
 const s=B.create({ally:["character_mirei","character_merina","character_yuno"],enemy:['guard','archer'],deployment:true,enemyPotions:0});
 s.deploying=false;s.actor='character_mirei';s.ethers=1;s.potions.ally=2;
 s.itemInventories={'character_mirei':{potion:1,ether:0},'character_merina':{potion:1,ether:0},'character_yuno':{potion:0,ether:1}};
 for(const [i,u] of s.units.entries()){u.next=100000+i;u.pos=[21,32,40,23,49][i];u.activeSkills=[skill];u.skillSources=[{id:skill,level}];if(u.side==='enemy')u.intent={kind:'action_defend',target:null,name:'防御',reason:'test',cells:[]};}
 s.units[0].next=1;return s;
}
function inventory(s,uid,id,action,slot){const q=C.inventoryQuote(s,uid,id,action,null,1,slot);assert(q.ok,q.reason);assert(C.inventoryAction(s,uid,id,action,null,1,slot,q.token));assert(!C.inventoryAction(s,uid,id,action,null,1,slot,q.token),'duplicate token must reject');}
test('equipment values and independently selected level sources',()=>{
 for(const [id,hp,level] of [['kungfu-pants',5,1],['kungfu-pants-1',25,1],['kungfu-pants-2',25,2],['kungfu-pants-3',25,3]]){
  const s=require('./test-current-fixture.cjs')(),c=s.characters["character_mirei"],base=C.stats(c).max;c.inventory[id]=1;
  inventory(s,"character_mirei",id,'equip','lowerBody');const st=C.stats(s.characters["character_mirei"]);
  assert.equal(st.max,base+hp);assert.equal(st.skillSources.find(x=>x.id==='skill_leg_sweep').level,level);assert(C.validate(s).ok);
 }
 const actor={side:'ally',activeSkills:[],skillSources:[{id:'skill_item_use',level:1,classification:'passive'},{id:'skill_item_use',level:2,classification:'passive'}]};
 assert.equal(B.activeSkillOptions(actor).length,0);assert.equal(B.itemUseLevel(actor),2);
 actor.skillSources.pop();assert.equal(B.itemUseLevel(actor),1);

});
test('virtual fists appear on empty hands, cannot generate stock; two handed weapons suppress both',()=>{
 const s=require('./test-current-fixture.cjs')();inventory(s,"character_mirei",'guard-shield-wood','unequip','leftHand');
 assert(C.stats(s.characters["character_mirei"]).effects.includes('skill_item_use'));
 assert.equal(C.view(s).roster.find(u=>u.id==="character_mirei").equipmentDetails.leftHand.name,'拳');
 assert(!C.inventoryQuote(s,"character_mirei",'empty-leftHand','unequip',null,1,'leftHand').ok);
 for(let i=0;i<3;i++){inventory(s,"character_mirei",'guard-shield-wood','equip','leftHand');inventory(s,"character_mirei",'guard-shield-wood','unequip','leftHand');}
 assert.equal(s.characters["character_mirei"].inventory['guard-shield-wood'],1);assert.equal(s.characters["character_mirei"].inventory.fist,undefined);
 s.characters["character_mirei"].inventory['longspear-wood']=1;inventory(s,"character_mirei",'longspear-wood','equip','rightHand');
 assert(!C.stats(s.characters["character_mirei"]).effects.includes('skill_item_use'));assert(C.stats(s.characters["character_mirei"]).activeSkills.includes('skill_pole_vault'));
 assert.equal(C.stats(s.characters["character_mirei"]).attackWeapons.length,1);assert.equal(C.stats(s.characters["character_mirei"]).attackWeapons[0].atk,34);
 inventory(s,"character_mirei",'longspear-wood','unequip','rightHand');assert(C.stats(s.characters["character_mirei"]).effects.includes('skill_item_use'));
 assert.equal(B.itemUseLevel(C.stats(s.characters["character_yuno"])),3);
 assert.deepEqual(C.deserialize(C.serialize(s)),JSON.parse(JSON.stringify(s)));
 for(const id of ['fist','fist-2']){const bad=clone(s);bad.characters["character_mirei"].inventory[id]=1;assert(!C.validate(bad).ok);assert(!C.eligibility(s,"character_mirei",id).ok);}
});
test('item levels restrict self / orthogonal adjacent / unlimited and no skill means no items',()=>{
 const s=battle('skill_item_use'),a=s.units[0],b=s.units[1];a.hp-=20;b.hp-=30;
 for(const level of [1,2,3]){
  a.skillSources[0].level=level;assert(B.legalFor(s,a,'action_item',a.id));
  for(const pos of [22,31,32,49]){b.pos=pos;assert.equal(B.legalFor(s,a,'action_item',b.id),level===3||level===2&&[22,31].includes(pos));}
 }
 const grants=a.skillSources;a.skillSources=[];a.effects=[];assert(!B.legalFor(s,a,'action_item',a.id));
 a.skillSources=grants;a.skillSources[0].level=3;s.itemInventories["character_mirei"].potion=0;assert(!B.legalFor(s,a,'action_item',b.id));
});
test('item preview/cancel is pure and consumes only owner stock with MP0',()=>{
 const s=battle('skill_item_use',2),a=s.units[0],b=s.units[1];b.pos=22;b.hp-=40;
 const before=clone(s),effects=B.effectPreview(s,a,'action_item',b.id);assert.equal(effects.find(x=>x.id===b.id).hp,40);assert.deepEqual(s,before);
 assert(B.act(s,'action_item',b.id));assert.equal(s.itemInventories["character_mirei"].potion,0);assert.equal(s.itemInventories["character_merina"].potion,1);assert.equal(a.mp,before.units[0].mp);assert.equal(s.actions,1);
 assert(!B.act(s,'action_item',b.id));assert.equal(s.actions,1);
});
test('grapple targets exactly right two cells, either side, alive only, no row wrapping',()=>{
 const s=battle(),a=s.units[0],b=s.units[3];
 for(const side of ['ally','enemy']){b.side=side;for(const pos of [23,19,20,22,24,11,31,33,49]){b.pos=pos;assert.equal(B.legalFor(s,a,'action_skill',b.id),pos===23);}}
 b.pos=23;b.hp=0;assert(!B.legalFor(s,a,'action_skill',b.id));b.hp=50;a.pos=29;b.pos=31;assert(!B.legalFor(s,a,'action_skill',b.id));
});
test('grapple preview/cancel preserves resources, movement uses MP1; occupied intermediate still consumes exactly once',()=>{
 for(const blocked of [false,true]){
  const s=battle(),a=s.units[0],b=s.units[3];if(blocked)s.units[1].pos=22;
  const before=clone(s),effects=B.effectPreview(s,a,'action_skill',b.id);assert.deepEqual(s,before);
  assert.equal(effects.find(e=>e.id===b.id)?.position,blocked?undefined:22);
  assert(B.act(s,'action_skill',b.id));assert.equal(b.pos,blocked?23:22);assert.equal(a.mp,before.units[0].mp-1);assert.equal(b.hp,before.units[3].hp);assert.equal(s.actions,1);
 }
 const s=battle();s.units[0].mp=0;const before=clone(s);assert(!B.act(s,'action_skill',s.units[3].id));assert.deepEqual(s,before);
});

test('leg sweep covers eight neighbors only and rolls separately with exact 50/75/100 percent thresholds',()=>{
 for(const [level,chance] of [[1,.5],[2,.75],[3,1]]){
  const s=battle('skill_leg_sweep',level),a=s.units[0];a.pos=22;s.units[1].pos=40;s.units[2].pos=41;
  const prototype=s.units[3];s.units=s.units.slice(0,3);
  for(const [i,pos] of [11,12,13,21,23,31,32,33,14,20,24,44].entries())s.units.push({...clone(prototype),id:'target-'+i,pos,next:100000+i});
  const values=[0,chance-.00001,chance,0.99999,0.1,0.9,0.2,0.8];let calls=0;
  const hp=s.units.map(u=>u.hp),mp=a.mp;
  assert.equal(B.sweepCells(a).length,8);assert.deepEqual(B.skillTargets(s,a),[a.id]);
  assert(B.act(s,'action_skill',a.id,()=>values[calls++]));assert.equal(calls,8);
  assert.deepEqual(s.units.map(u=>u.hp),hp);assert.equal(a.mp,mp-1);assert.equal(s.actions,1);
  for(let i=0;i<12;i++)assert.equal(!!s.units[3+i].skipNextTurn,i<8&&values[i]<chance);
 }
 assert.deepEqual(B.sweepCells({pos:0}),[1,10,11]);assert.deepEqual(B.sweepCells({pos:49}),[38,39,48]);
});
test('leg sweep previews never roll or mutate and report probabilities, including existing nonstacking skip',()=>{
 const s=battle('skill_leg_sweep',2),a=s.units[0];s.units[3].pos=22;s.units[3].skipNextTurn=true;
 const before=clone(s),original=Math.random;Math.random=()=>{throw Error('preview must not roll')};
 try{
  const preview=B.effectPreview(s,a,'action_skill',a.id);assert.equal(preview.find(e=>e.id===s.units[3].id).skipChance,.75);assert(preview.find(e=>e.id===s.units[3].id).alreadySkipping);
  assert.deepEqual(B.damagePreview(s,a,'action_skill',a.id),[]);assert.deepEqual(s,before);
 }finally{Math.random=original;}
});
test('repeated leg sweep success keeps one skip; that whole turn consumes no MP or item and then expires',()=>{
 const s=battle('skill_leg_sweep',3),a=s.units[0],e=s.units[3];e.pos=22;e.agi=10;
 for(let i=0;i<2;i++){assert(B.act(s,'action_skill',a.id,()=>0));assert.equal(e.skipNextTurn,true);}
 const enemyMp=e.mp,stock=clone(s.potions),hp=s.units.map(u=>u.hp);a.next=1;e.next=2;
 assert(B.act(s,'action_defend',null));assert.equal(e.next,12);assert.equal(e.skipNextTurn,undefined);assert.equal(e.mp,enemyMp);assert.deepEqual(s.potions,stock);assert.deepEqual(s.units.map(u=>u.hp),hp);
 assert.equal(s.log.filter(x=>x.includes('足払いで手番をスキップ')).length,1);
 assert.equal(s.actions,3,'skipped turn does not become a new player action');
 const p=require('./battle-presentation.cjs');const frames=p.capture(s,B,()=>B.act(s,'action_defend',null));assert(frames.ok);assert.equal(frames.frames.filter(x=>x.kind==='action_skip').length,0);
});
test('skips produce causal presentation once and repeated ACK cannot replay or spend resources',()=>{
 const s=battle('skill_leg_sweep',3),a=s.units[0],e=s.units[3];e.pos=22;e.next=2;e.agi=10;
 const {Presentation}=require('./battle-presentation.cjs'),p=new Presentation();assert(p.start(s,B,()=>B.act(s,'action_skill',a.id,()=>0)));
 const frames=[];while(p.pending){const f=p.info();frames.push(f);assert(p.next(f.id,f.index));assert(!p.next(f.id,f.index));}
 assert.equal(frames.filter(f=>f.kind==='action_skip').length,1);assert.equal(frames.find(f=>f.kind==='action_skip').actor_id,e.id);assert.deepEqual(frames.find(f=>f.kind==='action_skip').voiceEvents,[]);assert.equal(s.actions,1);assert.equal(s.units.find(u=>u.id===a.id).mp,a.maxMp-1);
});
test('pole vault ignores intermediate enemy, ally or empty; crosses midpoint but rejects diagonal, wrapping, occupied and out of board',()=>{
 for(const middle of [null,'ally','enemy']){
  const s=battle('skill_pole_vault'),a=s.units[0];a.pos=22;s.units[1].pos=40;s.units[3].pos=49;
  if(middle)s.units[middle==='ally'?1:3].pos=23;
  assert.deepEqual(B.skillTargets(s,a).sort((a,b)=>a-b),[2,20,24,42]);
  for(const target of [-1,50,21,23,11,33,25,52])assert(!B.legalFor(s,a,'action_skill',target));
  const before=clone(s),preview=B.effectPreview(s,a,'action_skill',24);assert.equal(preview.find(x=>x.id===a.id).position,24);assert.deepEqual(s,before);
  assert(B.act(s,'action_skill',24));assert.equal(a.pos,24);assert.equal(a.mp,before.units[0].mp-1);assert.equal(s.actions,1);assert.deepEqual(s.units.slice(1).map(u=>u.hp),before.units.slice(1).map(u=>u.hp));
 }
 const s=battle('skill_pole_vault'),a=s.units[0];a.pos=24;s.units[3].pos=49;
 // Current movement allows crossing the board midpoint without an invasion grant.
 assert(B.legalFor(s,a,'action_skill',26));assert(B.skillTargets(s,a).includes(26));s.units[3].pos=26;assert(!B.legalFor(s,a,'action_skill',26));
 a.pos=29;assert(!B.legalFor(s,a,'action_skill',31));a.pos=0;assert(!B.legalFor(s,a,'action_skill',-2));a.mp=0;assert(!B.act(s,'action_skill',2));
});
test('new battle skills and pending skips survive save/reload; invalid stacked counters reject',()=>{
 const s=require('./test-current-fixture.cjs')();s.characters["character_mirei"].lowerBody='kungfu-pants-3';s.characters["character_mirei"].weapon='longspear-wood';s.characters["character_mirei"].leftHand='empty-leftHand';
 assert(C.depart(s,'east'));assert(C.travel(s,'safe',()=>0));assert(C.begin(s));
 const a=s.battle.units.find(u=>u.id==="character_mirei"),e=s.battle.units.find(u=>u.side==='enemy');e.skipNextTurn=true;
 assert(a.activeSkills.includes('skill_pole_vault')&&a.activeSkills.includes('skill_leg_sweep'));assert.equal(C.validate(s).ok,true,C.validate(s).error);
 assert.deepEqual(C.deserialize(C.serialize(s)),JSON.parse(JSON.stringify(s)));
 for(const val of [1,2,-1,'true']){const bad=clone(s);bad.battle.units.find(u=>u.id===e.id).skipNextTurn=val;assert(!C.validate(bad).ok);}
 assert(C.retreat(s));assert(!s.battle);assert.equal(s.characters["character_mirei"].lowerBody,'kungfu-pants-3');
});
console.log(`PASS ${groups} feedback 261019 groups`);
