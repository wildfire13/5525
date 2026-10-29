'use strict';
// Explicit QA boundaries, not evidence of playing preceding battles. Rules,
// artwork, RNG and personal saves are never changed by this fixture generator.
const C=require('../../native/campaign.js');
const B=require('../../native/campaign-battle.js');
const assert=require('node:assert/strict');
const gear=C.gear.filter(g=>!g.virtualDefault&&g.type!=='empty'&&!g.id.startsWith('fist-'));
function base(){
 const s=require('../../native/test-current-fixture.cjs')(),c=s.characters.guard;s.gold=5000;s.location='east';
 c.level=29;c.xp=2800;c.allocations={str:2,int:4,agi:1};c.statPoints=49;c.skillPoints=28;
 c.inventory=Object.fromEntries(gear.map(g=>[g.id,3]));c.inventory.potion=3;c.inventory.ether=2;
 c.weapon='partner-dagger';c.leftHand='empty-leftHand';c.lowerBody='kungfu-pants-2';
 return s;
}
function checked(s){assert(C.validate(s).ok,C.validate(s).error);const save=JSON.parse(C.serialize(s));assert.deepEqual(JSON.parse(C.serialize(C.deserialize(JSON.stringify(save)))),save);return save;}
const cases={};
for(const place of ['east','west','north','south']){const s=base();s.location=place;cases[place]=checked(s);}
for(const [name,weapon,pants,actor] of [
 ['sweep1','hammer-wood','kungfu-pants','guard'],['sweep2','hammer-wood','kungfu-pants-2','guard'],['sweep3','hammer-wood','kungfu-pants-3','guard'],
 ['pincer','partner-dagger','kungfu-pants','guard'],['vault','longspear-wood','kungfu-pants','guard'],
 ['item1','empty-rightHand','kungfu-pants','guard'],['item3','empty-rightHand','kungfu-pants','porter']]){
 const s=base();s.location='astaris';s.characters.guard.weapon=weapon;s.characters.guard.lowerBody=pants;
 // The town catalogue intentionally carries every icon. Combat cases carry
 // only usable supplies, within the current real capacity limit.
 s.characters.guard.inventory={potion:3,ether:2};
 assert(C.depart(s,'east'));assert(C.travel(s,'safe',()=>0));assert(C.begin(s));
 const b=s.battle;for(const u of b.units){u.next=1000;u.hp=u.max;u.mp=u.maxMp;}
 const a=b.units.find(u=>u.id===actor);a.next=1;b.actor=a.id;
 for(const e of b.units.filter(u=>u.side==='enemy'))B.plan(b,e);
 cases[name]=checked(s);
}
process.stdout.write(JSON.stringify({meta:{synthetic:true,validated:true,gear_count:gear.length,note:'Current C.validate and save roundtrip; itemUse2 is intentionally not resurrected.'},cases}));
