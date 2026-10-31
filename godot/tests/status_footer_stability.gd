extends "res://tests/brushup_gui.gd"
var measured=[]
func geometry():
 var strip=node("PartyFacesScroll").get_parent()
 return [strip.global_position.y,strip.size.y,game.footer.global_position.y,game.footer.size.y,game.location_bar.global_position.y]
func record(label: String):
 measured.append({"case":label,"geometry":geometry(),"text":game.footer.text,"visible":game.footer.visible})
 if DisplayServer.get_name()!="headless":await snapshot(label)
func run():
 create_timer(160).timeout.connect(func():print("FAIL status footer watchdog");quit(2))
 root.borderless=true;root.position=Vector2i.ZERO
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true;await settle();var seed=await saved()
 for dims in [Vector2i(1920,1080)]:
  root.size=dims;await game.update({"op":"campaign_load","data":seed});game.navigate("board");await settle()
  game.set_status("難易度は未設定です。");await settle();var baseline=geometry();await record("shown-"+str(dims.x))
  for message in ["","処理中…","説明".repeat(100)+"\n末尾",""]:
   game.set_status(message);await settle()
   check(geometry()==baseline,"party/footer/location coordinates unchanged "+str(dims)+" text length "+str(message.length()))
   check(game.footer.get_meta("full_message")==message,"full text retained")
   if message.length()>100:
    await record("long-"+str(dims.x))
    if DisplayServer.get_name()!="headless":await os_click(game.footer)
    else:game.show_status_details();await settle()
    check(game.modal_open() and game.dialog.window.find_children("*","Label",true,false).any(func(label):return label.text==message),"full explanation opens without losing last line")
    if DisplayServer.get_name()!="headless":await os_key("Escape")
    else:game.dialog.close();await settle()
    check(not game.modal_open() and geometry()==baseline,"closing full explanation keeps party coordinates")
  await record("empty-"+str(dims.x))
  check(game.footer.focus_mode==Control.FOCUS_NONE and game.footer.mouse_filter==Control.MOUSE_FILTER_IGNORE,"empty reserved row is not an invisible action")
  game.set_status("難易度は未設定です。");await settle()
  var choice=game.find_children("QuestChoice_*","Button",true,false)[0]
  if DisplayServer.get_name()!="headless":
   await os_click(choice);await os_key("Tab")
  else:choice.grab_focus();await settle()
  check(geometry()==baseline,"button focus change preserves party coordinates "+str(dims))
  await record("focus-"+str(dims.x))
  game.notice="診断エラー通知";game.render();await settle()
  check(game.footer.text=="診断エラー通知" and geometry()==baseline,"error notice preserved without movement")
  game.notice="";game.render();await settle();check(geometry()==baseline,"clearing notice preserves coordinates")
  check(await saved()==seed,"display changes do not change campaign")
 for spec in [["east","shop"],["astaris","party"],["astaris","inn"]]:
  var fixture=seed.duplicate(true);fixture.state.location=spec[0]
  await game.update({"op":"campaign_load","data":fixture});game.navigate(spec[1]);await settle();game.set_status("他画面の説明");await settle()
  check(game.footer.visible==(spec[1]=="inn"),"existing screen visibility policy "+spec[1])
 check(game.audio.muted.values().all(func(v):return v),"audio three OFF")
 var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
 f=FileAccess.open(evidence.path_join("geometry.json"),FileAccess.WRITE);f.store_string(JSON.stringify(measured,"\t"));f.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
