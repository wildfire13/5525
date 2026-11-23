extends Container
## Rows use the game viewport's cells, never a subdivision of the child window.
const Grid=preload("res://screen_grid.gd")
const Tokens=preload("res://ui_tokens.gd")
var scroll_content=false
var fixed_regions=false
var grid_box := Rect2i(2,1,6,8)
var heading: Control
var body: Control
var actions: Control

class HeadingBar extends Control:
	var bar: Panel
	var title_label: Label
	var close_button: Button
	var _text: String=""
	var _horizontal_alignment: HorizontalAlignment=HORIZONTAL_ALIGNMENT_LEFT

	var text: String:
		get:
			return _text
		set(value):
			_text=value
			tooltip_text=value
			if is_instance_valid(title_label):
				title_label.text=value
				title_label.tooltip_text=value

	var horizontal_alignment: HorizontalAlignment:
		get:
			return _horizontal_alignment
		set(value):
			_horizontal_alignment=value
			if is_instance_valid(title_label):
				title_label.horizontal_alignment=value

	func _init(initial_text: String=""):
		mouse_filter=Control.MOUSE_FILTER_STOP
		size_flags_vertical=Control.SIZE_FILL
		bar=Panel.new()
		bar.name="WindowBar"
		bar.mouse_filter=Control.MOUSE_FILTER_PASS
		bar.mouse_default_cursor_shape=Control.CURSOR_MOVE
		var bar_style=Tokens.window_bar_box()
		bar_style.corner_radius_bottom_left=0
		bar_style.corner_radius_bottom_right=0
		bar.add_theme_stylebox_override("panel",bar_style)
		add_child(bar)
		title_label=Label.new()
		title_label.name="WindowBarTitle"
		title_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		title_label.clip_text=true
		title_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		title_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		title_label.add_theme_font_size_override("font_size",Tokens.FONT_HEADING)
		title_label.add_theme_color_override("font_color",Tokens.INK_INVERSE)
		bar.add_child(title_label)
		self.text=initial_text
		resized.connect(_layout_bar)

	func attach_close(button: Button):
		close_button=button
		close_button.custom_minimum_size=Vector2(Tokens.CLOSE_BUTTON_SIZE,Tokens.CLOSE_BUTTON_SIZE)
		bar.add_child(close_button)
		_layout_bar()

	func _notification(what):
		if what==NOTIFICATION_RESIZED or what==NOTIFICATION_THEME_CHANGED:
			_layout_bar()

	func _layout_bar():
		if not is_instance_valid(bar) or not is_instance_valid(title_label):return
		var bar_h=minf(size.y,float(Tokens.WINDOW_BAR_HEIGHT))
		bar.position=Vector2.ZERO
		bar.size=Vector2(size.x,bar_h)
		var right_edge=bar.size.x-float(Tokens.SPACE_MD)
		if is_instance_valid(close_button):
			var close_side=minf(bar_h,float(Tokens.CLOSE_BUTTON_SIZE))
			var close_size=Vector2(close_side,close_side).max(close_button.get_combined_minimum_size())
			close_size.y=minf(close_size.y,bar_h)
			close_button.size=close_size
			close_button.position=Vector2(bar.size.x-close_size.x-float(Tokens.SPACE_XS),floorf((bar_h-close_size.y)*0.5))
			right_edge=close_button.position.x-float(Tokens.SPACE_SM)
		title_label.position=Vector2(float(Tokens.SPACE_MD),0.0)
		title_label.size=Vector2(maxf(0.0,right_edge-float(Tokens.SPACE_MD)),bar_h)

static func frame_rect(view: Vector2) -> Rect2:
	return Grid.cell_rect(view,1,1,8,8)

static func modal_frame_rect(view: Vector2) -> Rect2:
	return Grid.cell_rect(view,2,1,6,8)

static func confirm_frame_rect(view: Vector2) -> Rect2:
	return Grid.cell_rect(view,3,2,4,6)

static func modal_local_rect(view: Vector2,x: int,y: int,width: int,height: int,frame: Rect2=Rect2()) -> Rect2:
	var origin=frame.position if frame.has_area() else modal_frame_rect(view).position
	var rect=Grid.cell_rect(view,x,y,width,height)
	rect.position-=origin
	return rect

