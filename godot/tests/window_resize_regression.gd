extends "res://tests/ui_feedback_20261016.gd"
const Grid=preload("res://screen_grid.gd")
func rect(w: Window) -> Rect2:
 return Rect2(Vector2(w.position)-game.preferences.window_origin(w),Vector2(w.size))
func on_grid(r: Rect2) -> bool:
 var view=Vector2(root.size)
 var indices=(r.position*10/view).round()
 var spans=(r.size*10/view).round()
 return Grid.cell_rect(view,0,1,10,8).encloses(r) and r==Grid.cell_rect(view,int(indices.x),int(indices.y),int(spans.x),int(spans.y))
func contained(c: Control) -> bool:
 var w=c.get_window()
 return Rect2(Vector2.ZERO,Vector2(w.size)).encloses(c.get_global_rect()) and Rect2(Vector2.ZERO,Vector2(root.size)).encloses(Rect2(c.get_global_rect().position+Vector2(w.position),c.size))
func run():
 create_timer(150).timeout.connect(func():print("FAIL window resize watchdog");quit(2))
 root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true;await settle()
 var expected=Grid.cell_rect(Vector2(root.size),3,2,1,1).position
 var prefs=game.preferences
 var old_extent=Vector2(560,300)
 var previous=Rect2((game.size-old_extent+prefs.TITLE_MARGIN)/2,old_extent)
 for key in ["old-default","hand-placed"]:
  if prefs.config.has_section_key("layout_origin_v2",key):prefs.config.erase_section_key("layout_origin_v2",key)
  var stored=previous if key=="old-default" else Rect2(Vector2(74,96),old_extent)
  prefs.store_rect(key,stored)
  var probe=Window.new();game.add_child(probe);prefs.bind_window(probe,key,game.size,old_extent)
  check(rect(probe).position==(expected if key=="old-default" else Grid.cell_rect(Vector2(root.size),0,2 if probe.is_embedded() else 1,1,1).position) and on_grid(rect(probe)),key+" layout restored on the intended cells")
  probe.queue_free();await settle()
 game.open_menu();await settle()
 check(Rect2(game.menu.position,game.menu.size)==Grid.cell_rect(Vector2(root.size),3,1,3,8),"menu occupies its registered cells");game.menu.hide()
 var confirmation=game.confirm("確認",func():pass);await settle()
 var detail_frame=preload("res://window_grid.gd").frame_rect(Vector2(root.size))
 check(rect(confirmation)==detail_frame,"confirmation opens in the shared frame");confirmation.canceled.emit();await settle()
 game.portrait_dialog();await settle()
 var chooser=node("PortraitChooser");check(rect(chooser)==detail_frame,"portrait chooser opens in the shared frame");chooser.close_requested.emit();await settle()
 var ordinary=game.dialog.open("通知の詳細",func(_body,_actions):pass);await settle()
 check(rect(ordinary)==detail_frame,"detail opens in the shared frame")
 game.dialog.close();await settle()
 if game.debug_view.is_enabled() and DisplayServer.get_name()!="headless":
  game.debug_view.open();await settle()
  var dev=game.debug_view.window
  check(rect(dev).position==Grid.cell_rect(Vector2(root.size),3,1,1,1).position and on_grid(rect(dev)),"native developer window fits between the reserved rows in desktop coordinates")
  dev.hide();await settle()
 game.navigate("character");game.pages.party_view.workspace.set_tab("skills");await settle()
 var skills=game.find_children("CharacterSkill_active_*","Button",true,false)
 check(not skills.is_empty(),"active member has a skill explanation")
 if skills.is_empty():quit(1);return
 var origin=str(skills[0].name)
 node(origin).grab_focus();await click(origin);var before=await saved()
 var detail=node("SkillDetailsWindow")
 check(rect(detail)==detail_frame,"equipment skill description opens in the shared frame")
 var moved=Rect2(detail_frame.position+Vector2(192,0),detail_frame.size)
 detail.position=Vector2i(detail_frame.position+Vector2(192,-108)+prefs.window_origin(detail));await settle()
 check(node("SkillDetailsWindow")==detail and rect(detail)==moved,"skill detail moves horizontally without entering the top reserved row")
 detail.position.y+=216;await settle()
 check(rect(detail)==moved,"skill detail cannot enter the bottom reserved row")
 check(contained(node("SkillDetailsBack")) and contained(node("SkillDetailsSummary")),"fixed summary and back fit both child and parent")
 check(await saved()==before,"relayout changes no campaign or owner")
 await click("SkillDetailsBack");check(node(origin).has_focus(),"closing the moved detail restores focus to the same skill button")
 await click(origin)
 check(rect(node("SkillDetailsWindow"))==detail_frame,"skill detail opens again in the shared frame")
 await click("SkillDetailsBack")
 # Long titles and summary still leave the fixed close action reachable.
 var copy=preload("res://skill_text.gd");var doc=copy.document("skill_leg_sweep","長い足払いの名前".repeat(10),3,game.campaign())
 var extra=preload("res://skill_details.gd").new();game.add_child(extra);extra.configure(game,doc,"ガロ / 長い装備の名前".repeat(8));await settle();root.size=Vector2i(1920,1080);await settle()
 check(contained(node("SkillDetailsBack")) and contained(node("SkillDetailsSummary")),"long title context and sweep area leave footer inside FHD")
 await click("SkillDetailsBack")
 # More than one managed child must update independently, including nested ones.
 var first=Window.new();game.add_child(first);game.preferences.bind_window(first,"resize-test-one",game.size,Vector2(800,650),Vector2(560,560));first.popup()
 var second=Window.new();first.add_child(second);game.preferences.bind_window(second,"resize-test-two",game.size,Vector2(620,630),Vector2(420,600));second.popup()
 var original=[rect(first),rect(second)]
 first.size+=Vector2i(170,95);second.position+=Vector2i(Grid.cell_rect(game.size,0,0,1,1).size.x,0);await settle()
 for w in [first,second]:check(on_grid(rect(w)) and w.min_size.x<=w.size.x and w.min_size.y<=w.size.y,"nested managed child fits the FHD game grid")
 check(rect(first).size!=original[0].size and rect(second).position!=original[1].position,"resizing one child and moving another applies independently")
 second.hide();second.queue_free();first.hide();first.queue_free();await settle()
 game.preferences.store_rect("resize-reopen",Rect2(42,72,560,400))
 for i in range(3):
  var reopened=Window.new();game.add_child(reopened);game.preferences.bind_window(reopened,"resize-reopen",game.size,Vector2(560,400));reopened.popup();await settle()
  check(rect(reopened).position==Grid.cell_rect(Vector2(root.size),0,2 if reopened.is_embedded() else 1,1,1).position and on_grid(rect(reopened)),"reopening saved child keeps the same grid origin "+str(i))
  reopened.hide();reopened.queue_free();await settle()
 check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"resize regression keeps all audio OFF")
 var f=FileAccess.open(evidence.path_join("window-resize-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
