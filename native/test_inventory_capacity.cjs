'use strict';
const assert=require('node:assert/strict');
const I=require('./character-inventory.js');
let passed=0;
function test(name,fn){fn();console.log('PASS '+name);passed++;}
test('base capacity zero, additive grants, negative grants and unlimited',()=>{
  assert.equal(I.capacity([]),0);
  assert.equal(I.capacity([1,1]),2);
  assert.equal(I.capacity([5,1,-3]),3);
  assert.equal(I.capacity([-5,1]),0);
  assert.equal(I.capacity([null,-5,1]),null);
  assert.equal(JSON.parse(JSON.stringify({limit:I.capacity([null])})).limit,null);
});
test('distinct item IDs occupy slots regardless of quantity',()=>{
  const bag={potion:99,ether:3,'belt-plus1':1,'belt-plus2':1};
  assert.deepEqual(I.occupancy(bag,2),{used:4,limit:2,overflow:['belt-plus1','belt-plus2']});
  assert.deepEqual(I.occupancy(bag,null),{used:4,limit:null,overflow:[]});
  assert.equal(I.canReceive({potion:1},'potion',50,1),true);
  assert.equal(I.canReceive({potion:1},'ether',1,1),false);
  assert.equal(I.canReceive({},'potion',1,0),false);
});
test('overfull recipient refused while outgoing transfer can resolve excess',()=>{
  const from={potion:3,ether:1},to={potion:2};
  assert.equal(I.canReceive(from,'potion',1,1),false);
  const move=I.transfer(from,to,'ether',1);
  assert.deepEqual(I.occupancy(move.source,1).overflow,[]);
  assert.deepEqual(from,{potion:3,ether:1});
  assert.deepEqual(to,{potion:2});
});
test('capacity loss marks excess without deleting or merging possessions',()=>{
  const bag={potion:2,ether:3,spear:1},before=JSON.stringify(bag);
  assert.equal(I.occupancy(bag,3).overflow.length,0);
  assert.deepEqual(I.occupancy(bag,1).overflow,['ether','spear']);
  assert.equal(JSON.stringify(bag),before);
});
test('weights use quantities and explicitly preserve missing weight information',()=>{
  const definitions={potion:{weight:1},ornament:{weight:0},spear:{weight:7}};
  assert.deepEqual(I.weight({potion:3,spear:2,ornament:1},id=>definitions[id]),{known:17,total:17,unknown:[]});
  assert.deepEqual(I.weight({potion:3,oldItem:2},id=>definitions[id]),{known:3,total:null,unknown:['oldItem']});
});
test('malformed and unsafe capacities, receipts and weights are rejected',()=>{
  for(const n of [undefined,Infinity,-1,.5,'1'])assert.throws(()=>I.occupancy({},n));
  assert.throws(()=>I.capacity([null,NaN]));
  assert.throws(()=>I.capacity([Number.MAX_SAFE_INTEGER,1]));
  for(const amount of [0,-1,.5,NaN,Infinity])assert.equal(I.canReceive({},'potion',amount,null),false);
  assert.equal(I.canReceive({potion:Number.MAX_SAFE_INTEGER},'potion',1,null),false);
  assert.throws(()=>I.weight({potion:1},()=>({weight:-1})));
});
console.log(`${passed} inventory capacity checks passed`);
