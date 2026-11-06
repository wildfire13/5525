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
 check(not field.intersects(sidebar),"field separate from right inspector")
 check(game.hud.deployment_bar.get_global_rect().end.y<=field.position.y and game.hud.deployment_bar.size.y<=90,"compact formation row above battlefield")
 check(game.hud.deployment_options.find_children("*","Button",true,false).all(func(button):return button.size.y<=72),"formation controls stay under 72 pixels")
 var start=game.find_child("DeploymentBegin",true,false)
 check(start.get_global_rect().size.x>=150 and Rect2(Vector2.ZERO,Vector2(root.size)).encloses(start.get_global_rect()),"start readable and inside FHD")
 var ally=game.state().units.filter(func(u):return u.side=="ally")[0];var id=ally.id;var pos=ally.pos
 var enemy=game.state().units.filter(func(u):return u.side=="enemy")[0]
 await game.on_cell(int(enemy.pos));await settle()
 check(game.hud.selected_enemy==enemy.id and game.hud.right_panel.body.find_children("*","Label",true,false).any(func(l):return l.text==enemy.name),"enemy inspection in same sidebar")
 await game.on_cell(int(pos));await settle()
 check(game.hud.selected_enemy=="","ally selection restores inspector")
 await game.deployment_assigned(id,null);await settle()
 check(game.find_child("DeploymentReserves",true,false).find_children("*","Button",true,false).size()>0,"removed member appears in reserves")
 var drag=preload("res://deployment_drag.gd");var payload=drag.make_payload(game,id,"party")
 check(payload is Dictionary and drag.valid(game,payload),"reserve drag uses validated existing payload")
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
