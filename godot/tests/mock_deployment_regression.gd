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
 var chooser=strip.find_child("PartyJobFilter",true,false)
 var first_job=cards.get_child(0).get_meta("roster_job")
 for index in range(chooser.item_count):
  if chooser.get_item_metadata(index)==first_job:
   chooser.select(index);chooser.item_selected.emit(index);break
 await settle()
 check(cards.get_children().all(func(card):return card.visible==(card.get_meta("roster_job")==first_job)),"deployment filter limits visible cards to the chosen job")
 chooser.select(0);chooser.item_selected.emit(0);await settle()
 var cell=Vector2(root.size)/10
 var roster_rect=strip.get_global_rect()
 check(strip.find_child("PartyRoster",true,false)!=null and roster_rect==Rect2(Vector2(0,cell.y),cell*Vector2(2,8)),"deployment uses the shared roster in the left two grid columns")
 check(cards.vertical and strip.scroll.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_AUTO,"deployment roster uses vertical scrolling")
 check(field==Rect2(Vector2.ZERO,Vector2(root.size)) and roster_rect.position.y==sidebar.position.y and roster_rect.end.y==sidebar.end.y,"roster, battlefield and inspector align on shared grid edges")
 check(not strip.get_global_rect().intersects(game.find_child("CommonMenuButton",true,false).get_global_rect()),"roster avoids menu")
 for i in range(1,cards.get_child_count()):
  check(cards.get_child(i).position.y>=cards.get_child(i-1).position.y+cards.get_child(i-1).size.y,"member rows do not overlap")
 check(not roster_rect.intersects(sidebar),"field separate from right inspector")
 check(not sidebar.intersects(game.find_child("CommonMenuButton",true,false).get_global_rect()),"inspector avoids menu")
 var footer=game.find_child("DeploymentFooter",true,false).get_global_rect()
 var central=Rect2(0,cell.y,root.size.x,cell.y*8)
 check([sidebar,roster_rect].all(func(rect):return central.encloses(rect)),"deployment body leaves both outer rows free")
 check(footer==Rect2(0,cell.y*9,root.size.x,cell.y) and footer.encloses(game.hud.deployment_actions.get_global_rect()) and footer.encloses(game.hud.deployment_instructions.get_global_rect()),"deployment instructions and actions share the bottom footer row")
 check(central.encloses(game.hud.camera_hint.get_parent().get_global_rect()) and not footer.intersects(game.hud.camera_hint.get_parent().get_global_rect()),"deployment controls and help leave both common rows and the field clear")
 check(game.find_child("DeploymentFormationWindow",true,false)==null and game.find_child("EnemyJobFilter",true,false)!=null,"obsolete formation presets removed and enemy job filter present")
 var start=game.find_child("DeploymentBegin",true,false)
 check(start.is_visible_in_tree() and not start.disabled and Rect2(Vector2.ZERO,Vector2(root.size)).encloses(start.get_global_rect()),"start readable and inside FHD")
 check(not sidebar.intersects(start.get_global_rect()) and not strip.get_global_rect().intersects(start.get_global_rect()),"start does not cover field or roster")
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
 check(game.hud.selected_enemy==enemy.id and game.modal_open(),"board enemy opens inspection")
 game.dialog.close();await settle()
 var enemy_card=game.hud.right_panel.body.find_child("DeploymentEnemy_"+str(enemy.id),true,false)
 check(enemy_card!=null and enemy_card.find_children("*","Label",true,false).any(func(l):return l.text==enemy.name),"enemy roster shows the same named member")
 enemy_card.pressed.emit();await settle()
 var enemy_tabs=game.dialog.window.find_child("LoadoutTabBar",true,false)
 check(game.modal_open() and enemy_tabs.is_visible_in_tree() and game.dialog.window.find_child("BattleSlot_rightHand",true,false).is_visible_in_tree(),"enemy equipment exposes its tabs and right-hand slot")
 var weapon=game.dialog.window.find_child("BattleSlot_rightHand",true,false)
 weapon.pressed.emit();await settle()
 var equipped=enemy.get("equipment",{}).get("rightHand","")
 var details=game.dialog.window.find_child("SkillDetailsWindow",true,false)
 var title=details.find_child("SkillDetailsTitle",true,false) if details!=null else null
 var body=details.find_child("SkillDetailsBody",true,false) if details!=null else null
 check(not equipped.is_empty() and details!=null and details.visible and title!=null and not title.text.is_empty() and weapon.tooltip_text.ends_with(" / "+title.text) and body!=null and not body.text.is_empty(),"enemy weapon opens its common description over the equipment sheet")
 if details!=null:details.finish();await settle()
 game.dialog.window.find_child("BattleLoadoutTab_inventory",true,false).pressed.emit();await settle()
 check(game.dialog.window.find_child("BattleInventory",true,false)!=null,"enemy inventory tab switches within the same detail window")
 game.dialog.close();await settle()
 await game.on_cell(int(pos));await settle()
 check(game.hud.selected_enemy=="","ally selection restores inspector")
 await game.deployment_assigned(id,null);await settle()
 var reserve=game.find_child("PartyFace_"+str(id),true,false)
 check(reserve!=null and game.find_child("DeploymentReserves",true,false)==null,"removed member appears in reserves")
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
 await game.act("deployment_reset",[]);await settle()
 check(not game.hud.deployment_changed(),"reset preserved")
 var begin=game.find_child("DeploymentBegin",true,false)
 check(begin.is_visible_in_tree() and not begin.disabled,"the deployed party can start battle")
 begin.pressed.emit()
 var deadline=Time.get_ticks_msec()+10000
 while Time.get_ticks_msec()<deadline:
  if game.campaign().phase=="battle" and not game.presenting and game.hud.left_panel.is_visible_in_tree():break
  await process_frame
 check(not game.state().get("deploying",false) and game.board.get_global_rect()==Rect2(Vector2.ZERO,Vector2(root.size)),"starting battle retains the canonical deployment field rectangle")
 check(game.hud.left_panel.visible and game.hud.right_panel.find_child("DragHandle",true,false).visible,"battle inspector headers restored")
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await settle();quit(0 if failures.is_empty() else 1)
