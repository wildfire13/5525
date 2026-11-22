extends CanvasLayer
## Draw the mock's review captions without adding children to the game's layout.
const CATALOG = preload("res://ui_labels.json")
const FONT = preload("res://assets/fonts/NotoSansJP.ttf")
const FONT_SIZE = 14
const INK = Color("#665775")
const PAPER = Color("#fffdf5")
var ui
var enabled := true
var definitions := {}
var controls := {}
var foreground := {}
var overlays := {}
var file_windows := {}
var hint_windows := {}
var dirty := true
var elapsed := 0.0

class RegionOverlay extends Control:
	var captions: Array = []
	func _draw():
		for caption in captions:
			var baseline: Vector2 = caption[1].position + Vector2(0, FONT.get_ascent(FONT_SIZE))
			draw_rect(caption[1].grow(1), PAPER)
			draw_string(FONT, baseline, caption[0], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, INK)

func setup(game):
	ui = game
	for region in CATALOG.data.regions:
		for id in region.nodes:
			if not definitions.has(id): definitions[id] = []
			definitions[id].append(region)
	enabled = ui.preferences.config.get_value("inspection", "labels", true)
	layer = 2100
	add_overlay(ui.get_window(), self)
	get_tree().tree_changed.connect(invalidate)
	get_tree().node_added.connect(window_added)
	get_tree().node_removed.connect(window_removed)
	for popup in ui.find_children("*","Popup",true,false):window_added(popup)
	set_process(enabled)

func invalidate(): dirty = true

func window_added(node):
	if node is PopupMenu or node is PopupPanel:
		hint_windows[node]=true
	elif node is FileDialog and ui.is_ancestor_of(node):
		file_windows[node] = true
		if not node.use_native_dialog or not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
			node.get_vbox().set_meta("ui_region","FileContents")
			call_deferred("attach_window",node.get_instance_id())
	elif node is Window and not node is Popup and ui.is_ancestor_of(node):
		call_deferred("attach_window", node.get_instance_id())

func attach_window(id: int):
	var window = instance_from_id(id)
	if not is_instance_valid(window) or not window.is_inside_tree() or overlays.has(window): return
	if window is AcceptDialog:
		window.get_ok_button().get_parent().set_meta("ui_region", "DialogActionBar")
		for part in window.get_children(true):
			if part is Panel:part.set_meta("ui_region","DialogSurface")
	var canvas = CanvasLayer.new()
	canvas.layer = layer
	window.add_child(canvas)
	add_overlay(window, canvas)

func window_removed(node):
	if node is Window:
		overlays.erase(node)
		file_windows.erase(node)
		hint_windows.erase(node)

func add_overlay(window: Window, canvas: CanvasLayer):
	var overlay = RegionOverlay.new()
	overlay.name = "UiRegionLabels"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.focus_mode = Control.FOCUS_NONE
	canvas.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = enabled
	overlays[window] = overlay

func set_enabled(value: bool):
	enabled = value
	ui.preferences.config.set_value("inspection", "labels", value)
	ui.preferences.save()
	set_process(value)
	dirty = true
	for overlay in overlays.values(): overlay.visible = value

func collect(node: Node):
	if node == self or node is Node3D or node is SubViewport or node is Popup or node is FileDialog and not overlays.has(node): return
	if node is BaseButton or node is Label:
		var owner_window=node.get_window()
		if not foreground.has(owner_window): foreground[owner_window]=[]
		foreground[owner_window].append(node)
	if node is Control and definitions.has(str(node.get_meta("ui_region",node.name))):
		var window = node.get_window()
		if not controls.has(window): controls[window] = []
		controls[window].append(node)
	for child in node.get_children(): collect(child)

func visible_box(node: Control, bounds: Rect2) -> Rect2:
	var rect = bounds.intersection(node.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, node.size))
	var parent = node.get_parent()
	while rect.has_area() and parent is CanvasItem:
		if parent is Control and parent.clip_contents:
			rect = rect.intersection(parent.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, parent.size))
		parent = parent.get_parent()
	return rect

