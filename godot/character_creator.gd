extends CanvasLayer
## Player character creation modal (name, race, job, gender, live portrait & stats).

const Tokens = preload("res://ui_tokens.gd")
const Portraits = preload("res://portraits.gd")
const Grid = preload("res://screen_grid.gd")
const UiMotion = preload("res://ui_motion.gd")
const HelpBadge = preload("res://help_badge.gd")

const RACES := [
	{"id": "human", "label": "人間", "desc": "バランスが良く、どの職業でも扱いやすい。"},
	{"id": "elf", "label": "エルフ", "desc": "高い知性と機敏さを持ち、魔法や斥候が得意。"},
	{"id": "dwarf", "label": "ドワーフ", "desc": "頑強で剛力。重い装備や荷物を扱いやすい。"},
]
const JOBS := [
	{"id": "job_warrior", "label": "戦士", "desc": "前衛の要。剣盾で仲間を守りながら戦う。"},
	{"id": "job_scout", "label": "スカウト", "desc": "素早い行動順と奇襲で敵陣を崩す遊撃手。"},
	{"id": "job_mage", "label": "魔法使い", "desc": "遠距離攻撃や回復で戦況を支える術師。"},
	{"id": "job_porter", "label": "ポーター", "desc": "荷物を無限枠で運べる隊商の要。陣形強化も担う。"},
]
const SEXES := [
	{"id": "female", "label": "女性", "icon": "res://assets/interface_icons/female_64.png"},
	{"id": "male", "label": "男性", "icon": "res://assets/interface_icons/male_64.png"},
]

var ui
var overlay: ColorRect
var panel: PanelContainer
var name_input: LineEdit
var portrait_rect: TextureRect
var portrait_entry: Dictionary
var preview_texture: Texture2D
var reset_image: Button
var image_message: Label
var reading_image := false
var stats_label: Label
var desc_label: Label
var race_buttons := {}
var job_buttons := {}
var sex_buttons := {}

var selected_race := "human"
var selected_job := "job_porter"
var selected_sex := "female"
var _custom_name_edited := false
var _submitting := false


func _init(frontend) -> void:
	ui = frontend
	name = "CharacterCreatorLayer"
	layer = 1600