static func local_rect(view: Vector2,x: int,y: int,width: int,height: int) -> Rect2:
	return modal_local_rect(view,x,y,width,height)

static func title_label(text: String) -> Control:
	return HeadingBar.new(text)

static func set_heading_text(target: Control,value: String):
	if target==null:return
	if target is HeadingBar or target is Label:
		target.text=value
		target.tooltip_text=value

static func set_heading_alignment(target: Control,alignment: HorizontalAlignment):
	if target==null:return
	if target is HeadingBar or target is Label:
		target.horizontal_alignment=alignment

func set_regions(title: Control,content: Control,footer: Control):
	fixed_regions=true;heading=title;body=content;actions=footer
	if not is_inside_tree():
		ready.connect(set_regions.bind(title,content,footer),CONNECT_ONE_SHOT);return
	var window=get_window()
	if window!=get_tree().root and window.is_embedded():
		var close=Button.new();close.name="WindowHeadingClose";close.text="×";close.tooltip_text="閉じる"
		close.add_theme_font_size_override("font_size",Tokens.FONT_SM)
		close.pressed.connect(func():window.close_requested.emit())
		if heading is HeadingBar:
			heading.attach_close(close)
		else:
			heading.add_child(close)
			var fit_close=func():
				var side=minf(heading.size.y,float(Tokens.CLOSE_BUTTON_SIZE))
				close.position=Vector2(heading.size.x-side,floorf((heading.size.y-side)*0.5));close.size=Vector2(side,side)
			heading.resized.connect(fit_close)
		heading.mouse_filter=Control.MOUSE_FILTER_STOP
		heading.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
				window.set_meta("heading_dragging",event.pressed)
			elif event is InputEventMouseMotion and window.get_meta("heading_dragging",false) and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
				window.position+=Vector2i(event.relative))
		window.window_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:window.set_meta("heading_dragging",false))
	queue_sort()

func _get_minimum_size() -> Vector2:
	if not scroll_content or not is_inside_tree():return Vector2.ZERO
	var unit=float(get_tree().root.size.y)/Grid.DIVISIONS
	var height=0.0
	for child in get_children():
		if child is Control and child.visible:height+=maxi(1,ceili(child.get_combined_minimum_size().y/unit))*unit
	return Vector2(0,height)
func _ready():
	get_tree().root.size_changed.connect(queue_sort)
func _notification(what):
	if what!=NOTIFICATION_SORT_CHILDREN or not is_inside_tree():return
	var view=Vector2(get_tree().root.size)
	if fixed_regions:
		var gx=grid_box.position.x
		var gy=grid_box.position.y
		var gw=grid_box.size.x
		var gh=grid_box.size.y
		var frame=Grid.cell_rect(view,gx,gy,gw,gh)
		fit_child_in_rect(heading,modal_local_rect(view,gx,gy,gw,1,frame))
		fit_child_in_rect(body,modal_local_rect(view,gx,gy+1,gw,gh-2,frame))
		if actions!=null:fit_child_in_rect(actions,modal_local_rect(view,gx,gy+gh-1,gw,1,frame))
		return
	var unit=view.y/Grid.DIVISIONS
	var rows=[]
	var fixed=0
	var flexible=0
	for child in get_children():
		if not child is Control or not child.visible:continue
		var grow=bool(child.size_flags_vertical & Control.SIZE_EXPAND)
		var count=maxi(1,ceili(child.get_combined_minimum_size().y/unit))
		rows.append([child,count,grow]);fixed+=count
		if grow:flexible+=1
	var extra=maxi(0,roundi(size.y/unit)-fixed)
	var y=0
	for row in rows:
		var count=int(row[1])
		if row[2] and flexible>0:
			var share=extra/flexible
			count+=share;extra-=share;flexible-=1
		var rect=Grid.cell_rect(view,0,y,10,count)
		rect.size.x=size.x
		if scroll_content:rect.size.x=floorf(size.x/(view.x/Grid.DIVISIONS))*(view.x/Grid.DIVISIONS)
		row[0].size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row[0].size_flags_vertical=Control.SIZE_EXPAND_FILL if row[2] else Control.SIZE_FILL
		fit_child_in_rect(row[0],rect)
		y+=count
	if scroll_content:update_minimum_size()
