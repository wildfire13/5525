extends "res://tests/skill_grant_hud.gd"
const SELECTED_BG=Color("#dfe8dc")
const SELECTED_HOVER=Color("#d2e0d3")
const SELECTED_BORDER=Color("#345c4e")
func selected_palette(style):
 var flat=style as StyleBoxFlat
 return flat!=null and flat.bg_color.is_equal_approx(SELECTED_BG) and flat.border_color.is_equal_approx(SELECTED_BORDER) and flat.border_width_left==2 and flat.border_width_top==2 and flat.border_width_right==2 and flat.border_width_bottom==2
func selected_palette_all(control):
 var hover=control.get_theme_stylebox("hover") as StyleBoxFlat
 return selected_palette(control.get_theme_stylebox("normal")) and selected_palette(control.get_theme_stylebox("pressed")) and hover!=null and hover.bg_color.is_equal_approx(SELECTED_HOVER)
func selected_button(control):
 return control!=null and control.get_meta("selected",false) and not control.text.begins_with("● ") and selected_palette(control.get_theme_stylebox("normal"))
func unselected_button(control):
 return control!=null and not control.get_meta("selected",false) and not control.has_theme_stylebox_override("normal") and not control.has_theme_stylebox_override("hover") and not control.has_theme_stylebox_override("pressed")
func contrast_ratio(a: Color,b: Color) -> float:
 var a_luma=a.srgb_to_linear().get_luminance()
 var b_luma=b.srgb_to_linear().get_luminance()
 return (maxf(a_luma,b_luma)+0.05)/(minf(a_luma,b_luma)+0.05)
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
 for dims in [Vector2i(1920,1080)]:
  await game.update({"op":"campaign_load","data":dual})
  await game.update({"op":"campaign","action":"trial","args":["mage","staff-wood","rightHand"]});await settle()
  root.size=dims;game.hud.back_to_commands();await settle()
  check(game.hud.buttons.attack.text=="攻撃" and unselected_button(game.hud.buttons.attack),"command label has no battle-only dot "+str(dims))
  check(game.hud.buttons.attack.get_theme_stylebox("normal").bg_color.is_equal_approx(game.theme.get_stylebox("normal","Button").bg_color) and game.hud.buttons.attack.get_theme_color("font_color").is_equal_approx(game.theme.get_color("font_color","Button")),"enabled command keeps battle theme colors "+str(dims))
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
  check(not game.hud.inspection_pinned and selected_button(game.hud.buttons.skill) and selected_palette_all(game.hud.buttons.skill) and game.hud.buttons.skill.get_theme_color("font_color").is_equal_approx(game.theme.get_color("font_color","Button")),"skill parent selected and click clears pin "+str(dims))
  var choices=game.data.skillset.filter(func(o):return o.id=="mage")
  await game.select_skill(choices[1].key);await settle()
  var children=skill_buttons()
  check(children.size()==2 and children.filter(func(b):return selected_button(b)).size()==1 and children.filter(func(b):return unselected_button(b)).size()==1,"only selected grant uses shared palette "+str(dims))
  # Two staves leave no fist: use the original one-staff owner for item selection.
  await game.act("endTrial",[])
  await game.update({"op":"campaign_load","data":save})
  await game.act("trial",["mage","staff-wood","rightHand"]);await settle()
  game.hud.buttons.items.pressed.emit();await settle()
  check(selected_button(game.hud.buttons.items) and unselected_button(game.hud.buttons.skill) and unselected_button(game.hud.buttons.attack),"item parent uses shared selection and clears others "+str(dims))
  await game.choose_command("item");await settle()
  check(selected_button(game.find_child("BattleItem_potion",true,false)),"potion child uses shared palette "+str(dims))
  check(not selected_button(game.find_child("BattleItem_ether",true,false)),"other item not selected "+str(dims))
  await game.cancel();await settle()
  check(not selected_button(game.find_child("BattleItem_potion",true,false)) and selected_button(game.hud.buttons.items),"cancel keeps category but clears item "+str(dims))
  var probe=Button.new();probe.text="選択表示の比較";game.add_child(probe);await process_frame
  game.mark_selected(probe,true)
  var battle_style=game.hud.buttons.items.get_theme_stylebox("normal") as StyleBoxFlat
  var regular_style=probe.get_theme_stylebox("normal") as StyleBoxFlat
  check(probe.get_meta("selected",false) and battle_style!=null and regular_style!=null and battle_style.bg_color.is_equal_approx(regular_style.bg_color) and battle_style.border_color.is_equal_approx(regular_style.border_color) and battle_style.border_width_left==regular_style.border_width_left,"battle and shared regular selection use the same palette "+str(dims))
  check(contrast_ratio(probe.get_theme_color("font_color"),regular_style.bg_color)>=4.5,"selected label keeps readable contrast "+str(dims))
  game.mark_selected(probe,false)
  check(not probe.get_meta("selected",false) and not probe.has_theme_stylebox_override("normal") and not probe.has_theme_stylebox_override("hover") and not probe.has_theme_stylebox_override("pressed"),"deselection removes palette overrides "+str(dims))
  probe.queue_free();await process_frame
  var queue_labels=game.hud.middle.find_children("*","Label",true,false).filter(func(n):return n.text.begins_with("● "))
  check(not queue_labels.is_empty(),"actor queue marker preserved "+str(dims))
  game.hud.back_to_commands();await settle();await game.on_cell(int(enemy.pos));await settle()
  game.find_child("BattleDetails",true,false).pressed.emit();await settle()
  check(not game.hud.inspection_pinned,"non-command button clears pin "+str(dims))
  game.dialog.close();await settle()
  # Keep the final trial active for action/reset inspection checks below.
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
