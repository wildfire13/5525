extends RefCounted
## One exclusive session-only detail window, with context-checked restoration.
var ui
var window: Window
var body: VBoxContainer
var actions: HBoxContainer
var restore_callback: Callable
var checkpoint: Dictionary={}
var origin := ""
var epoch := -1
var connection := -1
var close_guard: Callable
func _init(frontend):ui=frontend
func open(title: String, builder: Callable, closed: Callable=Callable()) -> Window:
	ui.pages.shop_view.cancel_pending()
	close(false)
	close_guard=Callable()
	ui.memory.capture();checkpoint=ui.memory.scrolls.duplicate(true);origin=ui.memory.focus_key
	epoch=ui.pages.epoch;connection=ui.engine.connection_generation;restore_callback=closed
	window=Window.new();window.name="StateDetails";window.title=title;window.exclusive=true;window.transient=true;window.unresizable=true
	ui.add_child(window)
	var margin=preload("res://modal_input.gd").new();margin.owner_ref=weakref(self);window.add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,12)
	var box=VBoxContainer.new();box.add_theme_constant_override("separation",8);margin.add_child(box)
	ui.label_(box,title,true)
	body=ui.scroller(box);body.get_parent().name="ModalDetailScroll";body.get_parent().custom_minimum_size.y=80
	actions=ui.row(box);actions.name="ModalActions"
	builder.call(body,actions)
	if actions.get_child_count()==0:ui.local_button(actions,"閉じる",close)
	window.close_requested.connect(close)
	window.window_input.connect(func(event):
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
			window.set_input_as_handled();ui.get_viewport().set_input_as_handled();ui.modal_escape_frame=Engine.get_process_frames();close())
	resize();window.popup_centered()
	if actions.get_child_count()>0:actions.get_child(0).grab_focus()
	return window
func resize():
	if not is_instance_valid(window):return
	var status=window.title=="ステータス"
	window.size=Vector2i(mini(1040 if status else 840,int(ui.size.x)-32),mini(780 if status else 620,int(ui.size.y)-72))
	window.position=Vector2i((ui.size-Vector2(window.size))/2)
func close(restore:=true):
	if not is_instance_valid(window):return
	if restore and close_guard.is_valid():
		var finish=func():close_guard=Callable();close(restore)
		if not close_guard.call(finish):return
	var old=window;window=null;old.hide();old.queue_free()
	close_guard=Callable()
	var valid=restore and not ui.closing and epoch==ui.pages.epoch and connection==ui.engine.connection_generation
	if valid:
		if restore_callback.is_valid():restore_callback.call()
		ui.memory.scrolls.merge(checkpoint,true);ui.memory.request_focus(origin);ui.memory.restore()
	restore_callback=Callable()
