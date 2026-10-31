extends "res://tests/ui_feedback_20261016.gd"
func consent():
 for d in game.find_children("*","ConfirmationDialog",true,false):
  if d.visible:return d
 return null
func reload_inn(seed):
 await game.update({"op":"campaign_load","data":seed});await enter_facility("inn");await settle()
func run():
 create_timer(180).timeout.connect(func():print("FAIL inn watchdog");quit(2))
 if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
 var output=[]
 var code=OS.execute(OS.get_environment("NATIVE5525_NODE"),PackedStringArray([ProjectSettings.globalize_path("res://tests/inn_twelve_fixture.cjs")]),output,true,false)
 var twelve=JSON.parse_string("".join(output))
 check(code==0 and twelve is Dictionary and twelve.get("passed",false) and twelve.members==12,"twelve-member production canonical inn heals all once and survives reload")
 root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 await preload("res://tests/current_historical_fixture.gd").install(game)
 game.checks_fast=true;game.audio.fast_mode=true;await settle()
 var seed=await saved();seed.state.gold=500;seed.state.characters.guard.hp=1;seed.state.characters.archer.mp=0
 await reload_inn(seed);var inn=game.pages.inn_view;var before=await saved()
 inn.stay();await settle();check(consent()!=null,"injured party requests confirmation")
 consent().canceled.emit();await settle();check(await saved()==before,"cancel leaves exact save untouched")
 inn.stay();inn.stay();await settle();check(game.find_children("*","ConfirmationDialog",true,false).filter(func(d):return d.visible).size()==1,"repeat stay opens only one confirmation")
 var d=consent();d.confirmed.emit();d.confirmed.emit();await settle()
 var after=await saved();check(after.state.gold==470,"repeat confirmation charges once at canonical price")
 for id in game.campaign().selected:
  var u=game.roster().filter(func(m):return m.id==id)[0]
  check(int(u.hp)==int(u.max) and int(u.mp)==int(u.maxMp),"canonical recovery already complete "+str(id))
 check(node("InnRecoveryStatus").text.begins_with("宿泊完了") and not node("InnRecoveryStatus").text.contains("料金はかかりません"),"paid recovery message does not imply free lodging")
 check(inn.recovered.has("guard") and inn.recovered.has("archer") and not inn.recovered.has("mage"),"only previously deficient members participate in recovery")
 check(game.find_children("InnHeal_*","Control",true,false).size()==game.campaign().selected.size(),"real lodging starts healing graphics for every companion simultaneously")
 var starts=[]
 for effect in game.find_children("InnHeal_*","Control",true,false):starts.append(effect.started)
 check(starts.all(func(t):return t==inn.recovery_started),"all portrait healing graphics share one commit timestamp")
 check(inn.progress()<1.0 and node("InnHP_guard").get_meta("recovering",false),"committed HP count-up is independent of stats")
 check(not node("InnMP_guard").get_meta("recovering",false),"already full MP has no recovery animation")
 await create_timer(1.4).timeout;await frames();check(node("InnHP_guard").text=="HP 180/180","HP count-up ends exactly at canonical maximum")
 check(game.find_children("InnHeal_*","Control",true,false).is_empty(),"healing graphics clean up after count-up")
 before=await saved();inn.stay();await settle();check(await saved()==before and consent()==null,"full recovery click is free with no confirmation")
 check(node("InnRecoveryStatus").text.contains("料金はかかりません"),"full-health free action explicitly reports no fee")
 check(inn.dialogue==inn.FULL_GREETING and inn.recovered.is_empty() and inn.healing_party.is_empty() and inn.recovery_started==0,"full recovery uses dedicated dialogue without recovery effect")
 # Twelve real selected members, including the second-row boundary.
 var all_ids=[]
 for u in game.roster().slice(0,12):all_ids.append(u.id)
 await game.act("select",[all_ids]);await settle()
 for dims in [Vector2i(1920,1080)]:
  root.size=dims;game.render();await frames(12)
  var grid=node("InnParty");check(grid.columns>=1 and grid.columns<=6 and grid.get_child_count()==all_ids.size(),str(dims)+" responsive grid retains every real member")
  if dims.x==1920:check(grid.columns==6,"FHD retains six-column layout")
  check(absf(grid.get_child(0).position.y-grid.get_child(grid.columns-1).position.y)<1 and grid.get_child(grid.columns).position.y>grid.get_child(0).position.y,str(dims)+" first full row wraps to next row")
  check(node("InnPartyScroll").size.x<=node("InnPartyScroll").get_parent().size.x+1,str(dims)+" grid stays within scroll region")
  check(grid.get_child_count()==12 and grid.get_child(11).position.x+grid.get_child(11).size.x<=grid.size.x+1,str(dims)+" twelfth real member stays within horizontal grid bounds")
 var eleven=await saved()
 for uid in eleven.state.selected:eleven.state.characters[uid].hp=1;eleven.state.characters[uid].mp=0
 await reload_inn(eleven);inn.stay();await settle();consent().confirmed.emit();await settle()
 check(int(game.campaign().gold)==int(eleven.state.gold)-30 and inn.recovered.size()==12 and game.find_children("InnHeal_*","Control",true,false).size()==12,"twelve injured members heal in one canonical payment")
 for u in game.roster().filter(func(member):return all_ids.has(member.id)):check(int(u.hp)==int(u.max) and int(u.mp)==int(u.maxMp),"twelve-member simultaneous HP and MP recovery "+str(u.id))
 await reload_inn(seed);inn.stay();await settle();var token=game.campaign().inventoryToken;var epoch=game.pages.epoch;var connection=game.engine.connection_generation;var sequence=inn.sequence
 consent().canceled.emit();game.navigate("hub");await settle();before=await saved();await inn.commit(token,epoch,connection,sequence);check(await saved()==before,"stale confirmation after departure cannot charge")
 await reload_inn(seed);token=game.campaign().inventoryToken;epoch=game.pages.epoch;connection=game.engine.connection_generation;sequence=inn.sequence
 inn.commit(token,epoch,connection,sequence);game.navigate("hub");await settle();after=await saved();check(after.state.gold==470 and int(after.state.characters.guard.hp)==180,"departure during committed request retains exactly one charge and complete recovery")
 await game.update({"op":"campaign_load","data":after});await settle();check(await saved()==after and inn.recovered.is_empty(),"save reload retains healing and clears transient presentation")
 var poor=seed.duplicate(true);poor.state.gold=0;await reload_inn(poor);before=await saved();inn.stay();await settle();check(node("InnStay").disabled and consent()==null and await saved()==before,"insufficient funds has no transaction")
 check(game.audio.muted.values().all(func(v):return v),"audio BGM voice SE OFF")
 var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
