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
 game.choose_command("action_move");await settle()
 var moves=game.data.choices.get("action_move",[])
 check(not moves.is_empty(),"move choices available")
 if not moves.is_empty():
  var at=game.board.global_position+game.board.project_cell(int(moves[0]))
  for pressed in [true,false]:
   var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=at;event.global_position=at;root.push_input(event,true);await process_frame
  await settle()
 check(game.pending!=null,"projected board click selects move preview")
 await shot("19-battle-move")
 game.cancel();await settle();check(game.pending==null,"move cancellation")
 game.hud.back_to_commands();game.hud.choose_command("action_skill");await settle();await shot("20-battle-skills")
 game.hud.back_to_commands();game.choose_command("action_defend");await settle();await shot("21-battle-guard")
 game.hud.back_to_commands();game.open_menu();await shot("22-battle-menu");game.menu.hide()
 var actions_before=int(game.state().get("actions",0));game.choose_command("action_defend");await settle();await game.commit();await settle()
 check(int(game.state().get("actions",0))>actions_before,"guard executes and advances actual turn")
 if game.find_child("QuitGame",true,false)!=null:
  var field=game.board.get_global_rect()
  check(field.position.is_equal_approx(Vector2.ZERO) and field.size.is_equal_approx(Vector2(root.size)),"battle fills viewport behind information panels")
  check(field.encloses(game.hud.left_panel.get_global_rect()) and field.encloses(game.hud.right_panel.get_global_rect()),"information panels overlay battle")
  var menu_button=game.find_child("CommonMenuButton",true,false)
  check(menu_button.global_position.y<80 and menu_button.global_position.x>root.size.x-160,"battle menu at upper right")
  check(game.find_child("BattleDetails",true,false)==null,"obsolete battle details button removed")
  var hint=game.find_child("BattleCameraHint",true,false)
  check(hint.is_visible_in_tree() and hint.global_position.y>root.size.y-160 and hint.get_global_rect().end.y<=game.battle_header.global_position.y and field.encloses(hint.get_global_rect()),"camera guidance at bottom of battlefield")
  var panels=[game.hud.left_panel.get_global_rect(),game.hud.right_panel.get_global_rect()]
  for cell in range(50):
   var center=game.board.global_position+game.board.project_cell(cell)
   check(field.has_point(center) and not panels.any(func(panel):return panel.has_point(center)),"default camera exposes cell "+str(cell))
  check(game.theme.default_font_size==20,"B base font")
  check(game.hud.left_panel.get_theme_stylebox("panel").bg_color.is_equal_approx(Color(250.0/255,249.0/255,245.0/255,.90)),"B panel palette")
  check(abs(game.hud.left_panel.global_position.y-game.hud.right_panel.global_position.y)<2,"aligned information columns")
  check(game.find_child("QuitGame",true,false).text=="ゲームを終了する","exit menu item")
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