func open() -> void:
	if is_instance_valid(overlay):
		return
	_submitting = false
	_custom_name_edited = false
	portrait_entry = {}
	preview_texture = null
	reading_image = false
	selected_race = "human"
	var returning_player: bool = ui.campaign().get("playerProfile", {}).get("returningPlayer", false)
	selected_job = "job_warrior" if returning_player else "job_porter"
	selected_sex = "female"

	overlay = ColorRect.new()
	overlay.name = "CharacterCreatorOverlay"
	overlay.theme = ui.theme
	overlay.color = Color(Tokens.OVERLAY_DARK, 0.52)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	panel = PanelContainer.new()
	panel.name = "CharacterCreatorPanel"
	panel.clip_contents = true
	var style := Tokens.elevate(
		Tokens.box(Tokens.SURFACE, Tokens.BORDER_ACCENT, Tokens.RADIUS_LG, 0, Tokens.BORDER_WIDTH_EMPHASIS),
		16,
		6.0,
		Tokens.SHADOW_ELEVATED
	)
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)

	var root_col := VBoxContainer.new()
	root_col.add_theme_constant_override("separation", Tokens.SPACE_NONE)
	panel.add_child(root_col)

	# Title Bar
	var title_bar := PanelContainer.new()
	var bar_style := Tokens.window_bar_box()
	bar_style.corner_radius_bottom_left = 0
	bar_style.corner_radius_bottom_right = 0
	title_bar.add_theme_stylebox_override("panel", bar_style)
	title_bar.custom_minimum_size.y = 52
	root_col.add_child(title_bar)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", Tokens.SPACE_SM)
	title_bar.add_child(title_row)
	var heading := Label.new()
	heading.name = "CharacterCreatorTitle"
	heading.text = "主人公キャラクター作成"
	heading.add_theme_font_size_override("font_size", Tokens.FONT_HEADING)
	heading.add_theme_color_override("font_color", Tokens.INK_INVERSE)
	title_row.add_child(heading)

	# Main Content (2 columns: Left = form, Right = live portrait & stats)
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", Tokens.SPACE_XL)
	margin.add_theme_constant_override("margin_right", Tokens.SPACE_XL)
	margin.add_theme_constant_override("margin_top", Tokens.SPACE_LG)
	margin.add_theme_constant_override("margin_bottom", Tokens.SPACE_LG)
	root_col.add_child(margin)

	var content_col := VBoxContainer.new()
	content_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_col.add_theme_constant_override("separation", Tokens.SPACE_LG)
	margin.add_child(content_col)

	var intro := Label.new()
	intro.text = "アスタリスから旅立つ隊商のリーダーを作成してください。作成後、ゲームの流れを一通り体験できるチュートリアルが始まります。"
	intro.custom_minimum_size.x = 900
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", Tokens.FONT_SM)
	intro.add_theme_color_override("font_color", Tokens.MUTED_INK)
	content_col.add_child(intro)

	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", Tokens.SPACE_XL)
	content_col.add_child(split)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.25
	left.add_theme_constant_override("separation", Tokens.SPACE_MD)
	split.add_child(left)

	# Name field
	var name_head := HBoxContainer.new()
	name_head.add_theme_constant_override("separation", Tokens.SPACE_XS)
	left.add_child(name_head)
	var name_lbl := Label.new()
	name_lbl.text = "名前（1〜16文字・未入力時は種族/職業の候補名が入ります。自由に入力可）"
	name_lbl.add_theme_font_size_override("font_size", Tokens.FONT_SM)
	name_head.add_child(name_lbl)

	name_input = LineEdit.new()
	name_input.name = "CreatorNameInput"
	name_input.max_length = 16
	name_input.placeholder_text = "主人公の名前を入力"
	name_input.custom_minimum_size.y = Tokens.BUTTON_MD
	name_input.text_changed.connect(func(_t): _custom_name_edited = true)
	left.add_child(name_input)

	# Race selector
	var race_head := HBoxContainer.new()
	race_head.add_theme_constant_override("separation", Tokens.SPACE_XS)
	left.add_child(race_head)
	var race_lbl := Label.new()
	race_lbl.text = "種族"
	race_lbl.add_theme_font_size_override("font_size", Tokens.FONT_SM)
	race_head.add_child(race_lbl)
	HelpBadge.attach(race_head, "種族の違い", "種族によって初期のSTR/INT/AGIや種族専用の頭装備（髪飾り）が変わり、得意な戦い方に影響します。", "CreatorHelpRace")

	var race_row := HBoxContainer.new()
	race_row.add_theme_constant_override("separation", Tokens.SPACE_SM)
	left.add_child(race_row)
	race_buttons.clear()
	for spec in RACES:
		var rid := str(spec["id"])
		var btn: Button = ui.local_button(race_row, str(spec["label"]), func():
			selected_race = rid
			_refresh()
		)
		btn.name = "CreatorRace_" + rid
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		race_buttons[rid] = btn

	# Job selector
	var job_head := HBoxContainer.new()
	job_head.add_theme_constant_override("separation", Tokens.SPACE_XS)
	left.add_child(job_head)
	var job_lbl := Label.new()
	job_lbl.text = "職業"
	job_lbl.add_theme_font_size_override("font_size", Tokens.FONT_SM)
	job_head.add_child(job_lbl)
	HelpBadge.attach(job_head, "職業の役割", "戦士は前衛の壁、スカウトは高機敏の遊撃、魔法使いは遠距離支援・攻撃、ポーターは荷物を無限枠で運べる隊商の要です。", "CreatorHelpJob")

	var job_grid := GridContainer.new()
	job_grid.columns = 2
	job_grid.add_theme_constant_override("h_separation", Tokens.SPACE_SM)
	job_grid.add_theme_constant_override("v_separation", Tokens.SPACE_SM)
	left.add_child(job_grid)
	job_buttons.clear()
	for spec in JOBS:
		var jid := str(spec["id"])
		var btn: Button = ui.button(job_grid, str(spec["label"]), func():
			selected_job = jid
			_refresh()
		, not returning_player and jid != "job_porter")
		btn.name = "CreatorJob_" + jid
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		job_buttons[jid] = btn

	# Sex selector
	var sex_lbl := Label.new()
	sex_lbl.text = "性別・見た目"
	sex_lbl.add_theme_font_size_override("font_size", Tokens.FONT_SM)
	left.add_child(sex_lbl)

	var sex_row := HBoxContainer.new()
	sex_row.add_theme_constant_override("separation", Tokens.SPACE_SM)
	left.add_child(sex_row)
	sex_buttons.clear()
	for spec in SEXES:
		var sid := str(spec["id"])
		var btn: Button = ui.local_button(sex_row, str(spec["label"]), func():
			selected_sex = sid
			_refresh()
		)
		btn.name = "CreatorSex_" + sid
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if ResourceLoader.exists(str(spec["icon"])):
			btn.icon = load(str(spec["icon"]))
			btn.expand_icon = true
			btn.add_theme_constant_override("icon_max_width", 24)
		sex_buttons[sid] = btn

	desc_label = Label.new()
	desc_label.name = "CreatorDescription"
	desc_label.custom_minimum_size.x = 560
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", Tokens.FONT_SM)
	desc_label.add_theme_color_override("font_color", Tokens.MUTED_INK)
	left.add_child(desc_label)

	# Right column: live portrait + computed stats
	var right_card := PanelContainer.new()
	right_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_card.size_flags_stretch_ratio = 1.0
	right_card.add_theme_stylebox_override("panel", Tokens.box(Tokens.SURFACE_ALT, Tokens.BORDER, Tokens.RADIUS_SM, Tokens.SPACE_MD))
	split.add_child(right_card)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", Tokens.SPACE_SM)
	right_card.add_child(right)

	portrait_rect = TextureRect.new()
	portrait_rect.name = "CreatorPortraitPreview"
	portrait_rect.custom_minimum_size = Vector2(260, 280)
	portrait_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	right.add_child(portrait_rect)

	var image_actions := HBoxContainer.new()
	image_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_child(image_actions)
	var pick: Button = ui.local_button(image_actions, "画像を選ぶ", _pick_image)
	pick.name = "CreatorPickPortrait"
	reset_image = ui.local_button(image_actions, "元に戻す", _reset_image)
	reset_image.name = "CreatorResetPortrait"
	image_message = Label.new()
	image_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	image_message.hide()
	right.add_child(image_message)

	stats_label = Label.new()
	stats_label.name = "CreatorStatsPreview"
	stats_label.custom_minimum_size.x = 420
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.add_theme_font_size_override("font_size", Tokens.FONT_SM)
	right.add_child(stats_label)

	# Bottom action buttons
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", Tokens.SPACE_MD)
	content_col.add_child(actions)

	var skip_btn: Button = ui.local_button(actions, "チュートリアルをスキップして開始", func(): _submit(true), "lg_md")
	skip_btn.name = "CreatorStartSkip"
	skip_btn.custom_minimum_size.x = 300

	var start_btn: Button = ui.action_button(ui.local_button(actions, "この人物で旅を始める（チュートリアル）", func(): _submit(false), "lg_md"), "lg_md")
	start_btn.name = "CreatorStartTutorial"
	start_btn.custom_minimum_size.x = 360

	_layout()
	if not ui.resized.is_connected(_layout):
		ui.resized.connect(_layout)
	_refresh()
	UiMotion.reveal(panel, ui, UiMotion.BASE, 0.975)


