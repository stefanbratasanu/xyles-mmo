@tool
extends Window
const PATH := "res://resources/skills/skill_catalog.tres"
const Catalog = preload("res://scripts/skills/skill_catalog.gd")
var catalog: Resource
var section := "modifiers"
var selected := ""
var section_picker: OptionButton
var entries: ItemList
var inspector: VBoxContainer
var status: Label
var preview: RichTextLabel
var context_skill: OptionButton
var context_item: OptionButton
var context_installed: LineEdit
var search: LineEdit
var undo_stack: Array = []
var redo_stack: Array = []
var dirty := false
var percentage_locks: Dictionary = {}
var percent_rows: VBoxContainer
var revision := 0

func _ready() -> void:
	title = "Skill & Modifier Distribution"
	min_size = Vector2i(1050,680)
	close_requested.connect(hide)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,12)
	add_child(margin)
	var outer := VBoxContainer.new()
	margin.add_child(outer)
	var header := HBoxContainer.new()
	outer.add_child(header)
	section_picker = OptionButton.new()
	for name in ["Enchantment families & implementations","Skills & acquisition","Item / skill / family affinities","Global combat rules"]: section_picker.add_item(name)
	section_picker.item_selected.connect(func(i: int): section=["modifiers","skills","affinities","rules"][i]; _refresh_list())
	header.add_child(section_picker)
	search = LineEdit.new()
	search.placeholder_text = "Search name, event, operation..."
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(_text: String): _refresh_list())
	header.add_child(search)
	for pair in [["Duplicate",_duplicate],["Add affinity",_add_affinity],["Undo",_undo],["Redo",_redo]]:
		var button := Button.new()
		button.text=pair[0]
		button.pressed.connect(pair[1])
		header.add_child(button)
	var split := HSplitContainer.new()
	split.size_flags_vertical=Control.SIZE_EXPAND_FILL
	outer.add_child(split)
	entries=ItemList.new()
	entries.custom_minimum_size.x=255
	entries.item_selected.connect(_selected)
	split.add_child(entries)
	var tabs := TabContainer.new()
	tabs.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	split.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.name="Definition"
	tabs.add_child(scroll)
	inspector=VBoxContainer.new()
	inspector.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(inspector)
	var preview_column := VBoxContainer.new()
	preview_column.name="Context preview"
	tabs.add_child(preview_column)
	var context_row := HBoxContainer.new()
	preview_column.add_child(context_row)
	context_skill=OptionButton.new()
	context_skill.item_selected.connect(func(_i: int): _preview())
	context_row.add_child(context_skill)
	context_item=OptionButton.new()
	for item in ["unarmed","sword","greatsword","spear","staff","shield","armor","focus"]: context_item.add_item(item)
	context_item.item_selected.connect(func(_i: int): _preview())
	context_row.add_child(context_item)
	var sample := Button.new()
	sample.text="Simulate 1,000 five-choice offers"
	sample.pressed.connect(_simulate)
	context_row.add_child(sample)
	context_installed=LineEdit.new()
	context_installed.placeholder_text="Installed modifier IDs, comma separated (e.g. impact, chain)"
	context_installed.text_submitted.connect(func(_v: String): _preview())
	preview_column.add_child(context_installed)
	preview=RichTextLabel.new()
	preview.size_flags_vertical=Control.SIZE_EXPAND_FILL
	preview_column.add_child(preview)
	var percentages := ScrollContainer.new()
	percentages.name="Family percentages"
	tabs.add_child(percentages)
	percent_rows=VBoxContainer.new()
	percent_rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	percentages.add_child(percent_rows)
	var help := RichTextLabel.new()
	help.name="Guide"
	help.text="Offer weights control discovery, event weights choose the event rolled on an enchantment, and chance controls activation in combat. These are separate.\n\nValues use game units: 0.25 is 25%, radius/range are metres, duration/interval are seconds. Each min/max pair rolls once and is saved. Fixed values use equal bounds. Chain amount is additional hops; retention 0.8 means 80% per hop.\n\nChoose a skill and item in Context preview to inspect effective probabilities. Five-choice inclusion rates are simulated and differ from single-draw probabilities.\n\nAffinities are explicit matching profiles. '*' matches all; skill accepts an exact skill ID or delivery type. Family accepts an exact family ID. Item is the source weapon/item context. Multipliers combine only on matching rows; disabled weights remain disabled.\n\nEvent names describe actual events. ON_CHAIN means a valid hop launched; ON_CHAIN_HIT requires contact. Buff reaction events are active only while their mantle exists. ON_DEATH must use an explicit compatible response.\n\nChanges are drafts until Save. Save validates all records. Use Reload Balance Data in the in-game K window to apply a saved catalog outside combat. Installed rolls stay stable; offer-weight changes affect future offers.\n\nPower, rules and registered effect operations are data-driven. New operation code must be implemented before it can be selected."
	tabs.add_child(help)
	var footer := HBoxContainer.new()
	outer.add_child(footer)
	status=Label.new()
	status.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	status.clip_text=true
	footer.add_child(status)
	for pair in [["Validate",_validate],["Reload disk",_reload],["Save catalog",_save]]:
		var button := Button.new()
		button.text=pair[0]
		button.pressed.connect(pair[1])
		footer.add_child(button)
	_reload()

