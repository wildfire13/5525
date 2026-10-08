'use strict';
// QA-only chooser. Plans on a parsed COPY; does not mutate the live engine.
const fs=require('node:fs'),B=require('../../native/campaign-battle.js');
const state=JSON.parse(fs.readFileSync(process.argv[2],'utf8'));
const actor=state.units.find(u=>u.id===state.actor);
B.plan(state,actor);let {kind,target}=actor.intent;
if(actor.job==='porter'){
 const hurt=state.units.filter(u=>u.side==='ally'&&u.hp>0&&u.hp<30).sort((a,b)=>a.hp-b.hp).find(u=>B.legal(state,'item',u.id));
 if(hurt){kind='item';target=hurt.id;}else{kind=B.legal(state,'skill',actor.id)?'skill':'guard';target=kind==='skill'?actor.id:null;}
}
console.log(JSON.stringify({kind,target}));