# Transient content follows its source; its review region spans the game cells it touches.
func cell_cover(rect: Rect2, window: Window) -> Rect2:
	if not rect.has_area():return Rect2()
	var root=get_tree().root
	var to_game=root.get_screen_transform().affine_inverse()*window.get_screen_transform()
	var box=to_game*rect
	var unit=Vector2(root.size)/preload("res://screen_grid.gd").DIVISIONS
	var first=(box.position/unit).floor()
	var last=(box.end/unit).ceil()
	return window.get_visible_rect().intersection(to_game.affine_inverse()*Rect2(first*unit,(last-first)*unit))

func region_box(node: Control, window: Window, region: Dictionary) -> Rect2:
	var rect=visible_box(node,window.get_visible_rect())
	return cell_cover(rect,window) if region.get("grid_cover",false) else rect

func screen_id(window: Window, include_menu := true) -> String:
	if window is FileDialog:return "file"
	if window != ui.get_window(): return "debug" if window.name == &"DeveloperWindow" else "window"
	for dialog in file_windows:
		if include_menu and dialog.get_meta("file_dialog_active", false): return "file"
	if ui.loading_screen.active: return "loading"
	if include_menu and ui.menu.visible: return "menu"
	var dialogue = ui.pages.quest_board.dialogue
	if include_menu and is_instance_valid(dialogue) and dialogue.is_inside_tree() and dialogue.visible: return "story"
	if ui.results_view.active: return "victory" if ui.results_view.current.get("kind") == "battle" else "complete"
	var phase = ui.campaign().get("phase", "")
	if ui.view_kind == "battle":
		if ui.data.get("trial") != null: return "trial"
		return "deployment" if ui.state().get("deploying", false) else "battle"
	if ui.page == "character": return "character"
	if phase == "town":
		if ui.pages.facility_entry.at_top(): return "entry"
		if ui.page == "party":
			if ui.pages.warehouse_view.available(): return "warehouse"
			return "guild" if ui.campaign().get("guildAvailable", false) else "character"
		return ui.page if CATALOG.data.screens.has(ui.page) else "board"
	if ui.page == "board" and ui.campaign().get("activeQuest") is Dictionary: return "board"
	if phase == "camp" and ui.page == "items": return "items"
	if phase == "prepare": return "map"
	if phase == "delivery": return "arrival"
	return phase if CATALOG.data.screens.has(phase) else "startup"


func occupied_text(window: Window, bounds: Rect2) -> Array[Rect2]:
	var occupied: Array[Rect2] = []
	for node in foreground.get(window, []):
		if not is_instance_valid(node) or not node.is_visible_in_tree(): continue
		var rect = visible_box(node, bounds)
		if not rect.has_area(): continue
		if node is Label:
			if node.text.is_empty(): continue
			var height = minf(rect.size.y, node.get_line_height() * node.get_line_count())
			if node.vertical_alignment == VERTICAL_ALIGNMENT_CENTER: rect.position.y += (rect.size.y-height)/2
			elif node.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM: rect.position.y += rect.size.y-height
			rect.size.y = height
		elif node.mouse_filter == Control.MOUSE_FILTER_IGNORE: continue
		occupied.append(rect)
	return occupied

func place(captions: Array, text: String, area: Rect2, bounds: Rect2, occupied: Array[Rect2]):
	var extent = FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).ceil()
	var corner = (area.end-extent-Vector2(6,2)).clamp(Vector2.ONE*2,(bounds.end-extent-Vector2.ONE*2).max(Vector2.ONE*2)).floor()
	var box = Rect2(corner,extent)
	# Prefer the same edge, then the adjoining margin, before moving up the panel.
	for dy in [0,extent.y+4,-extent.y-3,-2*(extent.y+3),2*(extent.y+3),-3*(extent.y+3)]:
		for dx in range(0,ceili(maxf(area.size.x,extent.x)),32):
			var candidate = Rect2(corner+Vector2(-dx,dy),extent)
			if candidate.position.x < minf(area.position.x,corner.x)-2: break
			if not bounds.encloses(candidate): continue
			if occupied.any(func(rect: Rect2): return rect.intersects(candidate)): continue
			captions.append([text,candidate])
			occupied.append(candidate.grow(2))
			return
	# Small controls without an empty margin still need their review label.
	while captions.any(func(entry): return box.intersects(entry[1])) and box.position.y>=extent.y+4:
		box.position.y-=extent.y+3
	captions.append([text,box])
	occupied.append(box.grow(2))