func _reload() -> void:
	if dirty:
		var dialog := ConfirmationDialog.new()
		dialog.dialog_text="Discard unsaved catalog changes and reload?"
		add_child(dialog)
		dialog.confirmed.connect(func(): dirty=false; _reload(); dialog.queue_free())
		dialog.canceled.connect(dialog.queue_free)
		dialog.popup_centered()
		return
	catalog=ResourceLoader.load(PATH,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP).duplicate(true)
	context_skill.clear()
	for id: String in catalog.data.skills:
		context_skill.add_item(id)
	undo_stack.clear()
	redo_stack.clear()
	_refresh_list()
	_percentages()
	_preview()
	status.text="Loaded " + PATH

func _refresh_list() -> void:
	entries.clear()
	var values: Variant = catalog.data[section]
	var keys: Array = values.keys() if values is Dictionary else range(values.size())
	for key: Variant in keys:
		var value: Variant=values[key]
		var text_value:=str(key) + (" · "+str(value.get("name","")) if value is Dictionary else "")
		if not search.text.is_empty() and not (text_value+str(value)).to_lower().contains(search.text.to_lower()): continue
		entries.add_item(text_value)
		entries.set_item_metadata(entries.item_count-1,str(key))
	if entries.item_count>0:
		entries.select(0)
		_selected(0)

func _selected(index: int) -> void:
	selected=str(entries.get_item_metadata(index))
	for child in inspector.get_children(): child.queue_free()
	var value: Variant = catalog.data[section][int(selected)] if section=="affinities" else catalog.data[section][selected]
	_add_fields(value,[section,int(selected) if section=="affinities" else selected],0)

func _add_fields(value: Variant, path: Array, depth: int) -> void:
	if value is Dictionary:
		for key: String in value:
			var next:=path.duplicate()
			next.append(key)
			_add_fields(value[key],next,depth+1)
		if str(path.back())=="events":
			var add:=OptionButton.new()
			add.add_item("Enable another event...")
			for event: String in Catalog.EVENTS:
				if not value.has(event): add.add_item(event)
			add.item_selected.connect(func(i: int):
				if i>0:
					var next:=path.duplicate(); next.append(add.get_item_text(i))
					_change(next,1.0)
					_selected(entries.get_selected_items()[0]))
			inspector.add_child(add)
		if str(path.back()) in ["values","stats"]:
			var add:=OptionButton.new()
			add.add_item("Add "+str(path.back())+" parameter...")
			var keys: Array=["amount","duration","radius","range","retention","delay","interval","stacks"] if str(path.back())=="values" else ["armor","outgoing_damage","movement_speed","attack_speed","damage","health","mana"]
			for key: String in keys:
				if not value.has(key): add.add_item(key)
			add.item_selected.connect(func(i: int):
				if i>0:
					var next:=path.duplicate(); next.append(add.get_item_text(i))
					_change(next,[0.0,0.0] if str(path.back())=="values" else 0.0)
					_selected(entries.get_selected_items()[0]))
			inspector.add_child(add)
		return
	var row:=HBoxContainer.new()
	inspector.add_child(row)
	var label:=Label.new()
	label.text=" / ".join(path.slice(2).map(func(v): return str(v))) if path.size()>2 else str(path.back())
	label.custom_minimum_size.x=260
	label.tooltip_text="Path: "+str(path)
	row.add_child(label)
	if value is bool:
		var check:=CheckBox.new(); check.button_pressed=value
		check.toggled.connect(func(v: bool): _change(path,v))
		row.add_child(check)
	elif value is float or value is int:
		var spin:=SpinBox.new()
		spin.min_value=-100000; spin.max_value=100000; spin.step=.001
		spin.allow_greater=false; spin.allow_lesser=false; spin.value=float(value)
		spin.custom_minimum_size.x=150
		spin.value_changed.connect(func(v: float): _change(path,v))
		row.add_child(spin)
	elif value is Array and value.size()==2 and (value[0] is float or value[0] is int):
		for i in range(2):
			var spin:=SpinBox.new(); spin.min_value=-100000; spin.max_value=100000; spin.step=.001; spin.value=float(value[i]); spin.prefix="min " if i==0 else "max "
			spin.custom_minimum_size.x=145
			var next:=path.duplicate(); next.append(i)
			spin.value_changed.connect(func(v: float): _change(next,v))
			row.add_child(spin)
	elif str(path.back()) in ["op","type","target_policy","response"]:
		var choice:=OptionButton.new()
		var choices: Array={"op":Catalog.OPERATIONS,"type":Catalog.TYPES,"target_policy":["nearest","lowest_health","random"],"response":["","heal","fixed_damage"]}[str(path.back())]
		for option: String in choices: choice.add_item(option)
		choice.select(maxi(0,choices.find(str(value))))
		choice.item_selected.connect(func(i: int): _change(path,choices[i]))
		row.add_child(choice)
	else:
		var edit:=LineEdit.new()
		edit.text=JSON.stringify(value) if value is Array else str(value)
		edit.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		edit.tooltip_text="Arrays use JSON, for example [\"hit\", \"projectile\"]. Press Enter to apply."
		edit.text_submitted.connect(func(text_value: String):
			if value is Array:
				var parsed: Variant=JSON.parse_string(text_value)
				if parsed is Array: _change(path,parsed)
				else: status.text="Invalid JSON array"
			else: _change(path,text_value))
		row.add_child(edit)

