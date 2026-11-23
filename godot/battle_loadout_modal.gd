extends RefCounted
## Battle equipment and inventory inspection modal extracted from BattleHUD.
const ElementBadges = preload("res://element_badges.gd")
const Tokens = preload("res://ui_tokens.gd")
const WindowGrid = preload("res://window_grid.gd")
const ScreenGrid = preload("res://screen_grid.gd")
const MemberLoadoutColumn = preload("res://member_loadout_column.gd")
const MemberInventory = preload("res://member_inventory.gd")

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
		ui.dialog.open(side + "の装備・所持品 / " + str(member.name), func(body: Control, actions: Control):
			draw(body, member, "equipment")
			var close_button: Button = ui.hud.local(actions, "閉じる", ui.dialog.close)
			close_button.name = "CloseBattleEquipment"
		)
		return


func draw(body: Control, member: Dictionary, tab: String) -> void:
	ui.clear(body)
	var window := body.get_window()
	var old_column = window.get_node_or_null("BattleLoadoutColumn")
	if old_column != null:
		window.remove_child(old_column.stage)
		old_column.stage.queue_free()
		window.remove_child(old_column)
		old_column.queue_free()

	var heading: Control = window.find_child("ModalHeading", true, false)
	WindowGrid.set_heading_alignment(heading, HORIZONTAL_ALIGNMENT_LEFT)
	var summary := _build_summary_strip(heading, member)

	var host_scroll = body.get_parent()
	if host_scroll is ScrollContainer:
		host_scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	var line: HBoxContainer = ui.mock_shell.columns(body)
	line.add_theme_constant_override("separation", 0)

	var spacer := Panel.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(spacer)
	var left_bg := Tokens.box(Tokens.SURFACE, Tokens.BORDER, 0, Tokens.SPACE_NONE, 0)
	left_bg.border_width_bottom = Tokens.BORDER_WIDTH
	spacer.add_theme_stylebox_override("panel", left_bg)

	var column := MemberLoadoutColumn.new()
	column.name = "BattleLoadoutColumn"
	window.add_child(column)
	column.build(ui, member, tab, func(next_tab: String): draw(body, member, next_tab), "BattleLoadoutTab_")
	column.panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	var stage: Control = column.stage
	stage.reparent(window, false)
	column.stage.clip_contents = true

	var detail: VBoxContainer = ui.scroller(line)
	var detail_scroll: ScrollContainer = detail.get_parent()
	var detail_style := Tokens.box(Tokens.SURFACE, Tokens.BORDER, 0, Tokens.SPACE_NONE, 0)
	detail_style.border_width_left = Tokens.BORDER_WIDTH
	detail_style.border_width_bottom = Tokens.BORDER_WIDTH
	detail_style.content_margin_left = Tokens.SPACE_LG
	detail_style.content_margin_right = Tokens.SPACE_LG
	detail_style.content_margin_top = Tokens.SPACE_MD
	detail_style.content_margin_bottom = Tokens.SPACE_MD
	detail_scroll.add_theme_stylebox_override("panel", detail_style)

	var placeholder: Label = ui.hud.l(detail, "装備スロットまたは所持品を選ぶと詳細を表示します。")
	placeholder.add_theme_color_override("font_color", Tokens.MUTED_INK)

	var art := Control.new()
	column.stage.add_child(art)
	column.portrait.reparent(art, false)

	var fit := func():
		_fit_layout(summary, spacer, column, stage, detail_scroll, art)
	window.size_changed.connect(fit)
	column.tree_exiting.connect(func():
		if window.size_changed.is_connected(fit):
			window.size_changed.disconnect(fit)
	)
	fit.call()

	if tab == "equipment":
		_render_equipment_tab(column, art, member, detail, detail_scroll)
	else:
		_render_inventory_tab(column, member, detail, detail_scroll)


