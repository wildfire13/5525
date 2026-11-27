extends RefCounted
## Shared calibrated UI motion system (140ms-240ms ease-out, opacity/scale only,
## zero layout shifts, zero idle loops, and full reduced-motion support).

const PRESS_DOWN := 0.08
const FAST := 0.14
const BASE := 0.18
const EMPHASIS := 0.24
const STAGGER_STEP := 0.035

const TRANS := Tween.TRANS_CUBIC
const EASE := Tween.EASE_OUT


static func _resolve_ui(target: Variant) -> Object:
	if target == null:
		return null
	if target is Object and not (target is Node):
		return target
	if target is Node:
		var current: Node = target
		while current != null:
			if current.get("checks_fast") != null:
				return current
			current = current.get_parent()
	return null


static func is_reduced(target: Variant) -> bool:
	var ui := _resolve_ui(target)
	if ui == null:
		return false
	if bool(ui.get("checks_fast")):
		return true
	var prefs: Variant = ui.get("preferences")
	if prefs != null and bool(prefs.get("reduced_motion")):
		return true
	return false


static func duration(seconds: float, target: Variant, min_reduced: float = 0.001) -> float:
	return min_reduced if is_reduced(target) else seconds


static func _kill_meta_tween(control: Control, meta_key: StringName) -> void:
	if not is_instance_valid(control) or not control.has_meta(meta_key):
		return
	var existing: Variant = control.get_meta(meta_key)
	if existing is Tween and is_instance_valid(existing):
		existing.kill()
	control.remove_meta(meta_key)


static func _tween_scale(control: Control, to_scale: Vector2, dur: float) -> void:
	if not is_instance_valid(control) or not control.is_inside_tree():
		return
	_kill_meta_tween(control, &"ui_motion_scale_tween")
	if control.size.x > 0.0 and control.size.y > 0.0:
		control.pivot_offset = control.size * 0.5
	var tw := control.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(control, "scale", to_scale, dur).set_trans(TRANS).set_ease(EASE)
	control.set_meta(&"ui_motion_scale_tween", tw)


static func bind_button(button: BaseButton, target: Variant = null) -> void:
	if not is_instance_valid(button) or button.has_meta(&"ui_motion_bound"):
		return
	button.set_meta(&"ui_motion_bound", true)
	var owner_ref: Variant = target if target != null else button
	var hover_scale := func() -> Vector2:
		return Vector2(1.015, 1.015) if button.theme_type_variation == &"ActionButton" else Vector2(1.008, 1.008)
	button.mouse_entered.connect(func():
		if button.disabled or is_reduced(owner_ref):
			button.scale = Vector2.ONE
			return
		if not button.button_pressed:
			_tween_scale(button, hover_scale.call(), FAST)
	)
	button.mouse_exited.connect(func():
		if is_reduced(owner_ref):
			button.scale = Vector2.ONE
			return
		_tween_scale(button, Vector2.ONE, FAST)
	)
	button.button_down.connect(func():
		if button.disabled or is_reduced(owner_ref):
			button.scale = Vector2.ONE
			return
		_tween_scale(button, Vector2(0.97, 0.97), PRESS_DOWN)
	)
	button.button_up.connect(func():
		if is_reduced(owner_ref):
			button.scale = Vector2.ONE
			return
		var rest: Vector2 = hover_scale.call() if button.is_hovered() and not button.disabled else Vector2.ONE
		_tween_scale(button, rest, FAST)
	)


static func reveal(
	control: Control,
	target: Variant = null,
	dur: float = BASE,
	start_scale: float = 0.985,
	delay: float = 0.0
) -> void:
	if not is_instance_valid(control) or not control.is_inside_tree():
		return
	var owner_ref: Variant = target if target != null else control
	_kill_meta_tween(control, &"ui_motion_reveal_tween")
	if is_reduced(owner_ref):
		control.modulate.a = 1.0
		control.scale = Vector2.ONE
		return
	control.modulate.a = 0.0
	var animate_scale := start_scale < 0.999
	if animate_scale:
		if control.size.x > 0.0 and control.size.y > 0.0:
			control.pivot_offset = control.size * 0.5
		control.scale = Vector2(start_scale, start_scale)
	var tw := control.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.set_parallel(true)
	tw.tween_property(control, "modulate:a", 1.0, dur).set_trans(TRANS).set_ease(EASE)
	if animate_scale:
		tw.tween_property(control, "scale", Vector2.ONE, dur).set_trans(TRANS).set_ease(EASE)
	control.set_meta(&"ui_motion_reveal_tween", tw)


static func fade_in(
	control: Control,
	target: Variant = null,
	dur: float = BASE,
	delay: float = 0.0
) -> void:
	reveal(control, target, dur, 1.0, delay)
