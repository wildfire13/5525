'use strict';
// Replayable native prototype adapter. The frozen Journey/Battle defaults are
// still usable independently. Every number, road, offer and shop item below is
// a PROVISIONAL playtest choice, not a newly settled design decision.
const B = require('./campaign-battle.js');
const J = require('./journey.js');
const E = require('./equipment-skills.js');
const S = require('./equipment-slots.js');
const I = require('./character-inventory.js');
const Cargo = require('./quest-cargo.js');
const {createHash,randomUUID} = require('node:crypto');
const {isDeepStrictEqual} = require('node:util');
const Campaign = (() => {
  const INN_PRICE = 30; // Whole active party, provisional playtest price.
  const VERSION = 2, MAX_SAVE_BYTES = 1024 * 1024;
  const clone = value => JSON.parse(JSON.stringify(value));
  const inventoryEpochs=new WeakMap();
  function inventoryEpoch(s){if(!inventoryEpochs.has(s))inventoryEpochs.set(s,{id:randomUUID(),revision:0});return inventoryEpochs.get(s);}
  function invalidateInventory(s){inventoryEpoch(s).revision++;}
  const locations = [
    {id:'astaris',name:'アスタリス',kind:'city',facilities:['board','guild','inn']},
    {id:'east',name:'イース',kind:'village',facilities:['board','weapon']},
    {id:'west',name:'ウエス',kind:'village',facilities:['board','armor']},
    {id:'south',name:'サウス',kind:'village',facilities:['board','items']},
    {id:'north',name:'ノース',kind:'village',facilities:['board','accessory']},
  ];
  const materials = {
    wood:{name:'木製',metal:false},iron:{name:'鉄製',metal:true},
    silver:{name:'銀製',metal:true},cloth:{name:'布製',metal:false},leather:{name:'革製',metal:false},
  };
  // Legacy IDs retained; weapon/armor storage keys now mean right hand/upper body.
  const gear = require('./master-data.cjs').getMaster().gear;
  const items = [
    {id:'potion',name:'ポーション',price:40,amount:55,resource:'hp',battleKind:'item'},
    {id:'ether',name:'エーテル',price:30,amount:3,resource:'mp',battleKind:'ether',battleRole:'porter'},
  ];
  const skills = {guard:'かばう',archer:'スナイプ',mage:'ヒール',scout:'奇襲',stamp:'スタンプ',porter:'陣形強化',...Object.fromEntries(Object.entries(E.definitions).map(([id,d])=>[id,d.name]))};
  const provisional = [
    '地名・商品・価格・能力・成長値・依頼・経路は試遊用の仮設定です',
    '中央と各村、および隣接する村同士を結ぶ道路。各村から3方向へ移動できます',
    '装備は右手・左手・頭・上半身・下半身・足・装飾2枠。両手剣・両手槍は左右2枠を占有します',
    '防具の保護を最大HP増加で仮表現。武器スキル・材質・要求能力に差があります',
    'C01は保留。ポーターの攻撃不可を維持し、買い替えても攻撃スキルを有効化しません',
    '失敗時は受注直前（未受注移動は出発直前）の所持金・装備・編成・HP/MP・アイテム・EXP・経過時間へ復元します',
    'セーブはこの試作の単一データJSON。職解放・別セーブ統合・本開発の引継ぎを確定しません',
  ];
  const getGear = id => gear.find(g=>g.id===id);
  const getPlace = id => locations.find(p=>p.id===id);
  const template = id => B.roster.find(c=>c.id===id);
  const bases = {
    guard:{race:'human',str:16,int:8,agi:10,weapon:'sword-wood'},
    archer:{race:'human',str:12,int:8,agi:14,weapon:'bow-wood'},
    mage:{race:'elf',str:14,int:16,agi:11,weapon:'staff-wood'},
    scout:{race:'elf',str:10,int:9,agi:13,weapon:'dagger-wood'},
    porter:{race:'human',str:14,int:10,agi:12,weapon:'porter-kit'},
    warrior:{race:'dwarf',str:18,int:8,agi:10,weapon:'hammer-iron-1'},
  };
  function equipment(c,replacement) {
    const out=Object.fromEntries(Object.keys(S.slots).map(slot=>[slot,c[S.storage(slot)]||(slot.startsWith('accessory')?defaultAccessory(c,slot):`empty-${slot}`)]));
    if(replacement){out[S.canonical(replacement.targetSlot||replacement.slot)]=replacement.id;if(replacement.hands===2)out.leftHand='empty-leftHand';}
    return out;
  }
  function effectiveGear(c,slot,id,eq=equipment(c)) {
    const g=getGear(id);
    if(c.combatRevision!==1)return id==='longspear-wood'?{...g,skill:undefined}:g;
    if(['rightHand','leftHand'].includes(slot)&&g?.type==='empty'&&!(slot==='leftHand'&&getGear(eq.rightHand)?.hands===2)) {
      const fist=getGear(template(c.id).job==='porter'?'fist-2':'fist');
      return {...fist,id,type:'empty',virtualDefault:true};
    }
    return g;
  }
  function gearGrants(g) {
    const canonical=getGear(g.id),same=g.skill===canonical?.skill&&g.effect===canonical?.effect;
    return same?(require('./master-data.cjs').getMaster().grantsByEquipment[g.id]||[]).filter(x=>x.sourceField!=='legacySkill'):[g.skill,g.effect].filter(Boolean).map((id,index)=>({id,level:g.skillLevel??1,slotNo:index+1}));
  }
  function displayGear(g) {
    return {...clone(g),skillGrants:gearGrants(g).map(({id,level,slotNo})=>({id,level,slotNo}))};
  }
  function stats(c,replacement) {
    const t=template(c.id),base=bases[t.job],eq=equipment(c,replacement),entries=Object.entries(eq).map(([slot,id])=>({slot,gear:c.equipmentRevision===2?effectiveGear(c,slot,id,eq):{...getGear(id),skill:id==='longspear-wood'?undefined:getGear(id)?.legacySkill||getGear(id)?.skill}}));
    const w=entries.find(e=>['rightHand','leftHand'].includes(e.slot)&&e.gear.type!=='empty'&&(e.gear.atk||0)>0)?.gear||getGear('empty-rightHand');
    const str=base.str+c.allocations.str,int=base.int+c.allocations.int,agi=base.agi+c.allocations.agi;
    const skillSources=entries.flatMap(({slot,gear:g})=>{
      // Effective virtual fists and old save revisions retain their legacy contract.
      const grants=gearGrants(g);
      return grants.map(({id,level,slotNo})=>({id,slot,itemId:g.id,grantSlot:slotNo,classification:E.definitions[id]?.classification||(id==='invasion'?'passive':'active'),...(['scout','itemUse','legSweep','grapple','poleVault'].includes(id)?{level}: {})}));
    });
    const supplied=[...new Set(skillSources.filter(x=>x.classification==='active'&&x.id!=='returnHome').map(x=>x.id))];
    const activeSkills=t.job==='porter'?['porter',...supplied.filter(id=>['itemUse','legSweep','grapple','poleVault'].includes(id))]:supplied;
    const effects=[...new Set(skillSources.filter(x=>x.classification==='passive'||x.id==='returnHome').map(x=>x.id))];
    const attackWeapons=t.job==='porter'?[]:entries.filter(e=>['rightHand','leftHand'].includes(e.slot)&&e.gear.type!=='empty'&&(e.gear.atk||0)>0).map(({slot,gear:g})=>({slot,itemId:g.id,name:g.name,atk:g.atk,reach:g.reach,skill:g.skill||null}));
    const attackBonus=t.job==='porter'?0:Math.floor(c.allocations.str/2);
    const sum=key=>entries.reduce((n,e)=>n+(e.gear[key]||0),0);
    return {str,int,agi,attributeBreakdown:{str:{base:base.str,growth:c.allocations.str},int:{base:base.int,growth:c.allocations.int},speed:{agi,equipment:sum('agiBonus')}},effects,activeSkills,skillSources,attackWeapons,attackBonus,normalReach:Math.max(0,...attackWeapons.map(w=>w.reach)),equipment:eq,weaponType:w.type,max:t.max+sum('hp')+3*c.allocations.str,maxMp:t.mp+Math.floor(c.allocations.int/2)+sum('mp'),
      atk:t.job==='porter'?0:(w.atk||0)+Math.floor(c.allocations.str/2),def:c.def??0,reach:t.job==='porter'?0:w.reach||1,
      speed:Math.max(1,agi+sum('agiBonus')),skill:activeSkills[0]||null};
  }
  const defaultAccessory=(c,slot)=>slot==='accessory1'&&template(c.id).job==='scout'?'invasion-charm-1':`empty-${slot}`;
  function character(id) {
    const t=template(id),base=bases[t.job];
    return {id,equipmentRevision:2,combatRevision:1,inventory:{},...(t.job==='guard'?{leftHand:'guard-shield-wood'}:{}),race:base.race,weapon:base.weapon,armor:'armor-cloth',hp:t.max,mp:t.mp,def:0,xp:0,level:1,statPoints:0,skillPoints:0,allocations:{str:0,int:0,agi:0}};
  }
  function create() {
    const state={version:VERSION,phase:'town',location:'astaris',gold:180,xp:0,level:1,hours:0,
      selected:['guard','archer','mage','scout','porter'],characters:Object.fromEntries(B.roster.map(t=>[t.id,character(t.id)])),
      activeQuest:null,journey:null,battle:null,rollback:null,
      sequence:0,boardRound:0,completed:0,result:null,history:['アスタリスに到着。繰り返し遊べる試作を開始。']};
    state.cargoRevision=1;state.characters[state.selected[0]].inventory={potion:3,ether:1};return state;
  }
  function inventoryTotals(s,ids=s.selected) {
    return Object.fromEntries(items.map(item=>[item.id,ids.reduce((n,id)=>n+I.count(s.characters[id]?.inventory,item.id),0)]));
  }
  function inventoryToken(s) {
    return createHash('sha256').update(JSON.stringify([inventoryEpoch(s),s.version,s.phase,s.location,s.selected,s.gold,s.characters,s.sequence])).digest('hex');
  }
  function note(s,text) {s.history.push(text);if(s.history.length>200)s.history.splice(0,s.history.length-200);}
  function hasPorter(s) {return s.selected.some(id=>template(id)?.job==='porter');}
  // R08: center spokes plus the bidirectional east-north-west-south ring.
  const routes={astaris:['east','west','south','north'],east:['north','astaris','south'],north:['east','astaris','west'],west:['north','astaris','south'],south:['east','astaris','west']};
  function destinations(s) {return (routes[s.location]||[]).map(getPlace);}
  function board(s) {
    if(s.phase!=='town'||s.activeQuest)return [];
    const choices=s.location==='astaris'?[locations[1+s.boardRound%4],locations[1+(s.boardRound+1)%4]]:destinations(s);
    return choices.map((p,i)=>{
      const urgent=s.location==='astaris'?i===0:s.boardRound%2===0;
      const flavors={east:['鍛冶職人リタ','鍛冶場の包帯'],west:['仕立屋エマ','染料の小瓶'],south:['薬師イネス','診療所の薬箱'],north:['村の世話役ノア','雪道の灯油'],astaris:['ギルド受付サラ','村からの修理部品']},[client,cargo]=flavors[p.id];
      return {id:`${s.location}-${p.id}-${s.boardRound}-${i}`,from:s.location,to:p.id,
        name:`${p.name}へ、${urgent?'急ぎの'+cargo:'修理用の部品箱'}（仮）`,client:client+'（仮）',
        cargo:urgent?cargo:'修理用の部品箱',weight:urgent?3:5,deadline:urgent?6:10,reward:urgent?180:150,xp:100,
        text:'繰り返しの受注・移動・買い替えを確かめる仮の配達依頼です。急ぎは納期6時間・報酬180G、通常は10時間・150G。'};
    });
  }
  function snapshot(s) {const saved=clone(s);saved.rollback=null;saved.battle=null;saved.journey=null;saved.result=null;return saved;}
  const PARTY_LIMIT=12,BATTLE_LIMIT=5;
  const battleIds=s=>s.battleSelected??s.selected;
  function select(s,ids) {
    if(s.phase!=='town'||s.location!=='astaris'||!Array.isArray(ids)||ids.length<1||ids.length>PARTY_LIMIT||new Set(ids).size!==ids.length||ids.some(id=>!template(id)))return false;
    if(s.battleSelected!==undefined||ids.length>BATTLE_LIMIT){const kept=battleIds(s).filter(id=>ids.includes(id));s.battleSelected=[...kept,...ids.filter(id=>!kept.includes(id))].slice(0,BATTLE_LIMIT);}
    s.selected=[...ids];invalidateInventory(s);note(s,'ギルドで無償編成。キャラ別の装備は保持。');return true;
  }
  function accept(s,id,ownerId) {
    if(s.phase!=='town'||s.activeQuest||!hasPorter(s))return false;
    const quest=board(s).find(q=>q.id===id);if(!quest)return false;
    if(!s.selected.includes(ownerId)||template(ownerId)?.job!=='porter')return false;
    s.rollback=snapshot(s);s.sequence++;s.activeQuest={...quest,token:s.sequence};Cargo.issue(s,ownerId);invalidateInventory(s);note(s,quest.name+'を受注。'+template(ownerId).name+'が「荷物」を受け取りました。');return true;
  }
  function depart(s,destination,formation='convoy') {
    if(s.phase!=='town'||!destinations(s).some(p=>p.id===destination)||!['convoy','flank'].includes(formation))return false;
    if(s.selected.some(id=>template(id).job==='porter'&&s.characters[id].hp<=0))return false;
    if(!s.activeQuest){s.rollback=snapshot(s);s.sequence++;}
    const j=J.create();j.phase='road';j.selected=[...s.selected];j.formation=formation;j.potions=inventoryTotals(s).potion;j.kit='campaign';
    j.job=s.activeQuest?clone(s.activeQuest):{name:'未受注の移動',deadline:100000000,reward:0};
    j.origin=s.location;j.destination=destination;j.token=s.sequence;j.questless=!s.activeQuest;j.history=[];
    s.journey=j;s.battle=null;s.result=null;s.phase='road';note(s,`${getPlace(destination).name}へ出発${s.activeQuest?'':'（未受注：配達報酬なし）'}。`);return true;
  }
  function applyEquipment(s,b,replacement) {
    b.skillCooldownVersion=1;
    for(const u of b.units.filter(u=>u.side==='ally')) {
      const c=s.characters[u.id];if(!c)continue;
      const g=replacement?.characterId===u.id?{...getGear(replacement.gearId),targetSlot:replacement.slot}:null,st=stats(c,g);
      u.max=st.max;u.maxMp=st.maxMp;u.hp=Math.min(st.max,c.hp);u.mp=Math.min(st.maxMp,c.mp);
      u.atk=st.atk;u.def=st.def;u.reach=st.reach;u.agi=st.speed;u.next=100/u.agi;u.equippedSkill=st.skill;
      u.attackWeapons=st.attackWeapons;u.attackBonus=st.attackBonus;u.activeSkills=st.activeSkills;u.skillSources=st.skillSources;u.effects=st.effects;u.canInvade=u.job!=='porter'&&st.effects.includes('invasion');
      u.weapon=template(u.id).job==='porter'?undefined:st.weaponType;
      u.race=c.race;u.str=st.str;u.int=st.int;u.equipment=st.equipment;
    }
    for(const u of b.units.filter(u=>u.side==='enemy'&&u.job==='scout'))u.skillSources=enemySkillSources(u);
  }
  function enemySkillSources(u) {
    if(u.job!=='scout')return undefined;
    const g=getGear(bases.scout.weapon);
    return [{id:'scout',slot:'rightHand',itemId:g.id,grantSlot:1,classification:'active',level:g.skillLevel??1}];
  }
  function normalizedSkillSources(sources) {
    if(!Array.isArray(sources))return sources;
    const ordinals=new Map();
    return sources.map(source=>{
      const key=JSON.stringify([source.slot,source.itemId]),ordinal=(ordinals.get(key)||0)+1;ordinals.set(key,ordinal);
      // Only fill fields absent in old saves. Existing values still undergo exact validation.
      return {...source,...(source.grantSlot===undefined?{grantSlot:ordinal}:{}),...(source.id==='scout'?{level:source.level??1}:{})};
    });
  }
  const separateHandCopies=(g,a,b)=>g&&!['fist','empty'].includes(g.type)&&g.hands!==2&&['rightHand','leftHand'].includes(a)&&['rightHand','leftHand'].includes(b)&&a!==b&&S.allowed(g).includes(a)&&S.allowed(g).includes(b);
  function deploymentPreset(ids,kind) {
    const preset=B.create({ally:ids,enemy:[],formation:kind,deployment:true}),used=new Set();
    // The legacy flank factory moves the scout to 14 after assigning other
    // members. New combinations can contain another member already at 14.
    // Preserve the formation's scout anchor and place only collisions nearby.
    const allies=[...preset.units].sort((a,b)=>Number(kind==='flank'&&b.job==='scout')-Number(kind==='flank'&&a.job==='scout'));
    for(const u of allies){
      if(used.has(u.pos)){
        const origin=u.pos,distance=p=>Math.abs(p%10-origin%10)+Math.abs(Math.floor(p/10)-Math.floor(origin/10));
        u.pos=Array.from({length:50},(_,p)=>p).filter(p=>B.boardOf(p)==='ally'&&!used.has(p)).sort((a,b)=>distance(a)-distance(b)||a-b)[0];
      }
      used.add(u.pos);
    }
    return preset;
  }
  function travel(s,route,random=Math.random) {
    if(s.phase!=='road'||!s.journey||!['short','safe'].includes(route)||typeof random!=='function')return false;
    const j=s.journey,count=route==='short'?(j.stage===0?3:4):(j.stage===0?2:3);
    let enemies;try{enemies=J.randomEnemies(count,()=>{const n=random();if(typeof n!=='number'||!Number.isFinite(n)||n<0||n>=1)throw new Error('Random value out of range');return n;});}catch(e){return false;}
    if(!J.travel(s.journey,route))return false;
    s.hours+=route==='short'?2:4;
    const ids=battleIds(s),b=B.create({ally:ids,enemy:enemies,formation:j.formation,formationVersion:2,
      potions:inventoryTotals(s,ids).potion,ethers:inventoryTotals(s,ids).ether,enemyPotions:j.stage===0?0:1,deployment:true});
    b.itemInventories=Object.fromEntries(ids.map(id=>[id,Object.fromEntries(items.map(item=>[item.id,I.count(s.characters[id].inventory,item.id)]))]));
    const preset=deploymentPreset(ids,j.formation);for(const u of b.units.filter(u=>u.side==='ally'))u.pos=preset.units.find(p=>p.id===u.id).pos;
    applyEquipment(s,b);b.campaignToken=j.token;b.campaignStage=j.stage;
    b.deploymentInitial=b.units.filter(u=>u.side==='ally').map(u=>({id:u.id,pos:u.pos}));
    s.battle=b;j.phase='deployment';s.phase='deployment';note(s,`${j.stage+1}区間目：${route==='short'?'近道':'迂回'}で遭遇。`);return true;
  }
  function deploy(s,id,pos) {return s.phase==='deployment'&&!!s.battle&&B.deploy(s.battle,id,pos);}
  // Membership changes are preparation-only. Build the candidate first; rejected drops
  // must not change inventories, formation, history, or the saved party selection.
  function deployment_assign(s,id,pos) {
    if(s.phase!=='deployment'||!s.battle?.deploying||!s.selected.includes(id))return false;
    const b=s.battle,current=b.units.filter(u=>u.side==='ally'),old=current.find(u=>u.id===id);
    if(pos!==null&&(!Number.isInteger(pos)||pos<0||pos>=50||B.boardOf(pos)!=='ally'))return false;
    if(old&&pos!==null)return B.deploy(b,id,pos);
    if(!old&&(pos===null||s.characters[id].hp<=0))return false;
    const occupant=pos===null?null:b.units.find(u=>u.hp>0&&u.pos===pos);
    if(occupant&&occupant.side!=='ally')return false;
    if(!old&&!occupant&&current.length>=BATTLE_LIMIT)return false;
    const ids=current.filter(u=>u.id!==id&&u.id!==occupant?.id).map(u=>u.id);
    let added=null;
    if(!old){
      const candidate=B.create({ally:[id],enemy:[],deployment:true});applyEquipment(s,candidate);
      added=candidate.units[0];added.pos=pos;ids.push(id);
    }
    const preset=deploymentPreset(ids,s.journey.formation);
    b.units=[...current.filter(u=>ids.includes(u.id)),...(added?[added]:[]),...b.units.filter(u=>u.side==='enemy')];
    // The tie breaker includes the member index. A newly created singleton has
    // index zero, so canonicalize every participant after membership edits.
    for(const u of b.units.filter(u=>u.side==='ally'))u.tie=preset.units.find(p=>p.id===u.id).tie;
    s.battleSelected=ids;
    b.itemInventories=Object.fromEntries(ids.map(uid=>[uid,b.itemInventories[uid]??Object.fromEntries(items.map(item=>[item.id,I.count(s.characters[uid].inventory,item.id)]))]));
    b.potions.ally=ids.reduce((n,uid)=>n+b.itemInventories[uid].potion,0);
    b.ethers=ids.reduce((n,uid)=>n+b.itemInventories[uid].ether,0);
    b.deploymentInitial=preset.units.map(u=>({id:u.id,pos:u.pos}));
    return true;
  }
  function chooseFormation(s,kind) {
    if(s.phase!=='deployment'||!s.battle||!['convoy','flank'].includes(kind))return false;
    const preset=deploymentPreset(battleIds(s),kind);
    s.battle.formationVersion=2;s.battle.formationKind=kind;s.journey.formation=kind;
    s.battle.deploymentInitial=preset.units.map(u=>({id:u.id,pos:u.pos}));
    return true;
  }
  function deployment_reset(s) {
    if(s.phase!=='deployment'||!s.battle)return false;
    for(const p of s.battle.deploymentInitial)s.battle.units.find(u=>u.id===p.id).pos=p.pos;return true;
  }
  function begin(s) {if(s.phase!=='deployment'||!s.battle||!s.battle.units.some(u=>u.side==='ally'&&u.hp>0)||!validate(s).ok||!B.begin(s.battle))return false;s.phase='battle';s.journey.phase='battle';return true;}
  function act(s,kind,target) {
    if(s.phase!=='battle'||!s.battle)return false;
    const accepted=B.act(s.battle,kind,target);
    if(accepted&&s.battle.result&&!s.battle.failure&&s.battle.units.filter(u=>u.side==='enemy').every(u=>u.hp<=0))s.battle.result='勝利！ 街道を切り抜けた。';
    return accepted;
  }
  function gainXp(s,amount) {
    // Legacy team xp/level fields are retained only for save compatibility.
    // Rewards apply exactly once to the current travelling characters.
    for(const id of s.selected){const c=s.characters[id],old=c.level;c.xp+=amount;c.level=1+Math.floor(c.xp/100);c.statPoints+=(c.level-old)*2;c.skillPoints+=c.level-old;}
  }
  function rollbackFailure(s,reason) {
    const failedTrip={origin:s.journey.origin,destination:s.journey.destination,hours:s.journey.hours};
    const old=clone(s.rollback);for(const key of Object.keys(s))delete s[key];Object.assign(s,old);
    invalidateInventory(s);
    s.phase='result';s.result={outcome:'failed',reason,restored:true,trip:failedTrip,gold:0,xp:0};
    note(s,reason+' 受注／出発前の状態を復元しました。');return true;
  }
  function retreat(s) {
    const b=s.battle,j=s.journey;
    if(s.phase!=='battle'||!b||b.result||!j||!s.rollback||b.campaignToken!==j.token||b.campaignStage!==j.stage)return false;
    return rollbackFailure(s,'戦闘から撤退しました。');
  }
  function finishBattle(s) {
    const b=s.battle,j=s.journey;
    if(s.phase!=='battle'||!b?.result||!j||b.campaignToken!==j.token||b.campaignStage!==j.stage)return false;
    const allies=b.units.filter(u=>u.side==='ally'),failed=allies.some(u=>u.job==='porter'&&u.hp<=0)||allies.every(u=>u.hp<=0)||!!b.failure;
    if(failed)return rollbackFailure(s,'ポーター戦闘不能または護送隊敗北。');
    if(b.units.some(u=>u.side==='enemy'&&u.hp>0))return false;
    if(!J.finishBattle(j,b))return false;
    // Journey recovery and EXP already apply to all travelling members. Reserve
    // characters retain their own HP/MP and items; only actual participants settle.
    if(s.battleSelected!==undefined)j.party=s.selected.map(id=>{
      const unit=allies.find(u=>u.id===id);if(unit)return clone(unit);
      const t=template(id),c=s.characters[id],st=stats(c);
      return {...t,hp:c.hp,mp:c.mp,max:st.max,maxMp:st.maxMp};
    });
    for(const u of allies){s.characters[u.id].hp=u.hp;s.characters[u.id].mp=u.mp;}
    for(const u of allies)for(const item of items){const count=b.itemInventories[u.id][item.id];if(count)s.characters[u.id].inventory[item.id]=count;else delete s.characters[u.id].inventory[item.id];}
    s.hours+=1;
    const reward={xp:20,gold:8};gainXp(s,reward.xp);s.gold+=reward.gold;
    note(s,`戦闘勝利：戦闘EXP＋${reward.xp}・戦利品${reward.gold}G（配達報酬とは別）。`);
    s.battle=null;s.phase=j.phase==='delivery'?'arrival':j.phase;return true;
  }
  function rest(s) {
    if(s.phase!=='camp'||!s.journey||!J.rest(s.journey))return false;
    s.hours+=2;
    for(const u of s.journey.party){s.characters[u.id].hp=u.hp;s.characters[u.id].mp=u.mp;}
    note(s,'野営で休息（2時間・HP＋60／MP＋2）。');return true;
  }
  function onward(s) {if(s.phase!=='camp'||!J.onward(s.journey))return false;s.phase='road';return true;}
  function forecast(s,choice) {
    if(!s.journey||!['road','camp'].includes(s.phase)||!['short','safe','rest'].includes(choice))return null;
    const f=J.forecast(s.journey,choice),hours=f.hours+(s.activeQuest?.elapsedHours||0),late=!!s.activeQuest&&hours>s.activeQuest.deadline;
    return {...f,hours,late,over:s.activeQuest?Math.max(0,hours-s.activeQuest.deadline):0,reward:s.activeQuest?Math.floor(s.activeQuest.reward*(late?.65:1)):0,questless:!s.activeQuest};
  }
  function arrive(s) {
    const j=s.journey;if(s.phase!=='arrival'||!j||j.stage!==2)return false;
    s.location=j.destination;
    if(s.activeQuest){
      s.activeQuest.elapsedHours=(s.activeQuest.elapsedHours||0)+j.hours;
      s.journey=null;s.battle=null;s.result=null;s.phase='town';
      note(s,getPlace(s.location).name+'に到着。依頼は未完了です。');return true;
    }
    s.boardRound++;s.phase='result';s.result={outcome:'travel',gold:0,xp:0,hours:j.hours,location:s.location,quest:null,restored:false};
    note(s,'未受注の移動で到着。配達報酬なし。');s.rollback=null;s.battle=null;j.phase='result';return true;
  }
  function completeQuest(s){
    const q=s.activeQuest;
    if(s.phase!=='town'||!q||s.location!==q.to||!Cargo.aboard(s))return false;
    const hours=q.elapsedHours||0,late=hours>q.deadline,gold=Math.floor(q.reward*(late?.65:1)),xp=late?60:q.xp;
    if(!Cargo.consume(s))return false;
    invalidateInventory(s);s.gold+=gold;if(xp)gainXp(s,xp);s.completed++;s.boardRound++;
    note(s,'「荷物」を渡しました。'+q.cargo+'を引き渡しました。');
    note(s,`配達完了：${gold}G・依頼EXP＋${xp}${late?'（遅配）':''}。`);
    s.phase='result';s.result={outcome:late?'late':'success',gold,xp,hours,location:s.location,quest:q.name,restored:false};
    s.activeQuest=null;s.rollback=null;s.journey=null;s.battle=null;return true;
  }
  function acknowledge(s) {
    if(s.phase!=='result')return false;
    s.phase='town';s.journey=null;s.battle=null;s.result=null;s.activeQuest=null;s.rollback=null;return true;
  }
  function eligibility(s,charId,gearId) {
    const c=s.characters[charId],g=getGear(gearId);if(!c||!g)return {ok:false,reason:'キャラまたは装備が不明です'};
    const st=stats(c),t=template(charId),m=materials[g.material];
    if(c.race==='elf'&&m.metal&&!['silver'].includes(g.material))return {ok:false,reason:'エルフは金・銀以外の金属装備不可'};
    if(c.race==='dwarf'&&['sword','dagger','greatsword'].includes(g.type))return {ok:false,reason:'ドワーフは刀剣類を装備不可（短剣も含む仮分類）'};
    for(const key of ['str','int','agi'])if(st[key]<g[key])return {ok:false,reason:`必要${key.toUpperCase()} ${g[key]}／現在${st[key]}`};
    if(g.jobOnly&&g.jobOnly!==t.job)return {ok:false,reason:'ポーター専用です'};
    if(g.virtualDefault)return {ok:false,reason:'装備なし時の既定性能です。所持品として装備できません'};
    if(g.starterOnly&&g.id!==bases[template(charId).job].weapon)return {ok:false,reason:'この職の初期装備ではありません'};
    return {ok:true,reason:t.job==='porter'?'C01保留：手道具交換後も攻撃・攻撃スキルは使えません':null};
  }
  function shop(s) {
    if(s.phase!=='town')return [];
    const kind=s.location==='east'?'weapon':s.location==='west'?'armor':s.location==='north'?'accessory':null;
    return kind?gear.filter(g=>(g.slot===kind||kind==='armor'&&['head','lowerBody','feet'].includes(g.slot)||kind==='accessory'&&['accessory1','accessory2'].includes(g.slot)||kind==='weapon'&&g.slot==='leftHand')&&!g.starterOnly&&g.type!=='fist').map(displayGear):s.location==='south'?clone(items):[];
  }
  function quote(s,charId,gearId,slot) {
    const c=s.characters[charId],g=getGear(gearId);if(!c||!g)return null;
    slot=S.canonical(slot||g.slot);if(!Object.hasOwn(S.slots,slot)||!S.allowed(g).includes(slot))return null;
    const eq=equipment(c),old=getGear(eq[slot]),cost=g.price,eligible=eligibility(s,charId,gearId);
    if(g.hands===2&&!eq.leftHand.startsWith('empty-')){eligible.ok=false;eligible.reason='両手装備には左手の空きが必要です。先に左手装備を外してください';}
    if(slot==='leftHand'&&getGear(eq.rightHand)?.hands===2){eligible.ok=false;eligible.reason='右手の両手装備が左手も使用中です。先に右手を交換してください';}
    if(!g.id.startsWith('empty-')&&Object.entries(eq).some(([k,id])=>k!==slot&&S.identity(id)===S.identity(g.id)&&!separateHandCopies(g,k,slot))){eligible.ok=false;eligible.reason='同じ装備は二つの枠に装備できません';}
    return {characterId:charId,gearId,slot,oldGearId:old.id,price:g.price,tradeIn:0,cost,retained:old.type!=='empty',affordable:s.gold>=cost,
      eligible:eligible.ok,reason:eligible.reason,same:old.id===g.id,available:shop(s).some(item=>item.id===gearId)};
  }
  function buyGear(s,charId,gearId,slot) {
    if(s.phase!=='town'||!s.selected.includes(charId))return false;
    const q=quote(s,charId,gearId,slot);if(!q||!q.available||!q.eligible||!q.affordable||q.same)return false;
    return commitInventory(s,draft=>{
      const c=draft.characters[charId],g=getGear(gearId);
      if(q.retained){const bag=I.add(c.inventory,q.oldGearId,1);if(!bag)return false;c.inventory=bag;}
      draft.gold-=q.cost;c[S.storage(q.slot)]=gearId;syncCharacter(draft,charId);
      note(draft,`${template(charId).name}：${g.name}を${q.cost}Gで購入・装備。${q.retained?'外した装備は本人のインベントリへ。':''}`);return true;
    });
  }
  function buyItem(s,id,count=1,ownerId,token) {
    const item=items.find(i=>i.id===id);
    if(s.phase!=='town'||s.location!=='south'||!item||!I.quantity(count)||!s.selected.includes(ownerId)||token!==inventoryToken(s)||inventoryTotals(s,Object.keys(s.characters))[id]+count>99||s.gold<item.price*count)return false;
    return commitInventory(s,draft=>{
      const bag=I.add(draft.characters[ownerId].inventory,id,count);if(!bag)return false;
      draft.characters[ownerId].inventory=bag;draft.gold-=item.price*count;
      note(draft,`${template(ownerId).name}が${item.name}を${count}個購入。`);return true;
    });
  }
  function innQuote(s) {
    return {price:INN_PRICE,available:s.phase==='town'&&s.location==='astaris',
      affordable:s.gold>=INN_PRICE,needsRecovery:s.selected.some(id=>{
        const c=s.characters[id],st=stats(c);return c.hp<st.max||c.mp<st.maxMp;
      })};
  }
  function inn(s) {
    const q=innQuote(s);
    if(!q.available||!q.affordable||!q.needsRecovery)return false;
    s.gold-=q.price;
    for(const id of s.selected){const c=s.characters[id],st=stats(c);c.hp=st.max;c.mp=st.maxMp;}
    note(s,`アスタリスの宿屋：${q.price}Gで編成中の全員のHP・MPを全回復。`);
    return true;
  }
  function syncCharacter(s,id) {
    const c=s.characters[id],st=stats(c);c.hp=Math.min(st.max,c.hp);c.mp=Math.min(st.maxMp,c.mp);
    if(s.journey){
      s.journey.potions=inventoryTotals(s).potion;
      const u=s.journey.party?.find(u=>u.id===id);
      if(u){u.hp=c.hp;u.mp=c.mp;u.max=st.max;u.maxMp=st.maxMp;}
    }
  }
  function commitInventory(s,change) {
    const draft=clone(s);if(!change(draft))return false;
    // Use the actual pretty-printed save representation, including whitespace.
    try{serialize(draft);}catch{return false;}
    // Validation finishes before either participant or any resource is changed.
    for(const [id,c] of Object.entries(draft.characters))Object.assign(s.characters[id],c);
    for(const [key,value] of Object.entries(draft))if(key!=='characters')s[key]=value;
    invalidateInventory(s);
    return true;
  }
  function inventoryQuote(s,ownerId,id,action,targetId=null,count=1,slot=null) {
    const owner=template(ownerId)&&s.characters[ownerId],item=items.find(i=>i.id===id),g=getGear(id),definition=item||g;
    const q={ownerId,itemId:id,action,targetId,count,slot,token:inventoryToken(s),ok:false,reason:'',name:definition?.name||id,ownerName:template(ownerId)?.name||ownerId,targetName:template(targetId)?.name||targetId,available:owner?I.count(owner.inventory,id):0};
    const fail=reason=>({...q,reason});
    if(Cargo.isKey(id)){
      if(action!=='transfer')return fail('クエストの荷物です。使用・売却・廃棄はできません。');
      if(!Cargo.validEntry(s,ownerId,id,count))return fail('荷物の所持者が変わりました。');
      if(!['town','camp'].includes(s.phase)||!s.selected.includes(ownerId)||!s.selected.includes(targetId))return fail('町・野営で同行中のポーターに渡せます。');
      if(targetId===ownerId||template(targetId)?.job!=='porter')return fail('荷物を持てるのはポーターだけです。');
      return {...q,name:'荷物',ok:true};
    }
    if(!owner||!definition||g?.type==='empty')return fail('所持品が見つかりません');
    if(!['town','camp'].includes(s.phase))return fail('町・野営で操作できます');
    if(!s.selected.includes(ownerId))return fail('編成中の仲間の所持品を操作できます');
    if(!I.quantity(count))return fail('個数は1以上の整数にしてください');
    if(action==='unequip'){
      if(count!==1||!Object.hasOwn(S.slots,slot)||equipment(owner)[slot]!==id)return fail('装備の状態が変わりました');
      if(slot==='leftHand'&&getGear(equipment(owner).rightHand)?.hands===2)return fail('右手の両手装備が使用中です');
    } else if(q.available<count)return fail('所持数が不足しています');
    if(action==='use'){
      if(!item)return fail('装備品です。「装備する」から装備枠を選択してください');
      if(count!==1)return fail('使用は1回につき1個です');
      const target=template(targetId)&&s.characters[targetId];
      if(!target||!s.selected.includes(targetId))return fail('編成中の回復対象を選んでください');
      if(target.hp<=0)return fail('戦闘不能の仲間には使用できません');
      const st=stats(target),max=item.resource==='hp'?st.max:st.maxMp;
      if(target[item.resource]>=max)return fail('全回復しています');
      q.resource=item.resource;q.before=target[item.resource];q.after=Math.min(max,q.before+item.amount);q.effect=q.after-q.before;
    } else if(action==='transfer'){
      if(targetId===ownerId)return fail('別の仲間を選んでください');
      if(!template(targetId)||!s.characters[targetId]||!s.selected.includes(targetId))return fail('編成中の受取人を選んでください');
      if(!I.transfer(owner.inventory,s.characters[targetId].inventory,id,count))return fail('受け渡しできる個数を超えています');
    } else if(action==='equip'){
      if(!g||count!==1)return fail('装備品を1個選んでください');
      const eq=quote(s,ownerId,id,slot);
      if(!eq||!eq.eligible||eq.same)return fail(eq?.reason||'装備枠または装備条件を確認してください');
      q.slot=eq.slot;q.oldGearId=eq.oldGearId;q.retained=eq.retained;
    } else if(!['discard','unequip'].includes(action))return fail('操作を選んでください');
    return {...q,ok:true};
  }
  function inventoryAction(s,ownerId,id,action,targetId,count,slot,token) {
    if(token!==inventoryToken(s))return false;
    const q=inventoryQuote(s,ownerId,id,action,targetId,count,slot);if(!q.ok)return false;
    return commitInventory(s,draft=>{
      const owner=draft.characters[ownerId],item=items.find(i=>i.id===id);
      if(action==='transfer'){
        const moved=I.transfer(owner.inventory,draft.characters[targetId].inventory,id,count);if(!moved)return false;
        owner.inventory=moved.source;draft.characters[targetId].inventory=moved.target;
        if(Cargo.isKey(id))draft.activeQuest.cargoOwnerId=targetId;
      } else if(action==='unequip'){
        owner.inventory=I.add(owner.inventory,id,1);if(!owner.inventory)return false;
        owner[S.storage(slot)]=`empty-${slot}`;
      } else {
        owner.inventory=I.remove(owner.inventory,id,count);if(!owner.inventory)return false;
        if(action==='use')draft.characters[targetId][item.resource]=q.after;
        if(action==='equip'){
          if(q.retained){owner.inventory=I.add(owner.inventory,q.oldGearId,1);if(!owner.inventory)return false;}
          owner[S.storage(q.slot)]=id;
        }
      }
      syncCharacter(draft,ownerId);if(targetId&&draft.characters[targetId])syncCharacter(draft,targetId);
      const text={use:`${q.targetName}に使用`,transfer:`${q.targetName}へ渡した`,discard:'捨てた',equip:'装備した',unequip:'装備から外した'}[action];
      note(draft,`${q.ownerName}の${q.name} ${count}個：${text}。`);return true;
    });
  }
  function useItem(s,id,targetId,ownerId,token) {
    return inventoryAction(s,ownerId,id,'use',targetId,1,null,token);
  }
  function inventoryView(s,ownerId) {
    const owner=s.characters[ownerId];
    return {ownerId,token:inventoryToken(s),entries:Object.entries(owner.inventory).map(([id,count])=>{
      const cargo=Cargo.definition(s,id);
      if(cargo)return {sale:saleQuote(s,ownerId,id),id,name:'荷物',count,kind:'quest',definition:clone(cargo),useTargets:[],transferTargets:s.selected.filter(target=>target!==ownerId).map(target=>inventoryQuote(s,ownerId,id,'transfer',target)),discard:inventoryQuote(s,ownerId,id,'discard'),equipSlots:[]};
      const item=items.find(i=>i.id===id),g=getGear(id);
      return {sale:saleQuote(s,ownerId,id),id,name:(item||g).name,count,kind:item?'consumable':'equipment',definition:item?clone(item):displayGear(g),
        useTargets:s.selected.map(target=>inventoryQuote(s,ownerId,id,'use',target)),
        transferTargets:s.selected.filter(target=>target!==ownerId).map(target=>inventoryQuote(s,ownerId,id,'transfer',target)),
        discard:inventoryQuote(s,ownerId,id,'discard'),
        equipSlots:g?S.allowed(g).map(slot=>inventoryQuote(s,ownerId,id,'equip',null,1,slot)):[]};
    })};
  }
  // R07: session-only state identity prevents stale allocation after load/new game.
  const allocationStates=new WeakMap();let allocationSerial=0;
  function allocationToken(s,id) {
    if(!allocationStates.has(s))allocationStates.set(s,++allocationSerial);
    const c=s.characters[id];if(!c)return '';
    return JSON.stringify([allocationStates.get(s),id,s.sequence,s.boardRound,s.phase,s.location,s.selected,c.xp,c.statPoints,c.allocations.str,c.allocations.int,c.allocations.agi]);
  }
  function allocateBatch(s,charId,delta,expectedToken) {
    const c=s.characters[charId],keys=['str','int','agi'];
    if(s.phase!=='town'||!c||!s.selected.includes(charId)||expectedToken!==allocationToken(s,charId)||!record(delta)||Object.keys(delta).length!==3||!keys.every(k=>Number.isSafeInteger(delta[k])&&delta[k]>=0))return false;
    const total=keys.reduce((n,k)=>n+delta[k],0);
    if(!Number.isSafeInteger(total)||total<1||total>c.statPoints)return false;
    const old=stats(c),next={...c,allocations:{...c.allocations},statPoints:c.statPoints-total};
    for(const key of keys)next.allocations[key]+=delta[key];
    const after=stats(next);next.hp+=after.max-old.max;next.mp+=after.maxMp-old.maxMp;
    s.characters[charId]=next;
    note(s,`${template(charId).name}：${keys.filter(k=>delta[k]).map(k=>`${k.toUpperCase()}＋${delta[k]}`).join(' / ')}（${total}点を確定、残り${next.statPoints}点）。`);
    return true;
  }
  function allocate(s,charId,key,count=1) {
    const c=s.characters[charId];
    if(s.phase!=='town'||!c||!s.selected.includes(charId)||!['str','int','agi'].includes(key)||!Number.isInteger(count)||count<1||count>c.statPoints)return false;
    const old=stats(c);c.allocations[key]+=count;c.statPoints-=count;const after=stats(c);c.hp+=after.max-old.max;c.mp+=after.maxMp-old.maxMp;
    note(s,`${template(charId).name}：${key.toUpperCase()}＋${count}（仮成長値）。`);return true;
  }
  function previewGear(s,charId,gearId,slot) {
    const q=quote(s,charId,gearId,slot);if(!q)return null;
    return {...q,ok:q.eligible,gear:displayGear(getGear(gearId)),current:displayGear(getGear(q.oldGearId)),afterGold:s.gold-q.cost,before:stats(s.characters[charId]),after:stats(s.characters[charId],{...getGear(gearId),targetSlot:q.slot}),skillName:stats(s.characters[charId],{...getGear(gearId),targetSlot:q.slot}).activeSkills.map(id=>skills[id]).join(' / '),effectDescription:getGear(gearId).note||'',
      warning:'試着は資金・装備・HP/MP・消耗品・EXP・旅に影響しません。数値は試作値です。'};
  }
  function trial(s,charId,gearId,slot) {
    const preview=previewGear(s,charId,gearId,slot);
    if(s.phase!=='town'||!s.selected.includes(charId)||!preview?.eligible||!preview.available)return null;
    const friends=[...new Set(['guard','archer','mage',...s.selected])].filter(id=>id!==charId&&s.selected.includes(id)).slice(0,2);
    const b=B.create({ally:[charId,...friends],enemy:['guard','archer','mage'],enemyPotions:0,potions:3,deployment:true,formationVersion:2,formation:'convoy'});
    const copy=clone(s);for(const id of [charId,...friends]){const st=stats(copy.characters[id]);copy.characters[id].hp=st.max;copy.characters[id].mp=st.maxMp;}
    applyEquipment(copy,b,{characterId:charId,gearId,slot:preview.slot});
    const hero=b.units.find(u=>u.id===charId);if(hero.activeSkills.includes(getGear(gearId).skill))hero.selectedSkill=getGear(gearId).skill;hero.hp=hero.max;hero.mp=hero.maxMp;hero.pos=24;hero.next=0;
    for(const [i,u] of b.units.filter(u=>u.side==='ally'&&u.id!==charId).entries()){u.pos=(hero.job==='porter'?[13,33]:[23,33])[i];u.hp=Math.max(1,u.max-60);u.next=1000000;}
    for(const [i,u] of b.units.filter(u=>u.side==='enemy').entries()){u.name=`木人${i+1}`;u.role='木人';u.hp=u.max=9999;u.pos=[25,15,35][i];u.next=1000000;u.atk=0;}
    for(const [i,u] of b.units.filter(u=>u.side==='ally'&&u.id!==charId).entries()){u.pos=(hero.job==='porter'?[13,33]:[14,34])[i];u.mp=Math.max(0,u.maxMp-3);}
    // R04: porter trials demonstrate the new basic condition, without changing campaign spawns.
    if(hero.job==='porter'){hero.pos=23;b.units.filter(u=>u.side==='ally'&&u.id!==charId).forEach((u,i)=>u.pos=[12,32][i]);}
    // Passive trials need a reachable dummy even for reach-1 non-invaders.
    let supportActorId=null;
    if(B.hasEffect(hero,'loneWolf'))b.units.filter(u=>u.side==='ally'&&u.id!==charId).forEach((u,i)=>u.pos=[12,32][i]);
    if(B.hasEffect(hero,'victoryBreath')){
      const dummy=b.units.find(u=>u.side==='enemy');
      b.units=b.units.filter(u=>u.side==='ally'||u===dummy);
      if(hero.job==='porter'){
        // Training only: porters retain their attack ban; a real ally finishes.
        const helper=b.units.find(u=>u.side==='ally'&&u.id!==charId&&u.atk>0);
        if(helper){hero.pos=23;helper.pos=24;helper.next=1;supportActorId=helper.id;}
      }
    }
    B.begin(b);for(const u of b.units.filter(u=>u.side==='enemy'))u.intent={kind:'guard',target:null,name:'静止',reason:'木人は行動しません',cells:[]};
    if(B.activeSkill(hero)==='pincer'){
      b.units.find(u=>u.side==='enemy').pos=23;
      b.units.filter(u=>u.side==='ally'&&u.id!==charId).forEach((u,i)=>u.pos=[13,33][i]);
    }
    if(B.activeSkill(hero)==='defenseLine'){
      const dummy=b.units.find(u=>u.side==='enemy'),friend=b.units.find(u=>u.side==='ally'&&u.id!==charId);
      dummy.pos=15;const overlap=b.units.find(u=>u.id!==dummy.id&&u.side==='enemy'&&u.pos===15);if(overlap)overlap.pos=25;
      dummy.atk=12;dummy.reach=1;dummy.next=1;dummy.intent={kind:'attack',target:friend.id,name:'試験打撃',reason:'防衛線の引受確認（12基礎ダメージ）',cells:[friend.pos]};
    }
    if(B.hasEffect(hero,'victoryBreath')){hero.mp=Math.max(0,hero.maxMp-2);for(const u of b.units.filter(u=>u.side==='enemy'))u.hp=1;}
    b.log=['木人試用：資金・装備・HP/MP・EXPに影響しない独立戦闘。'];
    const notice=B.hasEffect(hero,'loneWolf')?(hero.job==='porter'?'ポーターは攻撃禁止のため、孤軍の与ダメージ補正は発動しません。':'孤軍確認用：仲間から離れた初期位置で木人を攻撃できます。'):supportActorId?'一息の木人はHP1・1体。防御などの行動後に仲間が倒し、本人の勝利回復を確認。':B.activeSkill(hero)==='defenseLine'?'防衛線の木人は初回に基礎12の試験打撃。':B.hasEffect(hero,'victoryBreath')?'一息の木人はHP1。倒して勝利回復を確認。':B.activeSkill(hero)==='pincer'?'挟撃確認用：味方陣内の木人に仲間を隣接配置。':'木人は反撃しません。';
    const trialNotice=hero.job==='porter'&&B.hasEffect(hero,'victoryBreath')&&!supportActorId?'ポーターだけでは木人を倒せません。一息の勝利回復を確認するには、攻撃できる仲間を編成してください。':notice;
    b.log.push(trialNotice);
    return {battle:b,metadata:{characterId:charId,gearId,name:getGear(gearId).name,isolated:true,notice:trialNotice+'試着終了で元の状態へ戻ります。'},characterId:charId,gearId,preview,actions:0,lastAction:null,isolated:true,supportActorId};
  }
  function trialAct(t,kind,target) {
    if(!t?.isolated||t.actions>=100||!t.battle||t.battle.actor!==t.characterId)return false;
    const before=clone(t.battle.units),logAt=t.battle.log.length+(t.battle.logDropped||0);
    if(!B.act(t.battle,kind,target))return false;
    if(t.supportActorId&&t.battle.actor===t.supportActorId&&!t.battle.result){
      const dummy=t.battle.units.find(u=>u.side==='enemy'&&u.hp>0);
      if(dummy&&B.legal(t.battle,'attack',dummy.id))B.act(t.battle,'attack',dummy.id);
    }
    t.actions++;t.lastAction={kind,target,messages:t.battle.log.slice(Math.max(0,logAt-(t.battle.logDropped||0))),changes:t.battle.units.map(u=>({id:u.id,name:u.name,hp:u.hp-(before.find(v=>v.id===u.id)?.hp||0),mp:u.mp-(before.find(v=>v.id===u.id)?.mp||0)})).filter(d=>d.hp||d.mp)};
    return true;
  }
  function view(s) {
    const ids=battleIds(s),deployed=s.battle?s.battle.units.filter(u=>u.side==='ally').map(u=>u.id):[...ids];
    return {...clone(s),partyLimit:PARTY_LIMIT,battleLimit:BATTLE_LIMIT,battleSelected:[...ids],deploymentRoster:{deployed,reserves:s.selected.filter(id=>!deployed.includes(id)),remaining:BATTLE_LIMIT-deployed.length,minimum:1,canBegin:s.phase==='deployment'&&!!s.battle?.units.some(u=>u.side==='ally'&&u.hp>0)&&validate(s).ok},cargoAboard:Cargo.aboard(s),cargoCarriers:Cargo.carriers(s),inventory:inventoryTotals(s),inventoryTotals:inventoryTotals(s,Object.keys(s.characters)),inventoryToken:inventoryToken(s),saleAvailable:saleAvailable(s),inventoryByCharacter:Object.fromEntries(Object.keys(s.characters).map(id=>[id,inventoryView(s,id)])),inn:innQuote(s),town:s.location,towns:clone(locations),locations:clone(locations),routes:clone(routes),destinations:clone(destinations(s)),board:board(s),shop:shop(s),itemDefinitions:clone(items),provisional:[...provisional],
      slots:S.slots,skillNames:{...skills,invasion:'侵入'},skillDefinitions:clone(E.definitions),roster:B.roster.map(t=>{const c=s.characters[t.id];const st=stats(c);return {...t,...clone(c),allocationToken:allocationToken(s,t.id),max:st.max,maxMp:st.maxMp,atk:st.atk,agi:st.speed,reach:st.reach,stats:st,equipmentDetails:Object.fromEntries(Object.entries(st.equipment).map(([slot,id])=>[slot,displayGear(slot==='leftHand'&&getGear(st.equipment.rightHand)?.hands===2?getGear(st.equipment.rightHand):effectiveGear(c,slot,id))])),equipmentSlots:Object.entries(st.equipment).map(([slot,id])=>({slot,label:S.slots[slot],id,name:slot==='leftHand'&&getGear(st.equipment.rightHand)?.hands===2?getGear(st.equipment.rightHand).name+'（両手装備で使用中）':effectiveGear(c,slot,id).name,occupiedBy:slot==='leftHand'&&getGear(st.equipment.rightHand)?.hands===2?'rightHand':null})),activeSkillNames:st.activeSkills.map(id=>skills[id]),weaponName:getGear(c.weapon).name,armorName:getGear(c.armor).name,accessoryNames:['accessory1','accessory2'].map(slot=>getGear(c[slot]||defaultAccessory(c,slot)).name),skillName:st.activeSkills.map(id=>skills[id]).join(' / '),effectNames:st.effects.map(id=>skills[id]||'侵入')};}),
      guildAvailable:s.phase==='town'&&s.location==='astaris',hasPorter:hasPorter(s)};
  }
  function validate(state) {
    try {validateState(state,0);return {ok:true,error:null};}catch(e){return {ok:false,error:e.message};}
  }
  function demand(test,message) {if(!test)throw new Error('セーブデータが不正です：'+message);}
  const integer=(v,min=0,max=100000000)=>Number.isSafeInteger(v)&&v>=min&&v<=max;
  const record=v=>v!==null&&typeof v==='object'&&!Array.isArray(v)&&Object.getPrototypeOf(v)===Object.prototype;
  function safeTree(v,depth=0) {
    demand(depth<=35,'深すぎるデータ');
    if(v===null||typeof v==='boolean')return;
    if(typeof v==='number'){demand(Number.isFinite(v)&&Math.abs(v)<=1e10,'数値範囲');return;}
    if(typeof v==='string'){demand(v.length<=4000,'文字列が長すぎます');return;}
    demand(typeof v==='object','JSON以外の値');
    if(Array.isArray(v)){demand(v.length<=2000,'配列が長すぎます');for(const item of v)safeTree(item,depth+1);return;}
    demand(record(v),'オブジェクト形式');demand(Object.keys(v).length<=100,'項目数');
    for(const key of Object.keys(v)){demand(!['__proto__','constructor','prototype'].includes(key),'禁止されたキー');if(v[key]!==undefined)safeTree(v[key],depth+1);}
  }
  function validSelection(ids) {return Array.isArray(ids)&&ids.length>0&&ids.length<=PARTY_LIMIT&&new Set(ids).size===ids.length&&ids.every(id=>!!template(id));}
  function validateState(s,depth,version=VERSION) {
    if(depth===0)safeTree(s);
    demand(record(s)&&s.version===version,'バージョン');
    demand(!Object.hasOwn(s,'cargoRevision')||s.cargoRevision===1,'未対応の荷物形式');
    if(s.rollback)demand((s.cargoRevision===1)===(s.rollback.cargoRevision===1),'荷物形式と復元スナップショット');
    demand(['town','road','deployment','battle','camp','arrival','result'].includes(s.phase),'進行段階');
    demand(!!getPlace(s.location),'拠点');
    for(const key of ['gold','xp','hours','sequence','boardRound','completed'])demand(integer(s[key]),key);
    demand(integer(s.level,1),'旧隊レベル');demand(validSelection(s.selected),'編成');
    demand(s.battleSelected===undefined?s.selected.length<=BATTLE_LIMIT:Array.isArray(s.battleSelected)&&s.battleSelected.length<=BATTLE_LIMIT&&new Set(s.battleSelected).size===s.battleSelected.length&&s.battleSelected.every(id=>s.selected.includes(id)),'戦闘出場者');
    if(version===1)demand(record(s.inventory)&&Object.keys(s.inventory).length===2&&integer(s.inventory.potion,0,99)&&integer(s.inventory.ether,0,99),'アイテム');
    else demand(!Object.hasOwn(s,'inventory'),'旧共通在庫と個人所持の重複');
    demand(Array.isArray(s.history)&&s.history.length<=200&&s.history.every(x=>typeof x==='string'),'履歴');
    demand(record(s.characters)&&Object.keys(s.characters).length===B.roster.length,'キャラ一覧');
    for(const t of B.roster) {
      const c=s.characters[t.id];demand(record(c)&&c.id===t.id&&c.race===bases[t.job].race&&Object.keys(c).every(k=>['id','equipmentRevision','combatRevision','race','weapon','armor','accessory1','accessory2','leftHand','head','lowerBody','feet','hp','mp','def','xp','level','statPoints','skillPoints','allocations',...(version===2?['inventory']:[])].includes(k)),'キャラ情報');
      demand(c.def===undefined||integer(c.def),'キャラDEF');
      if(version===2){
        demand(record(c.inventory),'個人の所持品');
        demand(!Object.keys(c.inventory).some(id=>(getGear(id)?.type==='empty'||getGear(id)?.virtualDefault)),'所持品に空の装備枠が含まれています。元セーブと現在の進行は変更していません。正常な別セーブを選んでください');
        demand(Object.entries(c.inventory).every(([id,count])=>Cargo.isKey(id)?Cargo.validEntry(s,t.id,id,count):(items.some(item=>item.id===id)||getGear(id)&&getGear(id).type!=='empty')&&integer(count,1,1e10)),'個人の所持品');
      }
      demand(c.equipmentRevision===undefined||c.equipmentRevision===2,'装備移行版');
      demand(c.combatRevision===undefined||c.combatRevision===1,'戦闘スキル移行版');
      demand(record(c.allocations)&&Object.keys(c.allocations).length===3&&['str','int','agi'].every(k=>integer(c.allocations[k])),'能力配分');
      demand(integer(c.xp)&&c.level===1+Math.floor(c.xp/100)&&integer(c.statPoints)&&integer(c.skillPoints),'キャラ成長');
      demand(c.statPoints+Object.values(c.allocations).reduce((a,b)=>a+b,0)===(c.level-1)*2&&c.skillPoints===c.level-1,'獲得ポイント');
      if(getGear(c.weapon)?.type==='bow')demand(!c.leftHand||c.leftHand==='empty-leftHand',`弓は両手装備です。${c.id} の左手 ${c.leftHand} と競合しています。元セーブと現在の進行は変更していません。旧版で左手を空けて別名保存してから読み込んでください`);
      demand(getGear(c.leftHand)?.type!=='bow',`弓は右手に装備して両手を占有します。${c.id} の左手 ${c.leftHand} は自動移動・破棄しません。元セーブを保持し、旧版で右手へ移して左手を空け、別名保存してください`);
      for(const slot of Object.keys(S.slots)){const id=c[S.storage(slot)];demand(id===undefined||typeof id==='string'&&!!getGear(id)&&S.allowed(getGear(id)).includes(slot),'保存された装備枠');}
      const eq=equipment(c),used=[];demand(getGear(eq.rightHand)?.hands!==2||eq.leftHand==='empty-leftHand','両手装備の占有競合');for(const [slot,id] of Object.entries(eq)){const g=getGear(id);demand(!!g&&S.allowed(g).includes(slot),'装備枠');demand(eligibility(s,c.id,id).ok,'装備条件');if(!id.startsWith('empty-')){demand(!used.some(old=>old.id===S.identity(id)&&!separateHandCopies(g,old.slot,slot)),'装備の二重使用');used.push({id:S.identity(id),slot});}}
      demand(eligibility(s,c.id,c.weapon).ok&&eligibility(s,c.id,c.armor).ok,'装備条件');
      const st=stats(c);demand(integer(c.hp,0,st.max)&&integer(c.mp,0,st.maxMp),'HP/MP');
    }
    demand(s.activeQuest===null||record(s.activeQuest),'依頼');
    if(s.activeQuest) {
      const q=s.activeQuest;demand(typeof q.id==='string'&&typeof q.name==='string'&&typeof q.client==='string'&&typeof q.cargo==='string'&&typeof q.text==='string','依頼内容');
      if(Object.hasOwn(q,'cargoItemId')||Object.hasOwn(q,'cargoOwnerId'))demand(q.cargoItemId===Cargo.key(q.token)&&template(q.cargoOwnerId)?.job==='porter'&&Cargo.carriers(s).length===1&&Cargo.carriers(s)[0]===q.cargoOwnerId,'依頼荷物と所持者');
      demand((s.cargoRevision===1?getPlace(q.from)&&getPlace(q.to)&&routes[q.from]?.includes(q.to):q.from===s.location&&destinations(s).some(p=>p.id===q.to))&&integer(q.reward,0,10000)&&integer(q.xp,0,1000)&&integer(q.deadline,1,100)&&integer(q.weight,1,100)&&q.token===s.sequence,'依頼条件');
      if(q.elapsedHours!==undefined)demand(integer(q.elapsedHours),'依頼経過時間');
      if(s.cargoRevision===1)demand(q.cargoItemId===Cargo.key(q.token)&&Cargo.carriers(s).length===1,'荷物形式');
      demand(s.phase!=='result','報酬の二重取得');
    }
    if(version===2)demand(Object.values(inventoryTotals(s,Object.keys(s.characters))).every(count=>integer(count,0,99)),'消耗品合計（従来の99個上限）');
    demand(s.rollback===null||record(s.rollback),'復元情報');
    if(s.rollback){demand(depth===0&&s.rollback.rollback===null&&s.rollback.phase==='town'&&s.rollback.activeQuest===null,'復元スナップショット');validateState(s.rollback,1,version);}
    const tripPhases=['road','deployment','battle','camp','arrival'];
    if(tripPhases.includes(s.phase))demand(record(s.journey)&&s.rollback!==null,'進行中の旅');
    if(s.phase==='town')demand(s.journey===null&&s.battle===null&&s.result===null&&!!s.rollback===!!s.activeQuest,'街の状態');
    if(s.phase==='result')demand(record(s.result)&&['success','late','travel','failed'].includes(s.result.outcome)&&s.activeQuest===null&&s.rollback===null&&s.battle===null,'結果');
    if(s.journey!==null) {
      const j=s.journey;demand(record(j)&&getPlace(j.origin)&&getPlace(j.destination)&&j.origin!==j.destination&&routes[j.origin]?.includes(j.destination),'旅の経路');
      demand(Array.isArray(j.history)&&j.history.every(x=>typeof x==='string')&&validSelection(j.selected)&&JSON.stringify(j.selected)===JSON.stringify(s.selected),'旅の編成');
      demand(integer(j.hours)&&integer(j.stage,0,2)&&j.token===s.sequence&&['convoy','flank'].includes(j.formation)&&typeof j.questless==='boolean','旅の条件');
      demand(s.phase==='result'||j.questless===!s.activeQuest,'依頼の有無');
      demand(s.phase==='result'||s.location===j.origin,'出発地点');
      demand(j.phase===(s.phase==='arrival'?'delivery':s.phase),'旅の段階');
      demand(integer(j.potions,0,99)&&record(j.job)&&typeof j.job.name==='string'&&integer(j.job.deadline,1,100000000)&&integer(j.job.reward),'旅の荷物');
      if(s.activeQuest)demand(j.job.id===s.activeQuest.id&&j.job.name===s.activeQuest.name&&j.job.deadline===s.activeQuest.deadline&&j.job.reward===s.activeQuest.reward&&(s.cargoRevision===1||j.destination===s.activeQuest.to),'旅と依頼の一致');
      if(j.questless)demand(j.job.name==='未受注の移動'&&j.job.deadline===100000000&&j.job.reward===0&&Object.keys(j.job).length===3,'未受注の旅情報');
      demand(typeof j.rested==='boolean','休息状態');
      if(j.party!==null){
        demand(Array.isArray(j.party)&&j.party.length===s.selected.length&&JSON.stringify(j.party.map(u=>u.id))===JSON.stringify(s.selected),'旅のHP記録');
        for(const u of j.party){const st=stats(s.characters[u.id]);demand(['name','role','icon','image'].every(k=>typeof u[k]==='string'&&u[k].length>0),'旅のキャラ表示');demand(u.job===template(u.id).job&&u.max===st.max&&u.maxMp===st.maxMp&&integer(u.hp,0,st.max)&&integer(u.mp,0,st.maxMp),'旅のHP/MP');}
      }
      if(['camp','arrival'].includes(s.phase))demand(Array.isArray(j.party)&&j.party.length===s.selected.length&&j.stage===(s.phase==='arrival'?2:1),'野営・到着');
      if(s.phase==='road')demand(j.stage<2,'街道の区間');
    } else demand(['town','result'].includes(s.phase),'旅情報なし');
    if(s.battle!==null) {
      const b=s.battle,j=s.journey,ids=battleIds(s);demand(record(b)&&['deployment','battle'].includes(s.phase)&&b.campaignToken===j.token&&b.campaignStage===j.stage,'戦闘の対応');
      demand(b.formationVersion===undefined||[1,2].includes(b.formationVersion)&&['convoy','flank'].includes(b.formationKind)&&b.formationKind===j.formation&&(b.formationVersion===2||s.phase==='battle'),'陣形条件の版');
      demand(b.formationVersion!==undefined||b.formationKind===undefined,'陣形条件の版なし');
      demand(Array.isArray(b.units)&&b.units.length>=(s.phase==='deployment'?1:2)&&b.units.length<=10&&new Set(b.units.map(u=>u.id)).size===b.units.length,'戦闘人数');
      demand(JSON.stringify(b.units.filter(u=>u.side==='ally').map(u=>u.id))===JSON.stringify(ids),'味方の一致');
      demand(b.units.some(u=>u.side==='enemy')&&b.units.every(u=>['ally','enemy'].includes(u.side)),'敵味方');
      demand(integer(b.actions)&&record(b.potions)&&integer(b.potions.ally,0,99)&&integer(b.potions.enemy,0,99)&&Array.isArray(b.log)&&b.log.every(line=>typeof line==='string')&&Array.isArray(b.recentEnemies)&&b.recentEnemies.every(e=>record(e)&&typeof e.name==='string'&&typeof e.action==='string'),'戦闘資源');
      demand(b.ethers===undefined||integer(b.ethers,0,99),'戦闘エーテル');
      if(version===2){
        demand(record(b.itemInventories)&&Object.keys(b.itemInventories).length===ids.length&&ids.every(id=>record(b.itemInventories[id])&&Object.keys(b.itemInventories[id]).length===items.length&&items.every(item=>integer(b.itemInventories[id][item.id],0,99)&&b.itemInventories[id][item.id]<=I.count(s.characters[id].inventory,item.id))),'戦闘の個人所持品');
        const remaining=id=>ids.reduce((n,uid)=>n+b.itemInventories[uid][id],0);
        demand(remaining('potion')===b.potions.ally&&remaining('ether')===b.ethers,'戦闘残数と個人所持の一致');
      }
      demand(b.logDropped===undefined||integer(b.logDropped,0,Number.MAX_SAFE_INTEGER),'省略ログ件数');
      demand(b.victoryEffectsApplied===undefined||typeof b.victoryEffectsApplied==='boolean','勝利効果状態');
      demand(b.skillCooldownVersion===undefined||b.skillCooldownVersion===1,'スキルクールタイム形式');
      demand(b.skillEventSequence===undefined||integer(b.skillEventSequence,0,Number.MAX_SAFE_INTEGER),'発動連番');
      if(b.skillEvents!==undefined){
        demand(Array.isArray(b.skillEvents)&&b.skillEvents.length<=100,'発動履歴');
        let prior=0;
        for(const e of b.skillEvents){demand(record(e)&&integer(e.sequence,1,b.skillEventSequence||0)&&e.sequence>prior&&e.type==='skill.activated'&&Object.hasOwn(E.definitions,e.skillId)&&e.classification===E.definitions[e.skillId].classification&&b.units.some(u=>u.id===e.actorId),'発動情報');prior=e.sequence;}
      }
      demand((s.phase==='deployment')===!!b.deploying,'配置段階');
      demand(b.result===null||typeof b.result==='string','戦闘結果');
      const alivePositions=[];
      for(const u of b.units) {
        const base=template(u.side==='enemy'?u.id.replace(/^enemy-/, ''):u.id);demand(!!base&&u.job===base.job,'戦闘キャラ');
        demand(['id','name','role','icon','image'].every(key=>typeof u[key]==='string'&&u[key].length>0),'戦闘表示情報');
        demand(integer(u.max,1,100000000)&&integer(u.hp,0,u.max)&&integer(u.maxMp,0,100000000)&&integer(u.mp,0,u.maxMp)&&integer(u.pos,0,49),'戦闘能力');
        demand(integer(u.atk,0,100000000)&&integer(u.reach,0,10)&&integer(u.agi,1,100000000)&&typeof u.next==='number'&&u.next>0&&typeof u.tie==='number','戦闘順');
        demand(u.equippedSkill===undefined||u.equippedSkill===null||Object.hasOwn(skills,u.equippedSkill),'装備スキル');
        demand(u.canInvade===undefined||typeof u.canInvade==='boolean','侵入能力');
        demand(u.skipNextTurn===undefined||typeof u.skipNextTurn==='boolean','足払いの次回スキップ状態');
        const skillOptions=B.activeSkillOptions(u),optionKeys=new Set(skillOptions.map(option=>option.key));
        demand(u.selectedSkillKey===undefined||typeof u.selectedSkillKey==='string'&&skillOptions.some(option=>option.key===u.selectedSkillKey&&option.id===u.selectedSkill),'選択スキルの付与元');
        demand(u.skillCooldowns===undefined||record(u.skillCooldowns)&&Object.entries(u.skillCooldowns).every(([key,value])=>optionKeys.has(key)&&value===1),'スキルのクールタイム');
        demand(!b.result||u.skillCooldowns===undefined||Object.keys(u.skillCooldowns).length===0,'終了後のクールタイム');
        for(const key of ['firstMoveUsed','returnUsed'])demand(u[key]===undefined||typeof u[key]==='boolean','一戦の使用状態');
        const returnOptions=B.returnSkillOptions(u),returnKeys=new Set(returnOptions.map(option=>option.key));
        demand(u.selectedReturnSkillKey===undefined||typeof u.selectedReturnSkillKey==='string'&&returnKeys.has(u.selectedReturnSkillKey),'選択した帰還の付与元');
        demand(u.returnUsedGrants===undefined||record(u.returnUsedGrants)&&Object.entries(u.returnUsedGrants).every(([key,value])=>returnKeys.has(key)&&value===true),'帰還の使用済み付与元');
        demand(!u.returnUsed||u.returnUsedGrants===undefined||returnOptions.every(option=>u.returnUsedGrants[option.key]===true),'旧帰還使用状態の整合');
        demand(u.effects===undefined||Array.isArray(u.effects)&&new Set(u.effects).size===u.effects.length&&u.effects.every(id=>['invasion','returnHome','victoryBreath','loneWolf','firstStride','swift'].includes(id)),'装飾効果');
        demand(u.covers===undefined||Array.isArray(u.covers)&&u.covers.length<=2&&new Set(u.covers).size===u.covers.length&&u.covers.every(id=>id!==u.id&&b.units.some(t=>t.id===id&&t.side===u.side)),'防衛線');
        demand(u.skillStage===undefined||integer(u.skillStage,1,100000000),'旧スキル段階');
        demand(integer(u.def??0),'戦闘DEF');
        demand(typeof u.guard==='boolean'&&(u.cover===null||typeof u.cover==='string'&&b.units.some(t=>t.id===u.cover&&t.side===u.side))&&(u.boost===undefined||typeof u.boost==='boolean'),'戦闘支援状態');
        if(u.intent!==undefined){
          const intent=u.intent;demand(record(intent)&&['move','attack','skill','item','guard'].includes(intent.kind)&&Array.isArray(intent.cells)&&intent.cells.every(p=>integer(p,0,49)),'行動予告');
          demand(typeof intent.name==='string'&&typeof intent.reason==='string','行動予告の表示');
          demand(intent.target===null||typeof intent.target==='string'||integer(intent.target,0,49),'行動予告対象');
          demand(intent.path===undefined||Array.isArray(intent.path)&&intent.path.every(p=>integer(p,0,49)),'予告経路');
          demand(intent.destination===undefined||intent.destination===null||integer(intent.destination,0,49),'予告移動先');
          const skill=B.activeSkill(u),target=b.units.find(t=>t.id===intent.target);
          if(intent.kind==='guard')demand(intent.target===null&&intent.cells.length===0,'防御予告');
          else if(intent.kind==='move')demand(integer(intent.target,0,49)&&intent.destination===intent.target&&intent.cells.length===0,'移動予告');
          else if(intent.kind==='skill'&&skill==='stamp')demand(integer(intent.target,0,49)&&intent.cells.length>=1&&intent.cells.length<=3,'スタンプ予告');
          else {
            demand(!!target,'予告のキャラ対象');
            const offensive=intent.kind==='attack'||intent.kind==='skill'&&['archer','scout'].includes(skill);
            demand(offensive?target.side!==u.side&&intent.cells.length===1:target.side===u.side&&intent.cells.length===0,'予告の対象陣営');
            if(intent.kind==='skill'&&skill==='scout')demand(Array.isArray(intent.path)&&integer(intent.destination,0,49),'奇襲の経路と着地先');
          }
        }
        if(s.phase==='battle'&&u.side==='enemy'&&u.hp>0)demand(record(u.intent),'敵の予告なし');
        if(u.hp>0)alivePositions.push(u.pos);
        if(u.side==='enemy')demand(u.max===base.max&&u.maxMp===base.mp&&u.atk===base.atk&&u.agi===base.agi&&u.reach===base.reach&&u.equippedSkill===undefined&&u.weapon===base.weapon&&u.effects===undefined&&u.activeSkills===undefined&&u.selectedSkill===undefined&&(u.skillSources===undefined||isDeepStrictEqual(normalizedSkillSources(u.skillSources),enemySkillSources(u)))&&u.attackWeapons===undefined&&u.attackBonus===undefined,'敵の基本能力');
        if(u.side==='ally'){const st=stats(s.characters[u.id]);demand(u.max===st.max&&u.maxMp===st.maxMp&&u.atk===st.atk&&u.agi===st.speed&&u.reach===st.reach&&u.equippedSkill===st.skill,'装備能力の一致');
          demand(s.characters[u.id].equipmentRevision!==2||Array.isArray(u.attackWeapons)&&Array.isArray(u.skillSources)&&Array.isArray(u.activeSkills),'装備計算情報なし');
          demand(u.attackWeapons===undefined||isDeepStrictEqual(u.attackWeapons?.map(({name,...w})=>w),st.attackWeapons.map(({name,...w})=>w)),'通常攻撃武器');
          demand(u.attackBonus===undefined||u.attackBonus===st.attackBonus,'通常攻撃補正');
          demand((u.attackWeapons===undefined)===(u.attackBonus===undefined),'通常攻撃情報');
          demand(u.activeSkills===undefined||JSON.stringify(u.activeSkills)===JSON.stringify(st.activeSkills),'アクティブ一覧');
          demand(u.skillSources===undefined||isDeepStrictEqual(normalizedSkillSources(u.skillSources),st.skillSources),'スキル装備源');
          demand((u.def??0)===st.def,'装備DEFの一致');
          demand(u.selectedSkill===undefined||st.activeSkills.includes(u.selectedSkill),'選択スキル');
          demand(u.effects===undefined||JSON.stringify(u.effects)===JSON.stringify(st.effects),'装飾能力の一致');
          demand(u.canInvade===undefined||u.canInvade===(u.job!=='porter'&&st.effects.includes('invasion')),'侵入権限の一致');
          demand(!s.characters[u.id].accessory1&&!s.characters[u.id].accessory2||u.effects!==undefined,'装飾効果なし');
          demand(!u.firstMoveUsed||st.effects.includes('firstStride'),'先駆けの装備');demand(!u.returnUsed||st.effects.includes('returnHome'),'帰還の装備');
          demand(!u.covers?.length||st.activeSkills.includes('defenseLine'),'防衛線の装備');
        }
      }
      demand(new Set(alivePositions).size===alivePositions.length,'配置重複');
      demand(b.actor===null||b.units.some(u=>u.id===b.actor&&u.side==='ally'&&u.hp>0),'行動者');
      if(s.phase==='battle'&&!b.result)demand(b.actor!==null,'行動者なし');
      if(b.result)demand(b.actor===null&&(b.units.filter(u=>u.side==='enemy').every(u=>u.hp===0)||b.units.some(u=>u.side==='ally'&&u.job==='porter'&&u.hp===0)||b.units.filter(u=>u.side==='ally').every(u=>u.hp===0)),'戦闘結果の不一致');
      demand(Array.isArray(b.deploymentInitial)&&b.deploymentInitial.length===ids.length&&b.deploymentInitial.every(p=>ids.includes(p.id)&&integer(p.pos,0,49)&&B.boardOf(p.pos)==='ally')&&new Set(b.deploymentInitial.map(p=>p.pos)).size===ids.length&&new Set(b.deploymentInitial.map(p=>p.id)).size===ids.length,'初期配置');
    } else demand(!['deployment','battle'].includes(s.phase),'戦闘情報なし');
  }
  function serialize(s) {
    demand(s.cargoRevision===1,'保存前に旧形式の読込・移行が必要です');
    const checked=validate(s);if(!checked.ok)throw new Error(checked.error);
    const data=JSON.stringify({format:'5525-native-campaign',version:VERSION,cargoRevision:1,state:s},null,2);
    demand(Buffer.byteLength(data,'utf8')<=MAX_SAVE_BYTES,'保存サイズ');return data;
  }
  function migrateEquipment(s) {
    if(s.rollback)migrateEquipment(s.rollback);
    let changed=false;
    for(const c of Object.values(s.characters)) {
      if(c.equipmentRevision===2)continue;
      const setIds=['sword-wood','sword-iron-1'];
      if(setIds.includes(c.weapon)) {
        demand(!c.leftHand||c.leftHand==='empty-leftHand',`旧剣盾セットの分割先（左手）が ${c.leftHand} と競合しています。元セーブと現在の進行は変更していません。旧版で左手を空けて別名保存してから読み込んでください`);
        c.leftHand=c.weapon==='sword-wood'?'guard-shield-wood':'guard-shield-iron-1';
      } else demand(!setIds.includes(c.leftHand),'左手の旧剣盾セットは分割先が競合しています。元セーブを保持し、旧版で右手へ移して左手を空け、別名保存してください');
      c.equipmentRevision=2;changed=true;
    }
    if(changed&&s.battle)for(const u of s.battle.units.filter(u=>u.side==='ally')) {
      const st=stats(s.characters[u.id]);
      u.equippedSkill=st.skill;u.activeSkills=st.activeSkills;u.skillSources=st.skillSources;
      u.attackWeapons=st.attackWeapons;u.attackBonus=st.attackBonus;u.equipment=st.equipment;
    }
  }
  function migrateInventory(s) {
    // UI party portraits use this explicit saved order, never object-key order.
    const first=s.selected[0];
    demand(typeof first==='string'&&template(first)&&Object.hasOwn(s.characters,first),'旧在庫の受取人（編成の1キャラ目）が不在です。元セーブは変更していません');
    for(const c of Object.values(s.characters)){
      demand(!Object.hasOwn(c,'inventory'),'旧形式に個人在庫が混在しています');
      c.inventory={};
    }
    for(const item of items)if(s.inventory[item.id]>0)s.characters[first].inventory[item.id]=s.inventory[item.id];
    if(s.battle){
      const b=s.battle;b.ethers=b.ethers??s.inventory.ether;
      demand(b.potions.ally<=s.inventory.potion&&b.ethers<=s.inventory.ether,'戦闘残数が旧所持品を超えています');
      b.itemInventories=Object.fromEntries(s.selected.map(id=>[id,{potion:0,ether:0}]));
      b.itemInventories[first]={potion:b.potions.ally,ether:b.ethers};
    }
    delete s.inventory;s.version=VERSION;
    if(s.rollback)migrateInventory(s.rollback);
  }
  function deserialize(input) {
    let envelope;
    if(typeof input==='string'){demand(Buffer.byteLength(input,'utf8')<=MAX_SAVE_BYTES,'保存サイズ');try{envelope=JSON.parse(input);}catch(e){throw new Error('セーブJSONを読み取れません');}}
    else {safeTree(input);demand(Buffer.byteLength(JSON.stringify(input),'utf8')<=MAX_SAVE_BYTES,'保存サイズ');envelope=clone(input);}
    safeTree(envelope);
    if(envelope.cargoRevision!==undefined)demand(envelope.cargoRevision===1&&envelope.state?.cargoRevision===1,'荷物移行マーカー');
    demand(record(envelope)&&envelope.format==='5525-native-campaign'&&[1,VERSION].includes(envelope.version),'保存形式');
    validateState(envelope.state,0,envelope.version);
    // Only normalize an already-valid older save; never truncate before validation.
    const loaded=clone(envelope.state);
    migrateEquipment(loaded);
    if(envelope.version===1)migrateInventory(loaded);
    // A rollback is an alternative snapshot, never additional owned stock.
    // Refund each snapshot independently; removal makes migration idempotent.
    // Only the validated clone is touched, so source files/objects remain intact.
    function retirePaidFists(s) {
      if(s.rollback)retirePaidFists(s.rollback);
      let count=0;
      for(const c of Object.values(s.characters)) {
        count+=c.inventory['fist-1']||0;
        delete c.inventory['fist-1'];
        for(const slot of Object.keys(S.slots)) {
          const field=S.storage(slot);
          if(c[field]==='fist-1'){count++;c[field]=`empty-${slot}`;}
        }
      }
      if(!count)return;
      const refund=count*100;
      demand(integer(s.gold+refund),'旧拳＋1の返金後に所持金上限を超えます。元セーブは変更していません。所持金を調整して別名保存してください');
      s.gold+=refund;
      note(s,`旧拳＋1を${count}個、仮想拳へ移行。${refund}Gを返金。`);
    }
    retirePaidFists(loaded);
    if(envelope.cargoRevision===undefined&&loaded.cargoRevision===undefined){
      function upgradeCargo(s){
        if(s.rollback)upgradeCargo(s.rollback);
        if(s.activeQuest&&!s.activeQuest.cargoItemId){
          const owner=B.roster.filter(t=>t.job==='porter'&&s.characters[t.id]).sort((a,b)=>(a.id==='porter'?1:Number(a.id.split('-').pop()))-(b.id==='porter'?1:Number(b.id.split('-').pop())))[0];
          demand(owner,'旧依頼の荷物を持つポーターが存在しません。元セーブは変更していません。');
          Cargo.issue(s,owner.id);
        }
        s.cargoRevision=1;
      }
      upgradeCargo(loaded);
    }
    if(loaded.battle&&loaded.battle.formationVersion===undefined){loaded.battle.formationVersion=loaded.phase==='battle'?1:2;loaded.battle.formationKind=loaded.journey.formation;}
    function migrateCombatMetadata(s) {
      if(s.battle)s.battle.skillCooldownVersion=1;
      for(const c of Object.values(s.characters))c.def=c.def??0;
      if(s.rollback)migrateCombatMetadata(s.rollback);
      if(s.battle)for(const u of s.battle.units){
        u.def=u.def??0;
        if(u.side==='ally'){
          const nextSources=stats(s.characters[u.id]).skillSources;
          // Retired real fists become virtual empty hands. Keep the same used grant
          // on that hand instead of clearing its wait or retaining an obsolete key.
          for(const old of normalizedSkillSources(u.skillSources)||[]){
            if(old.id!=='itemUse'||!/^fist(?:-[12])?$/.test(old.itemId||''))continue;
            const next=nextSources.find(source=>source.id===old.id&&source.slot===old.slot&&source.grantSlot===old.grantSlot&&source.itemId===`empty-${old.slot}`);
            if(!next)continue;
            const oldKey=JSON.stringify([old.slot,old.itemId,old.grantSlot]),newKey=JSON.stringify([next.slot,next.itemId,next.grantSlot]);
            if(u.selectedSkillKey===oldKey)u.selectedSkillKey=newKey;
            if(u.skillCooldowns&&Object.hasOwn(u.skillCooldowns,oldKey)){u.skillCooldowns[newKey]=u.skillCooldowns[oldKey];delete u.skillCooldowns[oldKey];}
          }
          u.skillSources=nextSources;
        }
        else if(u.job==='scout')u.skillSources=enemySkillSources(u);
      }
    }
    migrateCombatMetadata(loaded);
    function upgradeCombat(s) {
      if(s.rollback)upgradeCombat(s.rollback);
      for(const c of Object.values(s.characters))c.combatRevision=1;
      if(s.battle)for(const u of s.battle.units.filter(u=>u.side==='ally')) {
        const st=stats(s.characters[u.id]);
        u.equippedSkill=st.skill;u.activeSkills=st.activeSkills;u.skillSources=st.skillSources;
        u.attackWeapons=st.attackWeapons;u.attackBonus=st.attackBonus;u.equipment=st.equipment;
        if(u.selectedSkill!==undefined&&!st.activeSkills.includes(u.selectedSkill))delete u.selectedSkill;
      }
    }
    upgradeCombat(loaded);
    function upgradeReturnGrants(s) {
      if(s.rollback)upgradeReturnGrants(s.rollback);
      for(const u of s.battle?.units||[]){
        // Old returnUsed exhausted the actor-wide allowance, so all old grants
        // remain exhausted. Migration never grants a fresh use in that battle.
        if(u.returnUsed===true&&u.returnUsedGrants===undefined)u.returnUsedGrants=Object.fromEntries(B.returnSkillOptions(u).map(option=>[option.key,true]));
      }
    }
    upgradeReturnGrants(loaded);
    const migrated=validate(loaded);if(!migrated.ok)throw new Error(migrated.error);
    if(loaded.battle)B.trimLog(loaded.battle);return loaded;
  }
  const {purchaseQuote,buyInventory,purchasePlan,buyPlan,saleQuote,sellInventory,saleAvailable}=require('./shop-transactions.js')({I,S,clone,record,integer,getGear,template,shop,equipment,eligibility,stats,syncCharacter,validate,inventoryToken,commitInventory,note,createHash});
  return {VERSION,MAX_SAVE_BYTES,equipment,slots:S.slots,locations,gear,items,materials,provisional,create,view,board,destinations,hasPorter,stats,
    select,accept,depart,travel,deploy,deployment_assign,chooseFormation,deployment_reset,begin,act,retreat,finishBattle,rest,onward,forecast,arrive,acknowledge,
    completeQuest,eligibility,shop,quote,buyGear,buyItem,inn,useItem,inventoryTotals,inventoryToken,inventoryQuote,inventoryAction,inventoryView,purchaseQuote,buyInventory,purchasePlan,buyPlan,saleQuote,sellInventory,saleAvailable,allocate,allocateBatch,allocationToken,previewGear,trial,trialAct,validate,serialize,deserialize};
})();
module.exports = Campaign;