func _build_summary_strip(heading: Control, member: Dictionary) -> PanelContainer:
	var old_summary = heading.get_node_or_null("BattleLoadoutSummary")
	if old_summary != null:
		heading.remove_child(old_summary)
		old_summary.queue_free()

	var summary := PanelContainer.new()
	summary.name = "BattleLoadoutSummary"
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var summary_style := Tokens.box(Tokens.SURFACE_ALT, Tokens.BORDER, 0, Tokens.SPACE_NONE, 0)
	summary_style.border_width_bottom = Tokens.BORDER_WIDTH
	summary_style.content_margin_left = Tokens.SPACE_LG
	summary_style.content_margin_right = Tokens.SPACE_LG
	summary_style.content_margin_top = Tokens.SPACE_XS
	summary_style.content_margin_bottom = Tokens.SPACE_XS
	summary.add_theme_stylebox_override("panel", summary_style)
	heading.add_child(summary)

	var summary_row: HBoxContainer = ui.row(summary)
	summary_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	summary_row.add_theme_constant_override("separation", Tokens.SPACE_MD)
	summary_row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var portrait: Control = ui.portrait(summary_row, member, true, 44)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var is_ally: bool = member.get("side", "ally") == "ally"
	var side_label: Label = ui.hud.l(summary_row, "味方" if is_ally else "敵")
	side_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	side_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	side_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side_label.add_theme_font_size_override("font_size", Tokens.FONT_SM)
	side_label.add_theme_color_override("font_color", Tokens.ACCENT if is_ally else Tokens.DANGER)

	var name_label: Label = ui.hud.l(summary_row, str(member.get("name", "")))
	name_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_override("font", ui.heading_font)

	ElementBadges.add(summary_row, str(member.get("element", "none")), 24)

	var stat_parts: Array[String] = [
		"HP %d/%d" % [int(member.get("hp", 0)), int(member.get("max", 0))],
		"MP %d/%d" % [int(member.get("mp", 0)), int(member.get("maxMp", 0))]
	]
	if member.has("carriedWeight"):
		var carried := float(member.get("carriedWeight", 0)) + float(member.get("fallenWeightShare", 0))
		stat_parts.append("Wt %.1f / %.1f" % [carried, float(member.get("weightLimit", member.get("str", 0)))])

	var stat_spacer := Control.new()
	stat_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary_row.add_child(stat_spacer)

	var stats_label: Label = ui.hud.l(summary_row, "   ".join(stat_parts))
	stats_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	stats_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_label.add_theme_font_size_override("font_size", Tokens.FONT_SM)
	stats_label.add_theme_color_override("font_color", Tokens.MUTED_INK)

	return summary


func _fit_layout(
	summary: PanelContainer,
	spacer: Panel,
	column: Control,
	stage: Control,
	detail_scroll: ScrollContainer,
	art: Control
) -> void:
	var view := Vector2(ui.get_tree().root.size)
	var head_rect := WindowGrid.local_rect(view, 2, 1, 6, 1)
	summary.position = Vector2(0.0, float(Tokens.WINDOW_BAR_HEIGHT))
	summary.size = Vector2(head_rect.size.x, maxf(0.0, head_rect.size.y - float(Tokens.WINDOW_BAR_HEIGHT)))

	var tab_rect := WindowGrid.local_rect(view, 2, 2, 2, 1)
	var stage_rect := WindowGrid.local_rect(view, 2, 3, 2, 5)
	spacer.custom_minimum_size = Vector2(stage_rect.size.x, tab_rect.size.y + stage_rect.size.y)

	var tabs: MarginContainer = column.get_node("LoadoutTabBar")
	tabs.add_theme_constant_override("margin_left", Tokens.SPACE_SM)
	tabs.add_theme_constant_override("margin_right", Tokens.SPACE_SM)
	tabs.custom_minimum_size.y = tab_rect.size.y
	tabs.get_child(0).custom_minimum_size.y = tab_rect.size.y

	column.panel.get_child(0).get_child(0).custom_minimum_size.y = 0
	column.panel.custom_minimum_size.y = stage_rect.size.y
	detail_scroll.custom_minimum_size.y = WindowGrid.local_rect(view, 4, 2, 4, 6).size.y
	column.custom_minimum_size = Vector2(stage_rect.size.x, tab_rect.size.y + stage_rect.size.y)

	ScreenGrid.place(column, Rect2(tab_rect.position, column.custom_minimum_size))
	stage.custom_minimum_size = Vector2.ZERO
	ScreenGrid.place(stage, stage_rect)

	var scale_factor := minf(stage_rect.size.x / column.ART_SIZE.x, stage_rect.size.y / column.ART_SIZE.y)
	art.scale = Vector2.ONE * scale_factor
	art.position.x = (stage_rect.size.x - column.ART_SIZE.x * scale_factor) / 2.0


