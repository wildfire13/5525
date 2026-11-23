extends RefCounted
## Native Control D&D carries a quote of current deployment context, never game state.
const Tokens=preload("res://ui_tokens.gd")
static func available(ui) -> bool:
	return is_instance_valid(ui) and not ui.closing and not ui.modal_open() and not ui.locked and not ui.presenting and not ui.loading_screen.active and not ui.engine.disconnected and ui.campaign().get("phase")=="deployment" and bool(ui.state().get("deploying",false)) and ui.data.get("trial")==null
static func deployed(ui) -> Array:
	return ui.state().get("units",[]).filter(func(u):return u.get("side")=="ally").map(func(u):return str(u.id))
static func alive(ui,uid: String) -> bool:
	for member in ui.campaign().get("roster",[]):
		if str(member.get("id"))==uid:return int(member.get("hp",0))>0
	return false
static func signature(ui) -> String:
	var positions=[]
	for u in ui.state().get("units",[]):
		positions.append([str(u.id),u.get("side"),u.get("pos"),u.get("hp")])
	return JSON.stringify([ui.campaign().get("selected",[]),positions,ui.state().get("formationKind"),ui.state().get("deploymentInitial",[])])
static func make_payload(ui,uid: String,source: String):
	if not available(ui) or source not in ["party","board","roster"] or not alive(ui,uid):return null
	var active=deployed(ui)
	if not ui.campaign().get("selected",[]).has(uid) or (source=="board" and not active.has(uid)) or (source=="party" and active.has(uid)):return null
	var journey=ui.campaign().get("journey",{})
	if not journey is Dictionary:return null
	return {"kind":"deployment_member","uid":uid,"source":source,"epoch":ui.pages.epoch,"connection":ui.engine.connection_generation,"campaign_id":ui.campaign_identity.current_id,"journey_token":journey.get("token"),"stage":journey.get("stage"),"deployment_stamp":signature(ui),"consumed":false}
static func valid(ui,payload) -> bool:
	if not available(ui) or not payload is Dictionary:return false
	if not payload.get("kind") is String or payload.kind!="deployment_member" or not payload.get("consumed",false) is bool or payload.get("consumed",false):return false
	var uid=payload.get("uid");var source=payload.get("source")
	if not uid is String or source not in ["party","board","roster"] or not ui.campaign().get("selected",[]).has(uid) or not alive(ui,uid):return false
	var journey=ui.campaign().get("journey",{})
	if not journey is Dictionary:return false
	for key in ["epoch","connection","journey_token","stage"]:
		if not (payload.get(key) is int or payload.get(key) is float):return false
	if not payload.get("campaign_id") is String or not payload.get("deployment_stamp") is String:return false
	if payload.epoch!=ui.pages.epoch or payload.connection!=ui.engine.connection_generation or payload.campaign_id!=ui.campaign_identity.current_id:return false
	if payload.journey_token!=journey.get("token") or payload.stage!=journey.get("stage") or payload.deployment_stamp!=signature(ui):return false
	var active=deployed(ui)
	return source=="roster" or (active.has(uid) if source=="board" else not active.has(uid))
static func consume(ui,payload) -> bool:
	if not valid(ui,payload):return false
	payload.consumed=true
	return true
static func preview(ui,uid: String) -> Control:
	var card=PanelContainer.new();card.set_meta("ui_region","MemberDragPreview");card.add_to_group("ui_drag_preview");card.theme=ui.theme;card.mouse_filter=Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel",Tokens.box(Tokens.SURFACE,Tokens.BORDER_ACCENT,Tokens.RADIUS_SM,Tokens.SPACE_SM,Tokens.BORDER_WIDTH_EMPHASIS))
	var row=HBoxContainer.new();row.add_theme_constant_override("separation",Tokens.SPACE_SM);row.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(row)
	for member in ui.campaign().get("roster",[]):
		if member.get("id")==uid:
			var image=TextureRect.new();image.texture=ui.portraits.texture(member,true);image.custom_minimum_size=Vector2(42,42);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(image)
			var label=Label.new();label.text=str(member.get("name",uid))+" を配置";label.add_theme_color_override("font_color",Tokens.INK);label.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(label);break
	return card
