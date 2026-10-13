'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),C=require('./campaign.js');
const clone=x=>JSON.parse(JSON.stringify(x));
const s=C.create();s.xp=730;s.level=999;
for(const c of Object.values(s.characters))c.xp=80;
assert(C.validate(s).ok,'obsolete team fields do not constrain individual growth');
const old=clone(s.characters),saved=C.serialize(s),loaded=C.deserialize(saved);
assert.deepEqual(loaded.characters,old,'load does not award old team EXP to any character');
assert(C.depart(loaded,'east'));assert(C.travel(loaded,'safe',()=>.2));assert(C.begin(loaded));
for(const u of loaded.battle.units.filter(u=>u.side==='enemy'))u.hp=0;
loaded.battle.result='勝利！ 街道を切り抜けた。';
assert(C.finishBattle(loaded));assert.equal(loaded.xp,730);assert.equal(loaded.level,999);
for(const [id,c] of Object.entries(loaded.characters)){
 if(loaded.selected.includes(id)){assert.equal(c.xp,100);assert.equal(c.level,2);assert.equal(c.statPoints,2);assert.equal(c.skillPoints,1);}
 else assert.deepEqual(c,old[id],'reserve personal growth is untouched');
}
const after=C.serialize(loaded);assert.equal(C.finishBattle(loaded),false);assert.equal(C.serialize(loaded),after);
assert.deepEqual(C.deserialize(after).characters,loaded.characters,'save/load never re-awards growth');
const legacy=JSON.parse(fs.readFileSync(require.resolve('./test_fixtures/campaign-a51a773-battle.json'),'utf8'));
const original=clone(legacy);const a=C.deserialize(legacy),b=C.deserialize(C.serialize(a));
assert.deepEqual(legacy,original,'legacy save input is untouched');
for(const id of Object.keys(legacy.state.characters)){
 for(const key of ['xp','level','statPoints','skillPoints','allocations'])assert.deepEqual(a.characters[id][key],legacy.state.characters[id][key]);
}
assert.deepEqual(a.characters,b.characters);
console.log('PASS team EXP inert; personal growth once; reserves preserved; v1/v2 load without re-award');
