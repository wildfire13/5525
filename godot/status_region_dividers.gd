extends ScrollContainer

# Draw in the existing gaps, without changing layout or intercepting input.
func _process(_delta: float) -> void:
	queue_redraw()

func divider_geometry() -> PackedVector2Array:
	var split=find_child("StatusEquipmentSplit",true,false) as GridContainer
	if split==null or split.get_child_count()<2:return PackedVector2Array()
	var left=split.get_child(0) as Control
	var right=split.get_child(1) as Control
	var origin=get_global_rect().position
	var top=maxf(0,split.global_position.y-origin.y-4)
	if top>=size.y:return PackedVector2Array()
	var x=(left.get_global_rect().end.x+right.global_position.x)*0.5-origin.x
	var start=maxf(0,split.global_position.x-origin.x)
	var end=minf(size.x,split.get_global_rect().end.x-origin.x)
	return PackedVector2Array([Vector2(start,top),Vector2(end,top),Vector2(x,top),Vector2(x,size.y)])

func _draw() -> void:
	var points=divider_geometry()
	if points.size()!=4:return
	var color=Color(0.82,0.85,0.88,0.85)
	draw_line(points[0],points[1],color,1.0)
	draw_line(points[2],points[3],color,1.0)
