extends Control
## Read-only hover drawn above embedded windows, with genuine UI click-through.
## Embedded Window.mouse_passthrough is unsupported; Control IGNORE is portable.
var source: Control
var content: Control
var idle := 0.0
var layout_bounds := Vector2i.ZERO
var input_guard: Control
var source_window: Window
var ui: Node
class HoverInputGuard extends Control:
	var hover: Control
	func _input(event):
		if visible and event is InputEventMouse and get_global_rect().has_point(event.position):
			hover.scroll_event(event)
			get_viewport().set_input_as_handled()
func _ready():
	name="EquipmentFullHover";add_to_group("equipment_full_hover");hide();mouse_filter=Control.MOUSE_FILTER_IGNORE;mouse_force_pass_scroll_events=false
	var panel=PanelContainer.new();panel.name="EquipmentTooltipPanel";panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.mouse_force_pass_scroll_events=false;add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	input_guard=HoverInputGuard.new();input_guard.hover=self;input_guard.name="EquipmentTooltipRootInputGuard";input_guard.mouse_filter=Control.MOUSE_FILTER_STOP;input_guard.mouse_force_pass_scroll_events=false;input_guard.hide();get_tree().root.add_child(input_guard)
	input_guard.gui_input.connect(func(event):scroll_event(event);input_guard.accept_event())
	visibility_changed.connect(sync_guard)
	source_window=source.get_window();source_window.window_input.connect(source_input)
	var ancestor: Node=source
	while ancestor!=null:
		if ancestor.has_method("modal_open"):ui=ancestor;break
		ancestor=ancestor.get_parent()
func ignore_pointer(node: Node):
	if node is Control:node.mouse_filter=Control.MOUSE_FILTER_IGNORE;node.mouse_force_pass_scroll_events=false
	for child in node.get_children(true):ignore_pointer(child)
func rebuild():
	var panel=get_child(0)
	if is_instance_valid(content):panel.remove_child(content);content.queue_free()
	theme=source.theme if source.theme!=null else source.get_window().theme
	panel.add_theme_stylebox_override("panel",source.get_theme_stylebox("panel","TooltipPanel"))
	content=source._make_custom_tooltip(source.tooltip_text);content.set_meta("hover_owner",weakref(self));panel.add_child(content);ignore_pointer(content)
	layout_bounds=get_tree().root.size
	var margins=panel.get_theme_stylebox("panel").get_minimum_size()
	size=(content.get_combined_minimum_size()+margins).ceil()
func present():
	idle=0;rebuild();place();show()
func place():
	var bounds=Vector2(get_tree().root.size)
	var anchor=source.game_window_offset()+source.get_global_rect().position
	var x=anchor.x+source.size.x+12
	if x+size.x>bounds.x-8:x=anchor.x-size.x-12
	position=Vector2(x,anchor.y+12).clamp(Vector2(8,8),(bounds-size-Vector2(8,8)).max(Vector2(8,8)))
	sync_guard()
func sync_guard():
	if not is_instance_valid(input_guard):return
	input_guard.position=position;input_guard.size=size
	# Embedded character controls receive real clicks/drags underneath. Outside
	# that Window, the same rectangle stops root board input. Root shop hovers
	# never install a guard over their own purchase/comparison controls.
	input_guard.visible=visible and is_instance_valid(source) and source.get_window()!=get_tree().root
func scroll_event(event) -> bool:
	if not visible or not is_instance_valid(content) or not content.get_meta("scrollable",false):return false
	if not event is InputEventMouseButton or not event.pressed or event.button_index not in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:return false
	var scroll=content.find_child("EquipmentTooltipScroll",true,false)
	var direction=-1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1
	scroll.scroll_vertical+=direction*maxi(24,int(source.detail_size)*3)
	idle=0;return true
func source_input(event):
	if not visible or not event is InputEventMouseButton:return
	var point=event.position+(Vector2(source_window.position) if source_window!=get_tree().root else Vector2.ZERO)
	if get_global_rect().has_point(point) and scroll_event(event):source_window.set_input_as_handled()
func _exit_tree():
	if is_instance_valid(source_window) and source_window.window_input.is_connected(source_input):source_window.window_input.disconnect(source_input)
	if is_instance_valid(input_guard):input_guard.hide();input_guard.queue_free()
func obstructed() -> bool:
	if not is_instance_valid(ui):return false
	var menu=ui.get("menu")
	if is_instance_valid(menu) and menu.visible:return true
	for window in ui.find_children("*","Window",true,false):
		if window!=source_window and window.visible and not window.is_in_group("equipment_comparison_hover"):return true
	return false
func _process(delta):
	if not visible:return
	if obstructed():hide();return
	if not is_instance_valid(source) or not source.is_visible_in_tree() or source.get_viewport().gui_is_dragging():hide();return
	if get_tree().root.size!=layout_bounds:rebuild()
	place()
	var point=source.get_global_mouse_position()+source.game_window_offset()
	var over_source=source.get_global_rect().has_point(source.get_global_mouse_position())
	var over_hover=get_global_rect().has_point(point)
	if over_source or over_hover:idle=0
	else:
		idle+=delta
		if idle>.22:hide()
