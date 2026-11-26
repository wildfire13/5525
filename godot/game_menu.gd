extends RefCounted
## Shared overlay menu (save/load, action log, settings, audio sliders, and exit).
const Tokens = preload("res://ui_tokens.gd")
const ScreenGrid = preload("res://screen_grid.gd")
const WindowGrid = preload("res://window_grid.gd")
const UiMotion = preload("res://ui_motion.gd")

const PALETTE_PREVIEWS := [
	{
		"label": "配色：緑",
		"tooltip": "既存：ディープパイン（クリックで次の配色へ）",
		"normal": Tokens.ACTION,
		"hover": Tokens.ACTION_HOVER,
		"pressed": Tokens.ACTION_PRESSED,
		"border": Tokens.ACTION_PRESSED,
		"ink": Tokens.INK_INVERSE,
	},
	{
		"label": "配色：ネイビー",
		"tooltip": "ネイビー×真鍮ゴールド（クリックで次の配色へ）",
		"normal": Color("#1e3a5f"),
		"hover": Color("#294d7a"),
		"pressed": Color("#142842"),
		"border": Color("#c28b2c"),
		"ink": Color("#f6f8fa"),
	},
	{
		"label": "配色：臙脂",
		"tooltip": "バーガンディ×スレート（クリックで次の配色へ）",
		"normal": Color("#7c2633"),
		"hover": Color("#963140"),
		"pressed": Color("#5e1b26"),
		"border": Color("#5e1b26"),
		"ink": Color("#f9f7f6"),
	},
	{
		"label": "配色：ティール",
		"tooltip": "マリンティール×ミスト（クリックで次の配色へ）",
		"normal": Color("#0f5e66"),
		"hover": Color("#167680"),
		"pressed": Color("#0a454b"),
		"border": Color("#0a454b"),
		"ink": Color("#f5f9f9"),
	},
	{
		"label": "配色：ダーク",
		"tooltip": "ダークスレート×アンバー（クリックで次の配色へ）",
		"normal": Color("#18212b"),
		"hover": Color("#243242"),
		"pressed": Color("#10171f"),
		"border": Color("#c88a2e"),
		"ink": Color("#f4efe4"),
	},
]

var ui
var overlay: Control
var panel: PanelContainer
var _last_size := Vector2.ZERO
var _palette_index := 0


func _init(frontend) -> void:
	ui = frontend


func build(menu_button: Button) -> void:
	# Facility controls use top_level for grid placement. A separate canvas puts
	# the open menu first for pointer input as well as drawing.
	var menu_layer := CanvasLayer.new()
	ui.add_child(menu_layer)

	overlay = Control.new()
	overlay.name = "CommonMenuOverlay"
	menu_layer.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.hide()

	panel = PanelContainer.new()
	panel.name = "CommonMenu"
	panel.clip_contents = true
	overlay.add_child(panel)
	panel.hide()

	var menu_style: StyleBoxFlat = ui.mock_shell.style()
	menu_style.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", menu_style)

	panel.visibility_changed.connect(func():
		if not panel.visible:
			overlay.hide()
			menu_button.grab_focus()
	)
	overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			panel.hide()
			overlay.accept_event()
	)

	var menu_grid := WindowGrid.new()
	panel.add_child(menu_grid)

	var top_section := VBoxContainer.new()
	top_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_section.add_theme_constant_override("separation", Tokens.SPACE_NONE)
	menu_grid.add_child(top_section)

	var heading := WindowGrid.title_label("メニュー")
	heading.name = "CommonMenuHeading"
	heading.custom_minimum_size.y = Tokens.WINDOW_BAR_HEIGHT
	heading.bar.mouse_default_cursor_shape = Control.CURSOR_ARROW
	var close_button := Button.new()
	close_button.name = "CommonMenuClose"
	close_button.text = "×"
	close_button.tooltip_text = "閉じる"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_size_override("font_size", Tokens.FONT_SM)
	close_button.pressed.connect(panel.hide)
	heading.attach_close(close_button)
	top_section.add_child(heading)

	var menu_scroll := ScrollContainer.new()
	menu_scroll.name = "CommonMenuScroll"
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.follow_focus = true
	menu_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll_pad := StyleBoxEmpty.new()
	scroll_pad.content_margin_left = Tokens.SPACE_SM
	scroll_pad.content_margin_right = Tokens.SPACE_SM
	scroll_pad.content_margin_top = Tokens.SPACE_SM
	scroll_pad.content_margin_bottom = Tokens.SPACE_SM
	menu_scroll.add_theme_stylebox_override("panel", scroll_pad)
	top_section.add_child(menu_scroll)

	var menu_body := VBoxContainer.new()
	menu_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_body.add_theme_constant_override("separation", Tokens.SPACE_XS)
	menu_scroll.add_child(menu_body)

	var actions := GridContainer.new()
	actions.name = "MenuActions"
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", Tokens.SPACE_XS)
	actions.add_theme_constant_override("v_separation", Tokens.SPACE_XS)
	menu_body.add_child(actions)
	_add_menu_actions(actions)
	for control in actions.get_children():
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if control is Button:
			control.clip_text = true
			control.add_theme_font_size_override("font_size", Tokens.FONT_SM)

	_add_cloud_speed(menu_body)
	_add_reduced_motion(menu_body)
	_add_audio_settings(menu_grid)

	ui.menu = panel
	ui.menu_overlay = overlay


