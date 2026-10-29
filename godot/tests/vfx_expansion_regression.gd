extends "res://tests/skill_effect_regression.gd"
## Independent canonical rule results replayed through the real battle board.
## Synthetic boundaries are explicitly separate from OS play evidence.
func run():
 create_timer(240).timeout.connect(func():print("FAIL expansion regression watchdog");quit(2))
 if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
 var output=[]
 var code=OS.execute(OS.get_environment("NATIVE5525_NODE"),[ProjectSettings.globalize_path("res://tests/vfx_expansion_fixtures.cjs")],output,true,false)
 check(code==0,"64 canonical expansion boundaries pass direct/save/RNG parity")
 var generated=JSON.parse_string("".join(output))
 if not generated is Dictionary:quit(2);return
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 await preload("res://tests/current_historical_fixture.gd").install(game)
 game.checks_fast=true;game.audio.fast_mode=true
 while game.locked or game.engine.busy or game.presenting or game.loading_screen.active:await process_frame
 board=load("res://battle_board.gd").new();board.portraits=game.portraits;board.size=Vector2(1180,812);root.add_child(board)
 for i in range(5):await process_frame
 var saved=(await game.engine.request({"op":"campaign_save"})).data
 var fx=board.skill_effects
 var asset_count=0
 for manifest_name in ["physical","support"]:
  var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx_expansion/"+manifest_name+"_manifest.json"))
  for entry in manifest.get("assets",manifest.get("images",[])):
   var key=str(entry.get("key",entry.get("name","")));var path="res://assets/vfx_expansion/"+str(entry.get("file",key+".png"))
   var image=Image.new();var loaded_image=image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
   check(loaded_image==OK and fx.textures.has(key),"new dedicated art loaded "+key)
   check(FileAccess.get_sha256(path)==entry.sha256,"adopted art immutable "+key)
   check(image.get_format()==Image.FORMAT_RGBA8 and image.get_size()==Vector2i(entry.size[0],entry.size[1]),"RGBA dimensions "+key)
   check(image.get_pixel(0,0).a==0 and image.get_pixel(image.get_width()-1,image.get_height()-1).a==0,"transparent texture border "+key)
   asset_count+=1
 check(asset_count==19 and fx.textures.size()==38,"19 new layers plus 19 original layers")
 for name_ in generated.cases:
  var c=generated.cases[name_]
  var loaded=await game.update({"op":"campaign_load","data":c.save})
  if not loaded.get("ok",false):print("LOAD_FAILURE ",name_," / ",loaded.get("error","unknown")," / ",game.notice)
  check(loaded.get("ok",false),name_+" bridge accepts canonical save")
  var native_before=(await game.engine.request({"op":"campaign_save"})).data
  board.reset_animation();board.effect_action.clear();board.last_animated_phase=""
  var observed=[]
  seed(552564);var first=randi();var expected_next=randi();seed(552564);check(randi()==first,name_+" presentation RNG starts at controlled boundary")
  for index in range(c.frames.size()):
   var frame=c.frames[index];var p=frame.presentation
   load_frame(c,frame,index);var before=board.data.duplicate(true)
   board.animate(p);fx.set_process(false)
   var snap=fx.snapshot();var e=snap.event
   if not e.is_empty():
    check(snap.emitter_count>0,name_+" committed visual contains actual graphics "+str(index))
    observed.append(e.duplicate(true))
    if p.phase in ["hurt","heal","resource"]:
     check(int(e.get("amount",0))==int(p.to)-int(p.from),name_+" exact committed amount "+str(index))
     check(int(e.get("recipient",-1))==int(unit(frame.state,p.unit_id).pos),name_+" exact actual recipient cell "+str(index))
    if name_=="scout" and p.phase=="hurt":check(int(e.get("origin",-1))==int(unit(frame.state,p.actor_id).pos),name_+" contact originates at actual post-ambush landing")
    if name_=="healingCross" and p.phase=="action":
     check(e.get("cells",[]).all(func(cell):return frame.state.units.any(func(u):return u.side=="ally" and u.pos==cell and u.hp<u.max)),name_+" cast artwork targets actual healing allies, not enemy or full center")
    if name_=="healingCross" and p.phase=="heal":check(p.unit_id!="guard",name_+" full HP center never gets recovery result")
    if name_=="splitShot_cover" and p.phase=="hurt":check(e.get("recipient_id")==p.unit_id,name_+" redirected actual hit preserves protector")
    if name_=="manaGift_cap" and p.phase=="resource":check(int(e.get("amount",0))==1,name_+" capped transfer shows one MP")
    var elapsed=fx.snapshot();check(board.animate(p)==0 and fx.snapshot()==elapsed,name_+" duplicate packet does not replay "+str(index))
   fx._process(.14)
   check(board.data==before,name_+" rendered phase leaves packet unchanged "+str(index))
   fx._process(3)
   check(not fx.snapshot().active,name_+" effect expires "+str(index))
  if not c.expected.accepted:check(observed.is_empty(),name_+" rejected action never creates success effect")
  if name_ in ["grapple_blocked","knockback_blocked","knockback_kill","knockback_edge"]:check(not observed.any(func(e):return e.get("phase")=="move"),name_+" no fabricated movement")
  if name_=="victoryBreath_full":check(not observed.any(func(e):return e.get("skill_id")=="victoryBreath" and e.get("phase")=="resource"),name_+" amount zero never shows MP recovery")
  if c.expected.accepted and name_!="firstStride_used":check(not observed.is_empty(),name_+" accepted expanded skill has visible event")
  check(randi()==expected_next,name_+" rendering consumes no global Godot RNG")
  fx.clear();await process_frame;await process_frame
  check(fx.emitters.is_empty() and fx.captions.is_empty() and fx.reactions.is_empty() and fx.stage.get_child_count()==0,name_+" cleanup removes every transient node")
  check((await game.engine.request({"op":"campaign_save"})).data==native_before,name_+" render leaves exact native save unchanged")
  observations.append({"case":name_,"events":observed})
 # Preview, cancellation, stale packets and load clear lifecycle.
 var c=generated.cases.knockback;var action=c.frames[0]
 load_frame(c,action,0);board.animate(action.presentation)
 var d=board.data.duplicate(true);d.erase("presentation")
 board.update_state(d,{"damage":999},"skill","",[])
 check(not fx.snapshot().active and board.effect_action.is_empty(),"preview/cancel/reload clears residual effect")
 check(board.effect_event(action.presentation).is_empty(),"packet absent from accepted presentation cannot activate")
 load_frame(c,action,0);var stale=action.presentation.duplicate(true);stale.id=int(stale.id)+100
 check(board.effect_event(stale).is_empty(),"stale presentation id cannot activate")
 check(game.audio.muted.values().all(func(value):return value),"all QA audio OFF")
 await game.update({"op":"campaign_load","data":saved})
 var file=FileAccess.open(evidence.path_join("vfx-expansion-checks.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"observations":observations},"\t"));file.close()
 board.queue_free();game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
 for i in range(4):await process_frame
 print("VFX expansion "+str(checks.filter(func(row):return row.passed).size())+"/"+str(checks.size()));quit(0 if checks.all(func(row):return row.passed) else 1)
