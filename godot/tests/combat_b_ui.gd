extends SceneTree
var game
var output=OS.get_environment("BATTLE_CAPTURE")
var failures=[]
func _initialize():call_deferred("run")
func check(ok,label):
 print(("PASS " if ok else "FAIL ")+label)
 if not ok:failures.append(label)
func settle():
 for i in range(25):await process_frame
 while game.locked or game.engine.busy or game.presenting:await process_frame
 await create_timer(.15).timeout
func shot(name):
 if output.is_empty():return
 await settle();await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run():
 create_timer(110).timeout.connect(func():print("FAIL watchdog");quit(2))
 if not output.is_empty():DirAccess.make_dir_recursive_absolute(output)
 root.size=Vector2i(1920,1080)
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true
 await game.act("depart",["east","convoy"]);await game.act("travel",["safe"]);await game.act("begin",[]);await settle()
 await shot("18-battle-command")
 game.choose_command("move");await settle()
 var moves=game.data.choices.get("move",[])
 check(not moves.is_empty(),"move choices available")
 if not moves.is_empty():
  var at=game.board.global_position+game.board.project_cell(int(moves[0]))
  for pressed in [true,false]:
   var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=at;event.global_position=at;root.push_input(event,true);await process_frame
  await settle()
 check(game.pending!=null,"projected board click selects move preview")
 await shot("19-battle-move")
 game.cancel();await settle();check(game.pending==null,"move cancellation")
 game.hud.back_to_commands();game.hud.choose_command("skill");await settle();await shot("20-battle-skills")
 game.hud.back_to_commands();game.choose_command("guard");await settle();await shot("21-battle-guard")
 game.hud.back_to_commands();game.open_menu();await shot("22-battle-menu");game.menu.hide()
 var actions_before=int(game.state().get("actions",0));game.choose_command("guard");await settle();await game.commit();await settle()
 check(int(game.state().get("actions",0))>actions_before,"guard executes and advances actual turn")
 if game.find_child("QuitGame",true,false)!=null:
  var field=game.board.get_global_rect()
  check(not field.intersects(game.hud.left_panel.get_global_rect()) and not field.intersects(game.hud.right_panel.get_global_rect()),"board separate from both information panels")
  check(range(50).all(func(cell):return field.has_point(game.board.global_position+game.board.project_cell(cell))),"all fifty cell centers visible")
  check(game.theme.default_font_size==20,"B base font")
  check(game.hud.left_panel.get_theme_stylebox("panel").bg_color.is_equal_approx(Color(250.0/255,249.0/255,245.0/255,.90)),"B panel palette")
  check(abs(game.hud.left_panel.global_position.y-game.hud.right_panel.global_position.y)<2,"aligned information columns")
  check(game.find_child("QuitGame",true,false).text=="ゲームを終了する","exit menu item")
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
