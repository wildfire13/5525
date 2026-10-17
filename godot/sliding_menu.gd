extends Control
## Clip at the parent command edge while the list slides beneath it.
var content := VBoxContainer.new()
var tween: Tween
var opening := false
var fast := false
var closing := false
func _init():
	clip_contents=true;size_flags_horizontal=Control.SIZE_EXPAND_FILL
	add_child(content)
func _ready():
	resized.connect(fit_width);content.minimum_size_changed.connect(refresh_height,CONNECT_DEFERRED);fit_width();call_deferred("reveal")
func fit_width():content.size.x=size.x
func refresh_height():
	if not closing:custom_minimum_size.y=content.get_combined_minimum_size().y
func reveal():
	if closing:return
	var height=content.get_combined_minimum_size().y
	custom_minimum_size.y=height;content.size=Vector2(size.x,height)
	if opening:
		content.position.y=-height
		tween=create_tween();tween.tween_property(content,"position:y",0.0,.001 if fast else .2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
func retract():
	closing=true
	if tween:tween.kill()
	tween=create_tween();tween.set_parallel(true)
	tween.tween_property(content,"position:y",-content.size.y,.001 if fast else .2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self,"custom_minimum_size:y",0.0,.001 if fast else .2)