func _add_menu_actions(menu_body: GridContainer) -> void:
	for item in [["セーブ", ui.save_game], ["ロード", ui.load_dialog], ["行動ログ", ui.show_action_log]]:
		var callback: Callable = item[1]
		ui.button(menu_body, item[0], func():
			panel.hide()
			callback.call()
		)

	var reopen_results: Button = ui.local_button(menu_body, "直近のリザルト", func():
		panel.hide()
		ui.results_view.reopen()
	)
	reopen_results.name = "ReopenResults"

	var label_switch := CheckButton.new()
	label_switch.name = "UiLabelSwitch"
	label_switch.text = "UIラベル表示"
	Tokens.apply_button_size(label_switch, Tokens.BUTTON_MD)
	label_switch.button_pressed = ui.ui_labels.enabled
	label_switch.toggled.connect(ui.ui_labels.set_enabled)
	menu_body.add_child(label_switch)

	var palette_button: Button = ui.local_button(menu_body, "", func(): pass)
	palette_button.name = "PalettePreviewButton"
	_apply_palette_preview(palette_button)
	palette_button.pressed.connect(func():
		_palette_index = (_palette_index + 1) % PALETTE_PREVIEWS.size()
		_apply_palette_preview(palette_button)
	)
	ui.local_button(menu_body, "全画面 F11", func():
		panel.hide()
		ui.fullscreen()
	)

	if ui.debug_view.is_enabled():
		var dev_button: Button = ui.local_button(menu_body, "開発情報", func():
			panel.hide()
			ui.debug_view.open()
		)
		dev_button.name = "OpenDeveloperWindow"
		dev_button.tooltip_text = "開発情報を別ウィンドウで開く"

	ui.button(menu_body, "新しい旅", func():
		panel.hide()
		ui.confirm(
			"未保存の進行を終了し、新しい旅を始めます。保存済みファイルは変更しません。",
			ui.new_game
		)
	)

	var quit_button: Button = ui.local_button(menu_body, "ゲームを終了する", func():
		panel.hide()
		ui.close_game()
	)
	quit_button.name = "QuitGame"

	ui.local_button(menu_body, "閉じる", panel.hide)

	var withdraw: Button = ui.local_button(menu_body, "護送を断念して撤退", func():
		panel.hide()
		ui.confirm(
			"水門の鐘の護送を断念しますか？　報酬はなく、受注前の状態に戻ります。",
			ui.act.bind("retreat", [])
		)
	)
	withdraw.name = "WithdrawSluice"
	withdraw.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	withdraw.hide()
	panel.visibility_changed.connect(func():
		var job = ui.campaign().get("activeQuest")
		withdraw.visible = (
			panel.visible
			and job is Dictionary
			and job.get("id") == "sluice-bell"
			and ui.campaign().get("phase") == "battle"
			and not ui.state().get("result")
		)
	)


func _apply_palette_preview(button: Button) -> void:
	var spec: Dictionary = PALETTE_PREVIEWS[_palette_index]
	button.text = str(spec["label"])
	button.tooltip_text = str(spec["tooltip"])
	var border: Color = spec["border"]
	var normal_box := Tokens.elevate(Tokens.box(spec["normal"], border), 4, 2.0, Tokens.SHADOW_ELEVATED)
	var hover_box := Tokens.elevate(Tokens.box(spec["hover"], border), 6, 3.0, Tokens.SHADOW_ELEVATED)
	var pressed_box := Tokens.box(spec["pressed"], border)
	button.add_theme_stylebox_override("normal", normal_box)
	button.add_theme_stylebox_override("hover", hover_box)
	button.add_theme_stylebox_override("pressed", pressed_box)
	button.add_theme_stylebox_override("hover_pressed", pressed_box)
	var ink: Color = spec["ink"]
	for key in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(key, ink)