func _layout() -> void:
	if not is_instance_valid(panel):
		return
	panel.custom_minimum_size = Vector2.ZERO
	Grid.place(panel, Grid.cell_rect(ui.size, 1, 1, 8, 8))


func _pick_image() -> void:
	if reading_image or _submitting:return
	var member := _preview_member(_matched_member()).duplicate()
	member.name = name_input.text.strip_edges()
	ui.pages.party_view.workspace.show_portrait_editor(member, portrait_entry, _apply_image, _read_image)

func _read_image(path: String) -> void:
	if not is_open() or reading_image or _submitting:return
	var owner_panel := panel
	reading_image = true
	var reply: Dictionary = await ui.read_portrait(path)
	if not is_open() or panel != owner_panel:return
	reading_image = false
	if not reply.get("ok", false):
		image_message.text = reply.get("error", "画像を読み込めませんでした")
		image_message.show()
		return
	_apply_image(reply.data)
	_pick_image()

func _apply_image(entry: Dictionary) -> void:
	portrait_entry = entry
	var image := Portraits.imported_image(entry)
	if entry.has("framing"):
		image = Portraits.framed_image(image, entry.framing)
	preview_texture = ImageTexture.create_from_image(image)
	image_message.hide()
	_refresh()

func _reset_image() -> void:
	portrait_entry = {}
	preview_texture = null
	image_message.hide()
	_refresh()

