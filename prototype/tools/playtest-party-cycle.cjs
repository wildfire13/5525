const B=require('../src/battle.js'),J=require('../src/journey.js'),play=require('./playtest-mirror.cjs'),fs=require('node:fs');
const teams={balanced:['guard','archer','mage','scout'],bows:['guard','archer','archer-2','mage'],healers:['guard','archer','mage','mage-2'],scouts:['guard','mage','scout','scout-2'],porters:['guard','archer','mage','porter-2']};
const records=[];
for(const seed of [7,42,2026])for(const [team,ids] of Object.entries(teams))for(const rest of [false,true]){
 let value=seed;const random=()=>((value=(value*1664525+1013904223)>>>0)/4294967296);
 const s=J.create();J.accept(s,'medicine');J.select(s,[...ids,'porter']);J.depart(s,'medicine','convoy');const battles=[];
 for(let leg=0;leg<2;leg++){
  J.travel(s,'short');const enemies=J.randomEnemies(leg===0?3:4,random);
  const b=B.create({ally:s.selected,enemy:enemies,previous:s.party,skillStage:1,potions:s.potions,enemyPotions:leg});
  const result=play(B,'front-focus',b,(k,t)=>B.act(b,k,t));battles.push({enemies:enemies.map(id=>B.roster.find(u=>u.id===id).job),...result});
  if(!b.result)break;J.finishBattle(s,b);if(s.phase==='result')break;
  if(s.phase==='camp'){if(rest)J.rest(s);J.onward(s);}
 }
 if(s.phase==='delivery')J.deliver(s);
 records.push({seed,team,rest,outcome:s.outcome||'unfinished',hours:s.hours,gold:s.gold,battles});
}
fs.writeFileSync('qa/porter-cycle-comparison.json',JSON.stringify(records,null,2));
for(const r of records)console.log(JSON.stringify({seed:r.seed,team:r.team,rest:r.rest,outcome:r.outcome,hours:r.hours,actions:r.battles.map(b=>b.actions),hp:r.battles.at(-1).party.map(u=>u.hp),mp:r.battles.at(-1).party.map(u=>u.mp)}));
