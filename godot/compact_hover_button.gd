extends Control
## Keep the full inspection text on the source, not in a second native tooltip.
var heading := ""
var hover_body := ""
var hover_window: Control
var hover_generation := 0
var hover_connected := false
var pointer_over := false

func connect_hover():
	if hover_connected:return
	hover_connected=true
	mouse_entered.connect(queue_hover)
	mouse_exited.connect(func():pointer_over=false;close_hover())
	if has_signal("pressed"):connect("pressed",close_hover)
	visibility_changed.connect(close_hover)

func _get_tooltip(_at: Vector2) -> String:return ""

func queue_hover():
	pointer_over=true
	hover_generation+=1
	var generation=hover_generation
	get_tree().create_timer(.45).timeout.connect(func():
		if generation==hover_generation and is_visible_in_tree() and pointer_over and not get_viewport().gui_is_dragging():show_hover())

func show_hover():
	if heading.is_empty() or not is_inside_tree():return
	for popup in get_tree().get_nodes_in_group("equipment_full_hover"):
		if popup!=hover_window:popup.hide()
	if not is_instance_valid(hover_window):
		hover_window=preload("res://equipment_hover_popup.gd").new()
		hover_window.source=self
		var layer=CanvasLayer.new();layer.name="CompactHoverLayer";layer.layer=1025
		get_tree().root.add_child(layer);layer.add_child(hover_window)
	hover_window.present()

func close_hover():
	hover_generation+=1
	if is_instance_valid(hover_window):hover_window.hide()

func _notification(what):
	if what==NOTIFICATION_DRAG_BEGIN:close_hover()

func _exit_tree():
	close_hover()
	if is_instance_valid(hover_window) and is_instance_valid(hover_window.get_parent()):
		hover_window.get_parent().queue_free()

func brief() -> String:return hover_body
