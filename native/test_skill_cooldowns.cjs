'use strict';
// Historical-ID fixtures retain the old roster; new-game/one-time migration
// behavior is tested separately in test_updateplan_roster.cjs.
const assert=require('node:assert/strict'),B=require('./campaign-battle.js');
let count=0;const test=(name,fn)=>{fn();count++;console.log('PASS '+name);};
const clone=x=>JSON.parse(JSON.stringify(x));
function scene(ids=['mage','mage']){
 const s=B.create({ally:['guard','mage'],enemy:['guard'],enemyPotions:0,deployment:true});
 const [a,b,e]=s.units;a.pos=24;b.pos=23;e.pos=25;a.mp=a.maxMp=30;a.hp=a.max-100;b.hp=b.max-90;
 a.activeSkills=[...new Set(ids)];a.skillSources=ids.map((id,i)=>({id,slot:i?'leftHand':'rightHand',itemId:'same-item',grantSlot:1,level:1,classification:'active'}));
 for(const u of s.units)u.next=1e6;a.next=1;s.skillCooldownVersion=1;s.deploying=false;s.actor=a.id;
 return {s,a,b,e,options:B.activeSkillOptions(a)};
}
test('same item in both hands: distinct grants, single MP/effect, next opportunity blocked only used grant',()=>{
 const {s,a,b,options}=scene();assert.equal(options.length,2);assert.notEqual(options[0].key,options[1].key);
 assert.ok(B.selectSkill(s,options[0].key));const hp=b.hp,mp=a.mp;assert.ok(B.act(s,'skill',b.id));assert.equal(b.hp,hp+60);assert.equal(a.mp,mp-1);
 assert.equal(s.actor,a.id);assert.equal(B.activeSkillOptions(a)[0].cooldown,1);assert.equal(B.legal(s,'skill',b.id),false);
 const before=clone(s);assert.equal(B.act(s,'skill',b.id),false);assert.deepEqual(s,before);
 assert.ok(B.selectSkill(s,options[1].key));assert.ok(B.legal(s,'skill',a.id));assert.ok(B.act(s,'skill',a.id));
 assert.equal(B.activeSkillOptions(a)[0].cooldown,0);assert.equal(B.activeSkillOptions(a)[1].cooldown,1);
 assert.ok(B.selectSkill(s,options[0].key));assert.ok(B.legal(s,'skill',b.id));
});
test('guard opportunity releases cooldown; previews, selection and invalid actions do not tick',()=>{
 const {s,a,b,options}=scene(['mage']);B.selectSkill(s,options[0].key);B.effectPreview(s,a,'skill',b.id);assert.equal(a.skillCooldowns,undefined);
 B.act(s,'skill',b.id);const before=clone(s);B.damagePreview(s,a,'skill',b.id);B.effectPreview(s,a,'skill',b.id);assert.deepEqual(s,before);
 B.selectSkill(s,options[0].key);assert.equal(B.activeSkillOptions(a)[0].cooldown,1);B.act(s,'guard');assert.equal(B.activeSkillOptions(a)[0].cooldown,0);
});
test('grant levels independent; repeated same-item grant slots remain distinct',()=>{
 const {s,a}=scene(['legSweep','legSweep']);a.skillSources[1]={...a.skillSources[0],grantSlot:2,level:3};const options=B.activeSkillOptions(a);
 assert.notEqual(options[0].key,options[1].key);B.selectSkill(s,options[0].key);assert.equal(B.skillLevel(a),1);assert.equal(B.sweepChance(a),.5);
 B.selectSkill(s,options[1].key);assert.equal(B.skillLevel(a),3);assert.equal(B.sweepChance(a),1);
});
test('passive fists grant the available item range without active buttons or cooldown',()=>{
 const {s,a,b}=scene([]);a.equipment={rightHand:'empty-rightHand',leftHand:'empty-leftHand'};
 a.skillSources=[{id:'itemUse',slot:'rightHand',itemId:'empty-rightHand',grantSlot:1,level:1,classification:'passive'},{id:'itemUse',slot:'leftHand',itemId:'empty-leftHand',grantSlot:1,level:3,classification:'passive'}];
 assert.equal(B.activeSkillOptions(a).length,0);assert.equal(B.itemUseLevel(a),3);assert(B.legal(s,'item',b.id));
 const n=s.potions.ally;assert(B.act(s,'item',a.id));assert.equal(s.potions.ally,n-1);assert.equal(a.skillCooldowns,undefined);
 assert(B.legal(s,'item',b.id));a.skillSources.pop();assert.equal(B.itemUseLevel(a),1);assert.equal(B.legal(s,'item',b.id),false);
});
test('skipped personal opportunity consumes cooldown; other actors do not',()=>{
 const {s,a,b,options}=scene(['mage']);b.next=2;B.selectSkill(s,options[0].key);B.act(s,'skill',b.id);assert.equal(s.actor,b.id);assert.equal(B.activeSkillOptions(a)[0].cooldown,1);
 a.skipNextTurn=true;B.act(s,'guard');assert.equal(a.skipNextTurn,undefined);assert.equal(B.activeSkillOptions(a)[0].cooldown,0);
});
test('JSON roundtrip preserves grant selection/cooldown; victory resets cooldown',()=>{
 const {s,a,b,e,options}=scene(['mage']);B.selectSkill(s,options[0].key);B.act(s,'skill',b.id);
 const restored=clone(s),copy=restored.units.find(u=>u.id===a.id);assert.equal(B.selectedSkillOption(copy).key,options[0].key);assert.equal(B.legal(restored,'skill',b.id),false);
 e.hp=1;assert.ok(B.act(s,'attack',e.id));assert.ok(s.result);assert.equal(a.skillCooldowns,undefined);
});
test('enemy planned skill cannot bypass cooldown and expires on completed opportunity',()=>{
 const {s,a,e}=scene();e.equippedSkill='stamp';e.mp=5;e.skillCooldowns={'legacy:stamp':1};e.intent={kind:'skill',target:a.pos,name:'スタンプ',cells:[a.pos],path:[]};s.actor=e.id;
 const hp=a.hp,mp=e.mp;assert.ok(B.stepEnemy(s));assert.equal(a.hp,hp);assert.equal(e.mp,mp);assert.equal(e.skillCooldowns,undefined);
});
test('real campaign entry, action and save/load enforce cooldown and clean next battle',()=>{
 const C=require('./campaign.js');let s=C.create();assert.ok(C.depart(s,'east'));assert.ok(C.travel(s,'safe',()=>0));assert.ok(C.begin(s));
 assert.equal(s.battle.skillCooldownVersion,1);
 const a=s.battle.units.find(u=>u.id==='recruit-mage-elf-female'),g=s.battle.units.find(u=>u.id==='recruit-guard-human-female');
 for(const u of s.battle.units)u.next=100000;a.next=1;s.battle.actor=a.id;a.pos=23;g.pos=24;g.hp-=80;
 const option=B.activeSkillOptions(a).find(o=>o.id==='mage');assert.ok(option);assert.ok(B.selectSkill(s.battle,option.key));assert.ok(C.act(s,'skill',g.id));
 assert.equal(B.selectedSkillOption(a).cooldown,1);assert.equal(C.validate(s).ok,true,C.validate(s).error);
 s=C.deserialize(C.serialize(s));const loaded=s.battle.units.find(u=>u.id==='recruit-mage-elf-female');
 assert.equal(B.selectedSkillOption(loaded).key,option.key);assert.equal(B.selectedSkillOption(loaded).cooldown,1);assert.equal(C.act(s,'skill',g.id),false);
 assert.ok(C.act(s,'guard'));assert.equal(B.selectedSkillOption(loaded).cooldown,0);
 assert.ok(C.retreat(s));assert.ok(C.acknowledge(s));assert.ok(C.depart(s,'east'));assert.ok(C.travel(s,'safe',()=>0));
 assert.ok(s.battle.units.every(u=>u.skillCooldowns===undefined));
});
test('each return grant is once per battle; cooldown expiry does not refresh it',()=>{
 const {s,a}=scene(['mage']);a.effects=['returnHome'];a.skillSources.push(
  {id:'returnHome',slot:'accessory1',itemId:'return-ring-1',grantSlot:1},
  {id:'returnHome',slot:'accessory2',itemId:'return-ring-2',grantSlot:1});
 const options=B.returnSkillOptions(a);assert.equal(options.length,2);assert.ok(B.selectReturnSkill(s,options[0].key));
 assert.ok(B.act(s,'return',3));assert.equal(B.returnSkillOption(a).used,true);assert.equal(B.legal(s,'return',4),false);
 assert.ok(B.act(s,'guard'));assert.equal(B.legal(s,'return',4),false);
 assert.ok(B.selectReturnSkill(s,options[1].key));assert.ok(B.act(s,'return',4));assert.ok(B.returnSkillOptions(a).every(o=>o.used));
 const loaded=clone(s),copy=loaded.units.find(u=>u.id===a.id);assert.ok(B.returnSkillOptions(copy).every(o=>o.used));
 assert.equal(B.legal(loaded,'return',3),false);assert.equal(a.mp,30);
});
test('stamp in a secondary grant keeps its weapon contribution on side cells',()=>{
 const {s,a,e}=scene(['mage','stamp']);a.skillSources[1]={id:'stamp',slot:'rightHand',itemId:'same-item',grantSlot:2,level:1};
 a.attackWeapons=[{slot:'rightHand',itemId:'same-item',atk:29,reach:1,skill:'mage'}];a.attackBonus=0;
 const stamp=B.activeSkillOptions(a).find(o=>o.id==='stamp');assert.ok(B.selectSkill(s,stamp.key));e.pos=15;
 assert.equal(B.reachFilteredPower(a,e,'skill').base,29);assert.equal(B.reachFilteredPower(a,e,'attack').base,0);
 const hp=e.hp;assert.ok(B.act(s,'skill',25));assert.equal(hp-e.hp,29);
});
test('enemy scout committed empty-cell miss consumes MP and cooldown; blocked path consumes neither',()=>{
 for(const blocked of [false,true]){
  const s=B.create({ally:['guard','mage'],enemy:['scout'],deployment:true,enemyPotions:0});
  const [target,other,scout]=s.units;target.pos=24;other.pos=0;scout.pos=27;target.next=2;other.next=100;scout.next=1;
  s.deploying=false;s.skillCooldownVersion=1;s.actor=scout.id;B.plan(s,scout);
  assert.equal(scout.intent.kind,'skill');assert.deepEqual(scout.intent.cells,[24]);assert.equal(scout.intent.destination,25);
  const mp=scout.mp,hp=target.hp;
  if(blocked)other.pos=26;else target.pos=23;
  assert.ok(B.stepEnemy(s));assert.equal(s.actor,target.id);assert.equal(target.hp,hp);
  assert.equal(scout.mp,mp-(blocked?0:1));assert.equal(scout.pos,blocked?27:25);
  assert.equal(B.selectedSkillOption(scout).cooldown,blocked?0:1);
  assert.ok(s.log.some(line=>line.includes(blocked?'奇襲経路が塞がれた':'空振り')));
 }
});
console.log(`${count} skill cooldown groups passed`);
