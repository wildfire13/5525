extends RefCounted
## Shared overlay menu (save/load, action log, settings, audio sliders, and exit).
const Tokens = preload("res://ui_tokens.gd")
const ScreenGrid = preload("res://screen_grid.gd")
const WindowGrid = preload("res://window_grid.gd")

var ui
var overlay: Control
var panel: PanelContainer
var _last_size := Vector2.ZERO


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

	var menu_scroll := ScrollContainer.new()
	menu_scroll.name = "CommonMenuScroll"
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.follow_focus = true
	menu_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_grid.add_child(menu_scroll)

	var menu_body := VBoxContainer.new()
	menu_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_scroll.add_child(menu_body)

	_add_menu_actions(menu_body)
	_add_audio_settings(menu_grid)

	ui.menu = panel
	ui.menu_overlay = overlay


func _add_menu_actions(menu_body: VBoxContainer) -> void:
	for item in [["セーブ", ui.save_game], ["ロード", ui.load_dialog], ["行動ログ", ui.show_action_log]]:
		var callback: Callable = item[1]
		ui.button(menu_body, item[0], func():
			panel.hide()
			callback.call()
		)

	var withdraw: Button = ui.local_button(menu_body, "護送を断念して撤退", func():
		panel.hide()
		ui.confirm(
			"水門の鐘の護送を断念しますか？　報酬はなく、受注前の状態に戻ります。",
			ui.act.bind("retreat", [])
		)
	)
	withdraw.name = "WithdrawSluice"
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

	ui.local_button(menu_body, "操作説明", func():
		panel.hide()
		ui.show_help()
	)
	ui.local_button(menu_body, "全画面 F11", func():
		panel.hide()
		ui.fullscreen()
	)

	if ui.debug_view.is_enabled():
		var dev_button: Button = ui.local_button(menu_body, "開発情報（別ウィンドウ）", func():
			panel.hide()
			ui.debug_view.open()
		)
		dev_button.name = "OpenDeveloperWindow"

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


func _add_audio_settings(menu_grid: Container) -> void:
	var audio_settings := VBoxContainer.new()
	audio_settings.name = "AudioSettings"
	menu_grid.add_child(audio_settings)

	for pair in [["bgm", "BGM"], ["voice", "ボイス"], ["se", "SE"]]:
		var kind := str(pair[0])
		var caption := str(pair[1])

		var controls := VBoxContainer.new()
		audio_settings.add_child(controls)

		var category := Label.new()
		category.text = caption + "音量"
		controls.add_child(category)

		var volume_row := HBoxContainer.new()
		controls.add_child(volume_row)

		var slider := HSlider.new()
		slider.name = "AudioVolume_" + kind
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 10
		slider.custom_minimum_size = Vector2(220, 32)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		volume_row.add_child(slider)

		var value_label := Label.new()
		value_label.name = "AudioVolumeValue_" + kind
		value_label.custom_minimum_size.x = 90
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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
	ScreenGrid.place(panel, ScreenGrid.cell_rect(ui.size, 3, 1, 3, 8))


func sync_size() -> void:
	if panel != null and panel.visible and _last_size != ui.size:
		fit()
