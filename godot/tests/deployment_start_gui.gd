extends "res://tests/research2_gui.gd"
## Fresh normal UI journey and XTest input; no campaign or layout fixtures.
var baseline=OS.get_environment("DEPLOYMENT_BASELINE")=="1"
var measurements=[]
func record_layout(label: String):
 var deploying=game.state().get("deploying",false)
 var controls=[node("DeploymentBegin"),game.hud.deployment_bar,game.hud.deployment_actions] if deploying else [node("BattleHistory"),node("BattleOrderDetails")]
 var rows=[]
 for control in controls:
  check(control.is_visible_in_tree() and Rect2(Vector2.ZERO,Vector2(root.size)).encloses(control.get_global_rect()),label+" control visible in viewport "+str(control.name))
  for panel in [game.hud.left_panel,game.hud.right_panel]:
   var overlap=panel.get_global_rect().intersection(control.get_global_rect()) if panel.visible else Rect2()
   if not baseline or not deploying:check(not overlap.has_area(),label+" panel cannot cover "+str(control.name)+" "+str(panel.name))
   rows.append({"control":str(control.name),"control_rect":str(control.get_global_rect()),"panel":str(panel.name),"panel_rect":str(panel.get_global_rect()),"overlap_area":overlap.get_area(),"overlap_fraction":overlap.get_area()/maxf(1,control.get_global_rect().get_area())})
 if deploying:
  var start=node("DeploymentBegin");var menu=node("CommonMenuButton")
  var overlap=start.get_global_rect().intersection(menu.get_global_rect()) if menu.visible else Rect2()
  if not baseline:check(not overlap.has_area(),label+" full start button stays clear of common menu")
  rows.append({"control":"DeploymentBegin","control_rect":str(start.get_global_rect()),"panel":"CommonMenuButton","panel_rect":str(menu.get_global_rect()),"overlap_area":overlap.get_area()})
  var fixed=[game.hud.deployment_bar,game.hud.deployment_actions,menu]
  var cells=[]
  for cell in range(50):
   if cell%10>=5:continue
   var point=game.board.global_position+game.board.project_cell(cell)
   var covered=[]
   for control in fixed:
    if control.visible and control.get_global_rect().has_point(point):covered.append(str(control.name))
   var inside=Rect2(Vector2.ZERO,Vector2(root.size)).has_point(point)
   if not baseline:check(inside and covered.is_empty(),label+" legal ally cell "+str(cell)+" center in viewport and clear of fixed footer")
   cells.append({"cell":cell,"x":point.x,"y":point.y,"inside_viewport":inside,"fixed_covered_by":covered})
  rows.append({"control":"all_25_ally_cell_centers","cells":cells})
 measurements.append({"label":label,"size":str(root.size),"phase":game.campaign().phase,"rows":rows})