func _change(path: Array, value: Variant) -> void:
	_snapshot()
	var parent: Variant=catalog.data
	for index in range(path.size()-1): parent=parent[path[index]]
	parent[path.back()]=value
	dirty=true
	revision+=1
	status.text="Unsaved change: "+str(path)
	_preview()

func _snapshot() -> void:
	undo_stack.append(catalog.data.duplicate(true))
	if undo_stack.size()>100: undo_stack.pop_front()
	redo_stack.clear()

func _undo() -> void:
	if undo_stack.is_empty(): return
	redo_stack.append(catalog.data.duplicate(true))
	catalog.data=undo_stack.pop_back(); dirty=true
	_refresh_list(); _percentages(); _preview()

func _redo() -> void:
	if redo_stack.is_empty(): return
	undo_stack.append(catalog.data.duplicate(true))
	catalog.data=redo_stack.pop_back(); dirty=true
	_refresh_list(); _percentages(); _preview()

func _duplicate() -> void:
	if section not in ["skills","modifiers"] or selected.is_empty(): return
	_snapshot()
	var id:=selected+"_copy"
	while catalog.data[section].has(id): id+="_copy"
	catalog.data[section][id]=catalog.data[section][selected].duplicate(true)
	catalog.data[section][id].name+=" copy"
	dirty=true; _refresh_list()

func _add_affinity() -> void:
	_snapshot()
	catalog.data.affinities.append({"item":"*","skill":"*","family":"*","event":"*","stat":"*","multiplier":1.0,"power_percent":100.0})
	section="affinities"; section_picker.select(2); dirty=true; _refresh_list()

func _validate() -> void:
	var errors: PackedStringArray=catalog.validate()
	status.text="Valid catalog" if errors.is_empty() else "Validation: "+"; ".join(errors)
	status.tooltip_text=status.text

func _save() -> void:
	var errors: PackedStringArray=catalog.validate()
	if not errors.is_empty():
		status.text="Not saved: "+"; ".join(errors); return
	var error:=_save_to(PATH)
	status.text="Saved. In game: K → Reload Balance Data." if error==OK else "Save failed: "+str(error)
	if error==OK: dirty=false

func _save_to(path: String) -> Error:
	if not catalog.validate().is_empty(): return ERR_INVALID_DATA
	var temporary:=path.get_basename()+".pending.tres"
	var error:=ResourceSaver.save(catalog,temporary)
	if error!=OK: return error
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(path))

func _preview_installed() -> Array:
	var result: Array=[]
	for id: String in context_installed.text.split(",",false):
		id=id.strip_edges()
		if not catalog.data.modifiers.has(id): continue
		var m: Dictionary=catalog.data.modifiers[id].duplicate(true)
		m.id=id
		m.event=m.events.keys()[0]
		for key: String in m.values: m.values[key]=float(m.values[key][0])
		result.append(m)
	return result

