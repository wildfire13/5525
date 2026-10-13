'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),C=require('./campaign.js'),B=require('./campaign-battle.js');
let checks=0;
function check(ok,message){assert(ok,message);checks++;}
function unit(id,side,pos){return {id,side,pos,job:'scout',hp:100,max:100,mp:9,maxMp:9,atk:23,reach:1,agi:10,def:0,guard:false,cover:null,canInvade:true};}
for(const side of ['ally','enemy'])for(const level of [1,2,3]){
 const a=unit('actor',side,22);a.skillStage=999;a.skillSources=[{id:'scout',level}];
 for(const [direction,pos] of [['right',24],['left',20],['up',2],['down',42],['diagonal',44]]){
  const b=unit('target',side==='ally'?'enemy':'ally',pos),s={units:[a,b],log:[]};
  const expected=level===1?direction===(side==='ally'?'right':'left'):level===2?['left','right'].includes(direction):direction!=='diagonal';
  const jump=B.ambush(s,a,b);check(!!jump===expected,'equipment level direction '+side+'/'+level+'/'+direction);
  if(jump){check(B.range({pos:jump.destination},b)===1,'landing distance is one');s.units.push(unit('blocker',side,jump.path[0]));check(!B.ambush(s,a,b),'blocked route refuses');}
 }
 check(B.skillInfo(a).level===level,'description uses same equipment level');
}
for(const side of ['ally','enemy'])for(const def of [0,7,100]){
 const a=unit('a',side,21),b=unit('b',side==='ally'?'enemy':'ally',22);b.def=def;
 const s={units:[a,b],log:[]},prediction=B.attackPreview(s,a,b);check(prediction.damage===Math.max(1,23-def),'DEF preview '+side+'/'+def);
 B.receive(s,b,23);check(100-b.hp===prediction.damage,'DEF execution matches '+side+'/'+def);
}
{
 const s=B.create({ally:['scout','porter'],enemy:['scout'],deployment:true}),a=s.units.find(u=>u.side==='enemy'),target=s.units.find(u=>u.id==='scout'),porter=s.units.find(u=>u.job==='porter');
 a.pos=22;a.next=0;a.skillSources=[{id:'scout',level:3}];target.pos=2;target.hp=100;target.def=7;target.next=1;porter.pos=0;porter.next=1;
 s.deploying=false;B.plan(s,a);s.actor=a.id;
 check(a.intent.kind==='skill'&&a.intent.target===target.id,'enemy plans equipment-Lv3 vertical ambush');
 check(B.stepEnemy(s)&&a.pos===12&&target.hp===84,'enemy vertical execution lands adjacent and subtracts ally DEF');
}
{
 const a=unit('a','enemy',21),b=unit('b','ally',22);b.def=7;b.guard=true;
 const s={units:[a,b],log:[]};B.receive(s,b,23,true);check(100-b.hp===6,'subtract DEF before formation .75 and guard .5');
}
{
 const a=unit('a','enemy',21),b=unit('b','ally',22),guard=unit('guard','ally',32);b.def=99;guard.def=4;guard.cover='b';
 const s={units:[a,b,guard],log:[]};B.receive(s,b,23);check(b.hp===100&&guard.hp===81,'cover uses actual recipient DEF and preserves redirection');
}
const dagger=C.gear.find(g=>g.id==='dagger-wood'),originalLevel=dagger.skillLevel;
{
 const s=C.create();s.location='east';s.gold=1000;
 check(C.buyGear(s,'scout','sword-wood','rightHand'),'actual weapon change succeeds');
 check(!C.stats(s.characters.scout).activeSkills.includes('scout'),'removing ambush weapon removes its skill');
 check(C.inventoryAction(s,'scout','dagger-wood','equip',null,1,'rightHand',C.inventoryToken(s)),'owned dagger can be re-equipped');
 check(C.stats(s.characters.scout).skillSources.some(source=>source.id==='scout'&&source.level===1),'re-equipping restores equipment-derived level');
}
try{
 for(const level of [1,2,3]){
  dagger.skillLevel=level;
  const s=C.create();s.xp=9900;s.level=100;s.characters.scout.xp=200;s.characters.scout.level=3;s.characters.scout.statPoints=4;s.characters.scout.skillPoints=2;
  C.depart(s,'east');C.travel(s,'safe',()=>.3);
  const actor=s.battle.units.find(u=>u.id==='scout');
  check(B.skillLevel(actor)===level,'normal battle uses gear level independent of team/personal levels');
  const scouts=s.battle.units.filter(u=>u.job==='scout'&&u.side==='enemy');check(scouts.length>0,'fixture actually contains enemy scout');
  for(const enemy of scouts)check(B.skillLevel(enemy)===level,'enemy uses same gear definition');
  s.location='east';s.phase='town';s.journey=null;s.battle=null;s.rollback=null;
  const t=C.trial(s,'scout','dagger-wood');check(B.skillLevel(t.battle.units.find(u=>u.id==='scout'))===level,'trial uses same gear level');
 }
}finally{dagger.skillLevel=originalLevel;}
{
 const a=unit('a','ally',22);a.skillSources=[{id:'scout',level:1},{id:'scout',level:1}];check(B.skillLevel(a)===1,'duplicate equal levels do not accumulate');
 a.skillSources[1].level=2;check(B.skillLevel(a)===null,'mixed levels have no invented priority');
}
{
 const s=C.create();check(Object.values(s.characters).every(c=>c.def===0),'all new character DEF zero');
 s.characters.guard.def=5;C.depart(s,'east');C.travel(s,'safe',()=>.0);
 check(s.battle.units.filter(u=>u.side==='enemy').every(u=>u.def===0),'all enemy DEF defaults zero');
 check(s.battle.units.find(u=>u.id==='guard').def===5,'character DEF copied to combat');
 const loaded=C.deserialize(C.serialize(s));check(loaded.characters.guard.def===5&&loaded.battle.units.find(u=>u.id==='guard').def===5,'positive DEF roundtrip');
}
{
 const old=JSON.parse(fs.readFileSync(require.resolve('./test_fixtures/campaign-a51a773-battle.json'),'utf8')),bytes=JSON.stringify(old),s=C.deserialize(old);
 check(JSON.stringify(old)===bytes,'old save source untouched');
 check(Object.values(s.characters).every(c=>c.def===0)&&s.battle.units.every(u=>u.def===0),'old missing DEF defaults zero for both sides');
 check(C.deserialize(C.serialize(s)).characters.guard.def===0,'normalized old save reloads');
 for(const value of [-1,.5,'4']){const bad=C.create();bad.characters.guard.def=value;check(!C.validate(bad).ok,'invalid DEF rejected');}
}
console.log('PASS '+checks+' scoped equipment-level/DEF checks (Lv2/3 definitions changed in-memory only; no new priced items)');
