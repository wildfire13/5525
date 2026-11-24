extends RefCounted
## Battle character sheet modal aligned to the shared x=2..4 (2-col) / x=2..6 (4-col with detail) grid.
const Tokens = preload("res://ui_tokens.gd")
const WindowGrid = preload("res://window_grid.gd")
const MemberLoadoutColumn = preload("res://member_loadout_column.gd")

var ui


func _init(frontend) -> void:
	ui = frontend


func open(uid: String) -> void:
	var hud = ui.hud
	if ui.modal_open() or not hud.live_board():
		return
	var origin = ui.board
	while ui.engine.busy:
		await ui.get_tree().process_frame
		if ui.modal_open() or not hud.live_board() or ui.board != origin:
			return
	var reply: Dictionary = await ui.engine.request({"op": "battle_equipment"})
	if not reply.get("ok", false) or not hud.live_board() or ui.board != origin or ui.modal_open():
		return
	for sheet in reply.get("members", []):
		if sheet.id != uid:
			continue
		var member: Dictionary = hud.unit(uid).merged(sheet, true)
		hud.clear_inspection()
		var side := "味方" if member.side == "ally" else "敵"
		ui.dialog.open(
			side + "の装備・所持品 / " + str(member.name),
			func(body: Control, actions: Control):
				draw(body, member, "equipment")
				var close_button: Button = ui.hud.local(actions, "閉じる", ui.dialog.close)
				close_button.name = "CloseBattleEquipment",
			Callable(),
			Rect2(),
			WindowGrid.battle_loadout_grid(false)
		)
		return


func _sheet_member(member: Dictionary) -> Dictionary:
	for roster_member in ui.roster():
		if str(roster_member.get("id", "")) == str(member.get("id", "")):
			return roster_member.merged(member, true)
	return member


func draw(body: Control, member: Dictionary, tab: String) -> void:
	ui.clear(body)
	var sheet_member := _sheet_member(member)
	var window := body.get_window()
	var state := {"box": WindowGrid.battle_loadout_grid(false)}
	if ui.dialog != null and ui.dialog.window == window and ui.dialog.grid_box != state.box:
		ui.dialog.set_grid_box(state.box)

	var heading: Control = window.find_child("ModalHeading", true, false)
	WindowGrid.set_heading_alignment(heading, HORIZONTAL_ALIGNMENT_LEFT)
	if heading is WindowGrid.HeadingBar and is_instance_valid(heading.title_label):
		heading.title_label.add_theme_font_size_override("font_size", Tokens.FONT_BODY)

	var host_scroll = body.get_parent()
	if host_scroll is ScrollContainer:
		host_scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	var view := Vector2(ui.get_tree().root.size)
	var frame := WindowGrid.grid_frame_rect(view, state.box)
	var body_rect := WindowGrid.modal_local_rect(
		view,
		state.box.position.x,
		state.box.position.y + 1,
		state.box.size.x,
		state.box.size.y - 2,
		frame
	)

	var line: HBoxContainer = ui.mock_shell.columns(body)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_theme_constant_override("separation", 0)

	var column := MemberLoadoutColumn.new()
	column.name = "BattleLoadoutColumn"
	line.add_child(column)
	column.build(
		ui,
		sheet_member,
		tab,
		func(next_tab: String): draw(body, member, next_tab),
		"BattleLoadoutTab_",
		false,
		true,
		true,
		body_rect.size.y
	)
	var left_style := Tokens.box(Tokens.SURFACE, Tokens.BORDER, 0, Tokens.SPACE_NONE, 0)
	left_style.border_width_top = Tokens.BORDER_WIDTH
	left_style.border_width_bottom = Tokens.BORDER_WIDTH
	column.panel.add_theme_stylebox_override("panel", left_style)

	var detail: VBoxContainer = ui.scroller(line)
	var detail_scroll: ScrollContainer = detail.get_parent()
	detail_scroll.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	detail_scroll.visible = false
	var detail_style := Tokens.box(Tokens.SURFACE, Tokens.BORDER, 0, Tokens.SPACE_NONE, 0)
	detail_style.border_width_top = Tokens.BORDER_WIDTH
	detail_style.border_width_left = Tokens.BORDER_WIDTH
	detail_style.border_width_bottom = Tokens.BORDER_WIDTH
	detail_style.content_margin_left = Tokens.SPACE_LG
	detail_style.content_margin_right = Tokens.SPACE_LG
	detail_style.content_margin_top = Tokens.SPACE_MD
	detail_style.content_margin_bottom = Tokens.SPACE_MD
	detail_scroll.add_theme_stylebox_override("panel", detail_style)

	var fit := func():
		_fit_layout(column, detail_scroll, state.box)
	var show_detail := func():
		detail_scroll.name = "BattleItemDetail"
		detail_scroll.visible = true
		var expanded := WindowGrid.battle_loadout_grid(true)
		state.box = expanded
		if ui.dialog != null and ui.dialog.window == window and ui.dialog.grid_box != expanded:
			ui.dialog.set_grid_box(expanded)
		fit.call()

	window.size_changed.connect(fit)
	column.tree_exiting.connect(func():
		if window.size_changed.is_connected(fit):
			window.size_changed.disconnect(fit)
	)
	fit.call()

	match tab:
		"equipment":
			_render_equipment_tab(column, sheet_member, detail, show_detail)
		"inventory":
			_render_inventory_tab(column, sheet_member, detail, show_detail)
		"ability":
			column.render_ability(ui, sheet_member, false, "BattleAbilityScroll", "battle_ability")
		"skills":
			column.render_skills(ui, sheet_member, "BattleSkill_", "BattleSkillList")
		_:
			_render_equipment_tab(column, sheet_member, detail, show_detail)


