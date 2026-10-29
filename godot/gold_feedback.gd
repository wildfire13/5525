extends RefCounted
## Presentation only. Authoritative money remains in the campaign snapshot.
var ui
var target := -1
var displayed := 0.0
var count_tween: Tween
var popup_tween: Tween
var popup: Label
func _init(frontend):ui=frontend
func write(value: float):
 displayed=value
 if is_instance_valid(ui.gold_header):ui.gold_header.text="%dG" % roundi(value)
func reset(value: int):
 if count_tween!=null:count_tween.kill()
 if popup_tween!=null:popup_tween.kill()
 if is_instance_valid(popup):popup.queue_free()
 popup=null;target=value;write(value)
func sync(value: int):
 if target!=value:reset(value)
func change(before: int,after: int):
 if before==after:return
 if target<0:displayed=before
 if count_tween!=null:count_tween.kill()
 target=after
 count_tween=ui.create_tween();count_tween.tween_method(write,displayed,float(after),0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 if popup_tween!=null:popup_tween.kill()
 if is_instance_valid(popup):popup.queue_free()
 popup=Label.new();popup.name="GoldDifference";popup.mouse_filter=Control.MOUSE_FILTER_IGNORE
 popup.text=("+%dG" % (after-before)) if after>before else "−%dG" % (before-after)
 popup.add_theme_color_override("font_color",Color("#8ee6ab") if after>before else Color("#ff9b92"));popup.add_theme_color_override("font_outline_color",Color("#111820"));popup.add_theme_constant_override("outline_size",5)
 popup.add_theme_font_size_override("font_size",24);ui.gold_header.add_child(popup);popup.position=Vector2(-8,-32)
 popup_tween=ui.create_tween();popup_tween.set_parallel(true)
 popup_tween.tween_property(popup,"position:y",-55.0,0.85)
 popup_tween.tween_property(popup,"modulate:a",0.0,0.5).set_delay(0.35)
 popup_tween.chain().tween_callback(popup.queue_free)
