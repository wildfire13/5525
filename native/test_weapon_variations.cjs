'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js'),B=require('./campaign-battle.js');
const clone=x=>JSON.parse(JSON.stringify(x));
const expected=[['greatsword-wood',2,50,1,14,140],['spear-wood',1,23,2,10,90],['longspear-wood',2,34,2,14,140],['javelin-wood',1,21,1,10,100]];
let count=0;const test=(name,fn)=>{fn();count++;console.log('PASS '+name);};
const town=()=>{const s=require('./test-current-fixture.cjs')();s.location='east';s.gold=1000;return s;};
test('approved four catalog entries and shop category, prices/stats, pole vault and virtual fist skills',()=>{
 const s=town();for(const [id,hands,atk,reach,str,price] of expected){const g=C.shop(s).find(x=>x.id===id);assert.ok(g,id);assert.deepEqual([g.hands,g.atk,g.reach,g.str,g.price],[hands,atk,reach,str,price]);assert.equal(g.material,'wood');assert.equal(g.skill,id==='longspear-wood'?'skill_pole_vault':id==='javelin-wood'?'skill_spear_throw':undefined);assert.equal(g.effect,undefined);}
 s.location='west';assert.equal(C.shop(s).some(g=>expected.some(([id])=>id===g.id)),false);
});
test('purchase, isolated live trial, one damage contribution, save/load for every new weapon',()=>{
 for(const [id,hands,atk,reach] of expected){const s=town(),before=C.serialize(s),q=C.previewGear(s,"character_merina",id,'rightHand'),t=C.trial(s,"character_merina",id,'rightHand');assert.ok(q.eligible,id);assert.ok(t,id);assert.equal(C.serialize(s),before);
  const a=t.battle.units.find(u=>u.id==="character_merina"),e=t.battle.units.find(u=>u.id==='enemy-guard');e.pos=24+reach;const p=B.damagePreview(t.battle,a,'action_attack',e.id);assert.equal(p[0].base,atk);assert.equal(p[0].weapons.length,1);assert.equal(p[0].bonus,0);assert.deepEqual(a.activeSkills,id==='longspear-wood'?['skill_pole_vault']:id==='javelin-wood'?['skill_spear_throw']:[]);const hp=e.hp;assert.ok(C.trialAct(t, 'action_attack',e.id));assert.equal(hp-e.hp,Math.max(0,atk-e.def));assert.equal(C.serialize(s),before);
  const gold=s.gold;assert.ok(C.buyGear(s,"character_merina",id,'rightHand'));assert.equal(s.gold,gold-q.cost);assert.equal(s.characters["character_merina"].weapon,id);assert.equal(C.stats(s.characters["character_merina"]).attackWeapons.length,1);assert.equal(C.view(s).roster.find(c=>c.id==="character_merina").equipmentSlots.find(e=>e.slot==='leftHand').occupiedBy,hands===2?'rightHand':null);assert.deepEqual(C.deserialize(C.serialize(s)),s);
  assert.ok(C.depart(s,'astaris'));assert.ok(C.travel(s,'safe',()=>.2));assert.deepEqual(C.deserialize(C.serialize(s)),clone(s));
 }
});
test('one-hand spear works in either hand, separately purchased duplicate allowed, distance-filtered sum',()=>{
 const s=town();assert.ok(C.buyGear(s,"character_merina",'spear-wood','leftHand'));const t=C.trial(s,"character_merina",'sword-wood','rightHand'),a=t.battle.units.find(u=>u.id==="character_merina");assert.equal(B.reachFilteredPower(a,{pos:25}).base,49);assert.equal(B.reachFilteredPower(a,{pos:26}).base,23);
 const gold=s.gold;assert.equal(C.buyGear(s,"character_merina",'spear-wood','rightHand'),true);assert.equal(s.gold,gold-90);assert.equal(s.characters["character_merina"].weapon,'spear-wood');assert.equal(s.characters["character_merina"].leftHand,'spear-wood');assert.equal(C.stats(s.characters["character_merina"]).attackWeapons.length,2);assert.deepEqual(C.deserialize(C.serialize(s)),s);
});
test('javelin normal attacks repeat only in melee without expenditure; throw tested separately',()=>{
 const s=town();C.buyGear(s,"character_merina",'javelin-wood','leftHand');const t=C.trial(s,"character_merina",'sword-wood','rightHand'),a=t.battle.units.find(u=>u.id==="character_merina"),e=t.battle.units.find(u=>u.id==='enemy-guard');const mp=a.mp,stock=clone(t.battle.potions);
 for(const [pos,damage] of [[25,47-e.def],[25,47-e.def],[25,47-e.def]]){e.pos=pos;const hp=e.hp;assert.ok(C.trialAct(t, 'action_attack',e.id));assert.equal(hp-e.hp,damage);assert.equal(a.mp,mp);assert.deepEqual(t.battle.potions,stock);}
 assert.equal(t.battle.actions,3);assert.equal(s.characters["character_merina"].leftHand,'javelin-wood');assert.deepEqual(C.inventoryTotals(s),{potion:0,ether:0});
});
test('both two-hand types reject occupied left, release after removal and exchange without loss',()=>{
 for(const id of ['greatsword-wood','longspear-wood']){const s=town(),old=clone(s);assert.equal(C.buyGear(s,"character_mirei",id),false);assert.deepEqual(s,old);assert.ok(C.buyGear(s,"character_mirei",'empty-leftHand','leftHand'));const hp=s.characters["character_mirei"].hp,mp=s.characters["character_mirei"].mp;assert.ok(C.buyGear(s,"character_mirei",id));const occupied=clone(s);assert.equal(C.buyGear(s,"character_mirei",'spear-wood','leftHand'),false);assert.deepEqual(s,occupied);assert.ok(C.buyGear(s,"character_mirei",'empty-rightHand','rightHand'));assert.ok(C.buyGear(s,"character_mirei",'spear-wood','leftHand'));assert.equal(s.characters["character_mirei"].hp,hp);assert.equal(s.characters["character_mirei"].mp,mp);assert.deepEqual(C.deserialize(C.serialize(s)),s);}
});
test('race/stat constraints and porter attack prohibition for all four',()=>{
 const s=town();assert.equal(C.eligibility(s,"character_grant",'greatsword-wood').ok,false);for(const id of ['spear-wood','longspear-wood','javelin-wood'])assert.equal(C.eligibility(s,"character_grant",id).ok,true);assert.equal(C.eligibility(s,"character_rio",'greatsword-wood').ok,false);assert.equal(C.eligibility(s,"character_rio",'longspear-wood').ok,false);assert.equal(C.eligibility(s,"character_rio",'javelin-wood').ok,true);
  for(const [id,hands] of expected){
    // The current porter keeps an unremovable whistle in the right hand.
    // Two-handed weapons cannot replace it; one-handed tools use the left.
    const before=C.serialize(s),q=C.quote(s,"character_yuno",id,hands===2?'rightHand':'leftHand');
    const t=C.trial(s,"character_yuno",id,hands===2?'rightHand':'leftHand');
    if(hands===2){
      assert.equal(q.eligible,false,id);assert.equal(q.reason,'この装備は外せません');
      assert.equal(t,null,id);assert.equal(C.buyGear(s,"character_yuno",id),false);
    }else{
      assert.ok(q.eligible,id);assert.ok(t,id);
      const a=t.battle.units.find(u=>u.id==="character_yuno"),e=t.battle.units.find(u=>u.side==='enemy');
      assert.deepEqual(a.activeSkills,['skill_formation_boost']);assert.deepEqual(a.attackWeapons,[]);assert.equal(B.legal(t.battle,'action_attack',e.id),false);assert.ok(C.trialAct(t, 'action_defend'));
    }
    assert.equal(C.serialize(s),before,id);
  }
});
console.log(`PASS ${count} weapon-variation groups`);
