'use strict';
// QA-only chooser. Selects from the parsed current board; does not mutate live engine state.
const fs=require('node:fs'),B=require('../../native/campaign-battle.js');
const state=JSON.parse(fs.readFileSync(process.argv[2],'utf8'));
const actor=state.units.find(u=>u.id===state.actor);
 let {kind,target}=B.chooseAction(state,actor);
if(actor.job==='job_porter'){
 const hurt=state.units.filter(u=>u.side==='ally'&&u.hp>0&&u.hp<30).sort((a,b)=>a.hp-b.hp).find(u=>B.legal(state,'action_item',u.id));
 if(hurt){kind='action_item';target=hurt.id;}else{kind=B.legal(state,'action_skill',actor.id)?'action_skill':'action_defend';target=kind==='action_skill'?actor.id:null;}
}
console.log(JSON.stringify({kind,target}));
