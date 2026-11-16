extends "res://tests/guild_regression.gd"
const CURRENT="recruit-guard-human-female"
const RESERVE="recruit-guard-human-male"
const MAGE="recruit-mage-elf-female"
const RESERVE_MAGE="recruit-mage-human-male"
const PORTER="recruit-porter-human-female"
const CARGO_REPLACEMENT="recruit-guard-elf-male"
func scroll_positions() -> Array:return [node("GuildReserveScroll").scroll_vertical,current_scroll().scroll_vertical]
func middle_scroll():
 node("GuildReserveScroll").scroll_vertical=60;current_scroll().scroll_vertical=60;await frames(12)
func run():
 create_timer(180).timeout.connect(func():print("FAIL feedback3 guild watchdog");quit(2))
 var evidence=OS.get_environment("INVENTORY_QA_ROOT")
 if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
 root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 await game.new_game();
 game.audio.fast_mode=true;game.checks_fast=true;actual=game.engine;recorder=RecordedEngine.new();recorder.actual=actual;game.add_child(recorder);game.engine=recorder;await settle();var seed=await saved()
 game.navigate("party");await settle();await tap("FacilityChoice_guild");var guild=game.pages.guild_view
 var selected=game.campaign().selected.duplicate();var payload=guild.drag_payload(RESERVE)
 check(guild.drop_operation(payload,CURRENT)==["swap",CURRENT,RESERVE],"reserve to current card replaces target")
 check(guild.drop_operation(payload,"",true)==["add","",RESERVE],"reserve to empty party slot adds")
 check(guild.drop_operation(payload,RESERVE_MAGE).is_empty(),"reserve to reserve rejected")
 var stale=payload.duplicate(true);guild.drag_payload(RESERVE_MAGE);check(not guild.valid_drag(stale),"previous drag token rejected")
 payload=guild.drag_payload(RESERVE);var sc=node("GuildReserveScroll");sc.scroll_vertical=160;await frames();var pos=sc.scroll_vertical
 guild.drop_member(payload,RESERVE_MAGE);await settle();check(game.campaign().selected==selected and node("GuildReserveScroll").scroll_vertical==pos,"invalid drop preserves order and scroll")
 var rejected_save=await saved();recorder.reject_next=true;guild.drop_member(payload,CURRENT);await settle()
 check((await saved())==rejected_save and node("GuildReserveScroll").scroll_vertical==pos,"native rejection preserves save and scroll")
 payload=guild.drag_payload(RESERVE);guild.drop_member(payload,CURRENT);await settle();selected[selected.find(CURRENT)]=RESERVE
 check(game.campaign().selected==selected,"reserve card swap commits exact slots")
 check(not guild.valid_drag(payload),"successful drag cannot replay")
 payload=guild.drag_payload(RESERVE);check(guild.drop_operation(payload,CURRENT)==["swap",RESERVE,CURRENT],"current to reserve card reverses replacement")
 guild.drop_member(payload,CURRENT);await settle();selected[selected.find(RESERVE)]=CURRENT
 payload=guild.drag_payload(RESERVE);guild.drop_member(payload,"",true);await settle();selected.append(RESERVE)
 check(game.campaign().selected==selected,"empty strip slot appends reserve")
 payload=guild.drag_payload(CURRENT);check(guild.drop_operation(payload,"",true).is_empty(),"existing member cannot duplicate through empty slot")
 var target=str(selected[1]);guild.drop_member(payload,target);await settle();var first=selected.find(CURRENT);var second=selected.find(target);selected[first]=target;selected[second]=CURRENT
 check(game.campaign().selected==selected,"existing member to existing member exchanges positions")
 check(game.find_children("GuildPartyAnimation","Control",true,false).is_empty() and game.find_children("RosterMember_*","Button",true,false).all(func(card):return card.modulate.a==1),"completed slide leaves no ghost or transparent card")
 payload=guild.drag_payload(str(selected[0]));guild.drop_member(payload,str(selected[1]))
 while guild.stage!="animating" and (game.locked or guild.stage in ["confirm","pending"]):await process_frame
 check(not guild.guard_leave(),"normal navigation held during slide")
 guild.reset();game.render();await create_timer(.5).timeout;await settle()
 check(game.find_children("GuildPartyAnimation","Control",true,false).is_empty() and game.find_children("RosterMember_*","Button",true,false).all(func(card):return card.modulate.a==1),"reset during slide leaves no ghost or transparent card")
 check((await saved()).state.characters==seed.state.characters,"drag operations preserve inventory and character data")
 var original=game.data.campaign.duplicate(true);var roster=original.roster.duplicate(true)
 game.data.campaign.roster=roster;game.data.campaign.selected=roster.slice(0,12).map(func(member):return str(member.id));guild.reset();game.render();await settle()
 payload=guild.drag_payload(str(roster[12].id));check(guild.drop_operation(payload,"",true).is_empty(),"twelve-person capacity rejects append")
 check(not guild.drop_operation(payload,str(roster[0].id)).is_empty(),"twelve-person capacity permits replacement")
 # Test only the strip overflow at FHD; no smaller game window.
 var bar=game.pages.party_view.face_bar(game);bar.size=Vector2(800,84);bar.position=Vector2(0,996);bar.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;bar.custom_minimum_size.x=800;bar.size.x=800
 await settle();var face=node("PartyFace_"+str(roster[0].id));var strip=node("PartyFacesScroll");strip.scroll_horizontal=0
 var touch=InputEventScreenTouch.new();touch.pressed=true;touch.position=Vector2(50,20);face._gui_input(touch)
 var motion=InputEventScreenDrag.new();motion.position=Vector2(10,20);face._gui_input(motion)
 check(face.swiping and strip.scroll_horizontal>0,"legacy strip component retains touch swipe used in deployment")
 bar.queue_free();await frames()
 game.data.campaign=original;guild.reset();game.render();await settle()
 # Eleven real members make the shared vertical roster scrollable at FHD, leaving one append slot.
 var eleven=game.campaign().selected.duplicate()
 var candidates=game.roster().duplicate();candidates.reverse()
 # Keep the existing leading reserve rows/scroll anchor while adding new candidates.
 for member in candidates:
  if eleven.size()>=11:break
  if not eleven.has(member.id) and member.id not in [RESERVE_MAGE,CARGO_REPLACEMENT]:eleven.append(member.id)
 await game.act("select",[eleven]);await settle()
 await middle_scroll();check(scroll_positions()==[60,60],"FHD fixture has genuine middle scroll on both lists")
 await middle_scroll();var scroll_before=scroll_positions();guild.choose(RESERVE_MAGE);await settle()
 check(scroll_positions()==scroll_before,"reserve selection preserves both genuine middle scroll positions")
 payload=guild.drag_payload(RESERVE_MAGE);guild.drop_member(payload,MAGE);await settle()
 check(scroll_positions()==scroll_before,"selected reserve to party preserves both middle scroll positions")
 await middle_scroll();scroll_before=scroll_positions();payload=guild.drag_payload(RESERVE_MAGE);guild.drop_member(payload,MAGE);await settle()
 check(scroll_positions()==scroll_before,"party to reserve preserves both middle scroll positions")
 await middle_scroll();scroll_before=scroll_positions();payload=guild.drag_payload(RESERVE_MAGE);game.mock_shell.drop(payload,MAGE);await settle()
 check(scroll_positions()==scroll_before,"reserve to shared roster preserves both middle scroll positions")
 payload=guild.drag_payload(RESERVE_MAGE);guild.drop_member(payload,MAGE);await settle()
 await middle_scroll();scroll_before=scroll_positions();guild.choose(RESERVE_MAGE);await settle();check(scroll_positions()==scroll_before,"append selection preserves both genuine middle scroll positions");payload=guild.drag_payload(RESERVE_MAGE);guild.drop_member(payload,"",true);await settle()
 check(scroll_positions()==scroll_before,"selected reserve to append preserves both middle scroll positions")
 await game.act("accept",[game.campaign().board[0].id,PORTER]);await settle();var cargo=await saved()
 payload=guild.drag_payload(CARGO_REPLACEMENT);guild.drop_member(payload,PORTER);await settle();check(guild.stage=="confirm","cargo owner replacement opens existing warning")
 await tap("GuildConfirmCancel");check((await saved())==cargo,"cargo owner cancel preserves exact save")
 check(game.audio.muted.values().all(func(v):return v),"BGM voice SE OFF")
 var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
 game.closing=true;await game.audio.finish_audio();actual.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(row):return row.passed) else 1)
