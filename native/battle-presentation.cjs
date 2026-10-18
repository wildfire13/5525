'use strict';

// Transient presentation state stays outside the battle/save schema.
const observers=new WeakMap(), stepping=new WeakSet();
const clone=value=>JSON.parse(JSON.stringify(value));
function mark(state, actor, kind, target, engine) {
  observers.get(state)?.action(actor,kind,target,engine);
}
function restore(state,snapshot) {
  for(const key of Object.keys(state))delete state[key];
  Object.assign(state,clone(snapshot));
}
function capture(state,engine,run) {
  const frames=[],cleanups=[];
  let current=null, actionNumber=0;const spoken=new Set();
  const add=(phase,unit,extra={})=>{
    const voiceEvents=(extra.voiceEvents||[]).filter(event=>{
      const key=event.character_id+'/'+event.cue;if(spoken.has(key))return false;spoken.add(key);return true;
    });
    frames.push({phase,unit_id:unit?.id||null,actor_id:current?.id||null,
      action_number:actionNumber,...extra,voiceEvents,state:clone(state)});
  };
  const observer={action(actor,kind,target,eng=engine){
    // enemyAction marks even misses; its nested apply must not duplicate it.
    if(current===actor)return;
    current=actor;actionNumber++;spoken.clear();
    const cue=kind==='return'?'skill:returnHome':kind==='skill'?'skill:'+eng.activeSkill(actor):'attack';
    add('action',actor,{kind,skill_id:kind==='skill'?eng.activeSkill(actor):kind==='return'?'returnHome':null,target:clone(target??null),label:actor.name+'：'+
      (kind==='skill'?eng.skillName(actor):({attack:'攻撃',move:'移動',guard:'防御',item:'回復薬',ether:'エーテル',return:'帰還',skip:'足払いで手番をスキップ'}[kind]||kind)),
      voiceEvents:actor.side==='ally'&&['attack','skill','return'].includes(kind)?[{character_id:actor.id,cue}]:[]});
  }};
  observers.set(state,observer);stepping.add(state);
  try {
    for(const unit of state.units)for(const key of ['hp','pos']){
      const descriptor=Object.getOwnPropertyDescriptor(unit,key);let value=unit[key];
      cleanups.push(()=>Object.defineProperty(unit,key,{...descriptor,value}));
      Object.defineProperty(unit,key,{enumerable:true,configurable:true,get:()=>value,set:next=>{
        const previous=value;value=next;
        if(next===previous)return;
        const phase=key==='pos'?'move':next<previous?'hurt':'heal';
        add(phase,unit,{...(phase==='move'&&unit===current&&engine.activeSkill(current)==='poleVault'?{jump:true}:{}),from:previous,to:next,label:unit.name+'：'+
          (phase==='move'?'移動':phase==='hurt'?'被ダメージ '+(previous-next):'HP回復 '+(next-previous)),
          voiceEvents:phase==='hurt'&&unit.side==='ally'?[{character_id:unit.id,cue:'hurt'}]:[]});
      }});
    }
    const ok=run();
    if(ok)add('settled',current,{label:'行動結果'});
    return {ok,frames:ok?frames:[]};
  } finally {
    cleanups.forEach(fn=>fn());observers.delete(state);stepping.delete(state);
  }
}

class Presentation {
  constructor(){this.serial=0;this.pending=null;}
  start(state,engine,run,onComplete=()=>{}) {
    if(this.pending)throw Error('演出中です');
    const before=clone(state);
    let result;
    try {result=capture(state,engine,run);} catch(error){restore(state,before);throw error;}
    if(!result.ok){restore(state,before);return false;}
    this.pending={id:++this.serial,index:0,state,engine,frames:result.frames,offset:0,batch:0,onComplete};
    this.show();return true;
  }
  show(){const p=this.pending;restore(p.state,p.frames[p.offset].state);}
  info(){
    const p=this.pending;if(!p)return null;
    const {state,...frame}=p.frames[p.offset];
    return {id:p.id,index:p.index,action_id:`${p.id}:${p.batch}:${frame.action_number}`,impact_group_id:0,...frame};
  }
  next(id,index){
    const p=this.pending;
    if(!p||p.id!==id||p.index!==index)return false;
    p.index++;p.offset++;
    if(p.offset<p.frames.length){this.show();return true;}
    const actor=p.state.units.find(u=>u.id===p.state.actor);
    if(!p.state.result&&actor?.side==='enemy'&&p.engine.stepEnemy){
      const result=capture(p.state,p.engine,()=>p.engine.stepEnemy(p.state));
      if(!result.ok)throw Error('敵行動を進められません');
      p.frames=result.frames;p.offset=0;p.batch++;this.show();return true;
    }
    this.pending=null;p.onComplete();return true;
  }
  finish(id){
    if(!this.pending||this.pending.id!==id)return false;
    // Closing a window settles the already accepted action once, silently.
    while(this.pending)this.next(this.pending.id,this.pending.index);
    return true;
  }
}
module.exports={mark,isStepping:state=>stepping.has(state),capture,Presentation};
