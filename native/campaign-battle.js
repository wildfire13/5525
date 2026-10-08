"use strict";
// Campaign-only extension of frozen battle.js (source sha256 documented in README).
// Optional equippedSkill changes the active command, never the character job.
// Unextended standalone/journey continue using battle.js.
const Presentation = require('./battle-presentation.cjs');
const Battle = (() => {
  const {definitions:equipmentSkills}=require('./equipment-skills.js');
  const hasEffect=(a,id)=>(a.effects||[]).includes(id);
  const moveReach=a=>(hasEffect(a,'firstStride')&&!a.firstMoveUsed?3:2)+(hasEffect(a,'swift')?1:0);
  const skillCost=a=>equipmentSkills[activeSkill(a)]?.cost??1;
  function emit(s,a,id,details={}) {
    s.skillEventSequence=(s.skillEventSequence||0)+1;
    (s.skillEvents||(s.skillEvents=[])).push({sequence:s.skillEventSequence,type:'skill.activated',actorId:a.id,skillId:id,classification:equipmentSkills[id].classification,...details});
    if(s.skillEvents.length>100)s.skillEvents.splice(0,s.skillEvents.length-100);
  }
  function freeCell(s,p){return Number.isInteger(p)&&p>=0&&p<50&&!alive(s).some(u=>u.pos===p);}
  function retreatCell(s,a){const p=a.pos+(a.side==='ally'?-1:1);return y(p)===y(a.pos)&&freeCell(s,p)&&canEnter(a,p)?p:null;}
  function crossCells(p){return [p,...[p-1,p+1,p-10,p+10].filter(q=>q>=0&&q<50&&range({pos:p},{pos:q})===1)];}
  function skillTargets(s,a,kind='skill') {
    if(kind==='return')return Array.from({length:50},(_,p)=>p).filter(p=>legalFor(s,a,kind,p));
    const id=activeSkill(a),d=equipmentSkills[id];
    if(d?.target==='pair'||d?.target==='upToTwo'){
      const candidates=alive(s).filter(b=>b.id!==a.id&&inRange(a,b.side,b.pos,'skill',s));
      const targets=d.target==='upToTwo'?candidates.map(b=>[b.id]):[];
      for(let i=0;i<candidates.length;i++)for(let j=i+1;j<candidates.length;j++)targets.push([candidates[i].id,candidates[j].id]);
      return targets.filter(t=>legalFor(s,a,'skill',t));
    }
    const targets=id==='stamp'?Array.from({length:50},(_,p)=>p):s.units.map(u=>u.id);
    return targets.filter(t=>legalFor(s,a,'skill',t));
  }
  // Weapon ATK excludes template ATK and growth; growth is added once after filtering.
  function reachFilteredPower(a,target,kind='attack') {
    if(a.job==='porter')return {base:0,weapons:[],bonus:0};
    if(!a.attackWeapons)return {base:a.atk,weapons:[],bonus:0};
    const skill=kind==='skill'?activeSkill(a):null;
    const weapons=a.attackWeapons.filter(w=>range(a,target)<=w.reach+(skill==='archer'?1:0)||(skill==='stamp'&&w.skill==='stamp'));
    const bonus=weapons.length?(a.attackBonus||0):0;
    return {base:weapons.reduce((n,w)=>n+w.atk,0)+bonus,weapons,bonus};
  }
  function power(s,a,base=a.atk,emitEvent=true){
    let p=base*(formation(s,a.side)?boosted(s,a.side)?1.75:1.5:1);
    if(hasEffect(a,'loneWolf')&&!alive(s).some(u=>u.side===a.side&&u.id!==a.id&&range(a,u)===1)){
      p*=1.25;if(emitEvent)emit(s,a,'loneWolf');
    }
    return p;
  }
  // Display history is independent of PlayLog diagnostic retention. Leave the
  // counter absent until the first eviction to preserve short-battle parity.
  const MAX_LOG_LINES = 1000;
  function trimLog(s) {
    const dropped=Math.max(0,s.log.length-MAX_LOG_LINES);
    if(dropped){s.log.splice(0,dropped);s.logDropped=(s.logDropped||0)+dropped;}
  }
  function log(s,message) {s.log.push(message);trimLog(s);}
  // 全員の位置は共通10×5座標。所属(side)と滞在陣地は独立。
  const x = p => p % 10, y = p => Math.floor(p / 10);
  const alive = s => s.units.filter(u => u.hp > 0);
  const range = (a,b) => Math.abs(x(a.pos)-x(b.pos))+Math.abs(y(a.pos)-y(b.pos));
  const boardOf = p => x(p)<5 ? "ally" : "enemy";
  const cell = (board,p) => Math.floor(p/5)*10 + p%5 + (board==='enemy'?5:0);
  const screen = (_,p) => ({x:x(p)%5,y:y(p)});
  const slots = {ally:[24,13,33],enemy:[25,16,36]};
  const formation = (s,side="ally") => slots[side].every(p=>alive(s).some(u=>u.side===side&&u.pos===p));
  // 仮接続：槌装備でスタンプを試せる。完成版の習得・使用条件は未決定。
  const activeSkills = a => a.activeSkills||[a.job==='porter'?'porter':(a.equippedSkill || (a.weapon==='hammer'?'stamp':a.job))];
  const activeSkill = a => activeSkills(a).includes(a.selectedSkill)?a.selectedSkill:(a.activeSkills?activeSkills(a)[0]||null:a.job==='porter'?'porter':(a.equippedSkill || (a.weapon==='hammer'?'stamp':a.job)));
  function selectSkill(s,id){const a=s.units.find(u=>u.id===s.actor);if(s.deploying||s.result||!a||a.hp<=0||!activeSkills(a).includes(id))return false;a.selectedSkill=id;return true;}
  const skillName = a => equipmentSkills[activeSkill(a)]?.name||({guard:"かばう",archer:"スナイプ",mage:"ヒール",scout:"奇襲",porter:"陣形強化",stamp:"スタンプ"})[activeSkill(a)]||'';
  const attackReach = (a,kind='attack') => (kind==='attack'||kind==='skill'&&activeSkill(a)==='archer')&&a.attackWeapons?Math.max(0,...a.attackWeapons.map(w=>w.reach+(kind==='skill'?1:0))):kind==='skill'&&equipmentSkills[activeSkill(a)]?equipmentSkills[activeSkill(a)].reach:a.reach+(kind==='skill'&&activeSkill(a)==='archer'?1:0);
  function stampCells(a,center) {
    if(!Number.isInteger(center)||center<0||center>=50||range(a,{pos:center})!==1)return [];
    const dx=x(center)-x(a.pos),dy=y(center)-y(a.pos);
    return [-1,0,1].map(offset=>({x:x(center)+(dy?offset:0),y:y(center)+(dx?offset:0)}))
      .filter(p=>p.x>=0&&p.x<10&&p.y>=0&&p.y<5).map(p=>p.y*10+p.x);
  }
  const boosted=(s,side='ally')=>formation(s,side)&&alive(s).some(u=>u.side===side&&u.boost);
  const templates = [
    {job:"guard",name:"ガロ",role:"盾役",icon:"盾",pos:24,max:180,atk:26,agi:10,reach:1,mp:6,image:"knight.png"},
    {job:"archer",name:"リノ",role:"弓手",icon:"弓",pos:13,max:100,atk:25,agi:14,reach:3,mp:4,image:"archer.png"},
    {job:"mage",name:"ミオ",role:"ヒーラー",icon:"癒",pos:33,max:100,atk:14,agi:11,reach:2,mp:8,image:"healer.png"},
    {job:"scout",name:"ニカ",role:"スカウト",icon:"斥",pos:4,max:105,atk:23,agi:13,reach:1,mp:5,image:"scout.png"},
    {job:"porter",name:"トワ",role:"ポーター",icon:"運",pos:22,max:110,atk:0,agi:12,reach:0,mp:6,image:"porter.png"},
    {job:"warrior",name:"槌戦士（仮）",role:"槌戦士",icon:"槌",weapon:"hammer",pos:24,max:180,atk:26,agi:10,reach:1,mp:6,image:"warrior.png"}
  ];
  const roster=templates.flatMap((t,i)=>t.job==='warrior'?[{...t,id:t.job}]:[{...t,id:t.job},{...t,id:t.job+'-2',name:['バルト','セナ','ユイ','ルカ','ハル'][i]}]);
  const defaultJobs=['guard','archer','mage','scout'];
  function swapTarget(s,a,p){
    if(a.job!=='porter'||!canEnter(a,p)||p===a.pos)return null;
    const b=alive(s).find(u=>u.side===a.side&&u.id!==a.id&&u.pos===p);
    if(!b||!canEnter(b,a.pos))return null;
    return paths({...s,units:s.units.filter(u=>u.id!==b.id)},a,moveReach(a)).has(p)?b:null;
  }
  const canEnter = (a,p) => Number.isInteger(p)&&p>=0&&p<50&&((a.canInvade??(a.job==='scout'))||boardOf(p)===a.side);
  function paths(s,a,max=49) {
    const occupied=new Set(alive(s).filter(u=>u.id!==a.id).map(u=>u.pos));
    const found=new Map([[a.pos,[]]]), queue=[a.pos];
    for(let i=0;i<queue.length;i++) {
      const p=queue[i], route=found.get(p);
      if(route.length>=max)continue;
      for(const q of [x(p)>0?p-1:-1,x(p)<9?p+1:-1,y(p)>0?p-10:-1,y(p)<4?p+10:-1]) {
        if(!canEnter(a,q)||occupied.has(q)||found.has(q))continue;
        found.set(q,[...route,q]);queue.push(q);
      }
    }
    return found;
  }
  function ambush(s,a,b) {
    if(!b||activeSkill(a)!=='scout'||a.side===b.side||b.hp<=0||y(a.pos)!==y(b.pos))return null;
    const direction=Math.sign(x(b.pos)-x(a.pos));
    if(!direction)return null;
    if(a.skillStage===1&&direction!==(a.side==='ally'?1:-1))return null;
    const destination=b.pos-direction, route=[];
    if(!canEnter(a,destination))return null;
    for(let p=a.pos+direction;p!==b.pos;p+=direction){
      if(alive(s).some(u=>u.id!==a.id&&u.pos===p))return null;
      route.push(p);
    }
    return {destination,path:route};
  }
  function inRange(a,side,pos,kind,s) {
    if(kind==='return')return hasEffect(a,'returnHome')&&!a.returnUsed&&pos!==a.pos&&boardOf(pos)===a.side&&(!s||freeCell(s,pos));
    if(kind==='skill'&&activeSkill(a)==='stamp')return stampCells(a,pos).length>0;
    if(a.job==='porter')return kind==='skill'&&side===a.side&&pos===a.pos;
    if(kind==='skill'&&activeSkill(a)==='scout')return !!(s&&ambush(s,a,{side,pos,hp:1}));
    const support=kind==='skill'&&['guard','mage','healingCross','defenseLine','manaGift'].includes(activeSkill(a));
    return (support?side===a.side:side!==a.side)&&range(a,{pos})<=attackReach(a,kind)&&(support||kind!=='skill'||reachFilteredPower(a,{pos},kind).base>0);
  }
  function legalFor(s,a,kind,target) {
    if(s.deploying||s.result||!a||a.hp<=0)return false;
    if(kind==='skill'&&!activeSkill(a))return false;
    if(kind==='guard')return true;
    if(kind==='move')return target!==a.pos&&(paths(s,a,moveReach(a)).has(target)||!!swapTarget(s,a,target));
    if(kind==='return')return Number.isInteger(target)&&target>=0&&target<50&&inRange(a,a.side,target,kind,s);
    if(kind==='skill'&&equipmentSkills[activeSkill(a)]){
      const id=activeSkill(a),d=equipmentSkills[id];if(a.mp<d.cost)return false;
      if(d.target==='pair'||d.target==='upToTwo'){
        return Array.isArray(target)&&target.length>0&&target.length<=2&&(d.target!=='pair'||target.length===2)&&new Set(target).size===target.length&&target.every(t=>{const b=alive(s).find(u=>u.id===t);return b&&b.id!==a.id&&inRange(a,b.side,b.pos,kind,s);});
      }
      const b=alive(s).find(u=>u.id===target);if(!b||!inRange(a,b.side,b.pos,kind,s))return false;
      if(id==='retreatSlash')return retreatCell(s,a)!==null;
      if(id==='healingCross')return alive(s).some(u=>u.side===a.side&&crossCells(b.pos).includes(u.pos)&&u.hp<u.max);
      if(id==='manaGift')return b.id!==a.id&&a.mp>0&&b.mp<b.maxMp;
      return true;
    }
    if(kind==='skill'&&activeSkill(a)==='stamp')return a.mp>0&&stampCells(a,target).length>0;
    const b=alive(s).find(u=>u.id===target);if(!b)return false;
    if(kind==='ether')return a.side==='ally'&&a.job==='porter'&&(s.ethers||0)>0&&b.side===a.side&&b.mp<b.maxMp;
    if(kind==='item')return s.potions[a.side]>0&&b.side===a.side&&b.hp<b.max;
    if(kind==='attack')return a.job!=='porter'&&b.side!==a.side&&range(a,b)<=attackReach(a,'attack');
    if(kind!=='skill'||a.mp<=0)return false;
    if(a.job==='porter')return b.id===a.id&&formation(s,a.side);
    if(activeSkill(a)==='scout')return !!ambush(s,a,b);
    if(!inRange(a,b.side,b.pos,kind,s))return false;
    return activeSkill(a)==='mage'?b.hp<b.max:activeSkill(a)==='guard'?b.id!==a.id:true;
  }
  const legal=(s,k,t)=>legalFor(s,s.units.find(u=>u.id===s.actor),k,t);
  function damageResult(s,target,power,formed=formation(s,target.side)) {
    const protector=alive(s).find(u=>u.side===target.side&&(u.cover===target.id||u.covers?.includes(target.id)));
    const recipient=protector||target;
    const hit=Math.max(1,Math.round(power*(formed?(boosted(s,target.side)?.65:.75):1)*(recipient.guard?.5:1)));
    return {protector,recipient,hit};
  }
  function attackPreview(s,a,target) {
    if(!legalFor(s,a,'attack',target.id))return null;
    const contribution=reachFilteredPower(a,target),{recipient,hit}=damageResult(s,target,power(s,a,contribution.base,false));
    return {targetId:target.id,targetName:target.name,recipientId:recipient.id,recipientName:recipient.name,damage:hit,hpLoss:Math.min(recipient.hp,hit),...contribution};
  }
  function receive(s,target,power,formed=formation(s,target.side),contribution=null) {
    const {protector,recipient,hit}=damageResult(s,target,power,formed);
    if(s.damagePreviewEvents)s.damagePreviewEvents.push({targetId:target.id,targetName:target.name,recipientId:recipient.id,recipientName:recipient.name,damage:hit,hpLoss:Math.min(recipient.hp,hit),...(contribution||{base:power,weapons:[],bonus:0})});
    recipient.hp=Math.max(0,recipient.hp-hit);
    if(recipient.hp===0&&recipient.covers)recipient.covers=[];
    log(s,`${protector?`${recipient.name}が${target.name}をかばう：`:""}${recipient.name}に${hit}ダメージ${recipient.hp===0?"・戦闘不能":""}`);
  }
  function apply(s,a,kind,target,landing,fixedCells) {
    Presentation.mark(s,a,kind,target,{activeSkill,skillName});
    if(kind==='return'){a.pos=target;a.returnUsed=true;emit(s,a,'returnHome',{target});log(s,`${a.name}の帰還 → (${x(target)+1},${y(target)+1})`);return;}
    if(kind==='skill'&&equipmentSkills[activeSkill(a)]){
      const id=activeSkill(a),b=s.units.find(u=>u.id===target),d=equipmentSkills[id];
      a.mp-=d.cost;emit(s,a,id,{target});log(s,`${a.name}の${d.name}`);
      if(id==='manaGift'){const amount=Math.min(2,a.mp,b.maxMp-b.mp);a.mp-=amount;b.mp+=amount;log(s,`${a.name}から${b.name}へMP${amount}移譲。`);return;}
      if(id==='defenseLine'){a.covers=[...target];a.cover=null;log(s,`次の本人の番まで ${target.map(id=>s.units.find(u=>u.id===id).name).join('・')} をかばう。`);return;}
      if(id==='healingCross'){for(const u of alive(s).filter(u=>u.side===a.side&&crossCells(b.pos).includes(u.pos))){const n=Math.min(30,u.max-u.hp);u.hp+=n;log(s,`${u.name}のHP＋${n}`);}return;}
      const factor=power(s,a,1);
      if(id==='splitShot'){for(const id of target){const u=s.units.find(u=>u.id===id),contribution=reachFilteredPower(a,u,'skill');if(u.hp>0&&contribution.base>0)receive(s,u,contribution.base*factor*.6,undefined,contribution);}return;}
      const destination=id==='retreatSlash'?retreatCell(s,a):null;
      const multiplier=id==='retreatSlash'?.7:id==='pincer'&&alive(s).some(u=>u.side===a.side&&u.id!==a.id&&range(u,b)===1)?1.5:1;
      const contribution=reachFilteredPower(a,b,'skill');
      if(contribution.base>0)receive(s,b,contribution.base*factor*multiplier,undefined,contribution);
      if(id==='retreatSlash'){a.pos=destination;log(s,`${a.name}が後退。`);}
      if(id==='knockback'&&b.hp>0){const p=b.pos+(x(b.pos)-x(a.pos))+10*(y(b.pos)-y(a.pos));if(freeCell(s,p)&&range(b,{pos:p})===1){b.pos=p;log(s,`${b.name}を1マス押し出した。`);}else log(s,'押し出し先なし：攻撃のみ。');}
      return;
    }
    if(kind==='move'){const b=swapTarget(s,a,target);if(hasEffect(a,'firstStride')&&!a.firstMoveUsed){a.firstMoveUsed=true;emit(s,a,'firstStride',{target});log(s,`${a.name}の先駆け：最初の移動。`);}if(b){b.pos=a.pos;a.pos=target;log(s,`${a.name}と${b.name}が入れ替わった。`);}else{a.pos=target;log(s,`${a.name}が${boardOf(target)==='ally'?'味方陣':'敵陣'}へ移動。`);}return;}
    if(kind==='guard'){a.guard=true;log(s,`${a.name}は防御。`);return;}
    const b=s.units.find(u=>u.id===target);
    if(kind==='ether'){s.ethers--;const heal=Math.min(3,b.maxMp-b.mp);b.mp+=heal;log(s,`${a.name}のエーテル：${b.name}のMP＋${heal}`);return;}
    if(kind==='item'){s.potions[a.side]--;const heal=Math.min(55,b.max-b.hp);b.hp+=heal;log(s,`${a.name}の回復薬：${b.name}のHP＋${heal}`);return;}
    if(kind==='skill')a.mp--;
    if(kind==='skill'&&activeSkill(a)==='stamp'){
      const cells=fixedCells||stampCells(a,target),targets=alive(s).filter(u=>u.side!==a.side&&cells.includes(u.pos));
      // 各対象へ通常威力。陣形・かばう・防御は既存のダメージ処理を使う。
      const factor=power(s,a,1);
      log(s,`${a.name}のスタンプ → 中心(${x(target)+1},${y(target)+1})・${cells.length}マス${targets.length?'':'：空振り。'}`);
      for(const enemy of targets){const contribution=reachFilteredPower(a,enemy,'skill');if(enemy.hp>0&&contribution.base>0)receive(s,enemy,contribution.base*factor,undefined,contribution);}
      return;
    }
    if(kind==='skill'&&a.job==='porter'){a.boost=true;log(s,`${a.name}の陣形強化：次の本人の番まで攻撃＋75％・被害−35％。重複なし。`);return;}
    if(kind==='skill'&&activeSkill(a)==='mage'){const heal=Math.min(60,b.max-b.hp);b.hp+=heal;log(s,`${a.name}のヒール：${b.name}のHP＋${heal}`);return;}
    if(kind==='skill'&&activeSkill(a)==='guard'){a.cover=b.id;log(s,`${a.name}は次の自分の番まで${b.name}をかばう。`);return;}
    if(kind==='skill'&&activeSkill(a)==='scout')a.pos=landing;
    log(s,`${a.name}の${kind==='skill'?skillName(a):'攻撃'} → ${b.name}`);
    const contribution=reachFilteredPower(a,b,kind);
    if(contribution.base>0)receive(s,b,power(s,a,contribution.base),undefined,contribution);
  }
  // Run the exact action on a detached copy; no turn advance or live events.
  function damagePreview(s,a,kind,target) {
    if(!['attack','skill'].includes(kind)||!legalFor(s,a,kind,target))return [];
    const copy=JSON.parse(JSON.stringify(s)),actor=copy.units.find(u=>u.id===a.id);
    copy.damagePreviewEvents=[];
    const landing=kind==='skill'&&activeSkill(actor)==='scout'?ambush(copy,actor,copy.units.find(u=>u.id===target))?.destination:undefined;
    apply(copy,actor,kind,target,landing);
    return copy.damagePreviewEvents;
  }
  function plan(s,a) {
    const friends=alive(s).filter(u=>u.side===a.side), enemies=alive(s).filter(u=>u.side!==a.side).sort((l,r)=>l.hp-r.hp);
    const make=(kind,target,reason)=>{
      const b=s.units.find(u=>u.id===target), jump=kind==='skill'&&activeSkill(a)==='scout'?ambush(s,a,b):null;
      a.intent={kind,target,reason,name:kind==='skill'?skillName(a):({attack:'攻撃',move:'移動',guard:'防御',item:'回復薬'})[kind],cells:kind==='skill'&&activeSkill(a)==='stamp'?stampCells(a,target):kind==='attack'||(kind==='skill'&&['archer','scout'].includes(activeSkill(a)))?[b.pos]:[],destination:kind==='move'?target:jump?.destination,path:jump?.path};
    };
    const hurt=[...friends].sort((l,r)=>(r.max-r.hp)-(l.max-l.hp));
    if(activeSkill(a)==='mage'){const b=hurt.find(b=>b.max-b.hp>=30&&legalFor(s,a,'skill',b.id));if(b){make('skill',b.id,'傷ついた味方を回復');return;}}
    if(activeSkill(a)==='guard'){const b=hurt.find(b=>b.id!==a.id&&b.hp<b.max*.65&&legalFor(s,a,'skill',b.id));if(b){make('skill',b.id,'傷ついた隣の味方を守る');return;}}
    const endangered=hurt.find(b=>b.hp<b.max*.3&&legalFor(s,a,'item',b.id));
    if(endangered){make('item',endangered.id,'瀕死の味方を救援');return;}
    if(activeSkill(a)==='stamp'){
      const centers=Array.from({length:50},(_,p)=>p).filter(p=>legalFor(s,a,'skill',p));
      const count=p=>enemies.filter(b=>stampCells(a,p).includes(b.pos)).length;
      centers.sort((l,r)=>count(r)-count(l));
      if(centers.length&&count(centers[0])){make('skill',centers[0],'指定した3マスの敵を狙う');return;}
    }
    const skill=enemies.find(b=>legalFor(s,a,'skill',b.id));
    if(skill){make('skill',skill.id,activeSkill(a)==='scout'?'同じ横列の弱った敵へ奇襲':'射程内の弱った敵を狙う');return;}
    const attack=enemies.find(b=>legalFor(s,a,'attack',b.id));
    if(attack){make('attack',attack.id,'射程内の弱った敵を狙う');return;}
    const goal=activeSkill(a)==='mage'&&hurt[0]?.hp<hurt[0]?.max*.7?hurt[0]:enemies[0];
    if(goal){const options=[...paths(s,a,2).keys()].filter(p=>p!==a.pos).sort((l,r)=>range({pos:l},goal)-range({pos:r},goal));if(options.length&&range({pos:options[0]},goal)<range(a,goal)){make('move',options[0],'届く位置へ接近');return;}}
    make('guard',null,'次の機会に備える');
  }
  function enemyAction(s,a) {
    Presentation.mark(s,a,a.intent.kind,a.intent.target,{activeSkill,skillName});
    const i=a.intent;s.recentEnemies.push({name:a.name,action:i.name});
    // 攻撃の予告は人物追尾せずセル固定。奇襲の着地点も固定。
    if(i.cells.length){
      if(i.kind==='skill'&&activeSkill(a)==='stamp'){
        if(a.mp<=0){log(s,`${a.name}のスタンプはMP不足で見送り。`);return;}
        apply(s,a,i.kind,i.target,undefined,i.cells);return;
      }
      if(i.kind==='skill'&&activeSkill(a)==='scout') {
        if(a.mp<=0||i.path.some(p=>alive(s).some(u=>u.id!==a.id&&u.pos===p))){log(s,`${a.name}の奇襲経路が塞がれた。`);return;}
        a.pos=i.destination;
      }
      const b=alive(s).find(u=>u.side!==a.side&&u.pos===i.cells[0]);
      if(!b||range(a,b)>attackReach(a,i.kind)){if(i.kind==='skill'&&activeSkill(a)==='scout')a.mp--;log(s,`${a.name}の${i.name}は空振り。`);return;}
      if(i.kind==='skill'&&a.mp<=0){log(s,`${a.name}の${i.name}はMP不足で見送り。`);return;}
      apply(s,a,i.kind,b.id,i.destination);return;
    }
    if(legalFor(s,a,i.kind,i.target))apply(s,a,i.kind,i.target);
    else log(s,`${a.name}の${i.name}は対象・経路が無効になり見送り。`);
  }
  const order=(a,b)=>a.next-b.next||b.agi-a.agi||a.tie-b.tie;
  function check(s){const fallen=s.units.find(u=>u.side==='ally'&&u.job==='porter'&&u.hp<=0);if(fallen){s.failure='porter';s.result=`クエスト失敗。${fallen.name}が倒れ、荷物を運べなくなった。`;}else if(!alive(s).some(u=>u.side==='enemy'))s.result='勝利！ ミラーマッチを制した。';else if(!alive(s).some(u=>u.side==='ally'))s.result='敗北。配置と連携を変えて再挑戦しよう。';
    if(s.result){
      for(const u of s.units)if(u.covers)u.covers=[];
      if(!s.failure&&!alive(s).some(u=>u.side==='enemy')&&!s.victoryEffectsApplied&&s.units.some(u=>hasEffect(u,'victoryBreath'))){
        s.victoryEffectsApplied=true;
        for(const u of alive(s).filter(u=>u.side==='ally'&&hasEffect(u,'victoryBreath'))){const amount=Math.min(2,u.maxMp-u.mp);u.mp+=amount;emit(s,u,'victoryBreath',{amount});log(s,`${u.name}の一息：MP＋${amount}`);}
      }
    }
    return !!s.result;}
  function advance(s){while(!check(s)){const a=alive(s).sort(order)[0];a.guard=false;a.cover=null;if(a.covers)a.covers=[];a.boost=false;s.actor=a.id;if(a.side==='ally'||Presentation.isStepping(s))return;enemyAction(s,a);a.next+=100/a.agi;if(check(s))break;plan(s,a);}s.actor=null;}
  function stepEnemy(s){const a=s.units.find(u=>u.id===s.actor);if(!a||a.side!=='enemy'||s.result)return false;enemyAction(s,a);a.next+=100/a.agi;if(!check(s))plan(s,a);advance(s);return true;}
  function create(options={}){
    const units=[];
    for(const side of ['ally','enemy']){
      const ids=options[side]||defaultJobs,used=new Set();
      const members=ids.map(id=>({...roster.find(t=>t.id===id)}));
      for(const t of members){if(!used.has(t.pos)){used.add(t.pos);}else t.pos=null;}
      for(const t of members){if(t.pos===null){t.pos=(t.job==='porter'?[32,12,2,42]:[24,13,33,4,14,34]).find(p=>!used.has(p));used.add(t.pos);}}
      if(side==='ally'&&options.formation==='flank'){const scout=members.find(t=>t.job==='scout');if(scout)scout.pos=14;}
      members.forEach((t,index)=>{
        const roleIndex=templates.findIndex(p=>p.job===t.job),old=side==='ally'?options.previous?.find(p=>p.id===t.id):null;
        const maxMp=old?.maxMp??t.mp+(side==='ally'?(options.bonusMp||0):0);
        units.push({...t,id:side==='ally'?t.id:'enemy-'+t.id,side,name:side==='ally'?t.name:'敵'+t.role+(options.enemy?' '+(index+1):''),pos:side==='ally'?t.pos:y(t.pos)*10+9-x(t.pos),hp:old?.hp??t.max,mp:old?.mp??maxMp,maxMp,skillStage:options.skillStage,next:100/t.agi,guard:false,cover:null,tie:roleIndex*4+(side===(roleIndex%2?'ally':'enemy')?0:1)+index*.01});
      });
    }
    const s={units,actor:null,result:null,potions:{ally:options.potions??3,enemy:options.enemyPotions??3},log:[options.ally?'荷物を守り、街道を切り抜けよう。':'4対4ミラーマッチ。スカウトだけが敵陣へ踏み込める。'],actions:0,recentEnemies:[]};if(options.ethers!==undefined)s.ethers=options.ethers;if(options.deployment){s.deploying=true;return s;}units.filter(u=>u.side==='enemy').forEach(u=>plan(s,u));advance(s);return s;
  }
  function deploy(s,id,pos){
    const a=alive(s).find(u=>u.id===id&&u.side==='ally');
    if(!s.deploying||!a||!Number.isInteger(pos)||pos<0||pos>=50||boardOf(pos)!=='ally')return false;
    const b=alive(s).find(u=>u.pos===pos&&u.id!==id);
    if(b&&b.side!=='ally')return false;
    if(b)b.pos=a.pos;a.pos=pos;return true;
  }
  function begin(s){
    if(!s.deploying)return false;
    const units=alive(s);
    if(new Set(units.map(u=>u.pos)).size!==units.length||units.some(u=>!Number.isInteger(u.pos)||u.pos<0||u.pos>=50||boardOf(u.pos)!==u.side))return false;
    s.deploying=false;units.filter(u=>u.side==='enemy').forEach(u=>plan(s,u));advance(s);return true;
  }
  function act(s,kind,target){if(!legal(s,kind,target))return false;const a=s.units.find(u=>u.id===s.actor);s.recentEnemies=[];const jump=kind==='skill'&&activeSkill(a)==='scout'?ambush(s,a,s.units.find(u=>u.id===target)):null;apply(s,a,kind,target,jump?.destination);a.next+=100/a.agi;s.actions++;advance(s);return true;}
  function queue(s){const copies=alive(s).map(u=>({...u})),result=[];for(let i=0;i<10&&copies.length;i++){copies.sort(order);result.push({id:copies[0].id,name:copies[0].name,side:copies[0].side});copies[0].next+=100/copies[0].agi;}return result;}
  return {stepEnemy,damagePreview,reachFilteredPower,attackPreview,activeSkills,selectSkill,equipmentSkills,hasEffect,moveReach,skillCost,skillTargets,crossCells,retreatCell,MAX_LOG_LINES,trimLog,roster,create,deploy,begin,act,legal,legalFor,formation,boosted,swapTarget,slots,queue,range,screen,cell,boardOf,activeSkill,skillName,attackReach,stampCells,inRange,paths,ambush,receive,plan};
})();
if(typeof module!=='undefined')module.exports=Battle;
