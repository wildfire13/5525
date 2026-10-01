const B=require('../src/battle.js'),J=require('../src/journey.js'),play=require('./playtest-mirror.cjs'),fs=require('node:fs');
const records=[];
for(const setup of ['default','scout-lane','porter-front']){
 const j=J.create();J.accept(j,'parts');J.depart(j,'medicine','convoy');const battles=[];
 for(let leg=0;leg<2;leg++){
  J.travel(j,'short');const s=B.create({ally:j.selected,enemy:leg===0?['scout','mage','archer']:['scout','archer','guard','archer-2'],previous:j.party,potions:j.potions,enemyPotions:leg,skillStage:1,deployment:true});
  if(setup==='scout-lane')B.deploy(s,'scout',14);
  if(setup==='porter-front')B.deploy(s,'porter',24);
  const positions=s.units.filter(u=>u.side==='ally').map(u=>({name:u.name,pos:u.pos,hp:u.hp}));B.begin(s);
  const result=play(B,'front-focus',s,(k,t)=>B.act(s,k,t));battles.push({positions,...result});
  if(!s.result)break;J.finishBattle(j,s);if(j.outcome)break;if(j.phase==='camp'){J.rest(j);J.onward(j);}
 }
 if(j.phase==='delivery')J.deliver(j);
 records.push({setup,outcome:j.outcome,hours:j.hours,battles});
}
fs.writeFileSync('qa/deployment-playtest.json',JSON.stringify(records,null,2));
console.log(JSON.stringify(records.map(r=>({...r,battles:r.battles.map(b=>({actions:b.actions,result:b.result,party:b.party,scout:b.trace.filter(t=>t.actor==='scout').slice(0,3)}))})),null,2));
