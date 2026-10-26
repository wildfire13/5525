extends "res://tests/feedback2_guild_gui.gd"
func visible_member(id: String):
 var control=node("GuildMember_"+id);var scroll=node("GuildCurrentScroll" if game.campaign().selected.has(id) else "GuildReserveScroll")
 scroll.ensure_control_visible(control);await frames(16)
 return control.get_global_rect().intersection(scroll.get_global_rect()).get_center()
func run():
 create_timer(180).timeout.connect(func():print("FAIL guild drag GUI watchdog");quit(2))
 root.borderless=true;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080)
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.audio.fast_mode=true;game.checks_fast=true;await settle();var guild=game.pages.guild_view
 game.navigate("party");await settle();await os_click(node("FacilityChoice_guild"))
 for dims in [Vector2i(1920,1080),Vector2i(1180,812)]:
  root.size=dims;await settle();var before=game.campaign().selected.duplicate()
  var source=await visible_member("guard-2");var target=await visible_member("guard")
  await os_mouse(source,"drag",target)
  var expected=before.duplicate();expected[expected.find("guard")]="guard-2"
  check(game.campaign().selected==expected,"OS reserve to current card swaps "+str(dims))
  source=await visible_member("guard");var face=node("PartyFace_guard-2")
  await os_mouse(source,"drag",face.get_global_rect().get_center())
  check(game.campaign().selected==before,"OS reserve to lower party face swaps "+str(dims))
  var first=node("PartyFace_"+str(before[0]));var second=node("PartyFace_"+str(before[1]))
  await os_mouse(first.get_global_rect().get_center(),"drag",second.get_global_rect().get_center())
  expected=before.duplicate();expected[0]=before[1];expected[1]=before[0]
  check(game.campaign().selected==expected,"OS horizontal lower bar drag exchanges "+str(dims))
  await snapshot("guild-drag-"+str(dims.x))
  source=await visible_member("guard-2");var append=node("GuildPartyAppend");node("PartyFacesScroll").ensure_control_visible(append);await frames(16)
  await os_mouse(source,"drag",append.get_global_rect().get_center());expected.append("guard-2")
  check(game.campaign().selected==expected,"OS reserve to empty lower bar slot appends "+str(dims))
  guild.choose("guard-2");await settle();await os_click(node("GuildRemove"));guild.cancel_selection();await settle()
 check(game.audio.muted.values().all(func(v):return v),"guild GUI sound3 OFF")
 var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
