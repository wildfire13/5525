'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js'),B=require('./campaign-battle.js');
const clone=x=>JSON.parse(JSON.stringify(x));
let count=0;function test(name,fn){fn();count++;console.log('PASS '+name);}
function town(location='east'){const s=require('./test-current-fixture.cjs')();s.location=location;s.gold=5000;return s;}
function roundtrip(s){assert.deepEqual(C.deserialize(C.serialize(s)),clone(s));}
function battle(s){assert.ok(C.depart(s,'astaris'));assert.ok(C.travel(s,'safe',()=>.2));assert.ok(C.begin(s));return s.battle;}
function turn(b,id){b.actor=id;for(const u of b.units)u.next=u.id===id?1:100000;return b.units.find(u=>u.id===id);}
test('eight distinct slots, old keys map losslessly and all body slots exchange',()=>{
 const s=town('west'),c=s.characters["character_mirei"],old=clone(c);
 assert.equal(Object.keys(C.equipment(c)).length,8);assert.equal(C.equipment(c).rightHand,old.weapon);assert.equal(C.equipment(c).upperBody,old.armor);
 for(const slot of ['head','lowerBody','feet']){if(C.equipment(c)[slot]!==`empty-${slot}`)assert.ok(C.buyGear(s,c.id,`empty-${slot}`,slot));assert.ok(C.buyGear(s,c.id,slot==='lowerBody'?'cloth-skirt':`cloth-${slot}`,slot));roundtrip(s);assert.ok(C.buyGear(s,c.id,`empty-${slot}`,slot));}
 assert.ok(C.buyGear(s,"character_mirei",'armor-leather-1','upperBody'));assert.equal(c.armor,'armor-leather-1');
 const before=clone(s);assert.equal(C.buyGear(s,"character_mirei",'armor-iron-2','head'),false);assert.deepEqual(s,before);
});
test('two hands preserve sources; selection spends nothing and each action pays its cost',()=>{
 const s=town();assert.ok(C.buyGear(s,"character_merina",'rest-staff','rightHand'));assert.ok(C.buyGear(s,"character_merina",'breaker-hammer','leftHand'));
 const st=C.stats(s.characters["character_merina"]);assert.deepEqual(st.activeSkills,['skill_healing_cross','skill_knockback']);assert.deepEqual(st.skillSources.filter(x=>x.classification==='active').map(x=>x.slot),['rightHand','leftHand']);
 const b=battle(s),a=turn(b,"character_merina"),e=b.units.find(u=>u.side==='enemy');b.units.find(u=>u.id==="character_mirei").pos=a.pos;a.pos=24;e.pos=25;a.hp-=40;
 const actions=b.actions,mp=a.mp;assert.ok(B.selectSkill(b,'skill_healing_cross'));assert.equal(b.actions,actions);assert.equal(a.mp,mp);
 assert.ok(C.act(s,'action_skill',a.id));assert.equal(a.mp,mp-2);
 turn(b,a.id);assert.ok(B.selectSkill(b,'skill_knockback'));const hp=e.hp;assert.ok(C.act(s,'action_skill',e.id));assert.ok(e.hp<hp);assert.equal(a.mp,mp-3);
 turn(b,a.id);const before=clone(b);assert.equal(B.selectSkill(b,'skill_split_shot'),false);assert.deepEqual(clone(b),before);roundtrip(s);
 assert.deepEqual(b.skillEvents.filter(x=>x.actorId===a.id&&x.classification==='active').map(x=>x.skillId),['skill_healing_cross','skill_knockback']);
});
test('separate hand copies allowed; invalid slots rejected atomically and sources retained',()=>{
 const s=town(),gold=s.gold;assert.ok(C.buyGear(s,"character_mirei",'sword-wood','leftHand'));assert.equal(s.gold,gold-C.gear.find(g=>g.id==='sword-wood').price);
 assert.ok(C.buyGear(s,"character_merina",'staff-silver-1','leftHand'));const st=C.stats(s.characters["character_merina"]);assert.deepEqual(st.activeSkills,['skill_heal']);assert.equal(st.skillSources.filter(x=>x.id==='skill_heal').length,2);
 const bad=clone(s);bad.characters["character_mirei"].head='sword-wood';assert.equal(C.validate(bad).ok,false);
 for(const slot of ['head','accessory1','nonsense','__proto__']){const old=clone(s);assert.equal(C.buyGear(s,"character_mirei",'breaker-hammer',slot),false);assert.deepEqual(s,old);}
 roundtrip(s);
});
test('passives coexist, legacy duplicate effect copies load without stacking',()=>{
 const s=town('north');assert.ok(C.buyGear(s,"character_mirei",'victory-earring-1','accessory1'));assert.ok(C.buyGear(s,"character_mirei",'lone-ring-2','accessory2'));
  assert.deepEqual(C.stats(s.characters["character_mirei"]).effects,['skill_secret_pouch','skill_victory_breath','skill_lone_wolf']);roundtrip(s);
  assert.ok(C.buyGear(s,"character_mirei",'victory-earring-2','accessory2'));const st=C.stats(s.characters["character_mirei"]);assert.deepEqual(st.effects,['skill_secret_pouch','skill_victory_breath']);assert.equal(st.skillSources.filter(x=>x.id==='skill_victory_breath').length,2);roundtrip(s);
});
test('return remains once per battle across selection changes and save reload',()=>{
 const s=town('north');C.buyGear(s,"character_mirei",'return-ring-1');s.location='east';C.buyGear(s,"character_mirei",'undertow-sword','rightHand');C.buyGear(s,"character_mirei",'battleline-shield','leftHand');
 const b=battle(s),a=turn(b,"character_mirei");assert.ok(B.selectSkill(b,'skill_defense_line'));assert.ok(C.act(s,'action_return',0));turn(b,"character_mirei");assert.ok(B.selectSkill(b,'skill_retreat_slash'));assert.equal(B.legal(b,'action_return',1),false);
 const loaded=C.deserialize(C.serialize(s));assert.ok(B.returnSkillOptions(loaded.battle.units.find(u=>u.id==="character_mirei")).every(option=>option.used));assert.equal(B.legal(loaded.battle,'action_return',1),false);
});
test('unequip removes only that source; stats and HP/MP do not regenerate',()=>{
 const s=town();C.buyGear(s,"character_merina",'sharing-tome','leftHand');const c=s.characters["character_merina"];c.mp=1;c.hp=10;
 assert.ok(C.stats(c).activeSkills.includes('skill_mana_gift'));assert.ok(C.buyGear(s,"character_merina",'empty-leftHand','leftHand'));assert.deepEqual(C.stats(c).activeSkills,['skill_heal']);assert.equal(c.mp,1);assert.equal(c.hp,10);roundtrip(s);
});
test('empty hands expose item use rather than inherited job skill; left-only weapon becomes primary',()=>{
 const s=town();assert.ok(C.buyGear(s,"character_merina",'empty-rightHand','rightHand'));
 assert.deepEqual(C.stats(s.characters["character_merina"]).activeSkills,[]);
 const t=C.trial(s,"character_merina",'empty-leftHand','leftHand'),a=t.battle.units.find(u=>u.id==="character_merina");
 assert.equal(B.activeSkill(a),null);assert.equal(B.itemUseLevel(a),1);assert.deepEqual(B.skillTargets(t.battle,a),[]);
 assert.ok(C.buyGear(s,"character_merina",'breaker-hammer','leftHand'));assert.equal(C.stats(s.characters["character_merina"]).atk,29);assert.deepEqual(C.stats(s.characters["character_merina"]).activeSkills,['skill_knockback']);roundtrip(s);
});
test('race and ability restrictions unchanged; porter cannot select offensive skills',()=>{
 const s=town();assert.ok(C.buyGear(s,"character_merina",'hammer-wood','leftHand'));assert.equal(C.buyGear(s,"character_merina",'hammer-iron-1','leftHand'),false);assert.equal(C.buyGear(s,"character_rio",'hammer-wood','leftHand'),false);
 assert.ok(C.buyGear(s,"character_yuno",'breaker-hammer','leftHand'));const b=battle(s),p=turn(b,"character_yuno");assert.deepEqual(B.activeSkills(p),['skill_formation_boost']);assert.equal(B.selectSkill(b,'skill_knockback'),false);assert.equal(p.atk,0);assert.equal(B.legal(b,'action_attack',b.units.find(u=>u.side==='enemy').id),false);roundtrip(s);
});
test('left-hand preview/trial isolated and selects offered skill',()=>{
 const s=town(),before=clone(s),preview=C.previewGear(s,"character_merina",'breaker-hammer','leftHand'),t=C.trial(s,"character_merina",'breaker-hammer','leftHand');assert.ok(t);assert.equal(preview.slot,'leftHand');assert.equal(preview.current.id,'empty-leftHand');assert.equal(B.activeSkill(t.battle.units.find(u=>u.id==="character_merina")),'skill_knockback');assert.deepEqual(s,before);
});
test('save rejects forged skills, sources, selection and body equipment',()=>{
 const s=town();C.buyGear(s,"character_merina",'sharing-tome','leftHand');battle(s);
 for(const mutate of [x=>x.battle.units.find(u=>u.id==="character_merina").activeSkills.push('skill_knockback'),x=>x.battle.units.find(u=>u.id==="character_merina").selectedSkill='skill_knockback',x=>x.battle.units.find(u=>u.id==="character_merina").skillSources[0].slot='head',x=>x.characters["character_merina"].head='staff-wood',x=>x.characters["character_merina"].head=null,x=>x.characters["character_merina"].accessory1='']){const bad=clone(s);mutate(bad);assert.equal(C.validate(bad).ok,false);}
});
console.log(`PASS ${count} equipment-slot groups`);
