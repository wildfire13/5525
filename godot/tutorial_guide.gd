extends CanvasLayer
## Guided tutorial scenario walking the player through the full 5525 game cycle:
## Hub -> Party/Board -> Quest Accept -> World Map -> Road -> Deployment/Battle -> Delivery.

const Tokens = preload("res://ui_tokens.gd")
const Grid = preload("res://screen_grid.gd")
const UiMotion = preload("res://ui_motion.gd")
const HelpBadge = preload("res://help_badge.gd")

var ui
var banner: PanelContainer
var step_badge: Label
var guide_label: Label
var skip_button: Button
var _last_step := ""
var _dialogue_busy := false
var _completion_queued := false


func _init(frontend) -> void:
	ui = frontend
	name = "TutorialGuideLayer"
	layer = 1400


func _ensure_banner() -> void:
	if is_instance_valid(banner):
		return
	banner = PanelContainer.new()
	banner.name = "TutorialBanner"
	banner.theme = ui.theme
	banner.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := Tokens.elevate(
		Tokens.box(Tokens.NOTICE_BG, Tokens.NOTICE_BORDER, Tokens.RADIUS_SM, Tokens.SPACE_SM, Tokens.BORDER_WIDTH),
		8,
		3.0,
		Tokens.SHADOW_ELEVATED
	)
	style.content_margin_left = Tokens.SPACE_MD
	style.content_margin_right = Tokens.SPACE_MD
	banner.add_theme_stylebox_override("panel", style)
	add_child(banner)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Tokens.SPACE_SM)
	banner.add_child(row)

	step_badge = Label.new()
	step_badge.name = "TutorialStepBadge"
	step_badge.add_theme_font_size_override("font_size", Tokens.FONT_XS)
	step_badge.add_theme_color_override("font_color", Tokens.NOTICE_BORDER)
	row.add_child(step_badge)

	guide_label = Label.new()
	guide_label.name = "TutorialGuideText"
	guide_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_label.add_theme_font_size_override("font_size", Tokens.FONT_SM)
	guide_label.add_theme_color_override("font_color", Tokens.INK_INVERSE)
	row.add_child(guide_label)

	HelpBadge.attach(
		row,
		"チュートリアル進行ガイド",
		"アスタリスで依頼を受け、街道を通ってイースへ荷物を届けるまでの一連のゲームサイクルを案内します。いつでも右の「スキップ」で終了できます。",
		"TutorialHelpBadge",
		20
	)

	skip_button = Button.new()
	skip_button.name = "TutorialSkipButton"
	skip_button.text = "スキップ"
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.custom_minimum_size = Vector2(96, 32)
	skip_button.add_theme_font_size_override("font_size", Tokens.FONT_XS)
	skip_button.pressed.connect(func():
		ui.act("tutorialAction", ["skip"])
	)
	row.add_child(skip_button)

	banner.minimum_size_changed.connect(_layout, CONNECT_DEFERRED)
	if not ui.resized.is_connected(_layout):
		ui.resized.connect(_layout)
	_layout()


func _layout() -> void:
	if not is_instance_valid(banner):
		return
	Grid.place(banner, Grid.cell_rect(ui.size, 3, 0, 5, 1))


func _player_name() -> String:
	var profile: Dictionary = ui.campaign().get("playerProfile", {})
	var n := str(profile.get("name", "")).strip_edges()
	return n if not n.is_empty() else "隊長"


func sync() -> void:
	var c: Dictionary = ui.campaign()
	if c.is_empty():
		hide_banner()
		return
	var tut: Dictionary = c.get("tutorial", {})
	if not bool(tut.get("active", false)):
		hide_banner()
		_last_step = ""
		_completion_queued = false
		return

	# 1. Opening welcome dialogue right after character creation.
	if not bool(tut.get("introShown", false)):
		hide_banner()
		if not _dialogue_busy and not ui.modal_open() and ui.pages.quest_board.dialogue == null:
			_dialogue_busy = true
			var pname := _player_name()
			var intro_story := {
				"sceneLabel": "チュートリアル：初仕事へ",
				"portrait": "merchant",
				"cast": ["merchant"],
				"story": [
					["merchant", "%s、アスタリス隊商ギルドへようこそ！ これから最初の配達依頼に挑戦しよう。" % pname],
					["merchant", "基本の流れは『掲示板で依頼を受ける → ワールドマップから出発 → 街道を切り抜けて目的地で納品』だ。"],
					["merchant", "まずは広場の『掲示板』を開いて、イース行きの配達依頼を確認してみよう！"],
				],
			}
			var dlg = preload("res://quest_dialogue.gd").new(ui, ui.pages.quest_board)
			ui.pages.quest_board.dialogue = dlg
			ui.add_child(dlg)
			dlg.open(intro_story, Callable(), func():
				ui.pages.quest_board.dialogue = null
				_dialogue_busy = false
				ui.act("tutorialAction", ["intro_done"])
			)
		return

	# 2. Completion dialogue once the first quest has been delivered!
	if int(c.get("completed", 0)) >= 1:
		hide_banner()
		if not _completion_queued and not _dialogue_busy and not ui.results_view.active and ui.pages.quest_board.dialogue == null and str(c.get("phase", "")) == "town":
			_completion_queued = true
			_dialogue_busy = true
			var pname := _player_name()
			var outro_story := {
				"sceneLabel": "チュートリアル完了",
				"portrait": "merchant",
				"cast": ["merchant"],
				"story": [
					["merchant", "見事だ、%s！ 最初の配達をやり遂げたな。" % pname],
					["merchant", "これで『依頼受注・出発・街道選択・配置と戦闘・施設での納品』の一通りを体験できたぞ。"],
					["merchant", "ここからは自由だ。稼いだ資金で武器や防具を整え、アスタリスのギルドで仲間を編成して次の旅へ挑もう！"],
				],
			}
			var dlg = preload("res://quest_dialogue.gd").new(ui, ui.pages.quest_board)
			ui.pages.quest_board.dialogue = dlg
			ui.add_child(dlg)
			dlg.open(outro_story, Callable(), func():
				ui.pages.quest_board.dialogue = null
				_dialogue_busy = false
				ui.act("tutorialAction", ["complete"])
			)
		return

	# Hide banner during blocking overlays/results/menus
	if ui.results_view.active or ui.modal_open() or (is_instance_valid(ui.menu) and ui.menu.visible):
		hide_banner()
		return

	_ensure_banner()
	var step_info := _current_step(c)
	banner.show()
	step_badge.text = str(step_info["badge"])
	guide_label.text = str(step_info["text"])
	_layout()
	var key := str(step_info["id"])
	if key != _last_step:
		_last_step = key
		UiMotion.reveal(banner, ui, UiMotion.BASE, 1.0)