func _add_cloud_speed(parent: Container) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Tokens.SPACE_SM)
	parent.add_child(row)
	var label := Label.new()
	label.text = "雲の速さ"
	row.add_child(label)

	var slider := HSlider.new()
	slider.name = "CloudSpeed"
	slider.max_value = ui.preferences.MAX_CLOUD_SPEED
	slider.step = 0.05
	slider.value = ui.preferences.cloud_speed
	slider.custom_minimum_size.y = Tokens.BUTTON_SM
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	var value := Label.new()
	value.text = "%.2f" % slider.value
	value.custom_minimum_size.x = 55
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	slider.value_changed.connect(func(speed: float):
		value.text = "%.2f" % speed
		ui.preferences.store_cloud_speed(speed)
	)


func _add_reduced_motion(parent: Container) -> void:
	var motion_switch := CheckButton.new()
	motion_switch.name = "ReducedMotionSwitch"
	motion_switch.text = "モーション軽減"
	motion_switch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Tokens.apply_button_size(motion_switch, Tokens.BUTTON_SM)
	motion_switch.button_pressed = ui.preferences.reduced_motion
	motion_switch.toggled.connect(ui.preferences.store_reduced_motion)
	parent.add_child(motion_switch)


func _add_audio_settings(menu_grid: Container) -> void:
	var audio_settings := MarginContainer.new()
	audio_settings.name = "AudioSettings"
	audio_settings.add_theme_constant_override("margin_left", Tokens.SPACE_MD)
	audio_settings.add_theme_constant_override("margin_right", Tokens.SPACE_MD)
	audio_settings.add_theme_constant_override("margin_top", Tokens.SPACE_SM)
	audio_settings.add_theme_constant_override("margin_bottom", Tokens.SPACE_MD)
	menu_grid.add_child(audio_settings)

	var audio_list := VBoxContainer.new()
	audio_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	audio_list.add_theme_constant_override("separation", Tokens.SPACE_XS)
	audio_settings.add_child(audio_list)
	audio_list.add_child(HSeparator.new())

	for pair in [["bgm", "BGM"], ["voice", "ボイス"], ["se", "SE"]]:
		var kind := str(pair[0])
		var caption := str(pair[1])

		var controls := VBoxContainer.new()
		controls.add_theme_constant_override("separation", 2)
		audio_list.add_child(controls)

		var category := Label.new()
		category.text = caption + "音量"
		category.add_theme_font_size_override("font_size", Tokens.FONT_SM)
		controls.add_child(category)

		var volume_row := HBoxContainer.new()
		volume_row.add_theme_constant_override("separation", Tokens.SPACE_SM)
		controls.add_child(volume_row)

		var slider := HSlider.new()
		slider.name = "AudioVolume_" + kind
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 10
		slider.custom_minimum_size = Vector2(220, 28)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		volume_row.add_child(slider)

		var value_label := Label.new()
		value_label.name = "AudioVolumeValue_" + kind
		value_label.custom_minimum_size.x = 90
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.add_theme_font_size_override("font_size", Tokens.FONT_SM)
		volume_row.add_child(value_label)

		var refresh_audio := func():
			var level: int = ui.audio.effective_volume(kind)
			slider.set_value_no_signal(level)
			value_label.text = "%d%%" % level + (" 無音" if level == 0 else "")

		refresh_audio.call()
		ui.audio.settings_changed.connect(refresh_audio)
		slider.value_changed.connect(func(value: float):
			ui.audio.set_sound_level(kind, value)
			ui.sync_audio()
		)


func open() -> void:
	var result_button = ui.find_child("ReopenResults", true, false)
	if result_button != null:
		var disabled: bool = (
			ui.results_view.recent.is_empty()
			or ui.campaign().get("phase") in ["battle", "deployment"]
			or ui.data.get("trial") != null
		)
		result_button.disabled = disabled
		result_button.set_meta("base_disabled", disabled)
		result_button.tooltip_text = (
			"戦闘外で、直近に確認した結果を表示できます"
			if disabled
			else "報酬を再付与せず、直近の結果を見返します"
		)

	if panel.visible:
		panel.hide()
		return

	overlay.show()
	panel.show()
	fit()
	UiMotion.reveal(panel, ui, UiMotion.BASE, 0.975)

	var controls := focus_controls()
	if not controls.is_empty():
		controls[0].grab_focus()


func focus_controls() -> Array:
	return panel.find_children("*", "Control", true, false).filter(func(control: Control):
		return (
			control.focus_mode == Control.FOCUS_ALL
			and control.is_visible_in_tree()
			and (not control is BaseButton or not control.disabled)
		)
	)


func fit() -> void:
	_last_size = ui.size
	ScreenGrid.place(panel, ScreenGrid.cell_rect(ui.size, 3, 1, 2, 6))


func sync_size() -> void:
	if panel != null and panel.visible and _last_size != ui.size:
		fit()
