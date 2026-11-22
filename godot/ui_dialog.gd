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
func open(title: String, builder: Callable, closed: Callable=Callable(),initial_rect:=Rect2()) -> Window:
	ui.pages.shop_view.cancel_pending()
	close(false)
	close_guard=Callable()
	escape_handler=Callable()
	ui.memory.capture();checkpoint=ui.memory.scrolls.duplicate(true);origin=ui.memory.focus_key
	epoch=ui.pages.epoch;connection=ui.engine.connection_generation;restore_callback=closed
	window=Window.new();window.name="StateDetails";window.title=title;window.exclusive=true;window.transient=true
	ui.add_child(window)
	var margin=preload("res://modal_input.gd").new();margin.owner_ref=weakref(self);window.add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,0)
	var box=preload("res://window_grid.gd").new();margin.add_child(box)
	if not initial_rect.has_area() and title not in ["行動ログ","商品と装備の比較","荷物を持つポーターを選択"]:ui.label_(box,title,true)
	body=ui.scroller(box);body.get_parent().name="ModalDetailScroll";body.get_parent().custom_minimum_size.y=80
	actions=ui.row(box);actions.name="ModalActions"
	builder.call(body,actions)
	for child in body.get_children():
		if child.name not in ["ActionLogHistory","QuestCargoChoices","PortraitFraming"]:continue
		var content=preload("res://window_grid.gd").new();content.scroll_content=true
		content.size_flags_vertical=Control.SIZE_EXPAND_FILL
		var children=body.get_children()
		body.add_theme_constant_override("separation",0);body.add_child(content)
		for item in children:item.reparent(content)
		break
	if actions.get_child_count()==0:ui.local_button(actions,"閉じる",close)
	window.close_requested.connect(close)
	window.window_input.connect(func(event):
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
			window.set_input_as_handled();ui.get_viewport().set_input_as_handled();ui.modal_escape_frame=Engine.get_process_frames();escape())
	place_window(initial_rect);window.popup()
	if actions.get_child_count()>0:actions.get_child(0).grab_focus()
	return window
func layout_key() -> String:
	return "dialog:"+window.title.get_slice(" / ",0)
func remember():
	if is_instance_valid(window):
		ui.preferences.keep_visible(window,ui.size)
		ui.preferences.remember_window(window,layout_key())
func place_window(initial_rect: Rect2):
	var extent=ui.preferences.DEFAULT_DIALOG_SIZE
	if window.title=="商品と装備の比較":extent=Vector2(1280,680)
	elif window.title=="荷物を持つポーターを選択":extent=Vector2(840,420)
	var fallback=initial_rect if initial_rect.has_area() else ui.preferences.default_window_rect(ui.size,extent)
	var key=layout_key()
	if initial_rect.has_area() and window.title.ends_with("の画像"):
		var saved=ui.preferences.config.get_value("windows",key,Rect2())
		if saved is Rect2 and saved.size==ui.preferences.DEFAULT_DIALOG_SIZE:
			ui.preferences.store_rect(key,Rect2(saved.position,initial_rect.size))
	if window.title=="商品と装備の比較" and not ui.preferences.config.get_value("migration","shop_feedback30",false):
		var rect=ui.preferences.rect_for(key,fallback,ui.size,Vector2(420,300))
		rect.size.x=maxf(rect.size.x,minf(extent.x,ui.size.x-32))
		ui.preferences.config.set_value("migration","shop_feedback30",true);ui.preferences.store_rect(key,rect)
	var previous=initial_rect if initial_rect.has_area() else Rect2((ui.size-extent)/2,extent)
	ui.preferences.place_window(window,key,ui.size,fallback,Vector2(420,300),previous)
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
