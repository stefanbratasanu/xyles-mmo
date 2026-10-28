extends SceneTree
const State = preload("res://scripts/game_state.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func count_spears(state: Node) -> int:
	var count := 0
	for item: Dictionary in state.equipment+state.inventory:
		if item.get("slot","")=="weapon" and state.item_weapon_type(item)=="spear": count+=1
	return count
func remove_spears(state: Node) -> void:
	for i in range(state.inventory.size()-1,-1,-1):
		if state.inventory[i].get("slot","")=="weapon" and state.item_weapon_type(state.inventory[i])=="spear": state.inventory.remove_at(i)
	for i in range(state.equipment.size()-1,-1,-1):
		if state.equipment[i].get("slot","")=="weapon" and state.item_weapon_type(state.equipment[i])=="spear": state.equipment.remove_at(i)
func _initialize() -> void:
	var state:=State.new()
	check(count_spears(state)==1,"New character receives one spear")
	var index := -1
	for i in range(state.inventory.size()):
		if state.inventory[i].get("weapon_type","")=="spear": index=i; break
	check(index>=0 and state.equip_item(index),"Spear can be equipped")
	check(state.weapon_context()=="spear","Skill distribution receives spear weapon context")
	check(state.item_weapon_type({"name":"Recovered Pike"})=="spear","Legacy spear name inference")
	check(state.item_weapon_type({"name":"Crownfall Greatblade"})=="greatsword","Greatblade compatibility")
	var path := "res://.godot/test-spear-save.json"
	check(state.save_game(path),"Spear save writes")
	var loaded:=State.new()
	check(loaded.load_game(path),"Spear save reloads")
	check(count_spears(loaded)==1 and loaded.weapon_context()=="spear","Weapon identity survives reload without duplicate grant")
	check(loaded.equipment.back().get("icon","")=="spear","Spear artwork survives reload")
	remove_spears(state)
	state.equipment_schema_version=1
	check(state.save_game(path),"Write pre-spear save")
	check(loaded.load_game(path) and count_spears(loaded)==1,"Existing save receives one migration spear")
	check(loaded.equipment_schema_version==2,"Migration version advances")
	check(loaded.save_game(path) and loaded.load_game(path) and count_spears(loaded)==1,"Repeated loads do not duplicate grant")
	remove_spears(loaded)
	check(loaded.save_game(path) and loaded.load_game(path) and count_spears(loaded)==0,"Dropped spears are not regenerated")
	loaded.wood=1000; loaded.iron=1000
	check(loaded.craft_spear("rare"),"Rare spear recipe")
	check(loaded.inventory.back().weapon_type=="spear" and loaded.inventory.back().modifiers.size()==3,"Crafted spear has correct weapon type and rarity modifiers")
	check(loaded.wood==850 and loaded.iron==850,"Spear recipe consumes tier-scaled materials")
	check(loaded.craft_sword("basic") and loaded.inventory.back().weapon_type=="sword","Sword recipe stays compatible")
	var before: int=loaded.wood
	check(not loaded.craft_weapon("invalid","basic") and loaded.wood==before,"Invalid weapon recipe cannot consume resources")
	var spear: Node3D=load("res://assets/animations/player_runtime/spear.tscn").instantiate()
	check(spear.get_node("ForgedHead").mesh is CylinderMesh,"Native editable spear model loads")
	check(spear.get_meta("weapon_type")=="spear","Spear model identity")
	spear.free(); state.free(); loaded.free()
	print("SPEAR ITEMS: ",failures," failures")
	quit(failures)