func _current_step(c: Dictionary) -> Dictionary:
	var phase := str(c.get("phase", "town"))
	var quest: Variant = c.get("activeQuest")
	var loc := str(c.get("location", "astaris"))
	var page := str(ui.page)
	var journey: Variant = c.get("journey")
	var stage := int(journey.get("stage", 0)) if journey is Dictionary else 0
	if phase == "arrival":
		return {"id": "arrival", "badge": "STEP 6/6", "text": "【到着】目的地の目前です！『街へ入る』を押して街に入り、依頼の荷物を納品しましょう。"}
	if phase == "camp":
		return {"id": "camp", "badge": "STEP 5/6", "text": "【野営・2区間目へ】HP/MPが心配なら『休息』、そのまま進むなら『次の区間へ』を選びましょう。"}
	if phase == "road":
		if stage == 1 and journey.get("banditAmbush", false) and not journey.get("returning", false):
			return {"id": "road_ambush", "badge": "STEP 5/6", "text": "【街道 2区間目】峠の近道か、川沿いの迂回路を選びましょう。"}
		if stage >= 1:
			return {"id": "road_2", "badge": "STEP 5/6", "text": "【街道 2区間目】川沿いの道を選ぶと時間はかかりますが、今回は戦闘を避けて安全に目的地へ到着できます。"}
		return {"id": "road_1", "badge": "STEP 4/6", "text": "【街道 1区間目】ルートを選びましょう（近道は早いが敵が多く、川沿いは時間がかかるが安全寄りです）。"}
	if phase in ["deployment", "battle"]:
		var badge := "STEP 5/6" if stage >= 1 else "STEP 4/6"
		var prefix := "2区間目" if stage >= 1 else "1区間目"
		var battle: Dictionary = c.get("battle", {})
		if battle.has("banditChiefId"):
			for unit in battle.get("units", []):
				if unit.id == battle.banditChiefId and unit.hp > 0:
					return {"id": "bandit_chief", "badge": badge, "text": "山賊の頭目ガンザが街道を封鎖しています。頭目を倒すと、ポーターが敵陣最奥から突破できます。"}
		if phase == "deployment":
			return {"id": "deploy_%d" % stage, "badge": badge, "text": "【配置・%s】味方をドラッグで移動できます。準備ができたら右下の『戦闘開始』を押しましょう。" % prefix}
		return {"id": "battle_%d" % stage, "badge": badge, "text": "【戦闘・%s】左のコマンドを選び、盤面の対象をクリックして予測を確認後、右下の『実行』で行動します。" % prefix}
	if quest is Dictionary:
		var dest := str(quest.get("to", "east"))
		if loc == dest:
			var fac := str(quest.get("deliveryFacility", ""))
			var target_hint := "『武器店』に入り『納品する』" if fac == "weapon" else "『荷物を届ける』"
			return {"id": "deliver", "badge": "STEP 6/6", "text": "【納品】目的地に到着しました！%sを選んで報酬を受け取りましょう。" % target_hint}
		if page == "map":
			return {"id": "depart", "badge": "STEP 3/6", "text": "【出発】緑枠のクエスト目的地を選び、『出発する』で街道へ旅立ちましょう。"}
		return {"id": "to_map", "badge": "STEP 3/6", "text": "【出発準備】『届け先を確認』または広場の『出発の準備・街道口』から目的地へ出発しましょう。"}
	if page == "board":
		return {"id": "accept", "badge": "STEP 2/6", "text": "【依頼受注】『イースへ、急ぎの鍛冶場の包帯』を選び、ポーターに荷物を託して引き受けましょう。"}
	return {"id": "hub", "badge": "STEP 1/6", "text": "【拠点】まずは『掲示板』で最初の配達依頼を確認しましょう（左下の『パーティ情報』で装備も確認できます）。"}


func hide_banner() -> void:
	if is_instance_valid(banner):
		banner.hide()
