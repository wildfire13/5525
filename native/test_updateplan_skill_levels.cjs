'use strict';
const assert=require('node:assert/strict'),B=require('./campaign-battle.js');
function actor(id,level){return {id:'a',name:'試験',job:id,side:'ally',pos:22,hp:100,max:100,mp:2,maxMp:2,atk:25,reach:3,agi:10,next:0,tie:0,canInvade:true,activeSkills:[id],skillSources:[{id,level,slot:'rightHand',itemId:'fixture',grantSlot:1}],attackWeapons:[{slot:'rightHand',itemId:'fixture',atk:25,reach:id==='archer'?3:1}],selectedSkill:id};}
for(const level of [1,2,3]){
 const a=actor('archer',level),reach=[4,4.5,5][level-1];
 assert.equal(B.attackReach(a,'skill'),reach);assert.equal(B.skillCost(a),level===3?2:1);
 assert.equal(B.reachFilteredPower(a,{pos:27},'skill').base,level===3?25:0);
}
for(const id of ['archer','scout']){
 const a=actor(id,3),b={...actor('guard',1),id:'b',name:'敵',side:'enemy',pos:id==='archer'?27:24,hp:1000,max:1000,next:100,tie:1};
 const s={units:[a,b],actor:'a',result:null,log:[],actions:0,recentEnemies:[],potions:{ally:0,enemy:0},skillCooldownVersion:1};
 a.mp=1;assert.equal(B.legal(s,'skill','b'),false,id+' refuses insufficient MP');
 a.mp=2;assert(B.legal(s,'skill','b'));assert(B.act(s,'skill','b'));assert.equal(a.mp,0,id+' charges MP2 once');
 assert(b.hp<1000,id+' resolves attack');
}
assert.equal(B.skillInfo(actor('scout',3)).cost,2);
assert.match(B.skillInfo(actor('scout',3)).description,/MP2/);
console.log('PASS upper skill levels: range, power, cost, rejection, execution, description');
