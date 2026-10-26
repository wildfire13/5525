'use strict';
// Synthetic canonical result boundaries, never a claim of playing preceding fights.
const C=require('../../native/campaign.js'),assert=require('node:assert/strict');
const clone=x=>JSON.parse(JSON.stringify(x));
function saved(s){assert(C.validate(s).ok,C.validate(s).error);return JSON.parse(C.serialize(s));}
function won(s){assert(C.travel(s,'safe',()=>0));assert(C.begin(s));for(const u of s.battle.units)if(u.side==='enemy')u.hp=0;s.battle.actor=null;s.battle.result='勝利！ 街道を切り抜けた。';return saved(s);}
const free=C.create();assert(C.depart(free,'east'));const victory=won(free);const before=C.view(free);assert(C.finishBattle(free));const finished=saved(free),after=C.view(free);
function quest(urgent){
 const s=C.create(),q=C.board(s).find(q=>urgent?q.deadline===6:q.deadline===10);assert(q);assert(C.accept(s,q.id,'porter'));assert(C.depart(s,q.to));won(s);assert(C.finishBattle(s));assert(C.onward(s));won(s);assert(C.finishBattle(s));assert(C.arrive(s));const ready=saved(s);const before=C.view(s);assert(C.completeQuest(s));return {ready,result:saved(s),before,after:C.view(s)};
}
const fail=clone(victory);fail.state.battle.result='敗北。';for(const u of fail.state.battle.units)u.hp=u.side==='ally'?0:u.max;fail.state.battle.actor=null;assert(C.validate(fail.state).ok,C.validate(fail.state).error);
const value={victory,finished,battle_before:before,battle_after:after,normal:quest(false),late:quest(true),defeat:fail};
process.stdout.write(JSON.stringify(value).replace(/[^\x00-\x7f]/g,c=>'\\u'+c.charCodeAt(0).toString(16).padStart(4,'0')));