func _matched_member() -> Dictionary:
	for member in ui.roster():
		if str(member.get("race", "")) == selected_race and str(member.get("job", "")) == selected_job and str(member.get("sex", "")) == selected_sex:
			return member
	return ui.roster()[0] if not ui.roster().is_empty() else {}


func _preview_member(member: Dictionary) -> Dictionary:
	var former: Dictionary = ui.campaign().get("predecessor", {})
	if former.get("hire", false) and former.get("memberId") == member.get("id"):
		var successor := member.duplicate()
		successor.id = str(member.id) + "_successor"
		return successor
	return member

func _refresh() -> void:
	for rid in race_buttons:
		ui.mark_selected(race_buttons[rid], rid == selected_race)
	for jid in job_buttons:
		ui.mark_selected(job_buttons[jid], jid == selected_job)
	for sid in sex_buttons:
		ui.mark_selected(sex_buttons[sid], sid == selected_sex)

	var member := _matched_member()
	if not member.is_empty():
		if not _custom_name_edited or name_input.text.strip_edges().is_empty():
			name_input.text = str(member.get("name", "主人公"))
			_custom_name_edited = false
		portrait_rect.texture = preview_texture if preview_texture else ui.portraits.texture(_preview_member(member))
		reset_image.disabled = portrait_entry.is_empty() or reading_image
		var st: Dictionary = member.get("stats", {})
		var weapon_name := str(member.get("weaponName", "なし"))
		var skill_name := str(member.get("skillName", "なし"))
		if skill_name.is_empty():
			skill_name = "なし"
		stats_label.text = "職業: %s\nHP: %d  /  MP: %d\nSTR(重量上限): %d  /  INT: %d  /  AGI(SPD): %d\n初期武器: %s\nスキル: %s" % [
			str(member.get("role", "")),
			int(member.get("max", 0)),
			int(member.get("maxMp", 0)),
			int(st.get("str", 0)),
			int(st.get("int", 0)),
			int(st.get("speed", st.get("agi", 0))),
			weapon_name,
			skill_name,
		]
	var r_desc := ""
	for r in RACES:
		if r["id"] == selected_race:
			r_desc = str(r["desc"])
	var j_desc := ""
	for j in JOBS:
		if j["id"] == selected_job:
			j_desc = str(j["desc"])
	desc_label.text = "【種族】" + r_desc + "\n【職業】" + j_desc


func _submit(skip_tutorial: bool) -> void:
	if _submitting or reading_image:
		return
	_submitting = true
	HelpBadge.dismiss()
	var chosen_name := name_input.text.strip_edges()
	var payload := {
		"name": chosen_name,
		"race": selected_race,
		"job": selected_job,
		"sex": selected_sex,
		"skipTutorial": skip_tutorial,
	}
	var frontend := {} if portrait_entry.is_empty() else {"portrait":portrait_entry}
	var reply: Dictionary = await ui.update({"op":"campaign","action":"createPlayer","args":[payload]},frontend)
	if reply.get("ok", false):
		close()
		ui.tutorial_guide.sync()
	else:
		_submitting = false
		image_message.text = reply.get("error", "キャラクターを作成できませんでした")
		image_message.show()


func close() -> void:
	HelpBadge.dismiss()
	if ui.resized.is_connected(_layout):
		ui.resized.disconnect(_layout)
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null
	panel = null
	_submitting = false


func is_open() -> bool:
	return is_instance_valid(overlay) and overlay.visible
