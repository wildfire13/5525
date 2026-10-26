extends "res://tests/guild_regression.gd"
func scroll_positions() -> Array:return [node("GuildReserveScroll").scroll_vertical,node("GuildCurrentScroll").scroll_vertical]
func middle_scroll():
 node("GuildReserveScroll").scroll_vertical=140;node("GuildCurrentScroll").scroll_vertical=140;await frames(12)
func run():
 create_timer(180).timeout.connect(func():print("FAIL feedback3 guild watchdog");quit(2))
 var evidence=OS.get_environment("INVENTORY_QA_ROOT")
 if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
 root.size=Vector2i(1180,812);game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.audio.fast_mode=true;game.checks_fast=true;actual=game.engine;recorder=RecordedEngine.new();recorder.actual=actual;game.add_child(recorder);game.engine=recorder;await settle();var seed=await saved()
 game.navigate("party");await settle();await tap("FacilityChoice_guild");var guild=game.pages.guild_view
 var selected=game.campaign().selected.duplicate();var payload=guild.drag_payload("guard-2")
 check(guild.drop_operation(payload,"guard")==["swap","guard","guard-2"],"reserve to current card replaces target")
 check(guild.drop_operation(payload,"",true)==["add","","guard-2"],"reserve to empty party slot adds")
 check(guild.drop_operation(payload,"mage-2").is_empty(),"reserve to reserve rejected")
 var stale=payload.duplicate(true);guild.drag_payload("mage-2");check(not guild.valid_drag(stale),"previous drag token rejected")
 payload=guild.drag_payload("guard-2");var sc=node("GuildReserveScroll");sc.scroll_vertical=160;await frames();var pos=sc.scroll_vertical
 guild.drop_member(payload,"mage-2");await settle();check(game.campaign().selected==selected and node("GuildReserveScroll").scroll_vertical==pos,"invalid drop preserves order and scroll")
 var rejected_save=await saved();recorder.reject_next=true;guild.drop_member(payload,"guard");await settle()
 check((await saved())==rejected_save and node("GuildReserveScroll").scroll_vertical==pos,"native rejection preserves save and scroll")
 payload=guild.drag_payload("guard-2");guild.drop_member(payload,"guard");await settle();selected[selected.find("guard")]="guard-2"
 check(game.campaign().selected==selected,"reserve card swap commits exact slots")
 check(not guild.valid_drag(payload),"successful drag cannot replay")
 payload=guild.drag_payload("guard-2");check(guild.drop_operation(payload,"guard")==["swap","guard-2","guard"],"current to reserve card reverses replacement")
 guild.drop_member(payload,"guard");await settle();selected[selected.find("guard-2")]="guard"
 payload=guild.drag_payload("guard-2");guild.drop_member(payload,"",true);await settle();selected.append("guard-2")
 check(game.campaign().selected==selected,"empty strip slot appends reserve")
 payload=guild.drag_payload("guard");check(guild.drop_operation(payload,"",true).is_empty(),"existing member cannot duplicate through empty slot")
 var target=str(selected[1]);guild.drop_member(payload,target);await settle();var first=selected.find("guard");var second=selected.find(target);selected[first]=target;selected[second]="guard"
 check(game.campaign().selected==selected,"existing member to existing member exchanges positions")
 check(game.find_children("GuildPartyAnimation","Control",true,false).is_empty() and game.find_children("PartyFace_*","Button",true,false).all(func(card):return card.modulate.a==1),"completed slide leaves no ghost or transparent card")
 payload=guild.drag_payload(str(selected[0]));guild.drop_member(payload,str(selected[1]))
 while guild.stage!="animating" and (game.locked or guild.stage in ["confirm","pending"]):await process_frame
 check(not guild.guard_leave(),"normal navigation held during slide")
 guild.reset();game.render();await create_timer(.5).timeout;await settle()
 check(game.find_children("GuildPartyAnimation","Control",true,false).is_empty() and game.find_children("PartyFace_*","Button",true,false).all(func(card):return card.modulate.a==1),"reset during slide leaves no ghost or transparent card")
 check((await saved()).state.characters==seed.state.characters,"drag operations preserve inventory and character data")
 var original=game.data.campaign.duplicate(true);var roster=original.roster.duplicate(true)
 for i in range(3):
  var member=roster[0].duplicate(true);member.id="qa-extra-"+str(i);roster.append(member)
 game.data.campaign.roster=roster;game.data.campaign.selected=roster.slice(0,12).map(func(member):return str(member.id));guild.reset();game.render();await settle()
 payload=guild.drag_payload(str(roster[12].id));check(guild.drop_operation(payload,"",true).is_empty(),"twelve-person capacity rejects append")
 check(not guild.drop_operation(payload,str(roster[0].id)).is_empty(),"twelve-person capacity permits replacement")
 root.size=Vector2i(960,540);await settle();var face=node("PartyFace_"+str(roster[0].id));var strip=node("PartyFacesScroll");strip.scroll_horizontal=0
 var touch=InputEventScreenTouch.new();touch.pressed=true;touch.position=Vector2(50,20);face._gui_input(touch)
 var motion=InputEventScreenDrag.new();motion.position=Vector2(10,20);face._gui_input(motion)
 check(face.swiping and strip.scroll_horizontal>0,"guild touch horizontal swipe retained while mouse supports D&D")
 game.data.campaign=original;guild.reset();game.render();await settle()
 await middle_scroll();guild.choose("mage-2");await settle();var scroll_before=scroll_positions()
 payload=guild.drag_payload("mage-2");guild.drop_member(payload,"mage");await settle()
 check(scroll_positions()==scroll_before,"selected reserve to party preserves both middle scroll positions")
 await middle_scroll();scroll_before=scroll_positions();payload=guild.drag_payload("mage-2");guild.drop_member(payload,"mage");await settle()
 check(scroll_positions()==scroll_before,"party to reserve preserves both middle scroll positions")
 await middle_scroll();scroll_before=scroll_positions();payload=guild.drag_payload("mage-2");node("PartyFaceBar").drop(payload,"mage");await settle()
 check(scroll_positions()==scroll_before,"reserve to bottom face preserves both middle scroll positions")
 payload=guild.drag_payload("mage-2");guild.drop_member(payload,"mage");await settle()
 await middle_scroll();guild.choose("mage-2");await settle();scroll_before=scroll_positions();payload=guild.drag_payload("mage-2");node("PartyFaceBar").drop(payload);await settle()
 check(scroll_positions()==scroll_before,"selected reserve to append preserves both middle scroll positions")
 await game.act("accept",[game.campaign().board[0].id,"porter"]);await settle();var cargo=await saved()
 payload=guild.drag_payload("warrior");guild.drop_member(payload,"porter");await settle();check(guild.stage=="confirm","cargo owner replacement opens existing warning")
 await tap("GuildConfirmCancel");check((await saved())==cargo,"cargo owner cancel preserves exact save")
 check(game.audio.muted.values().all(func(v):return v),"BGM voice SE OFF")
 var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
 game.closing=true;await game.audio.finish_audio();actual.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(row):return row.passed) else 1)
