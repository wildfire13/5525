extends SceneTree
## Exercise the actual menu signal and production shutdown; success exits via close_game.
var game
var shutdown_elapsed=-1.0
func _process(delta):
 if shutdown_elapsed>=0:
  shutdown_elapsed+=delta
  if shutdown_elapsed>15:
   push_error("Production shutdown did not exit within 15 seconds");quit(1)
 return false
func _initialize():call_deferred("run")
func run():
 var isolation=OS.get_environment("MENU_EXIT_QA_ROOT").replace("\\","/")
 if isolation.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(isolation.to_lower()+"/"):
  push_error("User data must be isolated");quit(2);return
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true
 game.open_menu()
 var button=game.find_child("QuitGame",true,false)
 if button==null or not button.is_visible_in_tree() or button.disabled:
  push_error("QuitGame must be available in the open menu");quit(1);return
 print("PASS QuitGame available")
 button.pressed.emit()
 if not game.closing:
  push_error("QuitGame did not enter close_game");quit(1);return
 print("PASS QuitGame entered production shutdown; successful process exit is required")
 shutdown_elapsed=0.0
