extends "res://tests/facility_gui_261022.gd"
func os_member(id: String):
 var button=node("GuildMember_"+id)
 var scroll=node("GuildCurrentScroll" if game.campaign().selected.has(id) else "GuildReserveScroll")
 scroll.ensure_control_visible(button);await frames(16)
 await os_mouse(button.get_global_rect().intersection(scroll.get_global_rect()).get_center(),"click")
func run():
 create_timer(180).timeout.connect(func():print("FAIL guild GUI watchdog");quit(2))
 root.borderless=true;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080)
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.audio.fast_mode=true;game.checks_fast=true;await settle();var guild=game.pages.guild_view
 game.navigate("party");await settle();await os_click(node("FacilityChoice_guild"))
 await os_member("guard-2");check(guild.chosen_id=="guard-2","OS reserve selects named identity")
 await os_click(node("GuildAdd"));check(game.campaign().selected.has("guard-2"),"OS central add joins named member above five")
 await os_member("guard-2");await os_click(node("GuildDetails"));check(game.pages.party_view.detail_uid=="guard-2","OS central details targets chosen character")
 game.dialog.close(false);await settle();check(guild.chosen_id=="guard-2","details close keeps chosen character")
 await os_click(node("GuildRemove"));check(not game.campaign().selected.has("guard-2"),"OS central remove affects only chosen member")
 for dims in [Vector2i(1920,1080),Vector2i(1180,812),Vector2i(960,540)]:
  root.size=dims;await settle();node("GuildReserveScroll").scroll_vertical=0;node("GuildCurrentScroll").scroll_vertical=0;await frames(16);await snapshot("guild-"+str(dims.x))
  await os_member("guard");check(guild.chosen_id=="guard","OS member and operations reachable "+str(dims))
  guild.cancel_selection();await settle()
  var scroll=node("GuildReserveScroll");var before=scroll.scroll_vertical
  await os_mouse(scroll.get_global_rect().get_center(),"wheel_down");check(node("GuildReserveScroll").scroll_vertical>before,"OS wheel scrolls reserve list "+str(dims))
  await snapshot("guild-scroll-"+str(dims.x))
 check(game.audio.muted.values().all(func(v):return v),"guild GUI sound3 OFF")
 var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
