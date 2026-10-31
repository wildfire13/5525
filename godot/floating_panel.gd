extends PanelContainer
## Draggable header and all eight resize edges. Children never pass input to board.
var preferences
var layout_key := ""
var minimum := Vector2(280,240)
var body: VBoxContainer
var footer: VBoxContainer
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
func configure(prefs,key: String,title: String,fallback: Rect2):
	preferences=prefs;layout_key=key;name=key
	mouse_filter=Control.MOUSE_FILTER_STOP
	var style=StyleBoxFlat.new();style.bg_color=Color("#18212af3");style.border_color=Color("#63717f");style.set_border_width_all(1);style.set_corner_radius_all(5);style.set_content_margin_all(10);add_theme_stylebox_override("panel",style)
	var box=VBoxContainer.new();add_child(box)
	var header=Label.new();header.name="DragHandle";header.text=title+"  ⋮";header.custom_minimum_size.y=30;header.mouse_filter=Control.MOUSE_FILTER_STOP;header.mouse_default_cursor_shape=Control.CURSOR_MOVE;box.add_child(header)
	header.gui_input.connect(func(event):handle(event,true))
	var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(scroll)
	body=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(body)
	footer=VBoxContainer.new();footer.name="PinnedActions";box.add_child(footer)
	restore_rect(fallback)
	gui_input.connect(func(event):handle(event,false))
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
		var available=get_viewport_rect().size
		available.y=maxf(1,available.y-reserved_bottom)
		var global_rect=Rect2(rect.position+offset,rect.size)
		if preserve_top and reserved_bottom>0:
			global_rect.size.y=minf(global_rect.size.y,maxf(minimum.y,available.y-maxf(0,global_rect.position.y)))
		var bounded=preferences.bounded(global_rect,available,minimum)
		return Rect2(bounded.position-offset,bounded.size)
	return preferences.bounded(rect,get_parent_control().size,minimum)
func constrain():
	var current=Rect2(position,size)
	var bounds=Rect2(get_parent_control().global_position,get_viewport_rect().size-Vector2(0,reserved_bottom))
	if applied_bounds==bounds and current!=applied_rect and pending_restore==null:preferred_rect=current
	var rect=bound_rect(Rect2(position,size) if dragging else preferred_rect,true)
	if viewport_bounds:
		position=rect.position;size=rect.size;applied_rect=Rect2(position,size);applied_bounds=bounds;return
	rect.position.y=maxf(reserved_top,rect.position.y)
	rect.size.y=minf(rect.size.y,maxf(minimum.y,get_parent_control().size.y-rect.position.y))
	if layout_bounds.has_area():
		rect=preferences.bounded(Rect2(rect.position-layout_bounds.position,rect.size),layout_bounds.size,minimum)
		rect.position+=layout_bounds.position
	position=rect.position;size=rect.size
func persist():
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
