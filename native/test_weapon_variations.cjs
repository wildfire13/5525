'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js'),B=require('./campaign-battle.js');
const clone=x=>JSON.parse(JSON.stringify(x));
const expected=[['greatsword-wood',2,50,1,14,140],['spear-wood',1,23,2,10,90],['longspear-wood',2,34,2,14,140],['javelin-wood',1,21,3,10,100]];
let count=0;const test=(name,fn)=>{fn();count++;console.log('PASS '+name);};
const town=()=>{const s=C.create();s.location='east';s.gold=1000;return s;};
test('approved four catalog entries and shop category, prices/stats, no new skills',()=>{
 const s=town();for(const [id,hands,atk,reach,str,price] of expected){const g=C.shop(s).find(x=>x.id===id);assert.ok(g,id);assert.deepEqual([g.hands,g.atk,g.reach,g.str,g.price],[hands,atk,reach,str,price]);assert.equal(g.material,'wood');assert.equal(g.skill,undefined);assert.equal(g.effect,undefined);}
 s.location='west';assert.equal(C.shop(s).some(g=>expected.some(([id])=>id===g.id)),false);
});
test('purchase, isolated live trial, one damage contribution, save/load for every new weapon',()=>{
 for(const [id,hands,atk,reach] of expected){const s=town(),before=C.serialize(s),q=C.previewGear(s,'mage',id,'rightHand'),t=C.trial(s,'mage',id,'rightHand');assert.ok(q.eligible,id);assert.ok(t,id);assert.equal(C.serialize(s),before);
  const a=t.battle.units.find(u=>u.id==='mage'),e=t.battle.units.find(u=>u.id==='enemy-guard');e.pos=24+reach;const p=B.damagePreview(t.battle,a,'attack',e.id);assert.equal(p[0].base,atk);assert.equal(p[0].weapons.length,1);assert.equal(p[0].bonus,0);assert.deepEqual(a.activeSkills,[]);const hp=e.hp;assert.ok(C.trialAct(t,'attack',e.id));assert.equal(hp-e.hp,atk);assert.equal(C.serialize(s),before);
  const gold=s.gold;assert.ok(C.buyGear(s,'mage',id,'rightHand'));assert.equal(s.gold,gold-q.cost);assert.equal(s.characters.mage.weapon,id);assert.equal(C.stats(s.characters.mage).attackWeapons.length,1);assert.equal(C.view(s).roster.find(c=>c.id==='mage').equipmentSlots.find(e=>e.slot==='leftHand').occupiedBy,hands===2?'rightHand':null);assert.deepEqual(C.deserialize(C.serialize(s)),s);
  assert.ok(C.depart(s,'astaris'));assert.ok(C.travel(s,'safe',()=>.2));assert.deepEqual(C.deserialize(C.serialize(s)),clone(s));
 }
});
test('one-hand spear works in either hand, duplicate ID rejected, distance-filtered sum',()=>{
 const s=town();assert.ok(C.buyGear(s,'mage','spear-wood','leftHand'));const t=C.trial(s,'mage','sword-wood','rightHand'),a=t.battle.units.find(u=>u.id==='mage');assert.equal(B.reachFilteredPower(a,{pos:25}).base,49);assert.equal(B.reachFilteredPower(a,{pos:26}).base,23);
 const old=clone(s);assert.equal(C.buyGear(s,'mage','spear-wood','rightHand'),false);assert.deepEqual(s,old);
});
test('javelin repeats without MP/ammo/item expenditure and combines with sword only in range',()=>{
 const s=town();C.buyGear(s,'mage','javelin-wood','leftHand');const t=C.trial(s,'mage','sword-wood','rightHand'),a=t.battle.units.find(u=>u.id==='mage'),e=t.battle.units.find(u=>u.id==='enemy-guard');const mp=a.mp,stock=clone(t.battle.potions);
 for(const [pos,damage] of [[25,47],[27,21],[27,21]]){e.pos=pos;const hp=e.hp;assert.ok(C.trialAct(t,'attack',e.id));assert.equal(hp-e.hp,damage);assert.equal(a.mp,mp);assert.deepEqual(t.battle.potions,stock);}
 assert.equal(t.battle.actions,3);assert.equal(s.characters.mage.leftHand,'javelin-wood');assert.deepEqual(s.inventory,{potion:3,ether:1});
});
test('both two-hand types reject occupied left, release after removal and exchange without loss',()=>{
 for(const id of ['greatsword-wood','longspear-wood']){const s=town(),old=clone(s);assert.equal(C.buyGear(s,'guard',id),false);assert.deepEqual(s,old);assert.ok(C.buyGear(s,'guard','empty-leftHand','leftHand'));const hp=s.characters.guard.hp,mp=s.characters.guard.mp;assert.ok(C.buyGear(s,'guard',id));const occupied=clone(s);assert.equal(C.buyGear(s,'guard','spear-wood','leftHand'),false);assert.deepEqual(s,occupied);assert.ok(C.buyGear(s,'guard','empty-rightHand','rightHand'));assert.ok(C.buyGear(s,'guard','spear-wood','leftHand'));assert.equal(s.characters.guard.hp,hp);assert.equal(s.characters.guard.mp,mp);assert.deepEqual(C.deserialize(C.serialize(s)),s);}
});
test('race/stat constraints and porter attack prohibition for all four',()=>{
 const s=town();assert.equal(C.eligibility(s,'warrior','greatsword-wood').ok,false);for(const id of ['spear-wood','longspear-wood','javelin-wood'])assert.equal(C.eligibility(s,'warrior',id).ok,true);assert.equal(C.eligibility(s,'scout','greatsword-wood').ok,false);assert.equal(C.eligibility(s,'scout','longspear-wood').ok,false);assert.equal(C.eligibility(s,'scout','javelin-wood').ok,true);
 for(const [id] of expected){const t=C.trial(s,'porter',id);assert.ok(t,id);const a=t.battle.units.find(u=>u.id==='porter'),e=t.battle.units.find(u=>u.side==='enemy');assert.deepEqual(a.activeSkills,['porter']);assert.deepEqual(a.attackWeapons,[]);assert.equal(B.legal(t.battle,'attack',e.id),false);assert.ok(C.trialAct(t,'guard'));}
});
console.log(`PASS ${count} weapon-variation groups`);
