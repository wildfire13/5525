extends "res://tests/brushup_gui.gd"
func run():
 create_timer(450).timeout.connect(func():print("FAIL NPC GUI watchdog");quit(2))
 check(DisplayServer.get_name()!="headless","NPC actual rendered X11 display")
 var width=int(OS.get_environment("BRUSHUP_GUI_WIDTH"));width=1920 if width==0 else width
 root.borderless=true;root.position=Vector2i.ZERO;root.size=Vector2i(width,812 if width==1180 else 1080)
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true;await settle()
 var original=await saved();var art=game.pages.facility_art;var keepers={}
 for spec in [["east","shop","weapon"],["west","shop","armor"],["south","shop","item"],["north","shop","accessory"],["astaris","party","guild"],["astaris","inn","inn"]]:
  var seed=original.duplicate(true);seed.state.location=spec[0];seed.state.gold=500;seed.state.characters.guard.hp=140
  await game.update({"op":"campaign_load","data":seed});game.navigate(spec[1]);await settle()
  var before=await saved();var path=art.npc.selected_path;var rng=art.npc.rng.state
  check(node("FacilityNpc")!=null,"NPC present on rendered facility "+spec[2])
  await snapshot(spec[2]+"-"+str(width))
  var stage=node("FacilityNpcStage");await os_mouse(stage.get_global_rect().get_center(),"click")
  check((await saved())==before and art.npc.selected_path==path,"OS click in NPC decoration does not change game "+spec[2])
  if spec[1]=="shop" and spec[0]!="south":
   var item=game.pages.shop_view.offered()[0]
   await os_click(node("ProductBuy_"+str(item.id)));await os_click(node("PurchaseDecline"))
   check((await saved())==before and art.npc.selected_path==path and art.npc.rng.state==rng,"OS purchase cancel retains keeper "+spec[2])
   await os_click(node("PartyFace_guard"));await os_click(node("PartyFace_archer"));await os_key("Escape")
   check(not game.modal_open() and art.npc.selected_path==path and art.npc.rng.state==rng,"OS character switching retains keeper "+spec[2])
  elif spec[1]=="inn":
   await os_click(node("InnStay"))
   var dialog=game.find_children("*","ConfirmationDialog",true,false).filter(func(n):return n.visible)[0]
   await os_click(dialog.get_cancel_button());check((await saved())==before and art.npc.selected_path==path,"OS inn cancellation preserves state and keeper")
   await os_click(node("InnStay"));dialog=game.find_children("*","ConfirmationDialog",true,false).filter(func(n):return n.visible)[0]
   await os_click(dialog.get_ok_button())
   check(int(game.campaign().gold)==470 and int(game.campaign().characters.guard.hp)==180 and art.npc.selected_path==path and art.npc.rng.state==rng,"OS inn confirmation remains accessible and keeps keeper")
  elif spec[1]=="party":
   await os_click(node("GuildMember_guard"));await os_click(node("GuildDetails"));await os_key("Escape")
   check(game.pages.guild_view.chosen_id=="guard" and art.npc.selected_path==path and art.npc.rng.state==rng,"OS guild details return without changing keeper")
  else:
   await os_click(node("PartyFace_guard"));await os_click(node("PartyFace_archer"));await os_key("Escape")
   check(not game.modal_open() and art.npc.selected_path==path,"OS item shop character switching retains keeper")
  game.navigate("hub");await settle();check(node("FacilityNpc")==null,"NPC leaves with facility "+spec[2])
  game.navigate(spec[1]);await settle()
  check(art.npc.selected_path.get_file() in art.npc.CATALOG[spec[2]],"NPC reentry uses assigned facility "+spec[2])
 # Deterministic entry seeds for both actual weapon PNGs; no image substitutions.
 var east=original.duplicate(true);east.state.location="east";east.state.gold=500
 await game.update({"op":"campaign_load","data":east});game.navigate("hub");await settle()
 for seed in range(16):
  art.npc.rng.seed=seed;game.navigate("shop");await settle()
  var path=art.npc.selected_path
  if not keepers.has(path):keepers[path]=true;await snapshot(path.get_file().get_basename()+"-"+str(width))
  var state=art.npc.rng.state;root.size=Vector2i(1180,812) if width==1920 else Vector2i(1920,1080);await settle()
  check(art.npc.selected_path==path and art.npc.rng.state==state,"actual resize retains selected weapon keeper")
  root.size=Vector2i(width,812 if width==1180 else 1080);await settle();game.navigate("hub");await settle()
  if keepers.size()==2:break
 check(keepers.size()==2,"both weapon keepers rendered via entry RNG")
 check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"NPC OS checks kept BGM voice SE OFF")
 var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
