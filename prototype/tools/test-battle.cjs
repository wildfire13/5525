const assert=require('node:assert/strict'),B=require('../src/battle.js');
const unit=(s,id)=>s.units.find(u=>u.id===id);
let s=B.create();
for(const a of s.units.filter(u=>u.side==='ally')){
 const e=unit(s,'enemy-'+a.job);
 for(const key of ['max','atk','agi','reach','mp','job'])assert.equal(a[key],e[key],key);
 assert.equal(a.pos%10+e.pos%10,9);assert.equal(Math.floor(a.pos/10),Math.floor(e.pos/10));
}
assert.equal(B.formation(s),true);assert.equal(B.formation(s,'enemy'),true);
assert.equal(B.range(unit(s,'guard'),unit(s,'enemy-guard')),1);
assert.equal(B.legalFor(s,unit(s,'guard'),'move',25),false);
assert.equal(B.legalFor(s,unit(s,'scout'),'move',15),true);
assert.equal(B.legalFor(s,unit(s,'enemy-scout'),'move',4),false,'occupied');
unit(s,'enemy-scout').pos=45;unit(s,'scout').pos=6;assert.equal(B.legalFor(s,unit(s,'scout'),'move',4),true,'return across border');
assert.equal(unit(s,'scout').side,'ally','affiliation unchanged on enemy ground');
// Burst route and target direction.
s=B.create();const a=unit(s,'scout'),b=unit(s,'enemy-mage');a.pos=34;
const jump=B.ambush(s,a,b);assert.ok(jump);assert.equal(B.range({pos:jump.destination},b),1);
for(const p of jump.path)assert.ok(!s.units.some(u=>u.hp>0&&u.id!==a.id&&u.pos===p));
s.actor=a.id;a.next=0;const hp=b.hp;assert.ok(B.act(s,'skill',b.id));assert.equal(a.pos,jump.destination);assert.equal(a.mp,4);assert.ok(b.hp<hp);assert.equal(s.actions,1);
assert.equal(B.ambush(s,a,{side:'enemy',hp:10,pos:0}),null,'different row is not a valid ambush');
assert.equal(B.ambush(s,a,{side:'enemy',hp:10,pos:46}),null,'diagonal is not a valid ambush');
assert.equal(jump.destination,35,'lands immediately before the target');
// Both directions use a straight path; an obstacle cannot be bypassed.
s=B.create();unit(s,'scout').pos=30;unit(s,'mage').pos=43;unit(s,'guard').pos=32;
assert.equal(B.ambush(s,unit(s,'scout'),unit(s,'enemy-mage')),null);
unit(s,'guard').pos=42;
assert.deepEqual(B.ambush(s,unit(s,'scout'),unit(s,'enemy-mage')).path,[31,32,33,34,35]);
unit(s,'enemy-scout').pos=39;unit(s,'enemy-mage').pos=46;unit(s,'mage').pos=34;
assert.deepEqual(B.ambush(s,unit(s,'enemy-scout'),unit(s,'mage')),{destination:35,path:[38,37,36,35]});
// Both sides can strike backwards along their row, but not vertically.
s=B.create();unit(s,'scout').pos=39;unit(s,'enemy-mage').pos=35;
assert.deepEqual(B.ambush(s,unit(s,'scout'),unit(s,'enemy-mage')),{destination:36,path:[38,37,36]});
unit(s,'enemy-scout').pos=30;unit(s,'mage').pos=34;
assert.deepEqual(B.ambush(s,unit(s,'enemy-scout'),unit(s,'mage')),{destination:33,path:[31,32,33]});
unit(s,'guard').pos=32;
assert.equal(B.ambush(s,unit(s,'enemy-scout'),unit(s,'mage')),null,'backwards path cannot bypass an obstacle');
assert.equal(B.ambush(s,unit(s,'scout'),{side:'enemy',hp:10,pos:29}),null,'vertical forbidden');
// Block all exits: cannot teleport through units.
s=B.create();unit(s,'scout').pos=0;unit(s,'guard').pos=1;unit(s,'mage').pos=10;
assert.equal(B.ambush(s,unit(s,'scout'),unit(s,'enemy-mage')),null);
// Same support rules for either affiliation, including on invaded ground.
for(const side of ['ally','enemy']){
 s=B.create();const prefix=side==='ally'?'':'enemy-';const g=unit(s,prefix+'guard'),m=unit(s,prefix+'mage'),sc=unit(s,prefix+'scout');
 g.pos=22;sc.pos=23;m.pos=32;sc.hp=30;
 assert.ok(B.legalFor(s,g,'skill',sc.id));assert.ok(B.legalFor(s,m,'skill',sc.id));
 g.cover=sc.id;B.receive(s,sc,20,false);assert.equal(g.hp,g.max-20);assert.equal(sc.hp,30);
 g.hp=1;B.receive(s,sc,20,false);B.receive(s,sc,20,false);assert.equal(sc.hp,10);
}
s=B.create();s.actor='mage';unit(s,'mage').next=0;unit(s,'archer').hp=35;
assert.ok(B.act(s,'skill','archer'));assert.equal(unit(s,'archer').hp,95);
s=B.create();s.actor='archer';unit(s,'archer').next=0;unit(s,'guard').next=1;unit(s,'guard').cover='archer';
B.act(s,'guard');assert.equal(s.actor,'guard');assert.equal(unit(s,'guard').cover,null);
// Enemy healer and protector select identical abilities.
s=B.create();unit(s,'enemy-archer').hp=40;B.plan(s,unit(s,'enemy-mage'));assert.equal(unit(s,'enemy-mage').intent.kind,'skill');
unit(s,'enemy-guard').pos=15;B.plan(s,unit(s,'enemy-guard'));assert.equal(unit(s,'enemy-guard').intent.name,'かばう');
// Fixed cells and landing positions survive target movement; AI doesn't silently retarget.
s=B.create();const e=unit(s,'enemy-scout');const saved=JSON.stringify(e.intent);unit(s,'scout').pos=44;assert.equal(JSON.stringify(e.intent),saved);
assert.ok(B.queue(s).some(u=>u.side==='enemy'));
console.log('Passed: mirror parity, world distances, scout-only invasion, ambush path/direction/cost, both-side support, cover expiry, AI support, fixed intents.');
