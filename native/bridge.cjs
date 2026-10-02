'use strict';
const LegacyB = require('./battle.js');
let B = LegacyB;
const CampaignB = require('./campaign-battle.js');
let campaign=null,trial=null;
const campaignEngine=()=>require('./campaign.js');
const campaignSummary=()=>campaign?{location:campaign.location,phase:campaign.phase,gold:campaign.gold,xp:campaign.xp,level:campaign.level,selected:campaign.selected,inventory:campaign.inventory,activeQuest:campaign.activeQuest,characters:campaign.characters}:null;
function syncCampaign(){if(campaign){B=CampaignB;state=trial?trial.battle:campaign.battle;journey=campaign.journey;}}
const readline = require('node:readline');
const J=require('./journey.js'), P=require('./play-log.js');
let state,journey=null,qa=null,deploymentInitial=[],log=P.create({mode:'battle'});
const context=()=>({battle:state,journey});
const record=(type,details={})=>log.record(type,campaign?{...details,campaign:campaignSummary()}:details,context());
function start(scenario='normal') {
  state = B.create(scenario==='stamp' ? {ally:['warrior','archer','scout'],enemy:['archer','guard'],enemyPotions:0} : scenario==='porter' ? {ally:['guard','archer','porter'],enemy:['scout'],enemyPotions:0} : {});
  if(scenario!=='normal') {
    if(!state)return {ok,error,state:null,journey,qa,roster:B.roster,jobs:J.jobs,...(campaign?{campaign:campaignEngine().view(campaign),trial:trial?trial.metadata||{active:true}:null}:{})};
  const a=state.units.find(u=>u.id==='archer');
    state.actor=a.id;a.next=0;
    if(scenario==='support') {
      const g=state.units.find(u=>u.id==='guard');g.pos=23;g.next=0;state.actor=g.id;
      a.hp=30;
      const e=state.units.find(u=>u.id==='enemy-archer');e.pos=14;e.next=.01;B.plan(state,e);
    } else if(scenario==='stamp') {
      const w=state.units.find(u=>u.id==='warrior');state.actor=w.id;w.next=0;
      state.units.find(u=>u.id==='scout').pos=35;
      state.units.find(u=>u.id==='enemy-archer').pos=15;
      state.units.find(u=>u.id==='enemy-guard').pos=45;
      state.units.filter(u=>u.side==='enemy').forEach(u=>B.plan(state,u));
    } else if(scenario==='victory') {
      state.units.filter(u=>u.side==='enemy').forEach(u=>u.hp=0);
      const e=state.units.find(u=>u.id==='enemy-archer');e.hp=1;e.pos=15;
    } else if(scenario==='defeat') {
      state.units.filter(u=>u.side==='ally'&&u.id!==a.id).forEach(u=>u.hp=0);
      a.hp=1;a.pos=14;
      const e=state.units.find(u=>u.id==='enemy-scout');e.pos=15;e.next=.01;B.plan(state,e);
    } else if(scenario==='porter') {
      const p=state.units.find(u=>u.id==='porter');p.hp=1;p.pos=24;
      state.units.find(u=>u.id==='guard').pos=32;
      const e=state.units.find(u=>u.id==='enemy-scout');e.pos=25;e.next=.01;B.plan(state,e);
    }
    state.log.push('QA固定局面: '+scenario+'（標準戦闘とは別の境界テスト）');
  }
}
function view(ok=true, error=null) {
  if(!state)return {ok,error,state:null,journey,qa,roster:B.roster,jobs:J.jobs,...(campaign?{campaign:campaignEngine().view(campaign),trial:trial?trial.metadata||{active:true}:null}:{})};
  const a=state.units.find(u=>u.id===state.actor);
  const choices={};
  for(const k of ['move','attack','skill','item']) {
    const targets=k==='move'||(k==='skill'&&a&&B.activeSkill(a)==='stamp')?Array.from({length:50},(_,i)=>i):state.units.map(u=>u.id);
    choices[k]=targets.filter(t=>B.legal(state,k,t));
  }
  const ranges={};
  if(a)for(const kind of ['attack','skill'])ranges[kind]=Array.from({length:50},(_,p)=>p).filter(p=>{const u=state.units.find(u=>u.hp>0&&u.pos===p),support=kind==='skill'&&['mage','guard','porter'].includes(B.activeSkill(a));return B.inRange(a,u?.side||(support?'ally':'enemy'),p,kind,state);});
  const deployment=state.deploying?Object.fromEntries(state.units.filter(u=>u.side==='ally'&&u.hp>0).map(u=>[u.id,{ranges:Array.from({length:50},(_,p)=>p).filter(p=>B.inRange(u,p%10<5?'ally':'enemy',p,'attack',state)),ambush:state.units.filter(t=>t.hp>0&&B.ambush(state,u,t)).map(t=>t.pos)}])):{};
  const stampAreas=a&&B.activeSkill(a)==='stamp'?Object.fromEntries(choices.skill.map(p=>[p,B.stampCells(a,p)])):{};
  return {ok,error,state,journey,qa,roster:B.roster,jobs:J.jobs,...(campaign?{campaign:campaignEngine().view(campaign),trial:trial?trial.metadata||{active:true}:null}:{}),choices,ranges,deployment,stampAreas,queue:B.queue(state),skill:a?B.skillName(a):'',formed:{ally:B.formation(state,'ally'),enemy:B.formation(state,'enemy')},boosted:{ally:B.boosted(state,'ally'),enemy:B.boosted(state,'enemy')}};
}
function preview(kind,target,previewKind='attack') {
  if(!state||!B.legal(state,kind,target))return {ok:false,error:'無効なプレビュー'};
  const a=state.units.find(u=>u.id===state.actor),v=JSON.parse(JSON.stringify(state));
  const va=v.units.find(u=>u.id===a.id);
  let destination=null,path=[],swap=null,cells=[];
  if(kind==='move') {
    destination=target;swap=B.swapTarget(state,a,target)?.id||null;
    path=B.paths(swap?{...state,units:state.units.filter(u=>u.id!==swap)}:state,a,2).get(target)||[];
    if(swap)v.units.find(u=>u.id===swap).pos=a.pos;
    va.pos=target;
  } else if(kind==='skill'&&B.activeSkill(a)==='scout') {
    const jump=B.ambush(state,a,state.units.find(u=>u.id===target));
    destination=jump.destination;path=jump.path;va.pos=destination;
  } else if(kind==='skill'&&B.activeSkill(a)==='stamp')cells=B.stampCells(a,target);
  const inspectKind=kind==='move'?previewKind:kind==='skill'&&B.activeSkill(a)==='scout'?'attack':kind;
  const targets=v.units.filter(u=>cells.length?u.hp>0&&u.side!==a.side&&cells.includes(u.pos):inspectKind==='skill'&&B.activeSkill(va)==='stamp'?u.hp>0&&u.side!==a.side&&Array.from({length:50},(_,p)=>p).some(p=>B.legalFor(v,va,'skill',p)&&B.stampCells(va,p).includes(u.pos)):B.legalFor(v,va,inspectKind,u.id)).map(u=>u.name);
  const ranges=Array.from({length:50},(_,p)=>p).filter(p=>{
    const u=v.units.find(u=>u.hp>0&&u.pos===p),support=inspectKind==='skill'&&['mage','guard','porter'].includes(B.activeSkill(va));
    return cells.length?cells.includes(p):B.inRange(va,u?.side||(support?'ally':'enemy'),p,inspectKind,v);
  });
  const risks=state.units.filter(u=>u.hp>0&&u.side==='enemy'&&u.intent?.cells.includes(destination)).map(u=>u.name);
  return {ok:true,preview:{units:v.units,destination,path,swap,cells,ranges,targets,risks,
    formationBefore:B.formation(state),formationAfter:B.formation(v),kind,target,previewKind}};
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
    if(r.op==='reset') {campaign=null;trial=null;B=LegacyB;qa=null;const switching=!!journey,first=!state;journey=null;start(r.scenario);if(switching)log=P.create({mode:'battle'});if(switching||first)record('run.started',{reason:'battle.started'});else log.startRun(context(),'battle.restart');response=view();}
    else if(r.op==='journey_start') {
      const restarting=!!journey;campaign=null;trial=null;B=LegacyB;qa=null;journey=J.create();state=null;deploymentInitial=[];
      if(!restarting){log=P.create({mode:'journey'});record('run.started',{reason:'journey.started'});}
      else log.startRun(context(),'journey.restart');response=view();
    }
    else if(r.op==='qa_fixture') {
      campaign=null;trial=null;B=LegacyB;const fixture=require('./qa-fixtures.cjs').makeJourneyFixture(r.name);
      journey=fixture.journey;state=fixture.state;qa=fixture.metadata;deploymentInitial=[];
      log=P.create({mode:'journey'});record('qa.fixture.generated',qa);response=view();
    }
    else if(r.op==='campaign_start') {
      campaign=campaignEngine().create();trial=null;qa=null;syncCampaign();
      log=P.create({mode:'campaign'});record('run.started',{reason:'campaign.started'});response=view();
    }
    else if(r.op==='campaign_save') {
      if(!campaign||trial)throw Error('試用を終了してから保存してください');
      const saved=campaignEngine().serialize(campaign);response={ok:true,data:typeof saved==='string'?JSON.parse(saved):saved};record('campaign.save.prepared');
    }
    else if(r.op==='campaign_load') {
      if(trial)throw Error('試用を終了してから読み込んでください');
      const loaded=campaignEngine().deserialize(typeof r.data==='string'?r.data:JSON.stringify(r.data));campaign=loaded;trial=null;qa=null;syncCampaign();
      log=P.create({mode:'campaign'});record('run.started',{reason:'campaign.loaded'});response=view();
    }
    else if(r.op==='campaign') {
      if(!campaign)throw Error('キャンペーンがありません');
      const C=campaignEngine(),args=r.args||[];let result;
      if(r.action==='endTrial'){result=!!trial;trial=null;}
      else if(trial)throw Error('木人試用を終了してください');
      else if(r.action==='forecast'){response={...view(),forecast:C.forecast(campaign,...args)};}
      else if(r.action==='previewGear'){response={...view(),previewGear:C.previewGear(campaign,...args)};}
      else if(r.action==='trial'){trial=C.trial(campaign,...args);result=!!trial;}
      else if(['accept','select','depart','travel','deploy','deployment_reset','begin','retreat','finishBattle','rest','onward','arrive','acknowledge','buyGear','buyItem','inn','useItem','allocate'].includes(r.action)) {
        result=C[r.action](campaign,...args);
      } else throw Error('Unknown campaign action');
      if(!response){syncCampaign();record('campaign.'+r.action,{args,accepted:!!result});response=view(!!result,result?null:campaign.error||'現在の状態では実行できません');}
    }
    else if(r.op==='journey') {
      const result=trip(r.action,r.args);
      if(r.action==='forecast')response={...view(),forecast:result};
      else {record('journey.'+r.action,{args:r.args,accepted:result});response=view(!!result,result?null:'現在の状態では実行できません');}
    }
    else if(r.op==='act') {
      const before=(state?.log.length||0)+(state?.logDropped||0),actor=state?.actor;
      const ok=!!state&&(campaign?(trial?campaignEngine().trialAct(trial,r.kind,r.target):campaignEngine().act(campaign,r.kind,r.target)):B.act(state,r.kind,r.target));
      if(campaign)syncCampaign();
      if(ok&&!campaign&&journey&&state.result&&!state.failure&&state.units.some(u=>u.side==='ally'&&u.hp>0))state.result='勝利！ 荷物を守り切った。';
      record(ok?'battle.action':'battle.rejected',{actor,kind:r.kind,target:r.target??null,messages:state?.log.slice(Math.max(0,before-(state?.logDropped||0)))});
      response=view(ok,ok?null:'不正な行動です');
    }
    else if(r.op==='preview')response=preview(r.kind,r.target,r.previewKind);
    else if(r.op==='record') {record(r.type,r.details);response={ok:true};}
    else if(r.op==='export') {record('log.export.requested');response={ok:true,data:{...log.export(context()),...(campaign?{campaign:campaignSummary()}: {})}};}
    else if(r.op==='view')response=view();
    else response={ok:false,error:'Unknown operation'};
    console.log(JSON.stringify(response));
  } catch(e) {console.log(JSON.stringify({ok:false,error:e.message}));}
});
