"use strict";
const C=require('../../native/campaign.js'),B=require('../../native/campaign-battle.js'),assert=require('assert/strict');
function fixture(selfHeal){
 const s=C.create();assert(C.depart(s,'east'));assert(C.travel(s,'short',()=>.5));assert(C.begin(s));
 const b=s.battle, mage=b.units.find(u=>u.id==='mage'), guard=b.units.find(u=>u.id==='guard');
 b.units.forEach(u=>{u.next=10000;u.hp=u.max;});mage.next=1;mage.hp=70;guard.hp=60;b.actor=mage.id;
 const healer=b.units.find(u=>u.side==='enemy'&&u.job==='mage'),enemy=b.units.find(u=>u.side==='enemy'&&u.job==='guard');
 assert(healer&&enemy);healer.next=2;enemy.next=3;
 const target=selfHeal?healer:enemy;target.hp=Math.max(1,target.max-70);
 b.units.filter(u=>u.side==='enemy').forEach(u=>B.plan(b,u));
 assert.equal(healer.intent.kind,'skill');assert.equal(healer.intent.target,target.id);
 assert(C.validate(s).ok,C.validate(s).error);return JSON.parse(C.serialize(s));
}
function finish(){
 const f=fixture(true),b=f.state.battle;
 b.units.forEach(u=>{u.next=10000;if(u.side==='enemy')u.hp=0;});
 const archer=b.units.find(u=>u.id==='archer'),enemy=b.units.find(u=>u.side==='enemy'&&u.job==='guard');
 archer.next=1;b.actor=archer.id;enemy.hp=1;enemy.next=2;
 assert(C.validate(f.state).ok,C.validate(f.state).error);return f;
}
// Keep Unicode intact through Windows OS.execute text decoding.
console.log(JSON.stringify({self:fixture(true),other:fixture(false),finish:finish()}).replace(/[^\x00-\x7f]/g,c=>"\\u"+c.charCodeAt(0).toString(16).padStart(4,"0")));
