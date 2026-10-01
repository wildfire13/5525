// ブラウザーにも同じ方針を渡し、実際のUI操作で比較する。
function playMirror(B, policy, s, perform) {
 const trace=[], crossings=[], maximum=180;
  const enemyOrder=(policy==='healer-rush'||policy==='line-setup')?['mage','archer','scout','guard']:['guard','archer','scout','mage'];
 for(let step=0;step<maximum&&!s.result;step++) {
  const a=s.units.find(u=>u.id===s.actor), friends=s.units.filter(u=>u.side==='ally'&&u.hp>0);
  const enemies=s.units.filter(u=>u.side==='enemy'&&u.hp>0).sort((l,r)=>{
   if(policy==='intercept') {const li=B.boardOf(l.pos)==='ally',ri=B.boardOf(r.pos)==='ally';if(li!==ri)return Number(ri)-Number(li);}
   return enemyOrder.indexOf(l.job)-enemyOrder.indexOf(r.job);
  });
  let kind,target;
  const injured=[...friends].sort((l,r)=>(r.max-r.hp)-(l.max-l.hp));
  const heal=a.job==='mage'?injured.find(t=>t.max-t.hp>=35&&B.legal(s,'skill',t.id)):null;
  const cover=a.job==='guard'&&(policy==='intercept'||policy==='escort')?injured.find(t=>t.id!==a.id&&(policy==='escort'||t.hp<t.max*.6)&&B.legal(s,'skill',t.id)&&enemies.some(e=>e.intent.cells.includes(t.pos))):null;
  const potion=injured.find(t=>t.hp<30&&B.legal(s,'item',t.id));
  const stage=policy==='line-setup'&&a.job==='scout'?enemies.flatMap(e=>[...B.paths(s,a,2).keys()].filter(p=>p!==a.pos&&B.ambush(s,{...a,pos:p},e)).map(p=>({p,e}))).find(({e})=>!B.ambush(s,a,e)):null;
  const ready=a.job==='scout'?enemies.find(e=>B.legal(s,'skill',e.id)):null;
  if(stage&&a.mp>0&&(!ready||enemies.indexOf(stage.e)<enemies.indexOf(ready))){kind='move';target=stage.p;}
  else if(policy==='escort'&&step===0&&a.job==='archer'){kind='move';target=14;}
  else if(heal){kind='skill';target=heal.id;}
  else if(cover){kind='skill';target=cover.id;}
  else if(potion){kind='item';target=potion.id;}
  else {
   const rush=a.job==='scout'&&policy!=='home-only'?enemies.find(t=>B.legal(s,'skill',t.id)):null;
   const attack=enemies.find(t=>B.legal(s,'attack',t.id));
   if(a.job==='porter'){kind=B.legal(s,'skill',a.id)?'skill':'guard';target=kind==='skill'?a.id:undefined;}
   else if(rush){kind='skill';target=rush.id;}
   else if(attack){kind=a.job==='archer'&&B.legal(s,'skill',attack.id)?'skill':'attack';target=attack.id;}
   else {
    const goal=a.job==='mage'&&injured[0]?.hp<injured[0]?.max*.6?injured[0]:enemies[0];
    const options=[...B.paths(s,a,2).keys()].filter(p=>p!==a.pos&&(policy!=='home-only'||B.boardOf(p)==='ally'));
    options.sort((l,r)=>B.range({pos:l},goal)-B.range({pos:r},goal));
    if(options.length&&B.range({pos:options[0]},goal)<B.range(a,goal)){kind='move';target=options[0];}
    else kind='guard';
   }
  }
  const before=s.units.map(u=>({id:u.id,pos:u.pos,side:u.side}));
  trace.push({actor:a.id,kind,target,pos:a.pos,hp:a.hp});
  perform(kind,target);
  for(const u of s.units){const old=before.find(t=>t.id===u.id);if(B.boardOf(u.pos)!==B.boardOf(old.pos))crossings.push({step:step+1,name:u.name,side:u.side,from:old.pos,to:u.pos});}
 }
 return {policy,result:s.result||'継続・行動上限で打ち切り',actions:s.actions,party:s.units.filter(u=>u.side==='ally').map(u=>({name:u.name,hp:u.hp,mp:u.mp,pos:u.pos})),potions:s.potions,crossings,trace,log:s.log};
}
module.exports=playMirror;
if(require.main===module){const B=require('../src/battle.js');for(const policy of ['front-focus','healer-rush','intercept','home-only','escort']){const s=B.create(),r=playMirror(B,policy,s,(k,t)=>B.act(s,k,t));console.log(JSON.stringify({...r,trace:undefined,log:undefined},null,2));}}
