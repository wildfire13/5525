extends Panel
## Draggable header and all eight resize edges. Children never pass input to board.
signal columns_changed(count: int)
const Grid=preload("res://screen_grid.gd")
var grid_columns := 2
var preferences
var layout_key := ""
var minimum := Vector2(280,240)
var body: VBoxContainer
var footer: VBoxContainer
var lower_scroll: ScrollContainer
var lower: VBoxContainer
var footer_scroll: ScrollContainer
var viewport_bounds := false
var reserved_top := 0.0
var reserved_bottom := 0.0
var layout_bounds := Rect2()
var drag_edges := Vector2.ZERO
var dragging := false
var moving := false
var origin := Rect2()
var pointer := Vector2.ZERO
var pending_restore = null
var restore_frames := 0
var preferred_rect := Rect2()
var applied_rect := Rect2()
var applied_bounds := Rect2()
var region_layout: Array=[]
var region_mode := ""
var region_frame := Rect2()
var region_movable := false
var body_scroll: ScrollContainer
var section_with_handle := Control.new()
var region_parent_position := Vector2.ZERO
var laid_out_size := Vector2.ZERO

func place_regions(_view: Vector2,frame: Rect2,body_rect: Rect2,lower_rect: Rect2,footer_rect: Rect2,movable:=false):
	var parent_position=get_parent_control().global_position
	var sections=[body_rect,lower_rect,footer_rect]
	if region_mode!=layout_key or region_frame!=frame:
		pending_restore=null;dragging=false
		Grid.place(self,frame)
		preferred_rect=Rect2(position,size)
	elif region_parent_position!=parent_position:
		global_position+=region_parent_position-parent_position
	elif size==laid_out_size and region_layout==sections and region_movable==movable:
		return
	region_parent_position=parent_position
	region_mode=layout_key;region_frame=frame;region_layout=sections;region_movable=movable
	_layout_regions()

func _layout_regions():
	if region_layout.is_empty():return
	laid_out_size=size
	var header=find_child("DragHandle",true,false)
	header.visible=region_movable
	section_with_handle.visible=region_movable
	var scale_=size/region_frame.size
	var controls=[body_scroll,lower_scroll,footer_scroll]
	for index in range(controls.size()):
		var control=controls[index]
		var section: Rect2=region_layout[index]
		var rect=Rect2((section.position-region_frame.position)*scale_,section.size*scale_)
		var with_handle=region_movable and section.has_area() and is_zero_approx(rect.position.y)
		var parent=section_with_handle if with_handle else self
		if control.get_parent()!=parent:control.reparent(parent)
		control.visible=section.has_area()
		control.clip_contents=true
		if not control.visible:continue
		if with_handle:
			section_with_handle.position=rect.position;section_with_handle.size=rect.size
			if header.get_parent()!=parent:
				header.reparent(parent)
				move_child(section_with_handle,-1)
			header.position=Vector2.ZERO;header.size=Vector2(rect.size.x,36)
			rect.position=Vector2(0,header.size.y);rect.size.y=maxf(0,rect.size.y-header.size.y)
		control.position=rect.position;control.size=rect.size

func configure(prefs,key: String,title: String,fallback: Rect2):
	preferences=prefs;layout_key=key;name=key
	section_with_handle.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(section_with_handle)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var style=preload("res://mock_shell.gd").surface_style();style.set_content_margin_all(0);add_theme_stylebox_override("panel",style)
	var box=VBoxContainer.new();box.add_theme_constant_override("separation",0);add_child(box);box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var header=Label.new();header.name="DragHandle";header.text=title+"  ⋮";header.custom_minimum_size.y=36;header.add_theme_color_override("font_color",Color("#29332f"));header.add_theme_font_size_override("font_size",20);header.mouse_filter=Control.MOUSE_FILTER_STOP;header.mouse_default_cursor_shape=Control.CURSOR_MOVE;box.add_child(header)
	header.gui_input.connect(func(event):handle(event,true))
	header.reparent(self)
	var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(scroll)
	body_scroll=scroll
	body=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(body)
	lower_scroll=ScrollContainer.new();box.add_child(lower_scroll)
	lower_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	lower=VBoxContainer.new();lower.size_flags_horizontal=Control.SIZE_EXPAND_FILL;lower_scroll.add_child(lower)
	footer_scroll=ScrollContainer.new();box.add_child(footer_scroll)
	footer_scroll.name="PinnedActions";footer_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	footer=VBoxContainer.new();footer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;footer_scroll.add_child(footer)
	lower_scroll.hide();footer_scroll.hide()
	restore_rect(fallback)
	gui_input.connect(func(event):handle(event,false))
	resized.connect(_layout_regions)
