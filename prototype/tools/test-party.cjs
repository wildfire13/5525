const assert=require('node:assert/strict'),B=require('../src/battle.js'),J=require('../src/journey.js');
assert.equal(B.roster.length,10);
for(const job of ['guard','archer','mage','scout','porter']){const [a,b]=B.roster.filter(u=>u.job===job);assert.notEqual(a.id,b.id);assert.notEqual(a.name,b.name);for(const k of ['max','atk','agi','reach','mp','image'])assert.equal(a[k],b[k]);}
const ids=B.roster.filter(u=>u.job!=='porter').map(u=>u.id);
for(let a=0;a<5;a++)for(let b=a+1;b<6;b++)for(let c=b+1;c<7;c++)for(let d=c+1;d<8;d++){
 const team=[ids[a],ids[b],ids[c],ids[d]],s=B.create({ally:team,enemy:team});assert.equal(new Set(s.units.map(u=>u.id)).size,8);assert.equal(new Set(s.units.map(u=>u.pos)).size,8);assert.ok(s.actor);for(const u of s.units.filter(u=>u.side==='enemy'))assert.ok(u.intent);
}
const s=J.create();J.accept(s,'medicine');assert.equal(J.select(s,ids),false);assert.equal(J.select(s,['guard','guard']),false);assert.ok(J.select(s,['mage','mage-2','scout','scout-2','porter']));assert.ok(J.depart(s,'medicine','convoy'));assert.equal(J.select(s,['guard']),false);
assert.deepEqual(J.forecast(s,'short'),{hours:6,late:false,over:0});assert.deepEqual(J.forecast(s,'safe'),{hours:8,late:true,over:1});s.stage=1;s.hours=3;assert.equal(J.forecast(s,'rest').hours,8);s.job=J.jobs[1];assert.equal(J.forecast(s,'rest').late,false);
const compositions=new Set();let seed=12345;const random=()=>((seed=(seed*1664525+1013904223)>>>0)/4294967296);
for(let i=0;i<100;i++){const enemies=J.randomEnemies(4,random);assert.equal(new Set(enemies).size,4);for(const id of enemies)assert.ok(ids.includes(id));compositions.add(enemies.map(id=>B.roster.find(u=>u.id===id).job).sort().join(','));}assert.ok(compositions.size>8);
const previous=B.create({ally:['guard','guard-2'],enemy:['mage']}).units.filter(u=>u.side==='ally');previous[0].hp=40;previous[1].hp=90;previous[1].mp=2;
const next=B.create({ally:['guard','guard-2'],enemy:['mage'],previous});assert.equal(next.units.find(u=>u.id==='guard').hp,40);assert.equal(next.units.find(u=>u.id==='guard-2').hp,90);assert.equal(next.units.find(u=>u.id==='guard-2').mp,2);
console.log('Party passed: clone parity, all 70 four-person combinations, unique IDs/positions, independent carryover, random compositions, deadline forecast.');
