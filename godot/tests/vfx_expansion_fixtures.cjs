'use strict';
// Synthetic validated boundaries, isolated from real play and personal saves.
const assert=require('node:assert/strict');
const {createHash}=require('node:crypto');
const {spawnSync}=require('node:child_process');
const C=require('../../native/campaign.js'), B=require('../../native/campaign-battle.js');
const {Presentation}=require('../../native/battle-presentation.cjs');
const clone=x=>JSON.parse(JSON.stringify(x));
const ids={guard:'character_mirei',archer:'character_shion',mage:'character_merina',scout:'character_rio',porter:'character_yuno'};
const equipment={skill_defense_line:'battleline-shield',skill_healing_cross:'rest-staff',skill_mana_gift:'sharing-tome',skill_pole_vault:'longspear-wood',skill_grapple:'grappling-rope',skill_retreat_slash:'undertow-sword',skill_knockback:'breaker-hammer',skill_split_shot:'twin-bow',skill_pincer:'partner-dagger'};
const caseSkills={guard:'skill_cover',defenseLine:'skill_defense_line',healingCross:'skill_healing_cross',manaGift:'skill_mana_gift',poleVault:'skill_pole_vault',grapple:'skill_grapple',retreatSlash:'skill_retreat_slash',knockback:'skill_knockback',splitShot:'skill_split_shot',pincer:'skill_pincer',porter:'skill_formation_boost'};
const specs=[];
function add(id,skill,variant='normal',actor='guard',kind='action_skill'){if(skill==='skill_pincer')actor='scout';specs.push({id,skill,variant,actor,kind});}
for(const id of ['guard','defenseLine','healingCross','manaGift','poleVault','grapple','retreatSlash','knockback','splitShot','pincer'])add(id,caseSkills[id]);
add('archer','skill_snipe','normal','archer');add('scout','skill_ambush','normal','scout');add('porter','skill_formation_boost','normal','porter');
for(const [id,variants] of Object.entries({guard:['self','repeat','mp0'],defenseLine:['one','duplicate','repeat'],healingCross:['full','edge'],manaGift:['cap','one','mp0','full'],grapple:['blocked','ally'],knockback:['blocked','kill','edge'],pincer:['alone'],splitShot:['cover','duplicate','single'],retreatSlash:['blocked','edge'],porter:['broken','repeat','mp0']}))for(const variant of variants)add(id+'_'+variant,caseSkills[id],variant,id==='porter'?'porter':'guard');
for(const variant of ['normal','edge','used','occupied','enemy','same'])add('return_'+variant,'skill_return_home',variant,'guard','action_return');
for(const variant of ['normal','cap','full','empty','mp0'])add('item_'+variant,'skill_item_use',variant,'guard','action_item');
for(const variant of ['normal','cap','full','empty','wrongJob'])add('ether_'+variant,'skill_item_use',variant,variant==='wrongJob'?'guard':'porter','action_ether');
for(const variant of ['normal','adjacent'])add('loneWolf_'+variant,'skill_lone_wolf',variant,'guard','action_attack');
for(const variant of ['normal','used','short'])add('firstStride_'+variant,'skill_first_stride',variant,'guard','action_move');
for(const variant of ['normal','cap','full','dead'])add('victoryBreath_'+variant,'skill_victory_breath',variant,'guard','action_attack');
function build(spec){
 const {skill,variant,actor:role,kind}=spec,s=C.create(),actorId=ids[role];
 s.selected=Object.values(ids);
 s.characters[ids.archer].weapon='bow-wood';
 s.characters[ids.archer].leftHand='empty-leftHand';
 s.characters[ids.scout].weapon='dagger-wood';
 if(equipment[skill])s.characters[actorId].weapon=equipment[skill];
 if(['skill_pole_vault','skill_split_shot'].includes(skill))s.characters[actorId].leftHand='empty-leftHand';
 if(['skill_return_home','skill_lone_wolf','skill_first_stride'].includes(skill))s.characters[actorId].accessory1={skill_return_home:'return-ring-1',skill_lone_wolf:'lone-ring-1',skill_first_stride:'pioneer-gloves-1'}[skill];
 if(skill==='skill_victory_breath')s.characters[ids.mage].accessory1='victory-earring-1';
 if(skill==='skill_item_use'){if(role!=='porter')s.characters[actorId].weapon='empty-rightHand';s.characters[actorId].accessory2='pouch-belt-3';s.characters[actorId].inventory={potion:2,ether:2};}
 assert(C.depart(s,'east'));assert(C.travel(s,'short',()=>0));assert(C.begin(s),spec.id+" begin");
 const b=s.battle, find=id=>b.units.find(u=>u.id===(ids[id]||id)),a=find(actorId),enemies=b.units.filter(u=>u.side==='enemy'),e=enemies[0];
 assert.deepEqual(b.units.filter(u=>u.side==='ally').map(u=>u.id),s.selected,spec.id+' current recruits only');
 assert.deepEqual(enemies.map(u=>u.id),['enemy-guard-2','enemy-archer','enemy-archer-2'],spec.id+' current enemies retained');
 const positions=Object.fromEntries(Object.entries({guard:24,archer:14,mage:23,scout:34,porter:32}).map(([role,pos])=>[ids[role],pos]));
 b.units.forEach(u=>{u.hp=u.max;u.mp=u.maxMp;u.next=10000;u.guard=false;u.cover=null;u.boost=false;if(u.side==='ally')u.pos=positions[u.id];});
 if(spec.id==='victoryBreath_dead')B.receive(b,find('mage'),10000,false);
 enemies.forEach((u,i)=>u.pos=[25,15,35][i]);if(skill==='skill_pincer'){find('guard').pos=22;a.pos=24;}a.next=1;find(role==='archer'?'mage':'archer').next=2;b.actor=a.id;
 if(kind==='action_skill')assert(B.selectSkill(b,skill),spec.id+' equipped skill selection');
 let target=e.id;
 if(skill==='skill_cover'){target=ids.mage;if(variant==='self')target=a.id;if(variant==='repeat')a.cover=target;}
 if(skill==='skill_defense_line'){target=variant==='one'?[ids.mage]:variant==='duplicate'?[ids.mage,ids.mage]:[ids.archer,ids.mage];if(variant==='repeat')a.covers=[...target];}
 if(skill==='skill_healing_cross'){target=a.id;find('mage').hp-=45;find('archer').hp-=7;find('scout').hp-=30;if(variant==='full')b.units.filter(u=>u.side==='ally').forEach(u=>u.hp=u.max);if(variant==='edge'){a.pos=0;find('mage').pos=1;find('archer').pos=10;}}
 if(skill==='skill_mana_gift'){target='mage';find('mage').mp-=variant==='cap'?1:3;if(variant==='one')a.mp=1;if(variant==='full')find('mage').mp=find('mage').maxMp;}
 if(skill==='skill_pole_vault')target=22;
 if(skill==='skill_grapple'){a.pos=22;find('mage').pos=13;target=variant==='ally'?'archer':e.id;if(variant==='ally')find('archer').pos=24;else e.pos=24;if(variant==='blocked')find('mage').pos=23;}
 if(skill==='skill_retreat_slash'){find('mage').pos=12;if(variant==='blocked')find('mage').pos=23;if(variant==='edge'){a.pos=20;e.pos=21;}}
 if(skill==='skill_knockback'){if(variant==='blocked')enemies[1].pos=26;if(variant==='kill')e.hp=1;if(variant==='edge'){a.pos=23;e.pos=24;find('mage').pos=13;enemies[1].pos=14;target=enemies[1].id;a.pos=4;find('archer').pos=12;}}
 if(skill==='skill_split_shot'){target=variant==='duplicate'?[e.id,e.id]:variant==='single'?[e.id]:[enemies[1].id,enemies[2].id];if(variant==='cover'){e.cover=enemies[1].id;e.covers=[enemies[1].id,enemies[2].id];}}
 if(skill==='skill_pincer'){if(variant==='alone'){find('archer').pos=12;find('mage').pos=13;}else {find('archer').pos=15;enemies[1].pos=16;}}
 if(skill==='skill_snipe'){a.pos=23;find('mage').pos=13;}
 if(skill==='skill_ambush'){a.pos=22;find('mage').pos=13;find('guard').pos=2;}
 if(skill==='skill_formation_boost'){target=a.id;find('guard').pos=24;find('archer').pos=13;find('mage').pos=33;find('porter').pos=22;if(variant==='broken')find('guard').pos=23;if(variant==='repeat')a.boost=true;}
 if(skill==='skill_return_home'){target=variant==='edge'?0:variant==='occupied'?14:variant==='enemy'?25:variant==='same'?a.pos:22;if(variant==='used'){a.returnUsed=true;a.returnUsedGrants=Object.fromEntries(B.returnSkillOptions(a).map(option=>[option.key,true]));}}
 if(kind==='action_item'||kind==='action_ether'){target=a.id;if(kind==='action_item')a.hp-=variant==='cap'?7:70;else a.mp-=variant==='cap'?1:4;if(variant==='full'){a.hp=a.max;a.mp=a.maxMp;}if(variant==='empty'){const item=kind==='action_item'?'potion':'ether';b.itemInventories[a.id][item]=0;if(item==='potion')b.potions.ally=Object.values(b.itemInventories).reduce((n,x)=>n+x.potion,0);else b.ethers=Object.values(b.itemInventories).reduce((n,x)=>n+x.ether,0);}}
 if(skill==='skill_lone_wolf'){find('mage').pos=12;find('archer').pos=13;find('scout').pos=3;if(variant==='adjacent')find('mage').pos=23;}
 if(skill==='skill_first_stride'){target=variant==='swap'?24:variant==='short'?22:variant==='used'?21:20;a.pos=23;find('mage').pos=12;if(variant==='used')a.firstMoveUsed=true;}
 if(skill==='skill_victory_breath'){enemies.slice(1).forEach(u=>u.hp=0);e.hp=1;const m=find('mage');m.mp=variant==='full'?m.maxMp:variant==='cap'?m.maxMp-1:m.maxMp-3;}
 if(variant==='mp0')a.mp=0;
 if(typeof target==='string')target=ids[target]||target;
 if(Array.isArray(target))target=target.map(id=>ids[id]||id);
 // The engine selects enemy actions from current positions at execution time.
 assert(C.validate(s).ok,spec.id+': '+C.validate(s).error);
 return {state:s,request:{op:'act',kind,target,presentation:true}};
}
function observe(spec){
 const {state,request}=build(spec),save=JSON.parse(C.serialize(state)),initial=clone(state.battle);
 const direct=C.deserialize(JSON.stringify(save)),observed=C.deserialize(JSON.stringify(save));
 assert.deepEqual(JSON.parse(C.serialize(direct)),save,spec.id+' roundtrip');
 const legal=B.legal(direct.battle,request.kind,request.target);let dc=0,oc=0;
 const accepted=B.act(direct.battle,request.kind,request.target,()=>{dc++;return .99;});assert.equal(legal,accepted);
 const p=new Presentation();assert.equal(p.start(observed.battle,B,()=>B.act(observed.battle,request.kind,request.target,()=>{oc++;return .99;})),accepted);
 const frames=[];while(p.pending){const presentation=clone(p.info());frames.push({presentation,state:clone(p.pending.state)});assert(p.next(presentation.id,presentation.index));}
 assert.deepEqual(JSON.parse(C.serialize(observed)),JSON.parse(C.serialize(direct)),spec.id+' exact save parity');assert.equal(C.serialize(observed),C.serialize(direct),spec.id+' exact serialized bytes');assert.equal(dc,oc,spec.id+' RNG parity');assert(C.validate(observed).ok,spec.id+' final validation');assert.deepEqual(clone(state.battle),initial);
 if(!accepted){assert.equal(frames.length,0);assert.deepEqual(JSON.parse(C.serialize(observed)),save);}
 const impacts=frames.filter(f=>['hurt','heal','move'].includes(f.presentation.phase)).map(f=>({...clone(f.presentation),delta:f.presentation.to-f.presentation.from}));
 const events=(observed.battle.skillEvents||[]).filter(e=>e.sequence>(initial.skillEventSequence||0));
 const actor=initial.units.find(u=>u.id===initial.actor);
 const choices=B.skillTargets(initial,actor);
 const geometry={ranges:{action_skill:Array.from({length:50},(_,p)=>p).filter(p=>{const u=initial.units.find(u=>u.hp>0&&u.pos===p);return B.inRange(actor,u?.side||'enemy',p,'action_skill',initial);})},choices:{action_skill:choices},stampAreas:{},sweepCells:[]};
 const rejected=/^(guard_(self|mp0)|defenseLine_duplicate|healingCross_full|manaGift_(mp0|full)|splitShot_(duplicate|single)|retreatSlash_(blocked|edge)|porter_(broken|mp0)|return_(used|occupied|enemy|same)|item_(full|empty)|ether_(full|empty|wrongJob))$/.test(spec.id);
 assert.equal(accepted,!rejected,spec.id+' intended legal boundary');
 if(spec.id==='grapple_blocked')assert.equal(impacts.length,0);
 if(['knockback_blocked','knockback_kill','knockback_edge'].includes(spec.id))assert.equal(impacts.filter(x=>x.phase==='move').length,0);
 if(spec.id==='splitShot_cover')assert.deepEqual(impacts.map(x=>x.unit_id),[initial.units.find(x=>x.side==='enemy').id,initial.units.find(x=>x.side==='enemy').id]);
 if(spec.id==='loneWolf_adjacent'||spec.id==='firstStride_used'||spec.id==='victoryBreath_dead')assert(!events.some(e=>e.skillId===spec.skill));
 if(spec.id==='victoryBreath_full')assert.equal(events.find(e=>e.skillId==='skill_victory_breath').amount,0);
 const expected={accepted,actor_id:actor.id,kind:request.kind,skill_id:request.kind==='action_skill'?spec.skill:request.kind==='action_return'?'skill_return_home':request.kind==='action_item'||request.kind==='action_ether'?'skill_item_use':null,target:request.target,impacts,events,random_calls:oc,final_save_sha256:createHash('sha256').update(C.serialize(observed)).digest('hex')};
 const campaign=C.deserialize(JSON.stringify(save));assert.equal(C.act(campaign,request.kind,request.target),accepted,spec.id+' campaign legality');assert(C.validate(campaign).ok);
 return {save,request,geometry,frames,expected,campaign_final_battle:clone(campaign.battle)};
}
const cases=Object.fromEntries(specs.map(spec=>[spec.id,observe(spec)]));
const meta={synthetic:true,validated:true,count:specs.length,note:'Canonical equipment and C.validate/B.legal/B.act boundaries. Not preceding-turn play evidence. Fixed random callback belongs only to this QA process; no production override.'};
function verifyBridge(){return Object.entries(cases).map(([name,c])=>{const requests=[{op:'campaign_load',data:c.save},{op:'preview',kind:c.request.kind,target:c.request.target},{op:'campaign_save'}];const r=spawnSync(process.execPath,[require.resolve('../../native/bridge.cjs')],{input:requests.map(JSON.stringify).join('\n')+'\n',encoding:'utf8',timeout:15000});assert.equal(r.status,0,name);const [loaded,preview,saved]=r.stdout.trim().split(/\r?\n/).map(JSON.parse);assert(loaded.ok,name+' bridge load');assert.equal(preview.ok,c.expected.accepted,name+' preview legality');assert.equal(preview.presentation,undefined);assert.deepEqual(saved.data,c.save,name+' preview save parity');return {name,passed:true,accepted:c.expected.accepted};});}
// ASCII escapes prevent OS.execute chunk boundaries splitting multibyte UTF-8.
if(require.main===module)console.log(JSON.stringify(process.argv.includes('--verify')?{meta,checks:verifyBridge()}:{cases,meta}).replace(/[^\x00-\x7f]/g,c=>'\\u'+c.charCodeAt(0).toString(16).padStart(4,'0')));
module.exports={cases,meta,verifyBridge,observe};