func restore_rect(fallback: Rect2):
	var stored=preferences.config.get_value("windows",layout_key,fallback)
	var rect=bound_rect(stored if stored is Rect2 else fallback,true)
	position=rect.position;size=rect.size
	preferred_rect=stored if stored is Rect2 else fallback
	pending_restore=preferred_rect;restore_frames=2
func _process(_delta):
	if pending_restore==null:return
	restore_frames-=1
	if restore_frames>0:return
	# Containers finish positioning the parent after mount/render. Clamp in that final space.
	var rect=bound_rect(pending_restore,true);pending_restore=null
	position=rect.position;size=rect.size
func edges(at: Vector2) -> Vector2:
	return Vector2(-1 if at.x<9 else 1 if at.x>size.x-9 else 0,-1 if at.y<9 else 1 if at.y>size.y-9 else 0)
func bound_rect(rect: Rect2,preserve_top:=false) -> Rect2:
	if viewport_bounds:
		var offset=get_parent_control().global_position
		var view=get_viewport_rect().size
		var available=Rect2(Vector2.ZERO,Vector2(view.x,maxf(1,view.y-reserved_bottom)))
		var global_rect=Rect2(rect.position+offset,rect.size)
		if not dragging or drag_edges.x==0:
			global_rect.size.x=view.x*grid_columns/Grid.DIVISIONS
		else:
			global_rect.size.x=clampf(global_rect.size.x,view.x*0.2,view.x*0.5)
		if preserve_top:
			global_rect.size.y=minf(global_rect.size.y,maxf(minimum.y,available.end.y-global_rect.position.y))
		var bounded=Grid.snap_rect(global_rect,view,minimum,available)
		return Rect2(bounded.position-offset,bounded.size)
	return preferences.bounded(rect,get_parent_control().size,minimum)
func constrain():
	var current=Rect2(position,size)
	var bounds=Rect2(get_parent_control().global_position,get_viewport_rect().size-Vector2(0,reserved_bottom))
	if applied_bounds==bounds and current!=applied_rect and pending_restore==null:preferred_rect=current
	var rect=bound_rect(current,true)
	if viewport_bounds:
		position=rect.position;size=rect.size;applied_rect=Rect2(position,size);applied_bounds=bounds;return
	rect.position.y=maxf(reserved_top,rect.position.y)
	rect.size.y=minf(rect.size.y,maxf(minimum.y,get_parent_control().size.y-rect.position.y))
	if layout_bounds.has_area():
		rect=preferences.bounded(Rect2(rect.position-layout_bounds.position,rect.size),layout_bounds.size,minimum)
		rect.position+=layout_bounds.position
	position=rect.position;size=rect.size
func persist():
	if viewport_bounds and drag_edges.x!=0:
		columns_changed.emit(clampi(roundi(size.x*Grid.DIVISIONS/get_viewport_rect().size.x),2,5))
	preferred_rect=Rect2(position,size)
	preferences.store_rect(layout_key,preferred_rect)
func handle(event,header: bool):
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			pending_restore=null
			get_parent().move_child(self,-1)
			drag_edges=edges(event.global_position-global_position);moving=header and drag_edges==Vector2.ZERO
			dragging=moving or drag_edges!=Vector2.ZERO;origin=Rect2(position,size);pointer=event.global_position
			if dragging:accept_event()
		elif dragging:dragging=false;persist();accept_event()
func _input(event):
	if not dragging:return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		dragging=false;persist()
	if event is InputEventMouseMotion:
		var delta=event.global_position-pointer
		var rect=origin
		if moving:rect.position+=delta
		else:
			for axis in range(2):
				if drag_edges[axis]<0:
					var shift=minf(delta[axis],origin.size[axis]-minimum[axis]);rect.position[axis]+=shift;rect.size[axis]-=shift
				elif drag_edges[axis]>0:rect.size[axis]=maxf(minimum[axis],origin.size[axis]+delta[axis])
		rect=bound_rect(rect);position=rect.position;size=rect.size
		if layout_bounds.has_area():constrain()
		get_viewport().set_input_as_handled()
