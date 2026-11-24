extends RefCounted
## One exclusive session-only detail window, with context-checked restoration.
var ui
var window: Window
var layout
var grid_box := Rect2i(2,1,6,8)
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
const Layout=preload("res://window_grid.gd")
const Tokens=preload("res://ui_tokens.gd")
func _init(frontend):ui=frontend
func set_grid_box(new_box: Rect2i):
	grid_box=new_box
	if is_instance_valid(layout):
		layout.grid_box=new_box
		layout.queue_sort()
	if is_instance_valid(window):
		ui.preferences.place_detail_frame(window,Layout.grid_frame_rect(Vector2(ui.get_tree().root.size),new_box))
func open(title: String, builder: Callable, closed: Callable=Callable(),_initial_rect:=Rect2(),box_rect: Rect2i=Rect2i(2,1,6,8)) -> Window:
	ui.pages.shop_view.cancel_pending()
	close(false)
	close_guard=Callable()
	escape_handler=Callable()
	grid_box=box_rect if box_rect.has_area() else Rect2i(2,1,6,8)
	ui.memory.capture();checkpoint=ui.memory.scrolls.duplicate(true);origin=ui.memory.focus_key
	epoch=ui.pages.epoch;connection=ui.engine.connection_generation;restore_callback=closed
	window=Window.new();window.theme=ui.theme;window.name="StateDetails";window.title=title;window.exclusive=true;window.transient=true
	ui.add_child(window)
	var margin=preload("res://modal_input.gd").new();margin.owner_ref=weakref(self);window.add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,0)
	var box=Layout.new();box.grid_box=grid_box;layout=box;margin.add_child(box)
	var heading=Layout.title_label(title);heading.name="ModalHeading";box.add_child(heading)
	body=ui.scroller(box);var detail_scroll: ScrollContainer=body.get_parent();detail_scroll.name="ModalDetailScroll"
	var scroll_pad=StyleBoxEmpty.new()
	scroll_pad.content_margin_left=Tokens.SPACE_LG;scroll_pad.content_margin_right=Tokens.SPACE_LG
	scroll_pad.content_margin_top=Tokens.SPACE_SM;scroll_pad.content_margin_bottom=Tokens.SPACE_SM
	detail_scroll.add_theme_stylebox_override("panel",scroll_pad)
	actions=ui.row(box);actions.name="ModalActions";actions.alignment=BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation",Tokens.SPACE_MD)
	box.set_regions(heading,detail_scroll,actions)
	builder.call(body,actions)
	for child in body.get_children():
		if child.name not in ["ActionLogHistory","QuestCargoChoices","PortraitFraming"]:continue
		detail_scroll.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
		var content=Layout.new();content.scroll_content=true
		content.size_flags_vertical=Control.SIZE_EXPAND_FILL
		var children=body.get_children()
		body.add_theme_constant_override("separation",0);body.add_child(content)
		for item in children:item.reparent(content)
		break
	if actions.get_child_count()==0:ui.local_button(actions,"閉じる",close)
	for child in actions.get_children():
		if child is Button:
			var min_w := maxi(int(child.custom_minimum_size.x),Tokens.BUTTON_W_MD)
			Tokens.apply_button_size(child,Tokens.BUTTON_MD,true,min_w)
	window.close_requested.connect(close)
	window.window_input.connect(func(event):
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
			window.set_input_as_handled();ui.get_viewport().set_input_as_handled();ui.modal_escape_frame=Engine.get_process_frames();escape())
	ui.preferences.place_detail_frame(window,Layout.grid_frame_rect(Vector2(ui.get_tree().root.size),grid_box));window.popup()
	if actions.get_child_count()>0:actions.get_child(0).grab_focus()
	return window
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
	var old=window;window=null;old.hide();old.queue_free()
	close_guard=Callable()
	escape_handler=Callable()
	var valid=restore and not ui.closing and epoch==ui.pages.epoch and connection==ui.engine.connection_generation
	if valid:
		if restore_callback.is_valid():restore_callback.call()
		ui.memory.scrolls.merge(checkpoint,true);ui.memory.request_focus(origin);ui.memory.restore()
	restore_callback=Callable()
