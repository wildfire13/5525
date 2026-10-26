'use strict';
// Synthetic validated boundaries, isolated from real play and personal saves.
const assert=require('node:assert/strict');
const {createHash}=require('node:crypto');
const {spawnSync}=require('node:child_process');
const C=require('../../native/campaign.js'), B=require('../../native/campaign-battle.js');
const {Presentation}=require('../../native/battle-presentation.cjs');
const clone=x=>JSON.parse(JSON.stringify(x));
const equipment={defenseLine:'battleline-shield',healingCross:'rest-staff',manaGift:'sharing-tome',poleVault:'longspear-wood',grapple:'grappling-rope',retreatSlash:'undertow-sword',knockback:'breaker-hammer',splitShot:'twin-bow',pincer:'partner-dagger'};
const specs=[];
function add(id,skill,variant='normal',actor='guard',kind='skill'){if(skill==='pincer')actor='scout';specs.push({id,skill,variant,actor,kind});}
for(const skill of ['guard','defenseLine','healingCross','manaGift','poleVault','grapple','retreatSlash','knockback','splitShot','pincer'])add(skill,skill);
add('archer','archer','normal','archer');add('scout','scout','normal','scout');add('porter','porter','normal','porter');
for(const [skill,variants] of Object.entries({guard:['self','repeat','mp0'],defenseLine:['one','duplicate','repeat'],healingCross:['full','edge'],manaGift:['cap','one','mp0','full'],grapple:['blocked','ally'],knockback:['blocked','kill','edge'],pincer:['alone'],splitShot:['cover','duplicate','single'],retreatSlash:['blocked','edge'],porter:['broken','repeat','mp0']}))for(const variant of variants)add(skill+'_'+variant,skill,variant,skill==='porter'?'porter':'guard');
for(const variant of ['normal','edge','used','occupied','enemy','same'])add('return_'+variant,'returnHome',variant,'guard','return');
for(const variant of ['normal','cap','full','empty','mp0'])add('item_'+variant,'itemUse',variant,'guard','item');
for(const variant of ['normal','cap','full','empty','wrongJob'])add('ether_'+variant,'itemUse',variant,variant==='wrongJob'?'guard':'porter','ether');
for(const variant of ['normal','adjacent'])add('loneWolf_'+variant,'loneWolf',variant,'guard','attack');
for(const variant of ['normal','used','short'])add('firstStride_'+variant,'firstStride',variant,'guard','move');
for(const variant of ['normal','cap','full','dead'])add('victoryBreath_'+variant,'victoryBreath',variant,'guard','attack');
function build(spec){
 const {skill,variant,actor:actorId,kind}=spec,s=C.create();
 if(equipment[skill])s.characters[actorId].weapon=equipment[skill];
 if(['poleVault','splitShot'].includes(skill))s.characters[actorId].leftHand='empty-leftHand';
 if(['returnHome','loneWolf','firstStride'].includes(skill))s.characters[actorId].accessory1={returnHome:'return-ring-1',loneWolf:'lone-ring-1',firstStride:'pioneer-gloves-1'}[skill];
 if(skill==='victoryBreath')s.characters.mage.accessory1='victory-earring-1';
 if(skill==='itemUse'){if(actorId!=='porter')s.characters[actorId].weapon='empty-rightHand';s.characters[actorId].inventory={potion:2,ether:2};}
 assert(C.depart(s,'east'));assert(C.travel(s,'short',()=>0));assert(C.begin(s),spec.id+" begin");
 const b=s.battle, find=id=>b.units.find(u=>u.id===id),a=find(actorId),enemies=b.units.filter(u=>u.side==='enemy'),e=enemies[0];
 const positions={guard:24,archer:14,mage:23,scout:34,porter:32};
 b.units.forEach(u=>{u.hp=u.max;u.mp=u.maxMp;u.next=10000;u.guard=false;u.cover=null;u.boost=false;if(u.side==='ally')u.pos=positions[u.id];});
 enemies.forEach((u,i)=>u.pos=[25,15,35][i]);if(skill==='pincer'){find('guard').pos=22;a.pos=24;}a.next=1;find(actorId==='archer'?'mage':'archer').next=2;b.actor=a.id;
 if(kind==='skill')assert(B.selectSkill(b,skill),spec.id+' equipped skill selection');
 let target=e.id;
 if(skill==='guard'){target='mage';if(variant==='self')target=a.id;if(variant==='repeat')a.cover=target;}
 if(skill==='defenseLine'){target=variant==='one'?['mage']:variant==='duplicate'?['mage','mage']:['archer','mage'];if(variant==='repeat')a.covers=[...target];}
 if(skill==='healingCross'){target=a.id;find('mage').hp-=45;find('archer').hp-=7;find('scout').hp-=30;if(variant==='full')b.units.filter(u=>u.side==='ally').forEach(u=>u.hp=u.max);if(variant==='edge'){a.pos=0;find('mage').pos=1;find('archer').pos=10;}}
 if(skill==='manaGift'){target='mage';find('mage').mp-=variant==='cap'?1:3;if(variant==='one')a.mp=1;if(variant==='full')find('mage').mp=find('mage').maxMp;}
 if(skill==='poleVault')target=22;
 if(skill==='grapple'){a.pos=22;find('mage').pos=13;target=variant==='ally'?'archer':e.id;if(variant==='ally')find('archer').pos=24;else e.pos=24;if(variant==='blocked')find('mage').pos=23;}
 if(skill==='retreatSlash'){find('mage').pos=12;if(variant==='blocked')find('mage').pos=23;if(variant==='edge'){a.pos=20;e.pos=21;}}
 if(skill==='knockback'){if(variant==='blocked')enemies[1].pos=26;if(variant==='kill')e.hp=1;if(variant==='edge'){a.pos=23;e.pos=24;find('mage').pos=13;enemies[1].pos=14;target=enemies[1].id;a.pos=4;find('archer').pos=12;}}
 if(skill==='splitShot'){target=variant==='duplicate'?[e.id,e.id]:variant==='single'?[e.id]:[enemies[1].id,enemies[2].id];if(variant==='cover'){e.cover=enemies[1].id;e.covers=[enemies[1].id,enemies[2].id];}}
 if(skill==='pincer'){if(variant==='alone'){find('archer').pos=12;find('mage').pos=13;}else {find('archer').pos=15;enemies[1].pos=16;}}
 if(skill==='archer'){a.pos=23;find('mage').pos=13;}
 if(skill==='scout'){a.pos=22;find('mage').pos=13;find('guard').pos=2;}
 if(skill==='porter'){target=a.id;find('guard').pos=23;find('archer').pos=12;find('mage').pos=32;find('porter').pos=22;if(variant==='broken')find('guard').pos=24;if(variant==='repeat')a.boost=true;}
 if(skill==='returnHome'){target=variant==='edge'?0:variant==='occupied'?14:variant==='enemy'?25:variant==='same'?a.pos:22;if(variant==='used')a.returnUsed=true;}
 if(kind==='item'||kind==='ether'){target=a.id;if(kind==='item')a.hp-=variant==='cap'?7:70;else a.mp-=variant==='cap'?1:4;if(variant==='full'){a.hp=a.max;a.mp=a.maxMp;}if(variant==='empty'){const item=kind==='item'?'potion':'ether';b.itemInventories[a.id][item]=0;if(item==='potion')b.potions.ally=Object.values(b.itemInventories).reduce((n,x)=>n+x.potion,0);else b.ethers=Object.values(b.itemInventories).reduce((n,x)=>n+x.ether,0);}}
 if(skill==='loneWolf'){find('mage').pos=12;find('archer').pos=13;find('scout').pos=3;if(variant==='adjacent')find('mage').pos=23;}
 if(skill==='firstStride'){target=variant==='swap'?24:variant==='short'?22:variant==='used'?21:20;a.pos=23;find('mage').pos=12;if(variant==='used')a.firstMoveUsed=true;}
 if(skill==='victoryBreath'){enemies.slice(1).forEach(u=>u.hp=0);e.hp=1;const m=find('mage');m.mp=variant==='full'?m.maxMp:variant==='cap'?m.maxMp-1:m.maxMp-3;if(variant==='dead')m.hp=0;}
 if(variant==='mp0')a.mp=0;
 for(const enemy of enemies)if(enemy.hp>0)B.plan(b,enemy);
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
 const geometry={ranges:{skill:Array.from({length:50},(_,p)=>p).filter(p=>{const u=initial.units.find(u=>u.hp>0&&u.pos===p);return B.inRange(actor,u?.side||'enemy',p,'skill',initial);})},choices:{skill:choices},stampAreas:{},sweepCells:[]};
 const rejected=/^(guard_(self|mp0)|defenseLine_duplicate|healingCross_full|manaGift_(mp0|full)|splitShot_(duplicate|single)|retreatSlash_(blocked|edge)|porter_(broken|mp0)|return_(used|occupied|enemy|same)|item_(full|empty)|ether_(full|empty|wrongJob))$/.test(spec.id);
 assert.equal(accepted,!rejected,spec.id+' intended legal boundary');
 if(spec.id==='grapple_blocked')assert.equal(impacts.length,0);
 if(['knockback_blocked','knockback_kill','knockback_edge'].includes(spec.id))assert.equal(impacts.filter(x=>x.phase==='move').length,0);
 if(spec.id==='splitShot_cover')assert.deepEqual(impacts.map(x=>x.unit_id),[initial.units.find(x=>x.side==='enemy').id,initial.units.find(x=>x.side==='enemy').id]);
 if(spec.id==='loneWolf_adjacent'||spec.id==='firstStride_used'||spec.id==='victoryBreath_dead')assert(!events.some(e=>e.skillId===spec.skill));
 if(spec.id==='victoryBreath_full')assert.equal(events.find(e=>e.skillId==='victoryBreath').amount,0);
 const expected={accepted,actor_id:actor.id,kind:request.kind,skill_id:request.kind==='skill'?spec.skill:request.kind==='return'?'returnHome':request.kind==='item'||request.kind==='ether'?'itemUse':null,target:request.target,impacts,events,random_calls:oc,final_save_sha256:createHash('sha256').update(C.serialize(observed)).digest('hex')};
 const campaign=C.deserialize(JSON.stringify(save));assert.equal(C.act(campaign,request.kind,request.target),accepted,spec.id+' campaign legality');assert(C.validate(campaign).ok);
 return {save,request,geometry,frames,expected,campaign_final_battle:clone(campaign.battle)};
}
const cases=Object.fromEntries(specs.map(spec=>[spec.id,observe(spec)]));
const meta={synthetic:true,validated:true,count:specs.length,note:'Canonical equipment and C.validate/B.legal/B.act boundaries. Not preceding-turn play evidence. Fixed random callback belongs only to this QA process; no production override.'};
function verifyBridge(){return Object.entries(cases).map(([name,c])=>{const requests=[{op:'campaign_load',data:c.save},{op:'preview',kind:c.request.kind,target:c.request.target},{op:'campaign_save'}];const r=spawnSync(process.execPath,[require.resolve('../../native/bridge.cjs')],{input:requests.map(JSON.stringify).join('\n')+'\n',encoding:'utf8',timeout:15000});assert.equal(r.status,0,name);const [loaded,preview,saved]=r.stdout.trim().split(/\r?\n/).map(JSON.parse);assert(loaded.ok,name+' bridge load');assert.equal(preview.ok,c.expected.accepted,name+' preview legality');assert.equal(preview.presentation,undefined);assert.deepEqual(saved.data,c.save,name+' preview save parity');return {name,passed:true,accepted:c.expected.accepted};});}
// ASCII escapes prevent OS.execute chunk boundaries splitting multibyte UTF-8.
if(require.main===module)console.log(JSON.stringify(process.argv.includes('--verify')?{meta,checks:verifyBridge()}:{cases,meta}).replace(/[^\x00-\x7f]/g,c=>'\\u'+c.charCodeAt(0).toString(16).padStart(4,'0')));
module.exports={cases,meta,verifyBridge,observe};
