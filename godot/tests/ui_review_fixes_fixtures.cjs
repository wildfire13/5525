'use strict';
// Synthetic review states only: victories are forced to reach result UI, not a combat proof.
const C=require('../../native/campaign.js'),assert=require('node:assert/strict');
function acceptWithPorter(s,id){return C.accept(s,id,s.selected.find(uid=>C.view(s).roster.find(u=>u.id===uid)?.job==='porter'));}
const followup=require('./followup_ui_fixtures.cjs');
function save(s){assert(C.validate(s).ok,C.validate(s).error);return JSON.parse(C.serialize(s));}
function result(destination,accepted=false){
 const s=C.create();s.location=['east','west'].includes(destination)?'north':'east';
 if(accepted)assert(acceptWithPorter(s,C.board(s).find(q=>q.to===destination).id));
 assert(C.depart(s,destination));
 for(let stage=0;stage<2;stage++){
  assert(C.travel(s,'safe',()=>0));assert(C.begin(s));
  for(const u of s.battle.units)if(u.side==='enemy')u.hp=0;
  s.battle.result='勝利！ ミラーマッチを制した。';assert(C.finishBattle(s));
  if(stage===0)assert(C.onward(s));
 }
 assert(C.arrive(s));return save(s);
}
const town=C.create();town.characters.guard.hp=60;town.characters.guard.mp=0;town.characters.mage.hp=0;
const four=C.create();assert(C.select(four,['guard','mage','scout','porter']));
const road=C.create();assert(C.depart(road,'east'));
const results=Object.fromEntries(['north','east','west','south','astaris'].map(id=>[id+'_travel',result(id)]));
const fixtures={...followup,...results,north_delivery:result('north',true),town:save(town),four:save(four),road:save(road)};
if(require.main===module)console.log(JSON.stringify(fixtures).replace(/[^\x00-\x7f]/g,c=>'\\u'+c.charCodeAt(0).toString(16).padStart(4,'0')));
module.exports=fixtures;
