extends Container
## Rows use the game viewport's cells, never a subdivision of the child window.
const Grid=preload("res://screen_grid.gd")
var scroll_content=false
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
