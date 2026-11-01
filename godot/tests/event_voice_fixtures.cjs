// Isolated, validated quest boundary; preceding battle victories are injected, not playthrough evidence.
const C=require('../../native/campaign.js'),assert=require('node:assert/strict');
const s=C.create(),q=C.board(s)[0],porter=s.selected.find(id=>id.startsWith('recruit-porter-'));
assert(C.accept(s,q.id,porter));assert(C.depart(s,q.to));
for(let i=0;i<2;i++){
 assert(C.travel(s,'safe',()=>0));assert(C.begin(s));
 for(const u of s.battle.units)if(u.side==='enemy')u.hp=0;
 s.battle.actor=null;s.battle.result='勝利！ 街道を切り抜けた。';
 assert(C.finishBattle(s));if(i===0)assert(C.onward(s));
}
assert(C.arrive(s));assert(C.validate(s).ok,C.validate(s).error);
process.stdout.write(C.serialize(s));
