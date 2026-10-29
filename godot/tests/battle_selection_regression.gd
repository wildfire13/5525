extends "res://tests/skill_grant_hud.gd"
func selected_button(control):
 return control!=null and control.text.begins_with("● ") and control.get_meta("battle_selected",false) and control.get_theme_stylebox("normal").bg_color.is_equal_approx(Color("#d8bd86"))
func run():
 create_timer(100).timeout.connect(func():print("FAIL watchdog");quit(2))
 if OS.get_environment("NATIVE5525_AUDIO_OFF")!="1":quit(2);return
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true
 await preload("res://tests/current_historical_fixture.gd").install(game);await settle()
 var save=(await game.engine.request({"op":"campaign_save"})).data
 save.state.location="east";save.state.gold=9999
 await game.update({"op":"campaign_load","data":save})
 await game.update({"op":"campaign","action":"buyGear","args":["mage","staff-silver-1","leftHand"]})
 var dual=(await game.engine.request({"op":"campaign_save"})).data
 for dims in [Vector2i(1920,1080),Vector2i(1180,812),Vector2i(960,540)]:
  await game.update({"op":"campaign_load","data":dual})
  await game.update({"op":"campaign","action":"trial","args":["mage","staff-wood","rightHand"]});await settle()
  root.size=dims;game.hud.back_to_commands();await settle()
  var ally=game.state().units.filter(func(u):return u.side=="ally")[0]
  var enemy=game.state().units.filter(func(u):return u.side=="enemy")[0]
  for u in [ally,enemy,enemy]:
   await game.on_cell(int(u.pos));await settle()
   check(game.hud.inspection_pinned and game.hud.person_box.get_meta("inspected_unit","")==u.id,"tile click pins "+str(u.side)+" "+str(dims))
   game.hud.inspect_hover(ally.id if u.id==enemy.id else enemy.id,game.board);await settle()
   check(game.hud.person_box.get_meta("inspected_unit","")==u.id,"hover cannot replace clicked person "+str(dims))
  var empty=0
  while not game.board.unit_at(empty).is_empty():empty+=1
  await game.on_cell(empty);await settle();game.hud.inspect_hover(ally.id,game.board)
  check(game.hud.inspection_pinned and not game.hud.person_box.has_meta("inspected_unit"),"empty cell remains empty on hover "+str(dims))
  await game.on_cell(int(enemy.pos));await settle()
  game.hud.buttons.skill.pressed.emit();await settle()
  check(not game.hud.inspection_pinned and selected_button(game.hud.buttons.skill),"skill parent selected and click clears pin "+str(dims))
  var choices=game.data.skillset.filter(func(o):return o.id=="mage")
  await game.select_skill(choices[1].key);await settle()
  var children=skill_buttons()
  check(children.size()==2 and children.filter(func(b):return selected_button(b)).size()==1,"only selected grant has dot and yellow "+str(dims))
  # Two staves leave no fist: use the original one-staff owner for item selection.
  await game.act("endTrial",[])
  await game.update({"op":"campaign_load","data":save})
  await game.act("trial",["mage","staff-wood","rightHand"]);await settle()
  game.hud.buttons.items.pressed.emit();await settle()
  check(selected_button(game.hud.buttons.items) and not selected_button(game.hud.buttons.skill),"item parent uses same selection "+str(dims))
  await game.choose_command("item");await settle()
  check(selected_button(game.find_child("BattleItem_potion",true,false)),"potion child dot and yellow "+str(dims))
  check(not selected_button(game.find_child("BattleItem_ether",true,false)),"other item not selected "+str(dims))
  await game.cancel();await settle()
  check(not selected_button(game.find_child("BattleItem_potion",true,false)) and selected_button(game.hud.buttons.items),"cancel keeps category but clears item "+str(dims))
  game.hud.back_to_commands();await settle();await game.on_cell(int(enemy.pos));await settle()
  game.find_child("BattleDetails",true,false).pressed.emit();await settle()
  check(not game.hud.inspection_pinned,"non-command button clears pin "+str(dims))
  game.dialog.close();await settle()
  if dims!=Vector2i(960,540):await game.act("endTrial",[])
 game.hud.back_to_commands();await settle()
 var u=game.state().units[0];await game.on_cell(int(u.pos));await settle()
 game.hud.last_action_count=-1;game.render();await settle()
 check(not game.hud.inspection_pinned,"new action clears pin")
 await game.on_cell(int(u.pos));game.hud.reset_context()
 check(not game.hud.inspection_pinned and game.hud.inspected_uid.is_empty(),"battle reset clears pin")
 check(game.audio.muted.values().all(func(v):return v),"all audio OFF")
 game.closing=true;await game.audio.finish_audio();await game.engine.finish_diagnostics();game.engine.close_engine();game.queue_free()
 for i in range(8):await process_frame
 quit(0 if checks.all(func(ok):return ok) else 1)