func native_resize(dims: Vector2i):
 request_id+=1
 var f=FileAccess.open(evidence.path_join("request.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"id":request_id,"action":"resize_window","window":DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE),"width":dims.x,"height":dims.y}));f.close()
 var deadline=Time.get_ticks_msec()+10000
 while Time.get_ticks_msec()<deadline:
  if FileAccess.file_exists(evidence.path_join("response.json")):
   var response=JSON.parse_string(FileAccess.get_file_as_string(evidence.path_join("response.json")))
   if response is Dictionary and response.get("id")==request_id:break
  await process_frame
 check(Time.get_ticks_msec()<deadline,"native parent resize acknowledged")
 await create_timer(.35).timeout;await settle()
 check(root.size==dims,"native parent resize reaches "+str(dims))
func clear_point(at: Vector2) -> bool:
 if not game.board.get_global_rect().has_point(at):return false
 for control in [game.hud.left_panel,game.hud.right_panel,game.hud.deployment_bar,game.hud.deployment_actions]:
  if control.visible and control.get_global_rect().has_point(at):return false
 return true
func deployment_drag():
 var pair=[]
 for ally in game.state().units.filter(func(u):return u.side=="ally"):
  var from=game.board.global_position+game.board.project_cell(int(ally.pos))
  if not clear_point(from):continue
  for cell in range(50):
   if cell%10>=5 or game.state().units.any(func(u):return u.hp>0 and int(u.pos)==cell):continue
   var to=game.board.global_position+game.board.project_cell(cell)
   if clear_point(to):pair=[ally.id,ally.pos,cell,from,to];break
  if not pair.is_empty():break
 check(not pair.is_empty(),"normal deployment exposes ally and legal empty board cell for real drag")
 if pair.is_empty():return
 var before=await saved()
 await os_mouse(pair[3],"drag",pair[4])
 var moved=game.state().units.filter(func(u):return u.id==pair[0])[0]
 check(int(moved.pos)==pair[2] and int(game.state().actions)==0,"actual OS placement drag moves selected ally without consuming battle action")
 var after=await saved()
 check(after.state.gold==before.state.gold and game.campaign().phase=="deployment","placement drag preserves economy and deployment phase")
 await snapshot("placement-drag")
func panel_drag(label: String):
 for panel in [game.hud.left_panel,game.hud.right_panel]:
  var handle=panel.find_child("DragHandle",true,false)
  var point=handle.get_global_rect().get_center()
  var observed={"moving":false}
  var watch=func():
   if panel.dragging and panel.moving:observed.moving=true
  process_frame.connect(watch)
  await os_mouse(point,"drag",Vector2(point.x,root.size.y-3))
  process_frame.disconnect(watch)
  check(observed.moving,"actual OS header enters panel move mode "+str(panel.name)+" "+label)
  record_layout(label+" bottom drag "+str(panel.name))
func run():
 create_timer(300).timeout.connect(func():print("FAIL deployment start GUI watchdog");quit(2))
 check(DisplayServer.get_name()!="headless","deployment start uses real X11 rendering")
 var width=int(OS.get_environment("DEPLOYMENT_WIDTH"));width=1180 if width==0 else width
 var original=Vector2i(width,832 if width==1283 else 1080 if width==1920 else 812)
 root.borderless=true;root.position=Vector2i.ZERO;root.size=original
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true;await settle()
 check(game.campaign().phase=="town" and game.campaign().location=="astaris","fresh isolated profile starts in Astaris square")
 await os_click(node("HubMap"));await os_click(node("Town_east"));await os_click(node("DepartButton"))
 var river=game.find_children("*","Button",true,false).filter(func(b):return b.text.begins_with("川沿いの道"))[0]
 await os_click(river)
 check(game.campaign().phase=="deployment" and game.state().get("deploying",false),"actual OS normal map east river path reaches placement")
 var initial=await saved();record_layout("fresh");await snapshot("deployment-fresh")
 # Probe the untouched central button before any panel or board adjustment.
 await os_click(node("DeploymentBegin"))
 if baseline and width<1920:
  check(game.campaign().phase=="deployment","baseline center click is blocked on small fresh placement")
  check(await saved()==initial,"baseline blocked center click does not start or mutate battle")
  await snapshot("deployment-center-blocked")
 else:
  check(game.campaign().phase=="battle" and not game.state().get("deploying",false),"actual OS central click starts canonical battle")
 # Restore only the save produced by this same normal journey, not a fixture.
 if game.campaign().phase=="battle":await game.update({"op":"campaign_load","data":initial});await settle()
 var before_resize=await saved()
 for dims in [Vector2i(1180,812),Vector2i(1283,832),Vector2i(1920,1080),original]:
  await native_resize(dims);record_layout("placement resized "+str(dims))
 check(await saved()==before_resize,"native parent shrink enlarge restore preserves exact deployment save")
 await snapshot("deployment-resized")
 await deployment_drag()
 var moved=await saved();await panel_drag("deployment")
 check(await saved()==moved,"actual OS panel dragging preserves selected placement and exact save")
 # Reach start through real Tab traversal and execute with Enter.
 var start_button=node("DeploymentBegin")
 for index in range(45):
  if start_button.has_focus():break
  await os_key("Tab")
 check(start_button.has_focus(),"actual OS Tab reaches start button")
 await os_key("Return")
 check(game.campaign().phase=="battle" and not game.state().get("deploying",false),"actual OS Enter starts battle after Tab navigation")
 record_layout("battle footer");await snapshot("battle-started")
 await panel_drag("battle footer")
 var battle=await saved()
 for id in ["BattleHistory","BattleOrderDetails"]:
  await os_click(node(id));check(game.dialog.window!=null and game.dialog.window.title==("戦闘履歴" if id=="BattleHistory" else "順番詳細"),"actual OS opens protected "+id)
  await os_key("Escape")
 check(await saved()==battle,"reading both battle footer controls preserves exact battle save")
 check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"deployment OS BGM voice SE remain OFF")
 for spec in [["checks.json",checks],["deployment-geometry.json",measurements]]:
  var file=FileAccess.open(evidence.path_join(spec[0]),FileAccess.WRITE);file.store_string(JSON.stringify(spec[1],"\t"));file.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
