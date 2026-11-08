"use strict";
const C=require('../../native/campaign.js'),B=require('../../native/campaign-battle.js'),assert=require('assert/strict');
function fixture(selfHeal){
 const s=require('../../native/test-current-fixture.cjs')();assert(C.depart(s,'east'));assert(C.travel(s,'short',()=>.5));assert(C.begin(s));
 const b=s.battle, mage=b.units.find(u=>u.id==='mage'), guard=b.units.find(u=>u.id==='guard');
 b.units.forEach(u=>{u.next=10000;u.hp=u.max;});mage.next=1;mage.hp=70;guard.pos=32;guard.hp=selfHeal?guard.max:60;b.actor=mage.id;
 const enemy=b.units.find(u=>u.side==='enemy'&&u.job==='guard');assert(enemy);enemy.next=2;
 const target=selfHeal?mage:guard;target.hp=Math.max(1,target.max-70);
 const action=B.chooseAction(b,mage);
 assert.equal(action.kind,'skill');assert.equal(action.target,target.id);
 assert(C.validate(s).ok,C.validate(s).error);return JSON.parse(C.serialize(s));
}
function finish(){
 const f=fixture(true),b=f.state.battle;
 b.units.forEach(u=>{u.next=10000;if(u.side==='enemy')u.hp=0;});
 const archer=b.units.find(u=>u.id==='archer'),enemy=b.units.find(u=>u.side==='enemy'&&u.job==='guard');
 archer.next=1;b.actor=archer.id;enemy.hp=1;enemy.pos=34;enemy.next=2;
 assert(C.validate(f.state).ok,C.validate(f.state).error);return f;
}
// Keep Unicode intact through Windows OS.execute text decoding.
console.log(JSON.stringify({self:fixture(true),other:fixture(false),finish:finish()}).replace(/[^\x00-\x7f]/g,c=>"\\u"+c.charCodeAt(0).toString(16).padStart(4,"0")));
