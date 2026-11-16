extends SceneTree
var failures=[]
func _initialize():call_deferred("run")
func check(value,text):
 print(("PASS " if value else "FAIL ")+text)
 if not value:failures.append(text)
func settle():
 for i in range(8):await process_frame
func run():
 root.size=Vector2i(1920,1080)
 var game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true
 await game.act("depart",["east","convoy"]);await game.act("travel",["safe"]);await settle()
 check(not game.hud.left_panel.visible,"single right inspector")
 var field=game.board.get_global_rect();var sidebar=game.hud.right_panel.get_global_rect()
 var strip=game.deployment_party_strip
 var cards=strip.scroll.get_child(0)
 check(strip.find_child("PartyRoster",true,false)!=null and strip.size.x==game.mock_shell.ROSTER_WIDTH,"deployment uses the campaign roster and its width")
 check(cards.vertical and strip.scroll.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_AUTO,"deployment roster uses vertical scrolling")
 check(strip.get_global_rect().end.x<field.position.x and not strip.get_global_rect().intersects(sidebar),"roster left, battlefield center, inspector right")
 check(not strip.get_global_rect().intersects(game.find_child("CommonMenuButton",true,false).get_global_rect()),"roster avoids menu")
 for i in range(1,cards.get_child_count()):
  check(cards.get_child(i).position.y>=cards.get_child(i-1).position.y+cards.get_child(i-1).size.y,"member rows do not overlap")
 check(not field.intersects(sidebar),"field separate from right inspector")
 check(not sidebar.intersects(game.find_child("CommonMenuButton",true,false).get_global_rect()),"inspector avoids menu")
 check(game.hud.deployment_bar.get_global_rect().end.y<=field.position.y and game.hud.deployment_bar.size.y<=90,"compact formation row above battlefield")
 check(game.hud.deployment_options.find_children("*","Button",true,false).all(func(button):return button.size.y<=72),"formation controls stay under 72 pixels")
 var start=game.find_child("DeploymentBegin",true,false)
 check(start.get_global_rect().size.x>=150 and Rect2(Vector2.ZERO,Vector2(root.size)).encloses(start.get_global_rect()),"start readable and inside FHD")
 check(not field.intersects(start.get_global_rect()) and not strip.get_global_rect().intersects(start.get_global_rect()),"start does not cover field or roster")
 if DisplayServer.get_name()!="headless" and not OS.get_environment("DEPLOYMENT_CAPTURE").is_empty():
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OS.get_environment("DEPLOYMENT_CAPTURE"))
 cards.custom_minimum_size.y=strip.size.y+400;await settle()
 strip.scroll.scroll_vertical=240;await settle()
 check(strip.scroll.scroll_vertical>0,"vertical overflow scroll reaches lower members")
 cards.custom_minimum_size.y=0;strip.scroll.scroll_vertical=0;await settle()
 var ally=game.state().units.filter(func(u):return u.side=="ally")[0];var id=ally.id;var pos=ally.pos
 var original_board=game.board
 game.find_child("PartyFace_"+str(id),true,false).pressed.emit();await settle()
 check(not original_board.is_visible_in_tree() and not original_board.can_process(),"inspected deployment board is suspended")
 check(game.page=="character" and game.pages.party_uid==id and game.find_child("CharacterPortrait",true,false)!=null and not game.modal_open(),"deployment card opens the shared full-page party information")
 if DisplayServer.get_name()!="headless" and not OS.get_environment("CHARACTER_DEPLOYMENT_CAPTURE").is_empty():
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OS.get_environment("CHARACTER_DEPLOYMENT_CAPTURE"))
 var workspace=game.pages.party_view.workspace
 for tab in ["inventory","ability","skills","equipment"]:
  workspace.set_tab(tab);await settle()
  check(workspace.tab==tab and game.page=="character","deployment opens shared "+tab+" tab")
 var other=game.campaign().selected.filter(func(uid):return uid!=id)[0]
 game.find_child("RosterMember_"+str(other),true,false).pressed.emit();await settle()
 check(game.pages.party_uid==other,"shared roster switches inspected member")
 game.find_child("RosterMember_"+str(other),true,false).pressed.emit();await settle()
 check(game.board==original_board and original_board.can_process() and original_board.is_visible_in_tree(),"return reuses the live deployment board")
 check(game.view_kind=="battle" and game.campaign().phase=="deployment" and game.state().units.any(func(u):return u.id==id and u.pos==pos),"closing party information restores unchanged deployment")
 var enemy=game.state().units.filter(func(u):return u.side=="enemy")[0]
 await game.on_cell(int(enemy.pos));await settle()
 check(game.hud.selected_enemy==enemy.id and game.hud.right_panel.body.find_children("*","Label",true,false).any(func(l):return l.text==enemy.name),"enemy inspection in same sidebar")
 await game.on_cell(int(pos));await settle()
 check(game.hud.selected_enemy=="","ally selection restores inspector")
 await game.deployment_assigned(id,null);await settle()
 check(game.find_child("DeploymentReserves",true,false).find_children("*","Button",true,false).size()>0,"removed member appears in reserves")
 var reserve=game.find_child("DeploymentReserves",true,false).find_children("*","Button",false,false)[0]
 reserve.pressed.emit();await settle()
 check(game.page=="character" and game.pages.party_uid==id,"reserve inspection uses the same party information")
 game.find_child("Header_character",true,false).pressed.emit();await settle()
 var drag=preload("res://deployment_drag.gd");var payload=drag.make_payload(game,id,"party")
 check(payload is Dictionary and drag.valid(game,payload),"reserve drag uses validated existing payload")
 var card=game.find_child("PartyFace_"+str(id),true,false)
 card.force_drag(payload,Control.new());await settle()
 check(root.gui_is_dragging(),"existing member card starts viewport drag")
 var cancel=InputEventKey.new();cancel.keycode=KEY_ESCAPE;cancel.pressed=true;root.push_input(cancel);await settle()
 check(not root.gui_is_dragging(),"drag cancels and allows another operation")
 await game.deployment_assigned(id,int(pos));await settle()
 check(game.state().units.any(func(u):return u.id==id),"reserve reassignment preserved")
 await game.act("chooseFormation",["flank"]);await settle()
 check(game.state().formationKind=="flank","formation choice preserved")
 await game.act("deployment_reset",[]);await settle()
 check(not game.hud.deployment_changed(),"reset preserved")
 await game.act("begin",[]);await settle()
 check(not game.state().get("deploying",false) and not game.board.get_global_rect().intersects(game.hud.right_panel.get_global_rect()),"battle begins with field separate from inspector")
 check(game.hud.left_panel.visible and game.hud.right_panel.find_child("DragHandle",true,false).visible,"battle inspector headers restored")
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await settle();quit(0 if failures.is_empty() else 1)
