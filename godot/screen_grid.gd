extends RefCounted
## All region edges, including embedded windows, refer to the main game viewport.
const DIVISIONS := 10

static func cell_rect(view: Vector2, x: int, y: int, w: int, h: int) -> Rect2:
	var start := (Vector2(x,y) * view / DIVISIONS).round()
	var end := (Vector2(x+w,y+h) * view / DIVISIONS).round()
	return Rect2(start,end-start)

static func snap_rect(rect: Rect2, view: Vector2, minimum:=Vector2.ONE, limit:=Rect2()) -> Rect2:
	var extent := view.max(Vector2.ONE)
	var bounds := limit.intersection(Rect2(Vector2.ZERO,extent)) if limit.has_area() else Rect2(Vector2.ZERO,extent)
	var pos := Vector2i.ZERO
	var span := Vector2i.ONE
	for axis in 2:
		var unit := extent[axis] / DIVISIONS
		var first := clampi(ceili((bounds.position[axis]-0.5)/unit),0,DIVISIONS-1)
		var last := clampi(floori((bounds.end[axis]+0.49)/unit),first+1,DIVISIONS)
		var needed := clampi(ceili(minimum[axis]/unit),1,last-first)
		span[axis]=clampi(roundi(rect.size[axis]/unit),needed,last-first)
		pos[axis]=clampi(roundi(rect.position[axis]/unit),first,last-span[axis])
	return cell_rect(extent,pos.x,pos.y,span.x,span.y)

static func place(control: Control, rect: Rect2):
	control.global_position=rect.position
	control.size=rect.size
