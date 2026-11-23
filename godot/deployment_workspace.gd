extends RefCounted
## Mock composition around the native battlefield; all actions use existing APIs.
var hud_ref: WeakRef
var hud:
	get: return hud_ref.get_ref()
	set(value): hud_ref = weakref(value)
var last_selected := ""
var enemy_job_filter := ""
const Grid = preload("res://screen_grid.gd")
const Tokens = preload("res://ui_tokens.gd")
const JOB_NAMES := {
	"job_warrior": "戦士",
	"job_scout": "スカウト",
	"job_archer": "弓兵",
	"job_mage": "魔法使い",
	"job_porter": "ポーター",
}
var panel_style = Tokens.surface_box(Tokens.SURFACE, false, Tokens.RADIUS_SM, Tokens.SPACE_NONE)
var normal_panel_style

var ui:
	get: return hud.ui

func restore():
	if normal_panel_style != null:
		hud.right_panel.add_theme_stylebox_override("panel", normal_panel_style)
	hud.right_panel.find_child("DragHandle", true, false).show()
	hud.right_panel.body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hud.right_panel.body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	enemy_job_filter = ""
	ui.header.remove_theme_color_override("font_color")

func enemy_role_label(enemy: Dictionary) -> String:
	var job := str(enemy.get("job", ""))
	if JOB_NAMES.has(job):
		return JOB_NAMES[job]
	var role := str(enemy.get("role", ""))
	return role if not role.is_empty() else job

func layout():
	var view = ui.size
	hud.left_panel.hide()
	var strip = ui.get("deployment_party_strip")
	if is_instance_valid(strip):
		strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		Grid.place(strip, Grid.cell_rect(view, 0, 1, 2, 8))
	var right_rect = Grid.cell_rect(view, 8, 1, 2, 8)
	hud.right_panel.place_regions(view, right_rect, right_rect, Rect2(), Rect2())
	hud.right_panel.find_child("DragHandle", true, false).hide()
	if normal_panel_style == null:
		normal_panel_style = hud.right_panel.get_theme_stylebox("panel").duplicate()
	panel_style.set_content_margin_all(Tokens.SPACE_NONE)
	hud.right_panel.add_theme_stylebox_override("panel", panel_style)
	var footer_rect = Grid.cell_rect(view, 0, 9, 10, 1)
	Grid.place(hud.deployment_footer, footer_rect)
	hud.layout_camera_guide()
	ui.board.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	ui.board.position = Vector2.ZERO
	ui.board.size = view
	var left_w: float = float(strip.size.x) if is_instance_valid(strip) else float(view.x) * 0.2
	var right_w: float = float(hud.right_panel.size.x) if is_instance_valid(hud.right_panel) else float(view.x) * 0.2
	ui.board.battle_play_width = maxf(1.0, view.x - left_w - right_w - 64.0)
	ui.board.deployment_bottom_limit = footer_rect.position.y - ui.board.global_position.y
	ui.board.update_camera()

func render():
	if ui.selected != last_selected:
		hud.selected_enemy = ""
		last_selected = ui.selected
	ui.header.add_theme_color_override("font_color", Tokens.INK)
	hud.left_panel.hide()
	ui.clear(hud.right_panel.body)
	ui.clear(hud.right_panel.lower)
	ui.clear(hud.right_panel.footer)
	hud.right_panel.body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hud.right_panel.body.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var margin = MarginContainer.new()
	margin.name = "EnemyRosterFrame"
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, Tokens.SPACE_SM)
	hud.right_panel.body.add_child(margin)

	var body = VBoxContainer.new()
	body.name = "EnemyRosterBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(body)

	var enemies = ui.state().get("units", []).filter(func(u): return u.side == "enemy")
	var heading = ui.label_(body, "敵パーティ     %d人" % enemies.size(), false)
	heading.name = "EnemyRosterHeading"
	heading.add_theme_color_override("font_color", Tokens.INK)

	var jobs: Array[String] = []
	for enemy in enemies:
		var job := str(enemy.get("job", ""))
		if not job.is_empty() and not jobs.has(job):
			jobs.append(job)
	if not enemy_job_filter.is_empty() and not jobs.has(enemy_job_filter):
		enemy_job_filter = ""

	var filter = OptionButton.new()
	filter.name = "EnemyJobFilter"
	filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Tokens.apply_button_size(filter, Tokens.BUTTON_MD, false)
	filter.tooltip_text = "職業で絞り込む"
	filter.add_item("すべて")
	filter.set_item_metadata(0, "")
	for job in jobs:
		var role_text: String = str(JOB_NAMES.get(job, job))
		filter.add_item(role_text)
		filter.set_item_metadata(filter.item_count - 1, job)
		if job == enemy_job_filter:
			filter.select(filter.item_count - 1)
	body.add_child(filter)

	var list = ui.scroller(body)
	list.get_parent().name = "EnemyRosterScroll"
	list.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 0)
	ui.memory.watch(list.get_parent(), "deployment_enemy_roster")

	filter.item_selected.connect(func(index):
		enemy_job_filter = str(filter.get_item_metadata(index))
		for row in list.find_children("*", "Button", true, false):
			if row.has_meta("roster_job"):
				row.visible = enemy_job_filter.is_empty() or row.get_meta("roster_job") == enemy_job_filter)

	for enemy in enemies:
		var button = ui.local_button(list, "", hud.open_equipment_sheet.bind(str(enemy.id)))
		button.name = "DeploymentEnemy_" + str(enemy.id)
		button.custom_minimum_size = Vector2(254, 88)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var job := str(enemy.get("job", ""))
		button.set_meta("roster_job", job)
		button.visible = enemy_job_filter.is_empty() or job == enemy_job_filter
		button.tooltip_text = str(enemy.name) + "の装備・所持品を開く"
		var line = ui.mock_shell.roster_member_line(button, enemy)
		var info = line.get_node("MemberInfo")
		var role_text := enemy_role_label(enemy)
		var detail_text := role_text
		if enemy.has("carriedWeight"):
			var wt_val := int(round(float(enemy.get("carriedWeight", 0))))
			var wt_limit := int(round(float(enemy.get("weightLimit", enemy.get("str", 0)))))
			detail_text = "%s   Wt %d / %d" % [role_text, wt_val, wt_limit]
		var detail = ui.label_(info, detail_text)
		detail.add_theme_font_size_override("font_size", Tokens.FONT_SM)
		if enemy.get("overburdened", false):
			detail.add_theme_color_override("font_color", Tokens.DANGER)
		for child in info.get_children():
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var state = Label.new()
		state.name = "DeploymentEnemyState"
		state.text = "戦闘不能" if int(enemy.get("hp", 0)) <= 0 else "出場"
		state.add_theme_font_size_override("font_size", Tokens.FONT_XS)
		state.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(state)
	layout()