func _render_equipment_tab(
	column: Control,
	art: Control,
	member: Dictionary,
	detail: VBoxContainer,
	detail_scroll: ScrollContainer
) -> void:
	column.equipment(ui, member, "", "BattleSlot_", func(item: Dictionary):
		if item.get("type", "empty") == "empty":
			return
		var slot_key := str(item.get("slot", ""))
		var gear = member.get("equipmentDetails", {}).get(slot_key, item.get("definition", {}))
		if gear is Dictionary and not gear.is_empty():
			ui.clear(detail)
			detail_scroll.name = "BattleItemDetail"
			ui.pages.describe_gear(detail, gear, true)
	)
	for slot in member.get("equipmentSlots", []):
		var button = column.stage.get_node_or_null("BattleSlot_" + str(slot.slot))
		if button != null:
			ui.memory.key(button, "equipment_" + str(slot.slot))
	for child in column.stage.get_children():
		if child != art:
			child.reparent(art, false)


func _render_inventory_tab(
	column: Control,
	member: Dictionary,
	detail: VBoxContainer,
	detail_scroll: ScrollContainer
) -> void:
	var inventory: VBoxContainer = ui.scroller(column.stage)
	inventory.name = "BattleInventory"
	var inv_scroll: ScrollContainer = inventory.get_parent()
	inv_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var inv_pad := StyleBoxEmpty.new()
	inv_pad.content_margin_left = Tokens.SPACE_SM
	inv_pad.content_margin_right = Tokens.SPACE_SM
	inv_pad.content_margin_top = Tokens.SPACE_XS
	inv_pad.content_margin_bottom = Tokens.SPACE_XS
	inv_scroll.add_theme_stylebox_override("panel", inv_pad)

	var entries: Array = ui.campaign().get("inventoryByCharacter", {}).get(member.id, {}).get("entries", [])
	var remaining: Dictionary = ui.state().get("itemInventories", {}).get(member.id, {})
	if member.side == "enemy":
		entries = []
		remaining = member.get("inventory", {})
		for item_def in ui.campaign().get("itemDefinitions", []):
			if remaining.get(item_def.id, 0) > 0:
				entries.append({
					"id": item_def.id,
					"kind": "item",
					"name": item_def.name,
					"count": remaining[item_def.id],
					"definition": item_def
				})

	for entry in entries:
		var item: Dictionary = entry.duplicate()
		item.count = remaining.get(item.id, item.count)
		if item.count <= 0:
			continue
		MemberInventory.add_row(ui, inventory, item, func():
			ui.clear(detail)
			detail_scroll.name = "BattleItemDetail"
			if item.kind == "equipment":
				ui.pages.describe_gear(detail, item.get("definition", item), true)
			else:
				ui.hud.l(detail, str(item.name), true)
				ui.hud.l(detail, "所持数 ×%d" % item.count)
				var description := str(item.get("definition", {}).get("description", ""))
				if not description.is_empty():
					ui.hud.l(detail, description)
		, false, false)

	if inventory.get_child_count() == 0:
		ui.hud.l(inventory, "所持品はありません。")
