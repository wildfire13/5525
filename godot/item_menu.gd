extends RefCounted
## Shared catalog presentation. The engine remains the source of legal actions.
static func definitions(campaign: Dictionary) -> Array:
	return campaign.get("itemDefinitions",[
		{"id":"potion","name":"ポーション","amount":55,"resource":"hp","battleKind":"item"},
		{"id":"ether","name":"エーテル","amount":3,"resource":"mp","battleKind":"ether","battleRole":"porter"}])
static func effect(item: Dictionary) -> String:
	return "%s+%d（上限まで）" % [str(item.resource).to_upper(),item.amount]
static func camp_reason(item: Dictionary,u: Dictionary,inventory: Dictionary) -> String:
	if int(inventory.get(item.id,0))<=0:return "在庫なし"
	if u.hp<=0:return "戦闘不能"
	var limit=u.max if item.resource=="hp" else u.maxMp
	return "全回復" if u.get(item.resource,0)>=limit else ""