func _preview() -> void:
	if context_skill.item_count==0: return
	var id:=context_skill.get_item_text(context_skill.selected)
	if not catalog.data.skills.has(id): return
	var errors: PackedStringArray=catalog.validate()
	if not errors.is_empty(): preview.text="Draft validation errors:\n"+"\n".join(errors); return
	var installed:=_preview_installed()
	var pool: Array=catalog.eligible(id,installed,context_item.get_item_text(context_item.selected))
	var family_weights: Dictionary={}
	for entry: Dictionary in pool: family_weights[entry.family]=entry.weight
	var total:=0.0
	for value: Variant in family_weights.values(): total+=float(value)
	var lines: Array[String]=["CONTEXT: "+id+" / "+context_item.get_item_text(context_item.selected),"Single-draw conditional family probabilities:"]
	for family: String in family_weights: lines.append("%s: %.2f%%" % [family,100*float(family_weights[family])/maxf(total,.001)])
	lines.append("\nINCOMPATIBLE ON THIS BASE SKILL:")
	for key: String in catalog.data.modifiers:
		var m: Dictionary=catalog.data.modifiers[key]
		if not catalog.compatible(id,m,installed): lines.append("%s requires %s; excludes %s" % [m.name,str(m.requires),str(m.excludes)])
	lines.append("\nEFFECTIVE EVENT WEIGHTS PER IMPLEMENTATION:")
	for entry: Dictionary in pool:
		var m: Dictionary=catalog.data.modifiers[entry.id]
		lines.append("%s: %s" % [m.name,str(catalog.roll_weights(id,m,installed,context_item.get_item_text(context_item.selected),"event"))])
	lines.append("\nEXAMPLE SAVED OFFER (seed 42):")
	for m: Dictionary in catalog.offers(id,installed,42,context_item.get_item_text(context_item.selected)): lines.append(catalog.describe(m)+"\n")
	preview.text="\n".join(lines)

func _simulate() -> void:
	if not catalog.validate().is_empty(): _validate(); return
	var id:=context_skill.get_item_text(context_skill.selected)
	var hits: Dictionary={}
	for seed_value in range(1000):
		for m: Dictionary in catalog.offers(id,_preview_installed(),seed_value,context_item.get_item_text(context_item.selected)):
			hits[m.family]=int(hits.get(m.family,0))+1
	var lines: Array[String]=["Five-choice inclusion rate: 1,000 deterministic samples.\nApproximate worst-case sampling margin ±3.1 percentage points (95%)."]
	for family: String in hits: lines.append("%s: %.1f%%" % [family,float(hits[family])/10])
	preview.text="\n".join(lines)

func _percentages() -> void:
	for child in percent_rows.get_children(): child.queue_free()
	var title_label:=Label.new(); title_label.text="Base family percentages • lock entries to preserve their share\nConditional eligibility and affinities still change effective context probabilities."
	percent_rows.add_child(title_label)
	var weights: Dictionary={}
	for m: String in catalog.data.modifiers: weights[catalog.data.modifiers[m].family]=float(catalog.data.modifiers[m].weight)
	var total:=0.0
	for value: Variant in weights.values(): total+=float(value)
	for family: String in weights:
		var row:=HBoxContainer.new(); percent_rows.add_child(row)
		var label:=Label.new(); label.text=family; label.custom_minimum_size.x=260; row.add_child(label)
		var lock:=CheckBox.new(); lock.text="Lock"; lock.button_pressed=percentage_locks.get(family,false); row.add_child(lock)
		lock.toggled.connect(func(v: bool): percentage_locks[family]=v)
		var spin:=SpinBox.new(); spin.min_value=0; spin.max_value=100; spin.step=.1; spin.suffix="%"; spin.value=float(weights[family])*100/maxf(total,.001); row.add_child(spin)
		var apply:=Button.new(); apply.text="Apply share"; row.add_child(apply)
		apply.pressed.connect(_set_percentage.bind(family,spin))

func _set_percentage(family: String, spin: SpinBox) -> void:
	var weights: Dictionary={}
	for m: String in catalog.data.modifiers: weights[catalog.data.modifiers[m].family]=float(catalog.data.modifiers[m].weight)
	var total:=0.0
	for value: Variant in weights.values(): total+=float(value)
	var locked:=0.0
	var others:=0.0
	for key: String in weights:
		weights[key]=100*float(weights[key])/maxf(total,.001)
		if key==family: continue
		if percentage_locks.get(key,false): locked+=float(weights[key])
		else: others+=float(weights[key])
	if percentage_locks.get(family,false) or spin.value+locked>100 or (others==0 and not is_equal_approx(spin.value+locked,100)):
		status.text="Cannot allocate that percentage while preserving locked shares."; return
	_snapshot()
	for key: String in weights:
		if key==family: weights[key]=spin.value
		elif not percentage_locks.get(key,false): weights[key]=float(weights[key])*(100-spin.value-locked)/maxf(others,.001)
	for m: String in catalog.data.modifiers: catalog.data.modifiers[m].weight=weights[catalog.data.modifiers[m].family]
	dirty=true; _percentages(); _preview()
