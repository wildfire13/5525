'use strict';
const VoiceEvents = require('./voice-events.cjs');
const presentation = new (require('./battle-presentation.cjs').Presentation)();
let B;
let CampaignB,masterStartupError=null;
try { CampaignB=require('./campaign-battle.js');B=CampaignB; }
catch (_) { masterStartupError='ゲームデータを読み込めません。配布ファイルを確認してください。セーブデータは変更していません。'; }
let campaign=null,trial=null;
const campaignEngine=()=>require('./campaign.js');
const campaignSummary=()=>campaign?{location:campaign.location,phase:campaign.phase,gold:campaign.gold,xp:campaign.xp,level:campaign.level,selected:campaign.selected,inventory:campaignEngine().inventoryTotals(campaign),activeQuest:campaign.activeQuest,characters:campaign.characters}:null;
function syncCampaign(){if(campaign){B=CampaignB;state=trial?trial.battle:campaign.battle;journey=campaign.journey;}}
const readline = require('node:readline');
const J=require('./journey.js'), P=require('./play-log.js');
let state,journey=null,qa=null,deploymentInitial=[],log=P.create({mode:'battle'});
const context=()=>({battle:state,journey});
const record=(type,details={})=>log.record(type,campaign?{...details,campaign:campaignSummary()}:details,context());
function start(scenario='normal') {
  const options=scenario==='stamp' ? {ally:['warrior','archer','scout'],enemy:['archer','guard'],enemyPotions:0} : scenario==='porter' ? {ally:['guard','archer','porter'],enemy:['scout'],enemyPotions:0} : {};
  if(scenario==='normal'&&B.stepEnemy)options.deployment=true;
  state = B.create(options);
  if(scenario!=='normal') {
    if(!state)return {ok,error,state:null,journey,qa,roster:B.roster,jobs:J.jobs,...(campaign?{campaign:campaignEngine().view(campaign),trial:trial?trial.metadata||{active:true}:null}:{})};
  const a=state.units.find(u=>u.id==='archer');
    state.actor=a.id;a.next=0;
    if(scenario==='support') {
      const g=state.units.find(u=>u.id==='guard');g.pos=23;g.next=0;state.actor=g.id;
      a.hp=30;
      const e=state.units.find(u=>u.id==='enemy-archer');e.pos=14;e.next=.01;
    } else if(scenario==='stamp') {
      const w=state.units.find(u=>u.id==='warrior');state.actor=w.id;w.next=0;
      state.units.find(u=>u.id==='scout').pos=35;
      state.units.find(u=>u.id==='enemy-archer').pos=15;
      state.units.find(u=>u.id==='enemy-guard').pos=45;
    } else if(scenario==='victory') {
      state.units.filter(u=>u.side==='enemy').forEach(u=>u.hp=0);
      const e=state.units.find(u=>u.id==='enemy-archer');e.hp=1;e.pos=15;
    } else if(scenario==='defeat') {
      state.units.filter(u=>u.side==='ally'&&u.id!==a.id).forEach(u=>u.hp=0);
      a.hp=1;a.pos=14;
      const e=state.units.find(u=>u.id==='enemy-scout');e.pos=15;e.next=.01;
    } else if(scenario==='porter') {
      const p=state.units.find(u=>u.id==='porter');p.hp=1;p.pos=24;
      state.units.find(u=>u.id==='guard').pos=32;
      const e=state.units.find(u=>u.id==='enemy-scout');e.pos=25;e.next=.01;
    }
    state.log.push('QA固定局面: '+scenario+'（標準戦闘とは別の境界テスト）');
  }
}
const boardCells = Array.from({length:50}, (_, pos) => pos);
function rangeCells(battle, actor, kind) {
  const support = kind === 'action_skill' && ['skill_heal','skill_cover','skill_formation_boost','skill_healing_cross','skill_defense_line','skill_mana_gift'].includes(B.activeSkill(actor));
  const emptySide = support ? 'ally' : 'enemy';
  return boardCells.filter(pos => {
    const occupant = battle.units.find(unit => unit.hp > 0 && unit.pos === pos);
    return B.inRange(actor, occupant?.side || emptySide, pos, kind, battle);
  });
}
function view(ok=true, error=null) {
  if(!state)return {ok,error,state:null,journey,qa,roster:B.roster,jobs:J.jobs,...(campaign?{campaign:campaignEngine().view(campaign),trial:trial?trial.metadata||{active:true}:null}:{})};
  const a=state.units.find(u=>u.id===state.actor);
  const choices={};
  for(const k of ['action_move','action_attack','action_skill','action_item',...(campaign?['action_ether']:[])]) {
    if(k==='action_skill'&&a&&B.skillTargets){choices[k]=B.skillTargets(state,a);continue;}
    const targets=k==='action_move'||(k==='action_skill'&&a&&B.activeSkill(a)==='skill_stamp')?boardCells:state.units.map(u=>u.id);
    choices[k]=targets.filter(t=>B.legal(state,k,t));
  }
  if(campaign)choices.action_return=a?B.skillTargets(state,a,'action_return'):[];
  const ranges={};
  if(a)for(const kind of ['action_attack','action_skill',...(campaign?['action_return']:[])])ranges[kind]=rangeCells(state,a,kind);
  const deployment=state.deploying?Object.fromEntries(state.units.filter(u=>u.side==='ally'&&u.hp>0).map(u=>[u.id,{ranges:boardCells.filter(p=>B.inRange(u,p%10<5?'ally':'enemy',p,'action_attack',state)),ambush:state.units.filter(t=>t.hp>0&&B.ambush(state,u,t)).map(t=>t.pos)}])):{};
  const stampAreas=a&&B.activeSkill(a)==='skill_stamp'?Object.fromEntries(choices.action_skill.map(p=>[p,B.stampCells(a,p)])):{};
  return {ok,error,state,journey,qa,roster:B.roster,jobs:J.jobs,...(campaign?{campaign:campaignEngine().view(campaign),trial:trial?trial.metadata||{active:true}:null,skillReach:a?B.attackReach(a,'action_skill'):0,normalAttackReach:a?B.attackReach(a,'action_attack'):0,skillset:a?B.activeSkillOptions(a).map(option=>({...option,name:B.skillName({...a,selectedSkill:option.id,selectedSkillKey:option.key}),selected:B.selectedSkillOption(a)?.key===option.key,sources:option.itemId?[{id:option.id,slot:option.slot,itemId:option.itemId,grantSlot:option.grantSlot,level:option.level,itemName:option.id==='skill_item_use'&&option.itemId.startsWith('empty-')?(a.job==='job_porter'?'拳＋2':'拳'):campaignEngine().gear.find(g=>g.id===option.itemId)?.name||option.itemId}]:[]})):[],itemUseInfo:a?B.itemSkillOption(a):null,returnSkillset:a?B.returnSkillOptions(a).map(option=>({...option,name:'帰還',selected:B.returnSkillOption(a)?.key===option.key,sources:option.itemId?[{...option,itemName:campaignEngine().gear.find(g=>g.id===option.itemId)?.name||option.itemId}]:[]})):[],returnSkillInfo:a?B.returnSkillOption(a):null,skillInfo:a?B.skillInfo(a):null,moveReach:a?B.moveReach(a):2,skillEvents:state.skillEvents||[]}:{}),formationSlots:B.formationSlots?B.formationSlots(state):B.slots,enemyInfo:state.units.filter(u=>u.side==='enemy').map(u=>({id:u.id,equipmentNames:Object.values(u.equipment||{}).map(id=>campaignEngine().gear.find(g=>g.id===id)?.name).filter(Boolean),normalReach:B.attackReach(u,'action_attack'),skill:B.skillName(u),reason:'敵の手番で現在の盤面から行動を選択'})),choices,ranges,deployment,stampAreas,queue:B.queue(state),skill:a?B.skillName(a):'',formed:{ally:B.formation(state,'ally'),enemy:B.formation(state,'enemy')},boosted:{ally:B.boosted(state,'ally'),enemy:B.boosted(state,'enemy')}};
}
function preview(kind,target,previewKind='action_attack') {
  if(!state||!B.legal(state,kind,target))return {ok:false,error:'無効なプレビュー'};
  const a=state.units.find(u=>u.id===state.actor),v=JSON.parse(JSON.stringify(state));
  const va=v.units.find(u=>u.id===a.id);
  let destination=null,path=[],swap=null,cells=[];
  if(kind==='action_move') {
    destination=target;swap=B.swapTarget(state,a,target)?.id||null;
    path=B.paths(swap?{...state,units:state.units.filter(u=>u.id!==swap)}:state,a,B.moveReach?B.moveReach(a):2).get(target)||[];
    if(swap)v.units.find(u=>u.id===swap).pos=a.pos;
    va.pos=target;
  } else if(kind==='action_skill'&&B.activeSkill(a)==='skill_ambush') {
    const jump=B.ambush(state,a,state.units.find(u=>u.id===target));
    destination=jump.destination;path=jump.path;va.pos=destination;
  } else if(kind==='action_skill'&&B.activeSkill(a)==='skill_stamp')cells=B.stampCells(a,target);
  else if(kind==='action_skill'&&B.activeSkill(a)==='skill_leg_sweep')cells=B.sweepCells(a);
  else if(kind==='action_skill'&&B.activeSkill(a)==='skill_pole_vault'){destination=target;path=[target];cells=[target];va.pos=target;}
  else if(kind==='action_return'){destination=target;va.pos=target;cells=[target];}
  else if(kind==='action_skill'&&B.equipmentSkills?.[B.activeSkill(a)]){
    const id=B.activeSkill(a),selected=(Array.isArray(target)?target:[target]).map(id=>v.units.find(u=>u.id===id));
    cells=id==='skill_healing_cross'?B.crossCells(selected[0].pos):selected.map(u=>u.pos);
    if(id==='skill_retreat_slash'){destination=B.retreatCell(state,a);va.pos=destination;}
    if(id==='skill_grapple'){const p=B.grappleCell(a,selected[0]);if(!v.units.some(u=>u.hp>0&&u.pos===p))selected[0].pos=p;}
  }
  const inspectKind=kind==='action_move'?previewKind:kind==='action_skill'&&B.activeSkill(a)==='skill_ambush'?'action_attack':kind;
  const skillTargets = inspectKind === 'action_skill' ? B.skillTargets(v,va).flat() : null;
  const skill = B.activeSkill(va);
  const supportSkill = ['skill_healing_cross','skill_defense_line','skill_mana_gift','skill_grapple'].includes(skill);
  const stampArea = !cells.length && skillTargets && skill === 'skill_stamp'
    ? new Set(skillTargets.flatMap(center => B.stampCells(va,center))) : null;
  const targets = v.units.filter(unit => {
    if (kind === 'action_skill' && skill === 'skill_grapple') return unit.id === target;
    if (cells.length) return unit.hp > 0 && (supportSkill ? unit.side === a.side : unit.side !== a.side) && cells.includes(unit.pos);
    if (stampArea) return unit.hp > 0 && unit.side !== a.side && stampArea.has(unit.pos);
    if (skillTargets) return skillTargets.includes(unit.id);
    return B.legalFor(v,va,inspectKind,unit.id);
  }).map(unit => unit.name);
  const ranges = cells.length ? boardCells.filter(pos => cells.includes(pos)) : rangeCells(v,va,inspectKind);
  const risks=[];
  return {ok:true,preview:{units:v.units,destination,path,swap,cells,ranges,targets,risks,effectPreview:B.effectPreview?B.effectPreview(state,a,kind,target):[],
    damagePreview:['action_attack','action_skill'].includes(kind)&&B.damagePreview?B.damagePreview(state,a,kind,target):inspectKind==='action_attack'&&B.attackPreview?v.units.map(u=>B.attackPreview(v,va,u)).filter(Boolean):[],formationBefore:B.formation(state),formationAfter:B.formation(v),...(kind==="action_move"?{formationSlots:B.formationSlots(v)}:{}),kind,target,previewKind}};
}
function trip(action,args=[]) {
  if(campaign||!journey)return false;
  if(action==='forecast')return J.forecast(journey,args[0]);
  if(action==='deploy')return B.deploy(state,...args);
  if(action==='deployment_reset') {
    if(journey.phase!=='deployment')return false;
    deploymentInitial.forEach(p=>state.units.find(u=>u.id===p.id).pos=p.pos);return true;
  }
  if(action==='begin') {
    if(journey.phase!=='deployment'||!B.begin(state))return false;
    journey.phase='battle';return true;
  }
  if(action==='finish')return J.finishBattle(journey,state);
  if(action==='rewards') {
    if(journey.phase!=='result')return false;
    journey.completionSeen=true;return true;
  }
  if(!['accept','select','depart','travel','rest','onward','deliver'].includes(action))return false;
  const ok=J[action](journey,...args);
  if(ok&&action==='travel') {
    const s=journey,count=s.route==='short'?(s.stage===0?3:4):(s.stage===0?2:3);
    state=B.create({ally:s.selected,enemy:J.randomEnemies(count),formation:s.formation,previous:s.party,
      bonusMp:s.kit==='ether'?2:0,skillStage:s.level,potions:s.potions,enemyPotions:s.stage===0?0:1,deployment:true});
    s.history.push('遭遇：'+state.units.filter(u=>u.side==='enemy').map(u=>u.role).join('・'));
    deploymentInitial=state.units.filter(u=>u.side==='ally').map(u=>({id:u.id,pos:u.pos}));
    s.phase='deployment';
  }
  return ok;
}
readline.createInterface({input:process.stdin}).on('line',line=>{
  try {
    const r=JSON.parse(line);let response;
    if(masterStartupError){console.log(JSON.stringify({ok:false,error:masterStartupError,state:null}));return;}
    if(presentation.pending&&!['view','presentation_next','presentation_finish','record'].includes(r.op))
      throw Error('演出中です。完了してから操作・保存してください');
    if(r.op==='presentation_next'||r.op==='presentation_finish') {
      const ok=r.op==='presentation_next'?presentation.next(r.id,r.index):presentation.finish(r.id);
      response={...view(ok,ok?null:'古い演出確認です'),presentation:presentation.info(),voiceEvents:[]};
      console.log(JSON.stringify(response));return;
    }
    if(r.op==='reset') {campaign=null;trial=null;B=CampaignB;qa=null;const switching=!!journey,first=!state;journey=null;start(r.scenario);if(r.presentation&&state.deploying)presentation.start(state,B,()=>B.begin(state));if(switching)log=P.create({mode:'battle'});if(switching||first)record('run.started',{reason:'battle.started'});else log.startRun(context(),'battle.restart');response=view();}
    else if(r.op==='journey_start') {
      const restarting=!!journey;campaign=null;trial=null;B=CampaignB;qa=null;journey=J.create();state=null;deploymentInitial=[];
      if(!restarting){log=P.create({mode:'journey'});record('run.started',{reason:'journey.started'});}
      else log.startRun(context(),'journey.restart');response=view();
    }
    else if(r.op==='campaign_start') {
      campaign=campaignEngine().create();trial=null;qa=null;syncCampaign();
      log=P.create({mode:'campaign'});record('run.started',{reason:'campaign.started'});response=view();
    }
    else if(r.op==='battle_equipment'){
      if(!campaign||!state)throw Error('戦闘がありません');
      response={ok:true,members:state.units.map(u=>({
        id:u.id,name:u.name,job:u.job,side:u.side,
        ...campaignEngine().equipmentSheet(u.equipment||{},campaign.characters[u.id])
      }))};
    }
    else if(r.op==='campaign_save') {
      if(!campaign||trial)throw Error('試用を終了してから保存してください');
      const saved=campaignEngine().serialize(campaign);response={ok:true,data:typeof saved==='string'?JSON.parse(saved):saved};record('campaign.save.prepared');
    }
    else if(r.op==='campaign_load') {
      if(trial)throw Error('試用を終了してから読み込んでください');
      const envelope=typeof r.data==='string'?JSON.parse(r.data):r.data;
      // Frontend PNG payloads have their own file-layer size/hash validation;
      // they are not campaign strings and must not enter its text validator.
      const {nativePortraits:embeddedPortraits,...campaignData}=envelope;
      const loaded=campaignEngine().deserialize(JSON.stringify(campaignData));
      // The file adapter validates embedded images against incoming save IDs.
      // Return them under the same explicit individual-ID map as the campaign.
      const nativePortraits={version:1,characters:{}},person=require('./semantic-ids.cjs').person;
      for(const [id,entry] of Object.entries(embeddedPortraits?.characters||{})){
        const next=person(id);
        if(Object.hasOwn(nativePortraits.characters,next))throw Error('人物画像IDの移行先が重複しています: '+next);
        if(!Object.hasOwn(loaded.characters,next))throw Error('保存画像のキャラIDが不正です');
        nativePortraits.characters[next]=entry;
      }
      if(loaded.battle&&loaded.battle.ethers===undefined)loaded.battle.ethers=campaignEngine().inventoryTotals(loaded).ether;campaign=loaded;trial=null;qa=null;syncCampaign();
      log=P.create({mode:'campaign'});record('run.started',{reason:'campaign.loaded'});response={...view(),nativePortraits};
    }
    else if(r.op==='campaign') {
      if(!campaign)throw Error('キャンペーンがありません');
      const C=campaignEngine(),args=r.args||[];let result,openingVoices;
      if(r.action==='endTrial'){result=!!trial;trial=null;}
      else if(trial)throw Error('木人試用を終了してください');
      else if(r.action==='forecast'){response={...view(),forecast:C.forecast(campaign,...args)};}
      else if(r.action==='previewGear'){response={...view(),previewGear:C.previewGear(campaign,...args)};}
      else if(r.action==='inventoryQuote'){response={...view(),inventoryQuote:C.inventoryQuote(campaign,...args)};}
      else if(r.action==='warehouseQuote'){response={...view(),warehouseQuote:C.warehouseQuote(campaign,...args)};}
      else if(r.action==='saleQuote'){response={...view(),saleQuote:C.saleQuote(campaign,...args)};}
      else if(r.action==='purchaseQuote'){response={...view(),purchaseQuote:C.purchaseQuote(campaign,...args)};}
      else if(r.action==='trial'){trial=C.trial(campaign,...args);result=!!trial;}
      else if(['accept','select','depart','travel','deploy','deployment_assign','chooseFormation','deployment_reset','begin','retreat','turnBack','finishBattle','rest','waitForEvent','onward','arrive','completeQuest','acknowledge','buyGear','buyInventory','buyItem','inn','useItem','inventoryAction','warehouseAction','sellInventory','allocate','allocateBatch'].includes(r.action)) {
        if(r.action==='begin'&&r.presentation) {
          result=presentation.start(state,B,()=>C.begin(campaign,...args),()=>record('campaign.begin',{args,accepted:true}));
        } else if(r.action==='begin') {
          const captured=VoiceEvents.capture(state,B,null,()=>C.begin(campaign,...args));
          result=captured.ok;openingVoices=captured.events;
        } else result=C[r.action](campaign,...args);
      } else throw Error('Unknown campaign action');
      if(!response){syncCampaign();if(!(r.action==='begin'&&r.presentation&&result))record('campaign.'+r.action,{args,accepted:!!result});response=view(!!result,result?null:r.action==='accept'&&!C.view(campaign).hasPorter?'クエスト受注には最低1人のポーターが必要です。':campaign.error||'現在の状態では実行できません');}
      if(openingVoices)response.voiceEvents=openingVoices;
    }
    else if(r.op==='journey') {
      if(r.action==='begin'&&r.presentation){
        B=CampaignB;
        const ok=presentation.start(state,B,()=>trip(r.action,r.args),()=>record('journey.begin',{args:r.args,accepted:true}));
        response={...view(ok),presentation:presentation.info(),voiceEvents:[]};
        console.log(JSON.stringify(response));return;
      }
      const captured=r.action==='begin'?VoiceEvents.capture(state,B,null,()=>trip(r.action,r.args)):null;
      const result=captured?captured.ok:trip(r.action,r.args);
      if(r.action==='forecast')response={...view(),forecast:result};
      else {record('journey.'+r.action,{args:r.args,accepted:result});response=view(!!result,result?null:'現在の状態では実行できません');}
      if(captured)response.voiceEvents=captured.events;
    }
    else if(r.op==='select_return_skill') {
      const ok=!!campaign&&!!state&&B.selectReturnSkill(state,r.skillId);
      if(ok)record('battle.skill.selected',{skillId:'skill_return_home'});
      response=view(ok,ok?null:'装備中の帰還スキルを選んでください');
    }
    else if(r.op==='select_skill') {
      const ok=!!campaign&&!!state&&B.selectSkill(state,r.skillId);
      if(ok)record('battle.skill.selected',{skillId:r.skillId});
      response=view(ok,ok?null:'装備中のスキルを選んでください');
    }
    else if(r.op==='act') {
      const before=(state?.log.length||0)+(state?.logDropped||0),actor=state?.actor;
      if(r.presentation&&B.stepEnemy){
        const ok=presentation.start(state,B,()=>!!state&&(campaign?(trial?campaignEngine().trialAct(trial,r.kind,r.target):campaignEngine().act(campaign,r.kind,r.target)):B.act(state,r.kind,r.target)),()=>{
          if(!campaign&&journey&&state.result&&!state.failure&&state.units.some(u=>u.side==='ally'&&u.hp>0))state.result='勝利！ 荷物を守り切った。';
          record('battle.action',{actor,kind:r.kind,target:r.target??null,...(campaign?{skillId:r.kind==='action_return'?'skill_return_home':r.kind==='action_skill'?B.activeSkill(state.units.find(u=>u.id===actor)):null,skillEvents:state.skillEvents||[]}:{}),messages:state.log.slice(Math.max(0,before-(state.logDropped||0)))});
        });
        if(!ok)record('battle.rejected',{actor,kind:r.kind,target:r.target??null});
        response={...view(ok,ok?null:'不正な行動です'),presentation:presentation.info(),voiceEvents:[]};
        console.log(JSON.stringify(response));return;
      }
      const captured=VoiceEvents.capture(state,B,r.kind,()=>!!state&&(campaign?(trial?campaignEngine().trialAct(trial,r.kind,r.target):campaignEngine().act(campaign,r.kind,r.target)):B.act(state,r.kind,r.target)));
      const ok=captured.ok;
      if(campaign)syncCampaign();
      if(ok&&!campaign&&journey&&state.result&&!state.failure&&state.units.some(u=>u.side==='ally'&&u.hp>0))state.result='勝利！ 荷物を守り切った。';
      record(ok?'battle.action':'battle.rejected',{actor,kind:r.kind,target:r.target??null,...(campaign?{skillId:r.kind==='action_return'?'skill_return_home':r.kind==='action_skill'?B.activeSkill(state.units.find(u=>u.id===actor)):null,skillEvents:state.skillEvents||[]}:{}),messages:state?.log.slice(Math.max(0,before-(state?.logDropped||0)))});
      response={...view(ok,ok?null:'不正な行動です'),voiceEvents:captured.events};
    }
    else if(r.op==='hover_preview') {
      const a=state?.units.find(u=>u.id===state.actor),u=state?.units.find(u=>u.id===r.uid);
      let target=u?.id;
      const skill=a&&B.activeSkill(a),shape=a&&B.equipmentSkills?.[skill]?.target;
      if(r.kind==='action_skill'&&(skill==='skill_stamp'||shape==='cell'))target=u?.pos;
      if(r.kind==='action_skill'&&skill==='skill_leg_sweep'&&(u?.id===a.id||B.sweepTargets(state,a).some(t=>t.id===u?.id)))target=a.id;
      if(r.kind==='action_skill'&&['pair','upToTwo'].includes(shape))target=[...new Set([...(Array.isArray(r.chosen)?r.chosen:[]),u?.id].filter(Boolean))];
      const legal=!!a&&a.side==='ally'&&!!u&&['action_attack','action_skill','action_item','action_ether'].includes(r.kind)&&B.legal(state,r.kind,target);
      const cost=a&&B.skillCost(a);
      const lacksMp=!legal&&a?.side==='ally'&&u&&r.kind==='action_skill'&&a.mp<cost&&B.legalFor(state,{...a,mp:cost},'action_skill',target);
      const support=r.kind!=='action_attack'&&(r.kind!=='action_skill'||['skill_heal','skill_cover','skill_formation_boost','skill_healing_cross','skill_defense_line','skill_mana_gift'].includes(skill));
      const recovery=r.kind==='action_item'||r.kind==='action_ether'||r.kind==='action_skill'&&['skill_heal','skill_healing_cross','skill_mana_gift'].includes(skill);
      const fullHealth=!!a&&a===u&&a.side==='ally'&&a.hp>0&&a.hp===a.max&&a.mp>0&&!state.deploying&&!state.result&&r.kind==='action_skill'&&skill==='skill_heal';
      response={ok:true,hover:{status:legal||fullHealth?'ready':lacksMp?'insufficient_mp':shape==='pair'&&target?.length<2?'needs_targets':'unavailable',fullHealth,accuracy:legal&&r.kind==='action_skill'&&skill==='skill_stamp'?null:legal&&r.kind==='action_attack'?Math.round(100*(1-(B.attackPreview(state,a,u)?.evasionChance||0))):legal&&r.kind==='action_skill'&&skill==='skill_leg_sweep'?B.sweepChance(a)*100:legal&&(!support||recovery)||fullHealth?100:null,...(legal?preview(r.kind,target).preview:{})}};
    }
    else if(r.op==='preview')response=preview(r.kind,r.target,r.previewKind);
    else if(r.op==='godot_io')response=require('./godot-io.cjs')(r);
    else if(r.op==='record') {record(r.type,r.details);response={ok:true};}
    else if(r.op==='export') {record('log.export.requested');response={ok:true,data:{...log.export(context()),...(campaign?{campaign:campaignSummary()}: {})}};}
    else if(r.op==='view')response=view();
    else response={ok:false,error:'Unknown operation'};
    if(presentation.pending)response.presentation=presentation.info();
    console.log(JSON.stringify(response));
  } catch(e) {console.log(JSON.stringify({ok:false,error:e.message}));}
});
