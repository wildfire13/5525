extends SceneTree
var failures: Array[String]=[]
func check(ok: bool,message: String):
	if not ok:
		failures.append(message);push_error(message)
func _initialize():call_deferred("run")
func run():
	var source=JSON.parse_string(FileAccess.get_file_as_string("res://../native/data/master-source.json"))
	var expected_nonempty={}
	var internals={"empty-rightHand":"empty","empty-leftHand":"empty","empty-head":"empty","empty-upperBody":"empty","empty-lowerBody":"empty","empty-feet":"empty","empty-accessory1":"empty","empty-accessory2":"empty","fist":"fist","fist-1":"fist","fist-2":"fist"}
	check(source.gear.size()==76,"master retains all 76 records")
	var real_count=0
	for gear in source.gear:
		if internals.has(gear.id):
			check(not gear.has("flavor"),"internal definition has no ordinary flavor: "+gear.id)
			continue
		real_count+=1
		check(not str(gear.get("flavor","")).is_empty(),"approved real gear flavor exists: "+gear.id)
	check(real_count==65,"exactly 65 real equipment definitions")
	var locked={"porter-bag":"[ポーター専用][解除不可][取引不可]\n不思議なリュック。","porter-whistle":"[ポーター専用][解除不可][取引不可]\n指示を送る笛。","stealth-cloak":"[スカウト専用][解除不可][取引不可]\n旅の装いに重ねる、一枚のマント。"}
	var trade_only={"elf-hair-ornament":"[エルフ専用][取引不可]\nエルフの風習として親から贈られる髪飾り。","dwarf-hair-ornament":"[ドワーフ専用][取引不可]\nドワーフの風習として親から贈られる髪飾り。"}
	for gear in source.gear:
		if locked.has(gear.id):check(gear.flavor==locked[gear.id] and gear.removable==false and gear.transferable==false and gear.sellable==false and gear.purchasable==false,"locked/trade flags and exact visible flavor: "+gear.id)
		if trade_only.has(gear.id):check(gear.flavor==trade_only[gear.id] and gear.removable==true and gear.transferable==false and gear.sellable==false and gear.purchasable==false,"removable trade-restricted ornament remains removable: "+gear.id)
	var tooltip=load("res://equipment_tooltip.gd")
	var source_hair=source.gear.filter(func(g):return g.id=="greatsword-wood")[0]
	var button=Button.new();button.set_script(tooltip);root.add_child(button)
	button.configure(source_hair.name,source_hair,{})
	check(button.plain_details.any(func(line):return line==source_hair.flavor),"multiline flavor remains a full plain hover detail")
	check(button.details.any(func(line):return line.begins_with("[lb]ドワーフ装備不可]")),"condition tag brackets are escaped in rich tooltip markup")
	var pouch=source.gear.filter(func(g):return g.id=="pouch-belt-3")[0]
	button.configure(pouch.name,pouch,{"names":{"secretPouch":"秘密のポーチ"},"definitions":{}})
	check(button.plain_details.any(func(line):return line.contains("インベントリ枠") and line.contains("5増やす")),"pouch capacity remains available in existing skill information")
	var leggings=source.gear.filter(func(g):return g.id=="leggings")[0]
	button.configure(leggings.name,leggings,{})
	check(button.plain_details.any(func(line):return line.begins_with("DEF 物1")),"leggings DEF=1 remains visible")
	button.queue_free();await process_frame
	print("PASS equipment flavor regression "+str(failures.size()==0))
	quit(0 if failures.is_empty() else 1)
