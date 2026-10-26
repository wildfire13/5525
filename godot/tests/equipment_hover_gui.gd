extends "res://tests/research2_gui.gd"
var baseline := OS.get_environment("LAYOUT_BASELINE")=="1"
var observations=[]
func os_resize(dims: Vector2i):
 request_id+=1
 var f=FileAccess.open(evidence.path_join("request.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"id":request_id,"action":"resize_window","window":DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE),"width":dims.x,"height":dims.y}));f.close()
 var deadline=Time.get_ticks_msec()+10000
 while Time.get_ticks_msec()<deadline:
  if FileAccess.file_exists(evidence.path_join("response.json")):
   var response=JSON.parse_string(FileAccess.get_file_as_string(evidence.path_join("response.json")))
   if response is Dictionary and response.get("id")==request_id:break
  await process_frame
 await create_timer(.4).timeout;await settle()
 check(root.size==dims,"X11 native resize delivered "+str(dims))
func screen_rect(c: Control) -> Rect2:return Rect2(c.get_global_rect().position+Vector2(c.get_window().position),c.size)
func internal_named(parent: Node,id: String):
 if str(parent.name)==id and parent is Control and parent.is_visible_in_tree():return parent
 for child in parent.get_children(true):
  var result=internal_named(child,id)
  if result!=null:return result
 return null
func hover_equipped(slot: String,label: String):
 var controls=game.find_children("*","Button",true,false).filter(func(b):return b.get_meta("ui_key","")=="equipment_"+slot)
 check(controls.size()==1,"equipped hover source uniquely identified "+label)
 var button=controls[0];await os_mouse(screen_rect(button).get_center());await create_timer(.85).timeout;await frames()
 var box=internal_named(root,"EquipmentTooltip")
 check(box!=null,"native custom equipment tooltip visible "+label)
 if box==null:return
 var body=box.find_child("EquipmentTooltipDetails",true,false);var popup=box.get_meta("hover_owner").get_ref();var children_min=0.0
 for child in box.get_children():children_min+=child.get_combined_minimum_size().y
 children_min+=box.get_theme_constant("separation")*(box.get_child_count()-1)
 var data={"case":label,"root":str(root.size),"popup_position":str(popup.position),"popup_size":str(popup.size),"box_size":str(box.size),"children_min_height":children_min,"body_size":str(body.size),"body_min":str(body.get_combined_minimum_size()),"body_content_height":body.get_content_height(),"full_text":body.get_parsed_text()}
 observations.append(data);print("HOVER_GEOMETRY "+JSON.stringify(data))
 if not baseline:
  check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(Rect2(Vector2(popup.position),Vector2(popup.size))),"hover frame fits viewport "+label)
  check(box.size.y<=children_min+4,"hover background follows laid-out content without blank tail "+label)
  check(body.get_content_height()<=body.size.y+2,"registered equipment explanation reaches its end without clipping "+label)
 await snapshot("F4-"+label)
 await os_mouse(Vector2(root.size.x-8,root.size.y-8));await create_timer(.2).timeout
func run():
 create_timer(300).timeout.connect(func():print("FAIL equipment hover GUI watchdog");quit(2))
 root.borderless=true;root.position=Vector2i.ZERO;root.size=Vector2i(1280,800)
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true;await settle();var original=await saved();var town=original.duplicate(true);town.state.location="east"
 town.state.characters.guard.level=29;town.state.characters.guard.xp=2800;town.state.characters.guard.allocations.str=2;town.state.characters.guard.statPoints=54;town.state.characters.guard.skillPoints=28;town.state.characters.guard.weapon="hammer-iron-1"
 check((await game.update({"op":"campaign_load","data":town})).get("ok",false),"isolated level29 hammer fixture passes canonical load")
 await enter_facility("shop");await settle();await os_click(node("PartyFace_guard"));var before=await saved()
 for dims in [Vector2i(1280,800),Vector2i(1180,812),Vector2i(1920,1080)]:
  await os_resize(dims)
  await hover_equipped("upperBody","plain-"+str(dims.x))
  await hover_equipped("rightHand","stamp-"+str(dims.x))
  check(await saved()==before,"equipped hover and resize never mutate campaign "+str(dims.x))
 game.dialog.close();await settle();town.state.characters.guard.allocations.agi=1;town.state.characters.guard.statPoints=53;town.state.characters.guard.leftHand="empty-leftHand"
 for item in [["partner-dagger","pincer","挟撃"],["longspear-wood","poleVault","ポールヴォールト"],["grappling-rope","grapple","引き寄せ"]]:
  town.state.characters.guard.weapon=item[0]
  check((await game.update({"op":"campaign_load","data":town})).get("ok",false),"long skill fixture passes canonical equipment eligibility "+item[0])
  await enter_facility("shop");await settle();await os_click(node("PartyFace_guard"));await os_resize(Vector2i(1180,812));before=await saved();await hover_equipped("rightHand",item[1]+"-1180")
  check(observations[-1].full_text.contains(item[2]),"tooltip is actual equipped skill rather than previous gear "+item[0])
  check(await saved()==before,"long skill hover is read-only "+item[0]);game.dialog.close();await settle()
 if not baseline:
  game.pages.party_view.open_detail("guard");await settle()
  var source=game.find_children("*","Button",true,false).filter(func(b):return b.get_meta("ui_key","")=="equipment_rightHand")[0]
  var long_note="診断用の長文メモ。".repeat(300)+"末尾の診断文字"
  source.heading="診断用の長い装備名".repeat(32);source.details.append(source.escaped(long_note));source.plain_details.append(long_note);source.tooltip_text+="\n"+long_note
  before=await saved();await hover_equipped("rightHand","synthetic-long-1180")
  await os_mouse(screen_rect(source).get_center());await create_timer(.85).timeout;await frames()
  var box=internal_named(root,"EquipmentTooltip");var body=box.find_child("EquipmentTooltipDetails",true,false)
  check(not body.get_meta("excerpt",true) and body.get_parsed_text().ends_with(long_note) and box.find_child("EquipmentTooltipHint",true,false).text.contains("スクロール"),"OS overlong note stays complete in its own scrollable hover")
  var active=source.hover_window;var scroll=box.find_child("EquipmentTooltipScroll",true,false)
  await os_mouse(scroll.get_global_rect().get_center());await create_timer(.7).timeout
  check(active.visible and source.hover_window==active and active.content.find_child("EquipmentTooltipDetails",true,false).get_parsed_text().ends_with(long_note),"OS long hover keeps its owner over underlying equipment buttons")
  await os_wheel(scroll.get_global_rect().get_center(),100);await create_timer(.7).timeout;await settle()
  check(active.visible and scroll.scroll_vertical>0 and scroll.scroll_vertical+scroll.size.y>=scroll.get_v_scroll_bar().max_value-2,"OS same long hover reaches its final original line by wheel")
  await snapshot("F4-long-hover-final-line-1180")
  check(source.tooltip_text.ends_with(long_note) and await saved()==before,"overlong preview keeps original note and canonical save unchanged")
 check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"all equipment hover audio OFF")
 var f=FileAccess.open(evidence.path_join("hover-geometry.json"),FileAccess.WRITE);f.store_string(JSON.stringify(observations,"\t"));f.close()
 f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
