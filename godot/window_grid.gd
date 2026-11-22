extends Container
## Rows use the game viewport's cells, never a subdivision of the child window.
const Grid=preload("res://screen_grid.gd")
var scroll_content=false
var fixed_regions=false
var heading: Control
var body: Control
var actions: Control

static func frame_rect(view: Vector2) -> Rect2:
	return Grid.cell_rect(view,1,1,8,9)

static func local_rect(view: Vector2,x: int,y: int,width: int,height: int) -> Rect2:
	var rect=Grid.cell_rect(view,x,y,width,height)
	rect.position-=frame_rect(view).position
	return rect

static func title_label(text: String) -> Label:
	var label=Label.new()
	label.text=text;label.clip_text=true;label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_vertical=Control.SIZE_FILL
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.add_theme_font_size_override("font_size",24)
	label.tooltip_text=text
	return label

func set_regions(title: Control,content: Control,footer: Control):
	fixed_regions=true;heading=title;body=content;actions=footer
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
		fit_child_in_rect(heading,local_rect(view,2,1,7,1))
		fit_child_in_rect(body,local_rect(view,2,2,7,7))
		if actions!=null:fit_child_in_rect(actions,local_rect(view,2,9,7,1))
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
