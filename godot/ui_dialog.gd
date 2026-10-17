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
var escape_handler: Callable
var escape_frame := -1
func _init(frontend):ui=frontend
func open(title: String, builder: Callable, closed: Callable=Callable()) -> Window:
	ui.pages.shop_view.cancel_pending()
	close(false)
	close_guard=Callable()
	escape_handler=Callable()
	ui.memory.capture();checkpoint=ui.memory.scrolls.duplicate(true);origin=ui.memory.focus_key
	epoch=ui.pages.epoch;connection=ui.engine.connection_generation;restore_callback=closed
	window=Window.new();window.set_meta("managed_layout",true);window.name="StateDetails";window.title=title;window.exclusive=title!="ステータス";window.transient=true;window.unresizable=false;window.min_size=Vector2i(420,300)
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
			window.set_input_as_handled();ui.get_viewport().set_input_as_handled();ui.modal_escape_frame=Engine.get_process_frames();escape())
	resize();window.popup()
	if actions.get_child_count()>0:actions.get_child(0).grab_focus()
	return window
func layout_key() -> String:
	return "status" if window.title=="ステータス" else "dialog:"+window.title.get_slice(" / ",0)
func remember():
	if is_instance_valid(window):keep_visible();ui.preferences.store_rect(layout_key(),Rect2(Vector2(window.position),Vector2(window.size)))
func keep_visible():
	if not is_instance_valid(window):return
	var available=ui.size
	if window.title=="ステータス":
		var faces=ui.find_child("PartyFaceBar",true,false)
		if faces!=null and faces.is_visible_in_tree():available.y=minf(available.y,faces.global_position.y-8)
	ui.preferences.keep_visible(window,available)
func resize():
	if not is_instance_valid(window):return
	var status=window.title=="ステータス"
	var extent=Vector2(1040,780) if status else Vector2(840,620)
	var rect=ui.preferences.rect_for(layout_key(),Rect2((ui.size-extent)/2,extent),ui.size,Vector2(420,300))
	window.size=Vector2i(rect.size);window.position=Vector2i(rect.position.max(Vector2(0,36)))
func escape():
	# Window and its input margin can both receive the same key event.
	var frame=Engine.get_process_frames()
	if escape_frame==frame:return
	escape_frame=frame
	if escape_handler.is_valid() and escape_handler.call():return
	close()
func close(restore:=true):
	if not is_instance_valid(window):return
	if restore and close_guard.is_valid():
		var finish=func():close_guard=Callable();close(restore)
		if not close_guard.call(finish):return
	remember()
	var old=window;window=null;old.hide();old.queue_free()
	close_guard=Callable()
	escape_handler=Callable()
	var valid=restore and not ui.closing and epoch==ui.pages.epoch and connection==ui.engine.connection_generation
	if valid:
		if restore_callback.is_valid():restore_callback.call()
		ui.memory.scrolls.merge(checkpoint,true);ui.memory.request_focus(origin);ui.memory.restore()
	restore_callback=Callable()