func _fit_layout(column: Control, detail_scroll: ScrollContainer, modal_box: Rect2i) -> void:
	var view := Vector2(ui.get_tree().root.size)
	var frame := WindowGrid.grid_frame_rect(view, modal_box)
	var gx := modal_box.position.x
	var gy := modal_box.position.y
	var tab_rect := WindowGrid.modal_local_rect(view, gx, gy + 1, 2, 1, frame)
	var stage_rect := WindowGrid.modal_local_rect(view, gx, gy + 2, 2, modal_box.size.y - 3, frame)
	var detail_rect := WindowGrid.modal_local_rect(view, gx + 2, gy + 1, 2, modal_box.size.y - 2, frame)
	var col_w := stage_rect.size.x
	var total_h := tab_rect.size.y + stage_rect.size.y

	column.custom_minimum_size = Vector2(col_w, total_h)
	var tabs = column.find_child("LoadoutTabBar", true, false)
	if tabs != null:
		tabs.custom_minimum_size.y = tab_rect.size.y
	if is_instance_valid(column.stage):
		column.stage.custom_minimum_size = Vector2(col_w, stage_rect.size.y)
		column.fit_stage_height(stage_rect.size.y)

	detail_scroll.custom_minimum_size = Vector2(detail_rect.size.x, total_h)


func _render_equipment_tab(
	column: Control,
	member: Dictionary,
	detail: VBoxContainer,
	show_detail: Callable
) -> void:
	column.equipment(ui, member, "", "BattleSlot_", func(item: Dictionary):
		if item.get("type", "empty") == "empty":
			return
		var slot_key := str(item.get("equipped_slot", item.get("slot", "")))
		var gear = member.get("equipmentDetails", {}).get(slot_key, item.get("definition", item))
		if gear is Dictionary and not gear.is_empty():
			ui.clear(detail)
			ui.pages.describe_gear(detail, gear, true)
			show_detail.call()
	, Callable(), false, true)
	for slot in member.get("equipmentSlots", []):
		var button = column.find_child("BattleSlot_" + str(slot.slot), true, false)
		if button != null:
			ui.memory.key(button, "equipment_" + str(slot.slot))


func _render_inventory_tab(
	column: Control,
	member: Dictionary,
	detail: VBoxContainer,
	show_detail: Callable
) -> void:
	var entries: Array = ui.campaign().get("inventoryByCharacter", {}).get(member.id, {}).get("entries", [])
	var remaining: Dictionary = ui.state().get("itemInventories", {}).get(member.id, {})
	var resolved: Array = []
	if member.side == "enemy":
		remaining = member.get("inventory", {})
		for item_def in ui.campaign().get("itemDefinitions", []):
			if remaining.get(item_def.id, 0) > 0:
				resolved.append({
					"id": item_def.id,
					"kind": "item",
					"name": item_def.name,
					"count": remaining[item_def.id],
					"definition": item_def
				})
	else:
		for entry in entries:
			var item: Dictionary = entry.duplicate(true)
			item.count = remaining.get(item.id, item.count)
			if item.count > 0:
				resolved.append(item)

	var on_select := func(item: Dictionary):
		ui.clear(detail)
		if item.get("kind") == "equipment":
			ui.pages.describe_gear(detail, item.get("definition", item), true)
		else:
			ui.hud.l(detail, str(item.get("name", "")), true)
			ui.hud.l(detail, "所持数 ×%d" % int(item.get("count", 1)))
			var description := str(item.get("definition", {}).get("description", ""))
			if not description.is_empty():
				ui.hud.l(detail, description)
		show_detail.call()

	column.render_readonly_inventory(
		ui,
		member,
		"",
		on_select,
		resolved,
		"BattleInventory",
		"所持品はありません。",
		true
	)
