"use strict";
let journey=Journey.create();
state=null; // The standalone battle created by app.js is not part of this trip.
function getJourneyLogState(){return journey;}
function journeyAction(action,...args){
 const from=journey.phase,accepted=Journey[action](journey,...args);
 recordPlay('journey.'+action,{accepted,from,to:journey.phase,args:action==='finishBattle'?[]:args});
 return accepted;
}
recordPlay('run.started',{reason:'page.opened'});
const cycle=document.querySelector('#cycle'),content=document.querySelector('#journey-content');
document.body.prepend(document.querySelector('#battle-trip'));
function partyMarkup(){return (journey.party||Battle.roster.filter(u=>journey.selected.includes(u.id)).map(u=>({...u,hp:u.max}))).map(u=>`<div class="party-line"><img src="${imageRoot+u.image}" alt=""><span><b>${u.name}・${u.role}</b>HP ${u.hp}/${u.max}　MP ${u.mp}${u.hp<=0?' ／ 戦闘不能':''}</span></div>`).join('');}
const deadlineDialog=document.createElement('dialog');
deadlineDialog.id='deadline-dialog';
deadlineDialog.setAttribute('aria-labelledby','deadline-title');
deadlineDialog.setAttribute('aria-describedby','deadline-description');
deadlineDialog.innerHTML='<small>DELIVERY / 配達期限の確認</small><h2 id="deadline-title">配達期限を超過します</h2><p id="deadline-description"></p><div class="deadline-actions"><button id="deadline-back" autofocus>戻る</button><button id="deadline-proceed" class="primary">このまま進む</button></div>';
document.body.append(deadlineDialog);
let deadlineAction=null,deadlineChoice=null;
function cancelDeadline(reason){recordPlay('deadline.cancelled',{choice:deadlineChoice,reason});deadlineAction=null;deadlineChoice=null;}
document.querySelector('#deadline-back').onclick=()=>{cancelDeadline('back');deadlineDialog.close();};
deadlineDialog.addEventListener('cancel',()=>cancelDeadline('escape'));
document.querySelector('#deadline-proceed').onclick=()=>{const action=deadlineAction;recordPlay('deadline.confirmed',{choice:deadlineChoice});deadlineAction=null;deadlineChoice=null;deadlineDialog.close();action?.();};
function confirmDeadline(choice,proceed){
 if(deadlineDialog.open)return;
 const f=Journey.forecast(journey,choice);
 if(!f.late){proceed();return;}
 document.querySelector('#deadline-description').textContent=`${choice==='rest'?'2時間の休息':choice==='safe'?'川沿いの道':'峠の近道'}を選ぶと、残りを最短で進んでも配達は出発から${f.hours}時間後になります。\n\n納期：${journey.job.deadline}時間 ／ 超過：${f.over}時間\n報酬：通常の65％（${Math.floor(journey.job.reward*.65)}G）\n\nこのまま進みますか？`;
 deadlineAction=proceed;deadlineChoice=choice;recordPlay('deadline.prompted',{choice,forecast:f});deadlineDialog.showModal();
}
function cycleRender(){
 cycle.classList.toggle('deploying',journey.phase==='deployment');
 document.body.classList.remove('in-battle');document.querySelector('#battle-return').hidden=true;document.querySelector('#battle-trip').hidden=true;
 const s=journey,phase=s.phase;World.progress(s.stage);
 const completion=phase==='result'&&s.outcome!=='failed'&&!s.completionSeen;
 cycle.classList.toggle('mission-complete',completion);
 document.querySelector('#trip-status').textContent=s.job?`${s.job.cargo} ／ ${s.hours}時間経過・納期${s.job.deadline}時間 ／ ${s.stage}/2区間`:'5 × 5 = 25　／　街道の運び屋';
 const titles={jobs:['今日、誰の荷物を運ぶ？','引き受けられる仕事は一件。あなたの選択で、今日の道が決まる。'],prepare:['荷物を積み、隊を整える。','4人の護送隊と出発。補給品と初期配置を選んでください。'],road:['次の道を選ぶ。','近道は速く、襲撃者が多い。迂回路は時間と引き換えに戦闘を軽くできる。'],camp:['焚き火のそばで。','HP・MP・回復薬は次の戦闘へ引き継ぐ。休むか、そのまま進むか。'],delivery:['荷物を、待つ人の手へ。','最後の一歩。配達を完了して、今日の仕事を締めくくろう。'],result:['道は、次の仕事へ。','一件の配達が、隊の経験になる。']};
 const [title,sub]=titles[phase]||titles.road;document.querySelector('#cycle-title').textContent=title;document.querySelector('#cycle-sub').textContent=sub;
 document.querySelector('#cycle-steps').innerHTML=['jobs','prepare','road','camp','delivery','result'].map((p,i)=>`<span class="${phase===p?'now':''}">${i+1}　${['受注','準備','街道','休息','配達','成長'][i]}</span>`).join('');
 if(phase==='jobs')content.innerHTML=Journey.jobs.map(j=>`<article class="card"><div class="eyebrow">REQUEST / ${j.client}</div><h2>${j.name}</h2><p>${j.text}</p><div class="meta"><span>荷物 ${j.weight}/8枠</span><span>納期 ${j.deadline}時間</span><span>報酬 ${j.reward}G</span></div><button class="primary" data-job="${j.id}">この依頼を引き受ける</button></article>`).join('');
 if(phase==='prepare')content.innerHTML=`<div class="card"><h2>${s.job.cargo}</h2><p>積載 ${s.job.weight}＋補給品2＝${s.job.weight+2}/8枠。補給はどちらか一組。</p><label>補給品<select id="kit"><option value="medicine">救護セット：回復薬3個</option><option value="ether">魔力セット：回復薬1個・各人の初期MP＋2</option></select></label><label>初期配置（各戦闘に適用）<select id="placement"><option value="convoy">護送陣：盾・弓・癒で陣形を維持</option><option value="flank">切り込み配置：ニカを弓手の列へ／護送陣を維持</option></select></label>${partyMarkup()}<div class="actions"><button class="primary" id="depart">この編成で出発</button></div></div>`;
 if(phase==='road')content.innerHTML=`<div class="card"><div class="eyebrow">LEG ${s.stage+1} / 2</div><h2>${s.stage===0?'風切り峠へ':'灯台村へ'}</h2><p>どちらの道にも戦闘があります。戦闘一回は1時間。初回は両ルートとも護送隊より小規模な敵です。</p><div class="actions"><button data-route="short" class="primary">峠の近道・2時間<br><small>敵${s.stage===0?'3':'4'}人</small></button><button data-route="safe">川沿いの道・4時間<br><small>敵${s.stage===0?'2':'3'}人</small></button></div></div><div class="card"><h2>護送隊の状態</h2>${partyMarkup()}<p>回復薬 ${s.potions}個 ／ 納期まで ${s.job.deadline-s.hours}時間</p></div>`;
 if(phase==='camp')content.innerHTML=`<div class="card"><h2>街道の野営地</h2>${partyMarkup()}<p>回復薬 ${s.potions}個。残り一区間、最短であと3時間。</p><div class="actions"><button id="rest" ${s.rested?'disabled':''}>${s.rested?'休息済み':'2時間休む：HP＋60 / MP＋2'}</button><button id="onward" class="primary">先へ進む</button></div></div>`;
 if(phase==='delivery')content.innerHTML=`<div class="card"><div class="eyebrow">DELIVERY</div><h2>${s.job.client}が待っている。</h2><p>${s.hours<=s.job.deadline?'約束の時刻に間に合った。':'約束の時刻を過ぎた。それでも、荷物を必要としている人がいる。'}</p><p>${s.job.cargo} ／ 所要 ${s.hours}時間</p><button id="deliver" class="primary">荷物を渡す</button></div>`;
 if(phase==='result')content.innerHTML=`<div class="card"><div class="eyebrow">${s.outcome==='failed'?'RETREAT':'COMPLETE'}</div><h2>${s.outcome==='failed'?'今回は、引き返そう。':s.outcome==='late'?'遅れても、届いた。':'約束を、届けた。'}</h2><p>${s.outcome==='failed'?'街へ戻り、もう一度準備を整えよう。':s.job.id==='medicine'?'「ありがとう。これで診療を始められるよ」':'「この部品があれば、明日には水車を回せる」'}</p><div class="meta"><span>報酬 ${s.gold}G</span><span>経験値 ${s.xp}/100</span><span>隊Lv.${s.level}</span></div>${s.level===2?'<p><b>成長：ニカの奇襲が第2段階へ。</b><br>前方限定 → 左右。次の段階は十字方向。</p>':'<p>Lv.2で奇襲が前方限定から左右へ成長。</p>'}<p>この試作は一件の仕事で完結。報酬・成長はこの結果画面までの検証です。</p><button id="new-trip" class="primary">別の選択でもう一度</button></div>`;
 content.insertAdjacentHTML('beforeend',`<div class="history">${s.history.join('<br>')}</div>`);
 if(phase==='deployment')renderDeployment();
 if(completion){
  const medicine=s.job.id==='medicine';
  document.querySelector('#cycle-title').textContent='任務達成';
  document.querySelector('#cycle-sub').textContent='街道を越えて、あなたたちは約束の荷物を届けた。';
  content.innerHTML=`<section class="completion-scene" aria-labelledby="completion-title"><div class="delivery-seal" aria-hidden="true">✓</div><div class="eyebrow">DELIVERY COMPLETE / 灯台村</div><h2 id="completion-title">${s.job.name}</h2><p class="completion-story">${medicine?'木箱を受け取ったイネスは、中身を確かめて大きく息をついた。<br>診療所の扉が開き、待っていた人たちが顔を上げる。':'包みをほどいたトマが、部品を両手で持ち上げた。<br>水車小屋の仲間たちにも、ようやく笑顔が戻る。'}</p><blockquote>「${medicine?(s.outcome==='late'?'待っていたよ。さあ、薬を届けに行こう。<br>ここまで運んでくれて、本当にありがとう。':'間に合った……！　これで診療を始められる。<br>ここまで運んでくれて、本当にありがとう。'):'これだ。この部品があれば、また水車を回せる。<br>重かっただろう。よく届けてくれたね。'}」<cite>― ${s.job.client}</cite></blockquote><div class="completion-party">${s.party.map(u=>`<figure><img src="${imageRoot+u.image}" alt="${u.name}"><figcaption>${u.name}</figcaption></figure>`).join('')}</div><p class="completion-cargo">${s.job.cargo}を引き渡した · 所要${s.hours}時間 · ${s.outcome==='late'?'遅配での達成':'納期内に達成'}</p><div class="completion-next"><button id="show-rewards" class="primary">報酬と成長を確認する →</button></div></section>`;
 }
 content.querySelectorAll('[data-job]').forEach(b=>b.onclick=()=>{journeyAction('accept',b.dataset.job);cycleRender();});
 content.querySelectorAll('[data-route]').forEach(b=>b.onclick=()=>confirmDeadline(b.dataset.route,()=>{if(journeyAction('travel',b.dataset.route))startJourneyBattle();}));
 if(phase==='prepare'){
  document.querySelector('#cycle-sub').textContent='最大5人の護送隊を編成。ポーターを最低1人含めて出発します。';
  document.querySelector('#placement').options[0].text='基本配置：各ロールの定位置を優先、重複時は空き枠へ';
  document.querySelector('#placement').options[1].text='切り込み配置：最初のスカウトを弓手の列へ';
  content.querySelector('.card').insertAdjacentHTML('afterbegin',`<section class="party-picker"><h2>護送隊を編成 <span id="party-count"></span></h2><p>${Battle.roster.length}人から最大5人。ポーターは最低1人必要。2人編成も可能ですが、どちらか1人でも倒れるとクエスト失敗です。</p><div class="member-grid">${Battle.roster.map(u=>`<label class="member-choice"><input type="checkbox" data-member="${u.id}" ${s.selected.includes(u.id)?'checked':''}><img src="${imageRoot+u.image}" alt=""><span><b>${u.name}・${u.role}</b><small>HP${u.max} / MP${u.mp} / ${u.job==='porter'?'攻撃なし':'ATK'+u.atk} / AGI${u.agi}</small></span></label>`).join('')}</div><p id="porter-required"></p><p>ポーターは移動先の味方と入れ替え可能（移動距離2）。陣形強化はMP1、次の本人の番まで攻撃＋75％・被害−35％。陣形成立時のみ有効、重複なし。</p><p>槌戦士（仮）：スタンプは隣接マスを中心に縦横4方向の3マス攻撃。リノ／セナ：スナイプはその一撃だけ通常射程＋1。どちらもMP1・通常威力。</p><p>陣形はロールではなく金色の3マスへの配置で成立します。重複ロールは空き配置枠へ入ります。</p></section>`);
  const refresh=()=>{document.querySelector('#party-count').textContent=`${s.selected.length}/5人`;content.querySelectorAll('[data-member]').forEach(b=>{b.disabled=!b.checked&&s.selected.length>=5;});document.querySelector('#depart').disabled=!Journey.hasPorter(s);document.querySelector('#porter-required').textContent=Journey.hasPorter(s)?'ポーター編成済み：出発できます。':'出発にはポーターを最低1人選んでください。';content.querySelectorAll('.party-line').forEach(b=>b.remove());content.querySelector('.actions').insertAdjacentHTML('beforebegin',partyMarkup());};
  content.querySelectorAll('[data-member]').forEach(b=>b.onchange=()=>{journeyAction('select',[...content.querySelectorAll('[data-member]:checked')].map(b=>b.dataset.member));refresh();});refresh();
 }
 const bind=(id,fn)=>{const b=document.getElementById(id);if(b)b.onclick=fn;};
  bind('show-rewards',()=>{s.completionSeen=true;recordPlay('journey.rewards.viewed');cycleRender();window.scrollTo(0,0);});
  if(phase==='result'&&s.outcome==='failed')content.querySelector('.card h2').insertAdjacentHTML('afterend',`<p>${s.failureReason||'クエスト失敗。'}</p>`);
 bind('depart',()=>{journeyAction('depart',document.querySelector('#kit').value,document.querySelector('#placement').value);cycleRender();});bind('rest',()=>confirmDeadline('rest',()=>{journeyAction('rest');cycleRender();}));bind('onward',()=>{journeyAction('onward');cycleRender();});bind('deliver',()=>{journeyAction('deliver');cycleRender();});bind('new-trip',restartJourney);
}
function restartJourney(){
 journey=Journey.create();state=null;mode='attack';previewKind='attack';resetPreview();
 deploymentSelected=null;deploymentInitial=[];deploymentDragging=null;
 deadlineAction=null;deadlineChoice=null;if(deadlineDialog.open)deadlineDialog.close();
 playLog.startRun(playLogContext(),'journey.restart');cycleRender();window.scrollTo(0,0);
}
function startJourneyBattle(){
 const s=journey,count=s.route==='short'?(s.stage===0?3:4):(s.stage===0?2:3);
  state=Battle.create({ally:s.selected,enemy:Journey.randomEnemies(count),formation:s.formation,previous:s.party,bonusMp:s.kit==='ether'?2:0,skillStage:s.level,potions:s.potions,enemyPotions:s.stage===0?0:1,deployment:true});
  s.history.push('遭遇：'+state.units.filter(u=>u.side==='enemy').map(u=>u.role).join('・'));
  deploymentInitial=state.units.filter(u=>u.side==='ally').map(u=>({id:u.id,pos:u.pos}));deploymentSelected=state.units.find(u=>u.side==='ally'&&u.hp>0)?.id;
  s.phase='deployment';recordPlay('deployment.started',{enemies:state.units.filter(u=>u.side==='enemy').map(u=>u.id)});cycleRender();window.scrollTo(0,0);
}
let deploymentSelected=null,deploymentInitial=[],deploymentDragging=null;
function renderDeployment(){
 document.querySelector('#cycle-title').textContent='敵を見て、隊を配置する。';
 document.querySelector('#cycle-sub').textContent='味方を選んで置き先をクリック、または味方画像をドラッグ。味方がいるマスなら交換。配置中は時間・HP・MPを消費しません。';
 const allies=state.units.filter(u=>u.side==='ally'),selected=allies.find(u=>u.id===deploymentSelected);
 content.innerHTML=`<div class="card"><div class="deployment-roster">${allies.map(u=>`<button data-deploy-unit="${u.id}" ${u.hp<=0?'disabled':''} class="${u.id===deploymentSelected?'selected':''}">${u.name}［${u.role}］<small>HP ${u.hp}/${u.max}・MP ${u.mp}${u.hp<=0?'・戦闘不能':''}</small></button>`).join('')}</div><p id="deployment-status">選択中：${selected?.name||'なし'} ／ 護送陣：${Battle.formation(state)?'成立':'未成立'}（攻撃＋50％・被害−25％）</p><p>金枠＝陣形マス ／ 青い面＝選択中の通常攻撃射程 ／ 緑枠＝奇襲可能な敵。敵の行動予告は配置確定後に決まります。</p><div class="deployment-arena">${['ally','enemy'].map(side=>`<section><h2>${side==='ally'?'護送隊 →':'← 街道の襲撃者'}</h2><div class="deployment-board">${Array.from({length:25},(_,i)=>{
 const pos=Battle.cell(side,i),u=state.units.find(u=>u.pos===pos&&u.hp>0),ranged=selected&&Battle.inRange(selected,side,pos,'attack',state),rush=selected?.job==='scout'&&u&&Battle.ambush(state,selected,u);
 return `<button data-deploy-pos="${pos}" ${side==='enemy'?'disabled':''} class="deploy-cell ${Battle.slots[side].includes(pos)?'slot':''} ${ranged?'reach':''} ${rush?'rush':''} ${u?.id===deploymentSelected?'selected':''}" aria-label="${side==='ally'?'味方':'敵'}陣 ${Math.floor(i/5)+1}行${i%5+1}列 ${u?.name||'空き'}"><small>${Math.floor(i/5)+1}-${i%5+1}</small>${u?`<img src="${imageFor(u)}" alt="" draggable="${side==='ally'}" ${side==='ally'?`data-drag-unit="${u.id}"`:''}><b>${u.name}</b><span>HP ${u.hp} / MP ${u.mp}</span>`:''}</button>`;
 }).join('')}</div></section>`).join('')}</div><div class="actions"><button id="reset-deployment">初期配置に戻す</button><button id="begin-battle" class="primary">この配置で戦闘開始</button></div></div>`;
 content.querySelectorAll('[data-deploy-unit]').forEach(b=>b.onclick=()=>{deploymentSelected=b.dataset.deployUnit;recordPlay('deployment.selected',{id:deploymentSelected});renderDeployment();});
 const clearDrag=()=>{deploymentDragging=null;content.querySelectorAll('.drop-target,.drag-source').forEach(b=>b.classList.remove('drop-target','drag-source'));};
 content.querySelectorAll('[data-drag-unit]').forEach(img=>{
  img.ondragstart=e=>{deploymentDragging=img.dataset.dragUnit;e.dataTransfer.effectAllowed='move';e.dataTransfer.setData('text/plain',deploymentDragging);img.closest('button').classList.add('drag-source');};
  img.ondragend=clearDrag;
 });
 content.querySelectorAll('[data-deploy-pos]').forEach(b=>{
  b.onclick=()=>{const pos=Number(b.dataset.deployPos),accepted=Battle.deploy(state,deploymentSelected,pos);recordPlay('deployment.placed',{id:deploymentSelected,pos,method:'click',accepted});if(accepted)renderDeployment();};
  b.ondragover=e=>{if(!deploymentDragging||b.disabled)return;e.preventDefault();e.dataTransfer.dropEffect='move';b.classList.add('drop-target');};
  b.ondragleave=e=>{if(!b.contains(e.relatedTarget))b.classList.remove('drop-target');};
  b.ondrop=e=>{if(!deploymentDragging||b.disabled)return;e.preventDefault();const id=deploymentDragging;clearDrag();const pos=Number(b.dataset.deployPos),accepted=Battle.deploy(state,id,pos);recordPlay('deployment.placed',{id,pos,method:'drag',accepted});if(accepted){deploymentSelected=id;renderDeployment();}};
 });
 document.querySelector('#reset-deployment').onclick=()=>{for(const p of deploymentInitial)state.units.find(u=>u.id===p.id).pos=p.pos;recordPlay('deployment.reset');renderDeployment();};
 document.querySelector('#begin-battle').onclick=()=>{if(Battle.begin(state)){journey.phase='battle';recordPlay('battle.started');showJourneyBattle();}};
}
function showJourneyBattle(){
 const s=journey;
 resetPreview();mode='attack';render();document.body.classList.add('in-battle');
 document.querySelector('body>header small').textContent='GoGo To Go / COURIER’S ROAD — ENCOUNTER '+(s.stage+1);
 document.querySelector('.brief').innerHTML='<b>荷物を守る、街道の戦い</b><p>金色の3マスで護送陣（攻撃＋50％・被害−25％）。HP・MP・回復薬は次の戦闘へ持ち越します。戦闘一回は1時間。今回の奇襲は第1段階：同じ横列の前方へ直進、着地点固定・通り抜け不可。</p><details><summary>補給と成長</summary><p>野営地の休息は2時間。全員HP＋60・MP＋2、戦闘不能者も復帰します。納期内の配達で経験値100、隊Lv.2へ。遅配は経験値60・報酬65％です。</p></details>';
 document.querySelector('.brief').insertAdjacentHTML('beforeend','<p><b>ポーターを守れ：1人でも戦闘不能になると即クエスト失敗。</b>ポーターは攻撃不可。移動先の味方と入れ替え、または陣形成立中にスキルで自分を選んで陣形強化。</p>');
 document.querySelector('#battle-trip').hidden=false;document.querySelector('#battle-trip').textContent=`${s.job.cargo} ／ 第${s.stage+1}区間 ／ ${s.hours}時間経過・納期${s.job.deadline}時間 ／ 奇襲：第1段階・前方のみ`;
 window.scrollTo(0,0);
}
document.addEventListener('battle-action',e=>{if(journey.phase!=='battle')return;for(const u of state.units){const old=e.detail.before.find(p=>p.id===u.id);if(old&&old.hp!==u.hp)World.burst(old.pos,u.hp>old.hp);}if(state.result){recordPlay('battle.finished');const won=!state.failure&&state.units.some(u=>u.side==='ally'&&u.hp>0);if(won){state.result='勝利！ 荷物を守り切った。';render();}const b=document.querySelector('#battle-return');b.hidden=false;b.textContent=won?'戦闘を終えて街道へ':'クエスト失敗の結果へ';}});
document.querySelector('#battle-return').onclick=()=>{if(journeyAction('finishBattle',state)){cycleRender();window.scrollTo(0,0);}};
cycleRender();
