"use strict";
let state=Battle.create(),mode='attack',previewPos=null,previewKind='attack',rushTarget=null;
const imageRoot='assets/characters/背景透過済み/';
const imageFor=u=>imageRoot+(u.side==='enemy'?'enemy/enemy_':'')+u.image;
const playLog=PlayLog.create({mode:document.querySelector('#cycle')?'journey':'battle'});
function playLogContext(){return {battle:state,journey:typeof getJourneyLogState==='function'?getJourneyLogState():null};}
function recordPlay(type,details={}){playLog.record(type,details,playLogContext());}
function exportPlayLog(){
 const status=document.querySelector('#play-log-status');let url;
 try{
  recordPlay('log.export.requested');
  const data=playLog.export(playLogContext());
  const blob=new Blob([JSON.stringify(data,null,2)],{type:'application/json;charset=utf-8'});
  url=URL.createObjectURL(blob);const link=document.createElement('a');
  link.href=url;link.download=`5525-${data.mode}-${data.exportedAt.replace(/[:.]/g,'-')}.json`;
  document.body.append(link);try{link.click();}finally{link.remove();}
  status.textContent='ログのダウンロードを開始しました';
 }catch(error){status.textContent='ログを保存できませんでした。もう一度お試しください';}
 finally{if(url)setTimeout(()=>URL.revokeObjectURL(url),1000);}
}
document.querySelector('#export-play-log').onclick=exportPlayLog;
const labels={attack:'攻撃',guard:'防御',move:'移動',skill:'スキル',item:'アイテム'};
function resetPreview(){previewPos=null;rushTarget=null;}
function perform(kind,target){const before=state.units.map(u=>({...u})),actor=state.actor,logStart=state.log.length;if(Battle.act(state,kind,target)){recordPlay('battle.action',{actor,kind,target:target??null,messages:state.log.slice(logStart)});resetPreview();mode='attack';render();document.dispatchEvent(new CustomEvent('battle-action',{detail:{before,kind,target}}));}else recordPlay('battle.rejected',{actor,kind,target:target??null});}
function render(){
 const actor=state.units.find(u=>u.id===state.actor),previewing=previewPos!==null&&!state.result;
 if(actor?.job==='porter'&&mode==='attack')mode='move';
 const swapped=previewing?Battle.swapTarget(state,actor,previewPos):null;
 const viewedActor=previewing?{...actor,pos:previewPos}:actor;
 const viewedState=previewing?{...state,units:state.units.map(u=>u.id===actor.id?viewedActor:u.id===swapped?.id?{...u,pos:actor.pos}:u)}:state;
 $('commandActor').innerHTML=state.result?'戦闘終了':`<img class="portrait" src="${imageRoot+actor.image}" alt=""><span>行動中：${actor.name}［${actor.role}］<small>HP ${actor.hp}/${actor.max} ／ MP ${actor.mp} ／ 射程${actor.reach}${actor.job==='scout'?' ／ 敵陣へ移動可能':''}</small></span>`;
 $('turn').textContent=state.result||`${actor.name}の行動`;
  $('formation').textContent=`護送陣：味方 ${Battle.boosted(state)?'強化中（攻撃＋75％・被害−35％）':Battle.formation(state)?'発動':'解除'} ／ 敵 ${Battle.formation(state,'enemy')?'発動':'解除'}`;
 $('timeline').innerHTML=state.result?'戦闘終了':Battle.queue(state).map((u,i)=>`<span class="turn-chip ${u.side}"><small>${i===0?'現在':i+'手先'}・${u.side==='ally'?'味方':'敵'}</small><b>${u.name}</b></span>`).join(' → ');
 $('enemyActivity').textContent=state.recentEnemies.length?'直前の敵行動：'+state.recentEnemies.map(e=>`${e.name}【${e.action}】`).join(' → '):'赤い札が敵の番。敵にも同じ射程・スキル・MP・回復薬があります。';
 for(const boardSide of ['ally','enemy']){
  const board=$(boardSide==='ally'?'allies':'enemies');board.replaceChildren();
  for(let i=0;i<25;i++){
   const p=Battle.cell(boardSide,i),u=viewedState.units.find(u=>u.hp>0&&u.pos===p);
   const threats=state.units.filter(e=>e.side==='enemy'&&e.hp>0&&e.intent.cells.includes(p));
   const incoming=state.units.filter(e=>e.side==='enemy'&&e.hp>0&&e.intent.destination===p);
   const target=mode==='move'?p:u?.id;
   const valid=!state.result&&!rushTarget&&Battle.legal(state,mode,target);
   const kind=previewing?previewKind:mode;
    const support=kind==='skill'&&['mage','guard','porter'].includes(actor?.job);
   const reach=!state.result&&(kind==='attack'||kind==='skill')&&Battle.inRange(viewedActor,u?.side||(support?'ally':'enemy'),p,kind,viewedState);
   const b=document.createElement('button');b.className='cell';b.dataset.pos=p;b.disabled=!valid;
   if(Battle.slots[boardSide].includes(p))b.classList.add('slot');
   if(u)b.classList.add(u.side==='ally'?'ally-unit':'enemy-unit');
   if(u?.id===state.actor)b.classList.add('current');
   if(valid)b.classList.add('valid');if(reach)b.classList.add('in-range');
   if(threats.length)b.classList.add('danger');if(threats.length>1)b.classList.add('overlap');
   if(incoming.length)b.classList.add('enemy-destination');if(previewing&&u?.id===actor.id)b.classList.add('ghost');
   const point=Battle.screen(boardSide,p);
   b.innerHTML=`<small>${point.y+1}-${point.x+1}</small>${u?`<img class="unit-image" src="${imageFor(u)}" alt="${u.side==='enemy'?'敵':'味方'}${u.role}"><b>${u.name}${previewing&&u.id===actor.id?'（仮）':''}</b><span>${u.hp}/${u.max}${u.guard?' 防御':''}</span><i style="width:${pct(u.hp,u.max)}"></i>`:''}${threats.length?`<em>⚠${threats.length>1?'×'+threats.length:''}</em>`:''}${incoming.length?'<span class="arrival">移動予定</span>':''}`;
   b.setAttribute('aria-label',`${boardSide==='ally'?'味方陣':'敵陣'}${point.y+1}行${point.x+1}列 ${u?`${u.side==='ally'?'味方':'敵'} ${u.name} HP${u.hp}`:'空き'} ${reach?'射程内':''}`);
   b.title=threats.map(e=>e.name+'の'+e.intent.name).concat(incoming.map(e=>e.name+'の移動先')).join('\n');
   b.onclick=()=>{
     if(mode==='move'){previewPos=p;previewKind=actor.job==='porter'?'skill':'attack';recordPlay('battle.preview',{actor:actor.id,kind:'move',target:p,swap:Battle.swapTarget(state,actor,p)?.id??null});render();return;}
    if(mode==='skill'&&actor.job==='scout'){const jump=Battle.ambush(state,actor,u);if(jump){rushTarget=u.id;previewPos=jump.destination;previewKind='attack';recordPlay('battle.preview',{actor:actor.id,kind:'skill',target:u.id,destination:previewPos});render();}return;}
    perform(mode,target);
   };board.append(b);
  }
 }
 $('commands').replaceChildren();
 for(const [key,text] of Object.entries(labels)){
  const b=document.createElement('button');b.textContent=(key==='skill'&&actor?Battle.skillName(actor):text)+(key==='skill'?` (${actor?.mp??0})`:key==='item'?` (${state.potions.ally})`:'');
   b.className=mode===key?'selected':'';b.disabled=!!state.result||previewing||(key==='skill'&&!actor?.mp)||(key==='item'&&!state.potions.ally);
   if(key==='attack'&&actor?.job==='porter'){b.hidden=true;b.disabled=true;}
  b.onclick=()=>{resetPreview();if(key==='guard')perform(key);else{mode=key;render();}};$('commands').append(b);
 }
  const skillHints={guard:'隣接する味方を、次の自分の番までかばう。',mage:'射程2の味方または自分のHPを60回復。',archer:'射程3・威力1.7倍の強撃。',scout:`同じ横列の${actor?.skillStage===1?'前方':'左右'}の敵へ直進し、手前で止まって攻撃。途中に別のキャラがいれば使用不可。着地点は固定。`,porter:'護送陣が成立中に自分を選択。次の本人の番まで攻撃＋75％・被害−35％。陣形が崩れると効果停止、再成立で復帰。二人で使っても倍率は重複しない。'};
  $('hint').textContent=state.result?'最初から再挑戦できます。':({attack:`本人から縦横${actor.reach}マス以内の敵を選択。`,move:'移動先を仮選択。移動距離2、ユニットを通り抜けません。スカウトだけが境界を越えられます。',skill:skillHints[actor.job]+' MP1。',item:'味方1人のHPを55回復。'})[mode];
  if(!state.result&&actor.job==='porter'&&mode==='move')$('hint').textContent='移動距離2。移動先に生存中の味方がいれば位置を交換できます。途中のキャラは通り抜け不可。ポーターが一人でも倒れるとクエスト失敗。';
 $('movePreview').hidden=!previewing;
 if(previewing){
  const targets=viewedState.units.filter(u=>Battle.legalFor(viewedState,viewedActor,previewKind,u.id)).map(u=>u.name);
  const before=Battle.formation(state),after=Battle.formation(viewedState);
  const risk=state.units.filter(u=>u.side==='enemy'&&u.hp>0&&u.intent.cells.includes(previewPos)).map(u=>u.name);
   $('previewText').textContent=`${rushTarget?'奇襲 → '+state.units.find(u=>u.id===rushTarget).name:'仮配置：'+(previewKind==='attack'?'攻撃':Battle.skillName(actor))+'の対象 '+(targets.join('・')||'なし')} ／ 護送陣 ${after?before?'維持':'再成立':before?'解除':'未成立'} ／ 着地点への予告：${risk.join('・')||'なし'}`;
   if(swapped)$('previewText').textContent=`${actor.name} ⇄ ${swapped.name}：位置を交換 ／ `+$('previewText').textContent;
  $('hint').textContent=rushTarget?'確定すると移動と通常威力の攻撃を一行動で実行。MP1。':'仮配置中はターンを消費しません。移動後の攻撃・支援は次の本人の番です。';
   $('confirmMove').textContent=rushTarget?'奇襲を確定':swapped?'入れ替えを確定':'移動を確定';
   $('previewAttack').disabled=!!rushTarget||actor.job==='porter';$('previewSkill').disabled=!!rushTarget;
  $('previewAttack').className=previewKind==='attack'?'selected':'';$('previewSkill').className=previewKind==='skill'?'selected':'';
 }
 $('roster').innerHTML=state.units.filter(u=>u.side==='ally').map(u=>`<span>${u.name}［${u.role}］ HP ${u.hp}/${u.max} ・MP ${u.mp} ・AGI ${u.agi}${u.hp<=0?' 戦闘不能':u.cover?' ／ '+state.units.find(t=>t.id===u.cover).name+'をかばう':''}</span>`).join('');
 $('intents').innerHTML=state.units.filter(u=>u.side==='enemy'&&u.hp>0).map(u=>`<p><b>${u.name}</b> HP ${u.hp}/${u.max}・MP ${u.mp}：${u.intent.name}<small class="intent-detail">${typeof u.intent.target==='string'?'対象：'+state.units.find(t=>t.id===u.intent.target).name+' ／ ':''}${u.intent.reason}</small></p>`).join('');
 $('log').replaceChildren(...state.log.slice(-40).reverse().map(text=>{const p=document.createElement('p');p.textContent=text;return p;}));
}
$('previewAttack').onclick=()=>{previewKind='attack';render();};$('previewSkill').onclick=()=>{previewKind='skill';render();};
$('confirmMove').onclick=()=>{if(previewPos!==null)perform(rushTarget?'skill':'move',rushTarget||previewPos);};
$('cancelMove').onclick=()=>{recordPlay('battle.preview.cancelled',{destination:previewPos,target:rushTarget});resetPreview();render();};$('restart').onclick=()=>{state=Battle.create();mode='attack';previewKind='attack';resetPreview();playLog.startRun(playLogContext(),'battle.restart');render();};
if(!document.querySelector('#cycle'))recordPlay('run.started',{reason:'page.opened'});
render();
