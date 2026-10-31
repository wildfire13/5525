extends Node
## CI viewport invariant; child dialogs may still be resized within the FHD game.
const FHD = Vector2i(1920,1080)
var observed := false
var failed := false
func _process(_delta: float) -> void:
 var window=get_tree().root
 var visible=Vector2i(window.get_visible_rect().size)
 if window.size!=FHD or visible!=FHD:
  if not failed:
   failed=true
   push_error("FHD contract: root="+str(window.size)+" viewport="+str(visible))
 elif not observed:
  observed=true
  print("PASS FHD contract: window and viewport 1920x1080")
func _exit_tree() -> void:
 if not observed:push_error("FHD contract: no verified frame")
