extends "res://tests/equipment_hover_gui.gd"
## X11/XTest input. Only evidence capture deliberately holds the existing engine
## busy boundary; the product has no such hold or minimum display duration.
var hold_next := false
var seen=[]
var captures=[]
func raw_request(payload: Dictionary):
 request_id+=1;payload.id=request_id
 var f=FileAccess.open(evidence.path_join("request.json"),FileAccess.WRITE);f.store_string(JSON.stringify(payload));f.close()
 var deadline=Time.get_ticks_msec()+10000
 while Time.get_ticks_msec()<deadline:
  if FileAccess.file_exists(evidence.path_join("response.json")):
   var reply=JSON.parse_string(FileAccess.get_file_as_string(evidence.path_join("response.json")))
   if reply is Dictionary and reply.get("id")==request_id:break
  await process_frame
 check(Time.get_ticks_msec()<deadline,"OS input acknowledged "+str(payload.get("action")))
 await frames(3)
func press_at(control: Control):
 var at=screen_rect(control).get_center();await raw_request({"action":"click","x":at.x,"y":at.y})
func on_painted(token: int):
 if seen.has(token):return
 seen.append(token)
 var image=root.get_texture().get_image();var filename="actual-transition-%02d-%dx%d.png" % [token,root.size.x,root.size.y];image.save_png(evidence.path_join(filename))
 captures.append({"token":token,"frame":Engine.get_process_frames(),"path":game.loading_screen.selected_path,"phase":game.campaign().get("phase"),"size":str(root.size),"file":filename})
 check(image.get_size()==root.size and game.loading_screen.panel.visible,"loading image exists in a real rendered frame before engine work")
 if hold_next:hold_next=false;game.engine.busy=true
func wait_active():
 var deadline=Time.get_ticks_msec()+10000
 while not game.loading_screen.active and Time.get_ticks_msec()<deadline:await process_frame
 check(game.loading_screen.active and game.engine.busy,"test-only engine hold exposes actual loading boundary")
func check_fullscreen(label: String):
 var panel=game.loading_screen.panel
 check(panel.get_global_rect()==Rect2(Vector2.ZERO,Vector2(root.size)),label+" full-window input blocker")
 check(game.loading_screen.picture.size==Vector2(root.size) and game.loading_screen.picture.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_COVERED,label+" aspect-preserving still covers window")
func probe_input(label: String):
 var before=game.data.duplicate(true);var mode=root.mode;var size_before=root.size
 for key in ["Tab","Return","Escape","F11","Left","space"]:await raw_request({"action":"key","key":key})
 await raw_request({"action":"click","x":root.size.x-60,"y":root.size.y-30})
 await raw_request({"action":"camera_drag","x":500,"y":300,"end_x":600,"end_y":360})
 check(not game.menu.visible and game.data==before and root.mode==mode and root.size==size_before,label+" OS keyboard/mouse/camera/menu cannot affect scene behind loading")
func run():
 create_timer(240).timeout.connect(func():print("FAIL loading GUI watchdog");quit(2))
 check(DisplayServer.get_name()!="headless","real X11 rendering")
 root.borderless=true;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080)
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true;await settle()
 game.loading_screen.frame_presented.connect(on_painted)
 await os_click(node("HubMap"));await os_click(node("Town_east"));await os_click(node("DepartButton"))
 check(game.campaign().phase=="road","normal new-profile map and departure reach road")
 var road=await saved();hold_next=true
 var river=game.find_children("*","Button",true,false).filter(func(b):return b.text.begins_with("川沿いの道"))[0]
 await press_at(river);await wait_active();check_fullscreen("FHD before");await probe_input("before")
 for dims in [Vector2i(1180,812),Vector2i(960,540),Vector2i(1920,1080)]:
  await raw_request({"action":"resize_window","window":DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE),"width":dims.x,"height":dims.y});await frames(10);check(root.size==dims,"native resize during loading "+str(dims));check_fullscreen(str(dims));await snapshot("before-held-"+str(dims.x))
 game.engine.busy=false;await settle()
 check(not game.loading_screen.active and game.campaign().phase=="deployment","ordinary road click creates deployment then removes overlay")
 await snapshot("deployment-ready")
 await os_click(node("DeploymentBegin"));await settle()
 check(not game.loading_screen.active and game.campaign().phase=="battle" and not game.presenting,"battle starts and existing first-turn presentation remains visible")
 var output=[];OS.execute(OS.get_environment("NATIVE5525_NODE"),[ProjectSettings.globalize_path("res://tests/audio_fixtures.cjs")],output,true,false);var fixtures=JSON.parse_string("".join(output))
 check((await game.update({"op":"campaign_load","data":fixtures.finished})).get("ok",false),"validated synthetic victory boundary loaded (not a full played victory)")
 var winner=await saved();hold_next=true
 var finish=game.find_children("*","Button",true,false).filter(func(b):return b.text=="戦闘を終えて街道へ")[0]
 await press_at(finish);await wait_active();check(game.loading_screen.selected_path.contains("after-"),"victory transition uses after artwork");await probe_input("after");await snapshot("after-held-FHD")
 game.engine.busy=false;await settle();var after=await saved()
 check(not game.loading_screen.active and game.campaign().phase=="camp","victory finish returns to camp without leftover overlay")
 check(int(after.state.gold)==int(winner.state.gold)+8,"finish rewards applied exactly once despite OS repeated input")
 await snapshot("camp-ready")
 check(game.audio.muted.values().all(func(v):return v),"BGM voice SE OFF")
 var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
 f=FileAccess.open(evidence.path_join("transitions.json"),FileAccess.WRITE);f.store_string(JSON.stringify(captures,"\t"));f.close()
 game.closing=true;game.loading_screen.finish(game.loading_screen.sequence);await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
