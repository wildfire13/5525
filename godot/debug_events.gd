extends RefCounted
## Only fixed enums and bounded numeric snapshots cross the diagnostics boundary.
const OPS=["campaign_start","campaign_save","campaign_load","select_skill","select_return_skill","preview","hover_preview","reset","journey_start","export"]
const CAMPAIGN=["select","accept","depart","travel","deploy","deployment_assign","chooseFormation","deployment_reset","begin","retreat","finishBattle","rest","onward","arrive","acknowledge","completeQuest","buyGear","buyItem","inn","useItem","inventoryAction","buyInventory","buyPlan","sellInventory","allocate","allocateBatch","trial","endTrial"]
const READ_ONLY=["forecast","previewGear","inventoryQuote","purchasePlan","saleQuote","purchaseQuote"]
const ACTIONS=["attack","move","skill","item","ether","guard","return"]
const FILES=["read","write","write_target","recover_write","portrait"]
const UI=["file_save","file_open","confirm","navigate","load_metadata"]
const SLOTS=["head","upperBody","lowerBody","rightHand","leftHand","feet","accessory1","accessory2",""]
const SKILLS=["guard","archer","mage","scout","porter","stamp","itemUse","legSweep","grapple","poleVault","retreatSlash","knockback","pincer","healingCross","defenseLine","manaGift","splitShot","returnHome","firstStride","loneWolf","victoryBreath","invasion","swift"]
var salt=""
var actors={}
func configure(session: String):salt=session;actors.clear()
func operation(payload: Dictionary) -> String:
 var op=payload.get("op")
 if not op is String:return "other"
 if op in ["view","record","presentation_next","presentation_finish","preview","hover_preview"]:return ""
 if op=="campaign":return "campaign."+str(payload.action) if payload.get("action") in CAMPAIGN else "other"
 if op=="act":return "act."+str(payload.kind) if payload.get("kind") in ACTIONS else "act.other"
 if op=="godot_io":return "godot_io."+str(payload.action) if payload.get("action") in FILES else "godot_io.other"
 return op if op in OPS else "other"
func quiet(payload: Dictionary) -> bool:
 return payload.get("op")=="campaign" and payload.get("action") in READ_ONLY
func actor_id(value) -> int:
 if not value is String or value.length()>256 or value.is_empty():return 0
 if not actors.has(value):
  if actors.size()>=256:return 0
  actors[value]=actors.size()+1
 return int(actors[value])
func grant(key,unit: Dictionary) -> Dictionary:
 if not key is String or key.length()>1024:return {}
 if key.begins_with("legacy:"):
  var id=key.trim_prefix("legacy:")
  if not id in SKILLS:return {}
  return {"slot":"","grant":1,"item_ref":(salt+":"+key).sha256_text(),"skill":id}
 var parsed=JSON.parse_string(key) if key.begins_with("[") else null
 if not parsed is Array or parsed.size()!=3:return {}
 if not parsed[0] in SLOTS or not parsed[1] is String or parsed[1].length()>256:return {}
 if not (parsed[2] is int or parsed[2] is float) or parsed[2]!=int(parsed[2]) or parsed[2]<1 or parsed[2]>3:return {}
 var skill=""
 var sources=unit.get("skillSources",[])
 if sources is Array:
  for source in sources.slice(0,64):
   if source is Dictionary and source.get("slot")==parsed[0] and source.get("itemId")==parsed[1] and source.get("grantSlot",1)==parsed[2] and source.get("id") in SKILLS:
    skill=source.id;break
 if skill.is_empty():return {}
 return {"slot":parsed[0],"grant":int(parsed[2]),"item_ref":(salt+":"+parsed[1]).sha256_text(),"skill":skill}
func snapshot(reply: Dictionary) -> Dictionary:
 var state=reply.get("state")
 if not state is Dictionary:return {}
 var result={"actor":actor_id(state.get("actor")),"order":[],"selected_grant":null,"selected_return_grant":null,"cooldowns":[],"returns":[]}
 var order=reply.get("queue",[])
 if order is Array:
  for entry in order.slice(0,16):
   if entry is Dictionary:result.order.append(actor_id(entry.get("id")))
 var units=state.get("units",[])
 if not units is Array:return result
 for unit in units.slice(0,32):
  if not unit is Dictionary:continue
  var actor=actor_id(unit.get("id"))
  if unit.get("id")==state.get("actor"):
   var selected_key=unit.get("selectedSkillKey")
   var active_options=reply.get("skillset",[])
   if active_options is Array:
    for option in active_options.slice(0,64):
     if option is Dictionary and option.get("selected",false)==true:selected_key=option.get("key");break
   var selected=grant(selected_key,unit)
   if not selected.is_empty():result.selected_grant=selected
   var return_key=unit.get("selectedReturnSkillKey")
   var return_options=reply.get("returnSkillset",[])
   if return_options is Array:
    for option in return_options.slice(0,16):
     if option is Dictionary and option.get("selected",false)==true:return_key=option.get("key");break
   var selected_return=grant(return_key,unit)
   if not selected_return.is_empty():result.selected_return_grant=selected_return
  var cooldowns=unit.get("skillCooldowns",{})
  if cooldowns is Dictionary:
   for key in cooldowns.keys().slice(0,64):
    if result.cooldowns.size()>=64:break
    var g=grant(key,unit);var value=cooldowns[key]
    if not g.is_empty() and (value is int or value is float) and value==int(value) and value>=0 and value<=2:
     g.actor=actor;g.remaining=int(value);result.cooldowns.append(g)
  var used=unit.get("returnUsedGrants",{})
  if used is Dictionary:
   for key in used.keys().slice(0,16):
    if result.returns.size()>=16:break
    var g=grant(key,unit)
    if not g.is_empty() and used[key] is bool:g.actor=actor;g.used=used[key];result.returns.append(g)
 return result
