extends RefCounted
## Session-only focus and item anchors. Never serialized into campaign saves.
var ui
var scrolls: Dictionary = {}
var focus_key := ""
var revision := 0
var layout_ready := true
var focus_override := ""
var reveal_focus := false
func _init(frontend):ui=frontend
func key(control: Control, value: String):
	control.set_meta("ui_key",value)
	return control
func item(control: Control, value: String):
	control.set_meta("anchor_id",value)
	return control
func watch(scroll: ScrollContainer, value: String):
	scroll.set_meta("scroll_key",value)
	scroll.follow_focus=true
	scroll.get_v_scroll_bar().value_changed.connect(func(_value):
		if layout_ready and not ui.layout_queued and scroll.is_inside_tree() and scroll.is_visible_in_tree() and scroll.size==scroll.get_meta("restored_size",Vector2.ZERO):capture_scroll(scroll))
	return scroll
func capture():
	if not layout_ready:return
	var focus=ui.get_viewport().gui_get_focus_owner()
	if focus_override.is_empty() and focus!=null and focus.has_meta("ui_key"):focus_key=str(focus.get_meta("ui_key"))
	elif not focus_override.is_empty():focus_key=focus_override
	for scroll in ui.find_children("*","ScrollContainer",true,false):
		if not scroll.has_meta("scroll_key") or not scroll.is_visible_in_tree() or scroll.get_child_count()==0:continue
		capture_scroll(scroll)
func capture_scroll(scroll: ScrollContainer):
	var children=scroll.get_child(0).get_children()
	var entry={"id":"","index":0,"offset":scroll.scroll_vertical,"horizontal":scroll.scroll_horizontal}
	for index in range(children.size()):
		var node=children[index]
		if node is Control and node.position.y<=scroll.scroll_vertical:
			entry.id=str(node.get_meta("anchor_id",node.name));entry.index=index;entry.offset=scroll.scroll_vertical-node.position.y
	scrolls[str(scroll.get_meta("scroll_key"))]=entry
func restore():
	revision+=1;layout_ready=false
	var token=revision
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	if token!=revision or not is_instance_valid(ui):return
	for scroll in ui.find_children("*","ScrollContainer",true,false):
		scroll.follow_focus=false
		var id=str(scroll.get_meta("scroll_key",""))
		if not scrolls.has(id) or scroll.get_child_count()==0:continue
		var entry: Dictionary=scrolls[id]
		var children=scroll.get_child(0).get_children()
		var match_=null
		for child in children:
			if str(child.get_meta("anchor_id",child.name))==entry.id:match_=child;break
		if match_==null and not children.is_empty():match_=children[mini(int(entry.index),children.size()-1)]
		scroll.scroll_vertical=int((match_.position.y if match_ is Control else 0)+entry.offset)
		scroll.scroll_horizontal=int(entry.horizontal)
	if not focus_override.is_empty():focus_key=focus_override
	if not focus_key.is_empty() and not ui.modal_open():
		for control in ui.find_children("*","Control",true,false):
			if str(control.get_meta("ui_key",""))==focus_key and control.is_visible_in_tree() and control.focus_mode!=Control.FOCUS_NONE:
				if control is BaseButton and control.disabled:continue
				control.grab_focus()
				if reveal_focus:
					var ancestor=control.get_parent()
					while ancestor!=null:
						if ancestor is ScrollContainer:ancestor.ensure_control_visible(control)
						ancestor=ancestor.get_parent()
				focus_override="";reveal_focus=false;break
	layout_ready=true
	for scroll in ui.find_children("*","ScrollContainer",true,false):scroll.set_meta("restored_size",scroll.size);scroll.follow_focus=true
func request_focus(value: String,reveal:=false):
	focus_override=value;focus_key=value;reveal_focus=reveal
func reset():
	scrolls.clear();focus_key="";focus_override="";revision+=1;layout_ready=false