# Label each contiguous set of unoccupied grid cells once, on its widest row.
func label_background(captions, bounds: Rect2, areas: Array, occupied):
	var unit=Vector2(get_tree().root.size)/preload("res://screen_grid.gd").DIVISIONS
	var empty={}
	for y in roundi(bounds.size.y/unit.y):
		for x in roundi(bounds.size.x/unit.x):
			var cell=Vector2i(x,y)
			var center=(Vector2(cell)+Vector2.ONE*0.5)*unit
			if not areas.any(func(area):return area.has_point(center)):empty[cell]=true
	while not empty.is_empty():
		var start=empty.keys()[0]
		var pending=[start]
		var island={}
		empty.erase(start)
		while not pending.is_empty():
			var cell=pending.pop_back()
			island[cell]=true
			for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next=cell+direction
				if empty.erase(next):pending.append(next)
		var widest=Rect2()
		for cell in island:
			if island.has(cell+Vector2i.LEFT):continue
			var width=1
			while island.has(cell+Vector2i.RIGHT*width):width+=1
			if width*unit.x>widest.size.x:widest=Rect2(Vector2(cell)*unit,Vector2(width,1)*unit)
		place(captions,CATALOG.data.prefix+CATALOG.data.surfaces.background.label,widest,bounds,occupied)

func refresh():
	if dirty:
		dirty = false
		controls.clear()
		foreground.clear()
		collect(ui)
		for group in ["equipment_full_hover","ui_drag_preview"]:
			for external in get_tree().get_nodes_in_group(group):
				if not ui.is_ancestor_of(external):collect(external)
		for dialog in overlays:
			if dialog is AcceptDialog:
				if not controls.has(dialog):controls[dialog]=[]
				for part in [dialog.get_ok_button().get_parent(),dialog.get_label()]+dialog.get_children(true):
					if part is Control and definitions.has(str(part.get_meta("ui_region",part.name))) and not controls[dialog].has(part):controls[dialog].append(part)
	for window in overlays:
		if not window.visible: continue
		var screen = screen_id(window)
		var bounds: Rect2 = window.get_visible_rect()
		var title: String = CATALOG.data.screens[screen].label
		if screen == "window": title += "／" + window.title
		if screen == "entry": title += "／" + ui.pages.facility_entry.facility_name(ui.page)
		var underneath = screen_id(window, false) if screen in ["menu","story","file"] else screen
		var occupied=occupied_text(window,bounds)
		var captions := []
		var areas := []
		place(captions, "場面：" + title, Rect2(Vector2.ZERO, Vector2(bounds.size.x * 0.68, 30)), bounds, occupied)
		for node in controls.get(window, []):
			if not is_instance_valid(node) or not node.is_visible_in_tree() or node.is_queued_for_deletion(): continue
			for region in definitions[str(node.get_meta("ui_region",node.name))]:
				if not region.screens.has(screen) and not region.screens.has(underneath) and not region.screens.has("共通"): continue
				if region.screens.has("共通") and screen in ["loading","complete","victory"]: continue
				var area = region_box(node,window,region)
				if area.size.x < 12 or area.size.y < 10: continue
				var caption: String = CATALOG.data.prefix + region.label
				place(captions, caption, area, bounds, occupied)
				if node.name not in [&"TownStill",&"FacilityStill"]:areas.append(area)
		# Godot draws these popup windows above the parent canvas. Mark the adjoining
		# edge on the parent so review text cannot cover the choices or the hint.
		for popup in hint_windows:
			if not popup.visible or popup.get_parent().get_window()!=window:continue
			var transform=window.get_screen_transform().affine_inverse()*popup.get_screen_transform()
			var rect=bounds.intersection(transform*popup.get_visible_rect())
			if not rect.has_area():continue
			occupied.append(rect)
			var role="choices" if popup is PopupMenu else "tooltip"
			place(captions,CATALOG.data.prefix+CATALOG.data.surfaces[role].label,cell_cover(rect,window),bounds,occupied)
		if screen=="file":
			place(captions,CATALOG.data.prefix+CATALOG.data.surfaces.file.label,bounds,bounds,occupied)
		else:label_background(captions,bounds,areas,occupied)
		var overlay = overlays[window]
		if overlay.captions != captions:
			overlay.captions = captions
			overlay.queue_redraw()

func _process(delta):
	elapsed += delta
	if elapsed >= 0.12:
		elapsed = 0.0
		refresh()
