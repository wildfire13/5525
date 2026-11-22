extends PanelContainer
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
func configure(prefs,key: String,title: String,fallback: Rect2):
	preferences=prefs;layout_key=key;name=key
	mouse_filter=Control.MOUSE_FILTER_STOP
	var style=preload("res://mock_shell.gd").surface_style();style.set_content_margin_all(0);add_theme_stylebox_override("panel",style)
	var box=VBoxContainer.new();box.add_theme_constant_override("separation",0);add_child(box)
	var header=Label.new();header.name="DragHandle";header.text=title+"  ⋮";header.custom_minimum_size.y=36;header.add_theme_color_override("font_color",Color("#29332f"));header.add_theme_font_size_override("font_size",20);header.mouse_filter=Control.MOUSE_FILTER_STOP;header.mouse_default_cursor_shape=Control.CURSOR_MOVE;box.add_child(header)
	header.gui_input.connect(func(event):handle(event,true))
	var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(scroll)
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
func fit_sections():
	var cell=get_viewport_rect().size.y/Grid.DIVISIONS
	var rows=maxi(1,roundi(size.y/maxf(1,cell)))
	var footer_rows=mini(maxi(0,rows-1),ceili(footer.get_combined_minimum_size().y/maxf(1,cell))) if footer.get_child_count()>0 else 0
	var lower_rows=mini(maxi(0,rows-footer_rows-1),ceili(lower.get_combined_minimum_size().y/maxf(1,cell))) if lower.get_child_count()>0 else 0
	footer_scroll.visible=footer_rows>0
	lower_scroll.visible=lower_rows>0
	var row_end=roundi(get_global_rect().end.y/maxf(1,cell))
	footer_scroll.custom_minimum_size.y=Grid.cell_rect(get_viewport_rect().size,0,row_end-footer_rows,1,footer_rows).size.y
	lower_scroll.custom_minimum_size.y=Grid.cell_rect(get_viewport_rect().size,0,row_end-footer_rows-lower_rows,1,lower_rows).size.y

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
