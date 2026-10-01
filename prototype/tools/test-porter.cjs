const assert=require('node:assert/strict'),B=require('../src/battle.js'),J=require('../src/journey.js');
const unit=(s,id)=>s.units.find(u=>u.id===id);
const make=()=>B.create({ally:['guard','archer','mage','porter','porter-2'],enemy:['guard','scout']});
const turn=(s,id)=>{s.actor=id;s.units.forEach(u=>u.next=100);unit(s,id).next=0;unit(s,'archer').next=1;};
let s=make(),p=unit(s,'porter');turn(s,'porter');
assert.equal(B.legal(s,'attack','enemy-guard'),false);
assert.equal(B.swapTarget(s,p,24).id,'guard');assert.equal(B.swapTarget(s,p,25),null);
const mp=p.mp;B.act(s,'move',24);assert.equal(p.pos,24);assert.equal(unit(s,'guard').pos,22);assert.equal(p.mp,mp);assert.equal(s.actions,1);
s=make();p=unit(s,'porter');unit(s,'archer').pos=23;assert.equal(B.swapTarget(s,p,24),null,'intermediate unit blocks swap');unit(s,'archer').pos=13;assert.equal(B.swapTarget(s,p,4),null,'swap limited to two steps');
s=make();turn(s,'porter');p=unit(s,'porter');assert.ok(B.formation(s));assert.ok(B.act(s,'skill',p.id));assert.equal(p.mp,5);assert.ok(B.boosted(s));
let g=unit(s,'guard'),hp=g.hp;B.receive(s,g,100);assert.equal(hp-g.hp,65);
unit(s,'porter-2').boost=true;hp=g.hp;B.receive(s,g,20);assert.equal(hp-g.hp,13,'two porters do not stack');
unit(s,'mage').pos=43;assert.equal(B.boosted(s),false);unit(s,'mage').pos=33;assert.ok(B.boosted(s));
const enemy=unit(s,'enemy-guard'),beforeHp=enemy.hp;s.actor='guard';unit(s,'guard').next=0;B.act(s,'attack',enemy.id);assert.equal(beforeHp-enemy.hp,46,'boosted attack is 26 × 1.75');
unit(s,'porter-2').boost=false;s.units.forEach(u=>u.next=100);unit(s,'archer').next=0;p.next=1;s.actor='archer';B.act(s,'guard');assert.equal(s.actor,'porter');assert.equal(p.boost,false,'expires at own next turn');
for(const id of ['porter','porter-2']){
 s=make();s.units.forEach(u=>u.next=100);s.actor='guard';unit(s,'guard').next=0;p=unit(s,id);p.hp=1;
 const e=unit(s,'enemy-scout');e.pos=p.pos+1;e.next=1;e.intent={kind:'attack',name:'攻撃',cells:[p.pos],target:id};
 B.act(s,'guard');assert.equal(s.failure,'porter');assert.equal(s.actor,null);assert.equal(B.act(s,'guard'),false);assert.ok(s.units.some(u=>u.side==='ally'&&u.hp>0));
 const j=J.create();J.accept(j,'parts');J.depart(j,'medicine','convoy');J.travel(j,'short');assert.ok(J.finishBattle(j,s));assert.equal(j.outcome,'failed');assert.equal(j.stage,0);
}
const j=J.create();j.selected=['guard'];assert.equal(J.accept(j,'parts'),false);j.selected=['porter'];J.accept(j,'parts');J.select(j,['guard']);assert.equal(J.depart(j,'medicine','convoy'),false);J.select(j,['porter','porter-2','guard','archer','mage']);assert.ok(J.depart(j,'medicine','convoy'));
s=make();turn(s,'porter');unit(s,'mage').pos=43;assert.equal(B.act(s,'skill','porter'),false);assert.equal(unit(s,'porter').mp,6,'invalid formation consumes no MP');
const ids=B.roster.map(u=>u.id);let count=0;
for(let a=0;a<6;a++)for(let b=a+1;b<7;b++)for(let c=b+1;c<8;c++)for(let d=c+1;d<9;d++)for(let e=d+1;e<10;e++){
 const ally=[ids[a],ids[b],ids[c],ids[d],ids[e]];if(!ally.some(id=>id.startsWith('porter')))continue;
 for(const formation of ['convoy','flank']){const b=B.create({ally,formation});assert.equal(new Set(b.units.map(u=>u.pos)).size,b.units.length);assert.ok(b.units.every(u=>Number.isInteger(u.pos)));}count++;
}
console.log(`Porter passed: ${count} five-member teams, swap path/cost, boost/expiry/nonstacking, either porter death, quest gates.`);
