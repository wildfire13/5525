extends Node
## Live input diagnostics only. Requests carry a click captured at dispatch, never the latest click at reply time.
var monitor
var ui
var dispatch: Dictionary = {}
var held: Dictionary = {}
var event_serial := 0

func _ready():
	monitor = get_parent()
	ui = monitor.ui
	for node in ui.find_children("*","Control",true,false) + ui.find_children("*","Window",true,false):
		watch(node)
	get_tree().node_added.connect(watch)
	if "click_observer" in ui.engine:ui.engine.click_observer = request_started

func watch(node: Node):
	if not (node is Control or node is Window) or not ui.is_ancestor_of(node):return
	var win := node.get_window()
	while win != null and win != ui.get_window():
		if win == monitor.window or win is FileDialog:return
		win=win.get_parent().get_window() if win.get_parent() != null else null
	if win == null:return
	if node is Control and not node.gui_input.is_connected(gui_input_received.bind(node)):
		node.gui_input.connect(gui_input_received.bind(node))
	if node is BaseButton:
		if not node.pressed.is_connected(button_pressed.bind(node)):
			node.pressed.connect(button_pressed.bind(node))
	elif node is Window and not node.window_input.is_connected(input_from.bind(node)):
		if node is PopupMenu:node.id_pressed.connect(menu_item.bind(node))
		node.window_input.connect(input_from.bind(node))

func _input(event):
	input_from(event,ui.get_window())

func control_name(control: Control) -> String:
	if not is_instance_valid(control):return "なし"
	if control is Button:
		var caption: String = control.text.get_slice("\n",0).strip_edges()
		if not caption.is_empty() and not caption.contains("/") and not caption.contains("\\"):
			return caption.left(48)
	return str(control.name) if not str(control.name).begins_with("@") else control.get_class()

func region_at(control: Control,screen: String) -> String:
	var node := control
	while node != null:
		for region in ui.ui_labels.definitions.get(str(node.get_meta("ui_region",node.name)),[]):
			if screen in region.screens or "共通" in region.screens:return region.label
		node=node.get_parent_control()
	return "領域未登録"

func input_from(event: InputEvent,win: Window):
	if is_queued_for_deletion() or not monitor.window.visible:return
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		dispatch={}
		return
	event_serial+=1
	if event.pressed:
		var hit := win.gui_get_hovered_control()
		var screen: String = ui.ui_labels.screen_id(win)
		monitor.click_number+=1
		held={"source":get_instance_id(),"id":monitor.click_number,"at":Time.get_ticks_usec(),"screen":ui.ui_labels.CATALOG.data.screens[screen].label,
			"region":region_at(hit,screen),"hit":control_name(hit),"before":control_name(win.gui_get_focus_owner()),
			"actions":[],"window_id":win.get_instance_id(),"point":Vector2i(event.position)}
	elif held.is_empty() or held.window_id != win.get_instance_id():
		dispatch={}
		return
	dispatch=held
	if not event.pressed:
		after_click.call_deferred(held)
		held={}
	end_dispatch.call_deferred(event_serial)

func end_dispatch(serial: int):
	if serial == event_serial:dispatch={}

func gui_input_received(event: InputEvent,control: Control):
	if dispatch.is_empty() or dispatch.has("receiver"):return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		dispatch.receiver=control_name(control)

func button_pressed(button: BaseButton):
	if not dispatch.is_empty():dispatch.actions.append(control_name(button))

func menu_item(id: int,menu: PopupMenu):
	if not dispatch.is_empty():dispatch.actions.append("メニュー項目 %d" % (menu.get_item_index(id)+1))

func board_action(cell: int,unit: Dictionary):
	if dispatch.is_empty():return
	dispatch.actions.append("マス (%d, %d)　%s" % [cell%10,floori(cell/10.0),unit.get("name","空き")])

func after_click(click: Dictionary):
	await drawn_frame()
	if not active():return
	var win=instance_from_id(click.window_id) as Window
	var focus := control_name(win.gui_get_focus_owner()) if is_instance_valid(win) and win.visible else control_name(ui.get_viewport().gui_get_focus_owner())
	var info := "#%d　%s　%s %s ／ 押下 %s ／ 受取 %s → 発火 %s ／ フォーカス %s → %s" % [click.id,click.screen,click.region,click.point,click.hit,click.get("receiver","未観測"),"・".join(click.actions) if not click.actions.is_empty() else "未観測",click.before,focus]
	monitor.append_entry(info+" ／ 入力→初回描画 %.1f ms" % ms(Time.get_ticks_usec()-int(click.at)),2)

func active() -> bool:
	return not is_queued_for_deletion() and is_instance_valid(monitor.window) and monitor.window.visible

func drawn_frame():
	if DisplayServer.get_name()=="headless":await get_tree().process_frame
	else:await RenderingServer.frame_post_draw

func ms(usec: int) -> float:return usec/1000.0

func request_started(operation: String,context) -> Callable:
	var click: Dictionary=dispatch if context==null else context
	if not active() or click.get("source")!=get_instance_id():return Callable()

	return request_replied.bind(click,operation,Time.get_ticks_usec())

func request_replied(click: Dictionary,operation: String,sent: int):
	var reply := Time.get_ticks_usec()
	after_reply.call_deferred(click,operation,sent,reply)

func after_reply(click: Dictionary,operation: String,sent: int,reply: int):
	await drawn_frame()
	if active():
		monitor.append_entry("#%d　%s ／ 入力→要求 %.1f ms ／ 応答待ち %.1f ms ／ 応答→次の描画 %.1f ms" % [click.id,operation,ms(sent-int(click.at)),ms(reply-sent),ms(Time.get_ticks_usec()-reply)],2)
