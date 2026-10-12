extends RefCounted
## UI session identity only; purchase plans never enter the campaign save.
var current_id := ""
var legacy_ids: Dictionary={}
func new_campaign():current_id=Crypto.new().generate_random_bytes(16).hex_encode()
func reconnect_bootstrap():current_id=""
func prepare_load(value,source_path: String="") -> Dictionary:
	var envelope=value
	if value is String:
		var parser=JSON.new()
		if parser.parse(value)!=OK:return {"ok":false,"error":"セーブJSONを読み取れません"}
		envelope=parser.data
	if not envelope is Dictionary:return {"ok":false,"error":"セーブJSONを読み取れません"}
	envelope=envelope.duplicate(true)
	var identity=envelope.get("godotCampaignId","")
	var pattern=RegEx.new();pattern.compile("^[0-9a-f]{32}$")
	if envelope.has("godotCampaignId") and (not identity is String or pattern.search(identity)==null):return {"ok":false,"error":"進行の識別情報が不正です"}
	envelope.erase("godotCampaignId")
	# Legacy saves are recognized only when the previously loaded source matches.
	var source=source_path.simplify_path().to_lower() if OS.get_name()=="Windows" else source_path.simplify_path()
	var key=source+":"+JSON.stringify(envelope,"",true).sha256_text()
	if identity.is_empty():identity=legacy_ids.get(key,Crypto.new().generate_random_bytes(16).hex_encode())
	return {"ok":true,"identity":identity,"legacy_key":key,"envelope":envelope}
func accept_load(prepared: Dictionary):
	current_id=prepared.identity;legacy_ids[prepared.legacy_key]=current_id
func save_metadata(envelope: Dictionary) -> Dictionary:
	var result=envelope.duplicate(true)
	if not current_id.is_empty():result.godotCampaignId=current_id
	return result
