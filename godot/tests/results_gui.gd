extends "res://tests/results_regression.gd"
var request_id=0
var shots=[]
func raw(payload: Dictionary):
 request_id+=1;payload.id=request_id;var f=FileAccess.open(evidence.path_join("request.json"),FileAccess.WRITE);f.store_string(JSON.stringify(payload));f.close()
 var deadline=Time.get_ticks_msec()+10000
 while Time.get_ticks_msec()<deadline:
  if FileAccess.file_exists(evidence.path_join("response.json")):
   var value=JSON.parse_string(FileAccess.get_file_as_string(evidence.path_join("response.json")))
   if value is Dictionary and value.get("id")==request_id:break
  await process_frame
 check(Time.get_ticks_msec()<deadline,"result OS request "+str(payload.action));await frames(5)
func os_click(control):
 check(control!=null and control.is_visible_in_tree(),"result OS click target visible")
 var point=control.get_global_rect().get_center()+Vector2(control.get_window().position);await raw({"action":"click","x":point.x,"y":point.y});await settle()
func key(value: String):await raw({"action":"key","key":value});await settle()
func shot(label: String):
 await create_timer(.25).timeout;await RenderingServer.frame_post_draw
 var image=root.get_texture().get_image();check(image.get_size()==root.size,"result real rendered frame "+label);image.save_png(evidence.path_join(label+".png"));shots.append(label+".png")
func geometry(label: String):
 var view=game.results_view;var bounds=Rect2(Vector2.ZERO,Vector2(root.size))
 check(bounds.encloses(view.panel.get_global_rect()) and bounds.encloses(view.continue_button.get_global_rect()) and bounds.encloses(view.save_button.get_global_rect()),label+" panel/actions fit real resized viewport")
func run():
 create_timer(240).timeout.connect(func():print("FAIL results GUI watchdog");quit(2))
 root.borderless=true;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080)
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true;await settle();var cases=fixture();var view=game.results_view
 await load_case(cases.victory)
 var finish=game.find_children("*","Button",true,false).filter(func(b):return b.text=="戦闘を終えて街道へ")[0]
 await os_click(finish);check(view.active and view.current.kind=="battle","real finish button opens committed battle result")
 var paid=await saved();geometry("FHD battle");await shot("battle-result-FHD")
 await raw({"action":"click","x":root.size.x-60,"y":root.size.y-30});check(not game.menu.visible and view.active and await saved()==paid,"result backdrop blocks common menu and gameplay")
 await os_click(view.save_button)
 var file=game.find_children("*","FileDialog",true,false).filter(func(w):return w.visible)
 check(file.size()==1,"result Save opens existing real file dialog")
 await key("Escape");check(view.active and await saved()==paid,"cancelling result save returns to unchanged receipt")
 var scroll=view.shade.find_child("ResultMembersScroll",true,false);await key("End");await shot("battle-result-members-bottom")
 check(scroll.scroll_vertical>=int(scroll.get_v_scroll_bar().max_value-scroll.get_v_scroll_bar().page)-2,"result keyboard End reaches final member")
 await os_click(view.continue_button);check(not view.active and await saved()==paid,"result real continue closes without regrant")
 await load_case(cases.normal.ready);game.navigate("hub");await settle();await os_click(node("HubDeliverCargo"));check(view.active and view.current.kind=="quest","real cargo hand-in opens quest completion result")
 var delivered=await saved();await shot("quest-result-FHD");await os_click(view.shade.find_child("ResultShop",true,false))
 check(not view.active and game.campaign().phase=="town" and game.page=="shop" and game.campaign().gold==delivered.state.gold,"quest facility shortcut acknowledges once and preserves paid reward")
 await load_case(cases.late.result);await shot("late-result-FHD")
 for dims in [Vector2i(1180,812),Vector2i(960,540),Vector2i(1920,1080)]:
  await raw({"action":"resize_window","window":DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE),"width":dims.x,"height":dims.y});await frames(12);check(root.size==dims,"result OS resize accepted "+str(dims));geometry(str(dims));await shot("quest-result-"+str(dims.x))
 await key("Tab");await key("Tab");await key("Tab");check(view.active,"keyboard focus traversal does not mutate result")
 await key("Escape");check(not view.active and game.campaign().phase=="town","result OS Escape returns to canonical town")
 var settled=await saved();await os_click(node("CommonMenuButton"));await os_click(node("ReopenResults"));check(view.active,"common menu reopens read-only result")
 await os_click(view.continue_button);check(await saved()==settled,"result real reopen cannot duplicate rewards")
 check(game.audio.muted.values().all(func(v):return v),"result real QA all audio OFF")
 var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close();f=FileAccess.open(evidence.path_join("screenshots.json"),FileAccess.WRITE);f.store_string(JSON.stringify(shots));f.close()
 game.closing=true;view.reset();await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
