extends RefCounted
## In-game authoring UI; draft mappings do not change gameplay until saved.
var hud: CanvasLayer
var selected_weapon := "sword"
var selected_action := "melee_cone"
var draft: Dictionary={}
var search_text := ""
var status: Label
var clip_list: ItemList
var speed: SpinBox
var upper_body: CheckBox
var preview_player: AnimationPlayer
var preview_upper_player: AnimationPlayer
var preview_character: Node3D
var preview_viewport: SubViewport
var current_clip: Label
var saved_mapping: Label
var captured_clip := ""
var capture_label: Label

func _init(owner_hud: CanvasLayer) -> void:
	hud=owner_hud
	selected_weapon=hud.game.player.weapon_style

func render() -> void:
	hud.overlay_title.text="Animation selection"
	hud.overlay_subtitle.text="F6 captures the animation currently playing. Select a new clip to replace it on your character immediately."
	var column:=VBoxContainer.new()
	hud.overlay_content.add_child(column)
	capture_label = hud._label("", 11, hud.GOLD)
	capture_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(capture_label)
	_update_capture_label()
	var selectors:=HBoxContainer.new()
	column.add_child(selectors)
	selectors.add_child(hud._label("Weapon",11,hud.GOLD))
	var weapons:=OptionButton.new()
	for weapon: String in hud.game.player.animation_profiles.WEAPONS: weapons.add_item(weapon.capitalize())
	weapons.select(hud.game.player.animation_profiles.WEAPONS.find(selected_weapon))
	weapons.item_selected.connect(func(i: int):
		selected_weapon=hud.game.player.animation_profiles.WEAPONS[i]; draft.clear(); _refresh())
	selectors.add_child(weapons)
	selectors.add_child(hud._label("Attack / action",11,hud.GOLD))
	var actions:=OptionButton.new()
	var action_names: Array=hud.game.player.animation_profiles.actions()
	for action: String in action_names: actions.add_item(action.replace("_"," ").capitalize())
	actions.select(action_names.find(selected_action))
	actions.item_selected.connect(func(i: int):
		selected_action=action_names[i]; draft.clear(); _refresh())
	selectors.add_child(actions)
	if draft.is_empty(): draft=hud.game.player.animation_entry(selected_action,selected_weapon).duplicate(true)
	var current: Dictionary=hud.game.player.animation_entry(selected_action,selected_weapon)
	saved_mapping=hud._label("Saved: %s · %.2f× · %s" % [current.clip,current.speed,"upper body" if current.upper_body else "full body"],11,hud.MUTED)
	saved_mapping.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	column.add_child(saved_mapping)
	var split:=HBoxContainer.new()
	split.add_theme_constant_override("separation",14)
	column.add_child(split)
	var controls:=VBoxContainer.new()
	controls.custom_minimum_size=Vector2(500,450)
	controls.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	split.add_child(controls)
	var search:=LineEdit.new()
	search.placeholder_text="Filter imported clips (thrust, sword, cast, parry...)"
	search.text=search_text
	search.text_changed.connect(func(text: String): search_text=text; _populate_clips())
	controls.add_child(search)
	clip_list=ItemList.new()
	clip_list.custom_minimum_size=Vector2(470,300)
	clip_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	clip_list.item_selected.connect(func(i: int):
		draft.clip=str(clip_list.get_item_metadata(i)); _draft_changed()
		if not captured_clip.is_empty():
			_preview()
			play_selected_on_character())
	controls.add_child(clip_list)
	var options:=HBoxContainer.new()
	controls.add_child(options)
	options.add_child(hud._label("Speed",11,hud.TEXT))
	speed=SpinBox.new()
	speed.min_value=.1; speed.max_value=4; speed.step=.05; speed.value=float(draft.speed); speed.suffix="×"
	speed.value_changed.connect(func(value: float): draft.speed=value)
	options.add_child(speed)
	upper_body=CheckBox.new()
	upper_body.text="Upper body · keep leg movement"
	upper_body.button_pressed=bool(draft.upper_body)
	upper_body.toggled.connect(func(value: bool): draft.upper_body=value)
	options.add_child(upper_body)
	current_clip=hud._label("",11,hud.TEXT)
	current_clip.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(current_clip)
	var buttons:=HBoxContainer.new()
	controls.add_child(buttons)
	for item: Array in [["PREVIEW",_preview],["STOP",_stop_preview],["SAVE THIS MAPPING",_save],["USE DEFAULT",_reset]]:
		var button: Button=hud._button(str(item[0]),10)
		button.pressed.connect(item[1])
		buttons.add_child(button)
	var live := HBoxContainer.new()
	controls.add_child(live)
	var play: Button = hud._button("PLAY ON CHARACTER", 11)
	play.pressed.connect(play_selected_on_character)
	live.add_child(play)
	var stop_live: Button = hud._button("STOP OVERRIDE", 11)
	stop_live.pressed.connect(hud.game.player.stop_animation_override)
	live.add_child(stop_live)
	status=hud._label("Mappings are saved separately for each weapon and action.",11,hud.MUTED)
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(status)
	_build_preview(split)
	_populate_clips()
	_draft_changed()
	var note: Label=hud._label("Travel playback follows movement speed and race stride. Speed here controls previews and actions; ordinary walk/run pace is automatic. Combat idle is separate from relaxed idle.",11,hud.MUTED)
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)

func _refresh() -> void:
	if hud.current_panel=="animations": hud._render_overlay()

func capture_current_animation() -> void:
	var player = hud.game.player
	var active: AnimationPlayer = player.animation_player
	if player.upper_body_player != null and player.upper_body_player.is_playing(): active = player.upper_body_player
	captured_clip = str(active.current_animation)
	if captured_clip.is_empty(): captured_clip = "rest pose"
	_update_capture_label()
	if is_instance_valid(status): status.text = "Captured current animation. Select a new clip to replace it."

func _update_capture_label() -> void:
	if is_instance_valid(capture_label):
		capture_label.text = "Captured: " + captured_clip + " · select a replacement below" if not captured_clip.is_empty() else "Press F6 to capture and replace the current animation."

func play_selected_on_character() -> void:
	if draft.is_empty():
		draft = hud.game.player.animation_entry(selected_action, selected_weapon).duplicate(true)
	var played: bool = hud.game.player.play_animation_override(str(draft.clip), float(draft.speed))
	var message := "Animation override: " + str(draft.clip) if played else "Cannot play this clip now. Select an imported clip in Options > Animation Selection."
	hud.show_notice(message)
	if is_instance_valid(status): status.text = message
	if played: hud.game.game_log.ui("animation_override", {"clip": str(draft.clip), "speed": draft.speed})

func _populate_clips() -> void:
	if not is_instance_valid(clip_list): return
	clip_list.clear()
	var clips: PackedStringArray=hud.game.player.available_animations()
	clips.sort()
	if selected_action=="dash": clips.insert(0,"procedural_roll")
	for clip: String in clips:
		if clip.begins_with("selected_once/") or clip.begins_with("sit/"): continue
		var category := ""
		if clip in ["protof/unarmed_idle", "protof/sword_idle", "protof/greatsword_idle", "actions/staff_idle", "travel/sword_ready", "travel/fencing_idle", "travel/fencing_breathe", "travel/sword_breathe", "travel/greatsword_breathe"]:
			category = "[Combat stance] "
		elif clip.begins_with("travel/"):
			category = "[Relaxed travel] "
		if not search_text.is_empty() and not (category + clip).to_lower().contains(search_text.to_lower()): continue
		clip_list.add_item(category + clip)
		clip_list.set_item_metadata(clip_list.item_count-1,clip)
		if clip==draft.clip: clip_list.select(clip_list.item_count-1)
	clip_list.ensure_current_is_visible()

func _draft_changed() -> void:
	if is_instance_valid(current_clip): current_clip.text="Draft: "+str(draft.clip)
	if is_instance_valid(upper_body):
		upper_body.disabled=selected_action not in hud.game.player.animation_profiles.ATTACK_TYPES or selected_action=="dash"
		if upper_body.disabled: upper_body.button_pressed=false; draft.upper_body=false
	if is_instance_valid(speed): speed.editable=draft.clip!="procedural_roll"

func _save() -> void:
	var profiles: RefCounted=hud.game.player.animation_profiles
	var previous: Dictionary=profiles.overrides.duplicate(true)
	if not profiles.set_entry(selected_weapon,selected_action,draft,hud.game.player.available_animations()):
		status.text="Invalid mapping. Choose an available clip and a speed from 0.1× to 4×."
		return
	if not profiles.save():
		profiles.overrides=previous
		status.text="Save failed. The previous mapping remains active."
		return
	status.text="Saved %s / %s → %s" % [selected_weapon,selected_action,draft.clip]
	saved_mapping.text="Saved: %s · %.2f× · %s" % [draft.clip,draft.speed,"upper body" if draft.upper_body else "full body"]
	hud.show_notice("Animation mapping saved for %s / %s." % [selected_weapon,selected_action.replace("_"," ")])

func _reset() -> void:
	var profiles: RefCounted=hud.game.player.animation_profiles
	var previous: Dictionary=profiles.overrides.duplicate(true)
	profiles.reset_entry(selected_weapon,selected_action)
	if not profiles.save():
		profiles.overrides=previous; status.text="Could not save the default mapping."; return
	draft.clear(); _refresh()

func _build_preview(parent: Control) -> void:
	var container:=SubViewportContainer.new()
	container.custom_minimum_size=Vector2(390,450)
	container.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	container.stretch=true
	parent.add_child(container)
	preview_viewport=SubViewport.new()
	preview_viewport.size=Vector2i(390,450)
	preview_viewport.own_world_3d=true
	preview_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	container.add_child(preview_viewport)
	var environment:=WorldEnvironment.new()
	var setting:=Environment.new()
	setting.background_mode=Environment.BG_COLOR
	setting.background_color=Color("202522")
	setting.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	setting.ambient_light_color=Color.WHITE
	setting.ambient_light_energy=.8
	environment.environment=setting
	preview_viewport.add_child(environment)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-35,-30,0)
	light.light_energy=1.3
	preview_viewport.add_child(light)
	var camera:=Camera3D.new()
	preview_viewport.add_child(camera)
	camera.position=Vector3(2.6,1.45,3.5)
	camera.look_at(Vector3(0,.95,0))
	camera.fov=35
	var models = load("res://scripts/character_models.gd")
	var model_scene: PackedScene = hud.game.player.CHARACTER_SCENE
	for entry in models._entries:
		if entry.id == hud.game.player.character_model_id and entry.status == "reviewed": model_scene = load(entry.scene)
	preview_character=model_scene.instantiate()
	preview_character.rotation.y=0
	preview_viewport.add_child(preview_character)
	preview_character.initialize_body()
	preview_player=preview_character.get_node("AnimationPlayer")
	for library in preview_player.get_animation_library_list(): preview_player.remove_animation_library(library)
	for library in hud.game.player.animation_player.get_animation_library_list():
		preview_player.add_animation_library(library, hud.game.player.animation_player.get_animation_library(library))
	preview_upper_player=AnimationPlayer.new()
	preview_upper_player.root_node=NodePath("..")
	preview_upper_player.process_priority=100
	preview_character.add_child(preview_upper_player)
	preview_upper_player.add_animation_library("preview",AnimationLibrary.new())
	if selected_weapon!="unarmed":
		var skeleton: Skeleton3D=preview_character.find_child("Skeleton3D",true,false)
		var attachment:=BoneAttachment3D.new()
		skeleton.add_child(attachment)
		attachment.bone_name="humanoid_ R Hand"
		attachment.add_child(hud.game.player.create_weapon_visual(selected_weapon))

	var idle: Dictionary=hud.game.player.animation_entry("idle",selected_weapon)
	preview_player.play(str(idle.clip))

func _preview() -> void:
	if not is_instance_valid(preview_player): return
	if draft.clip=="procedural_roll":
		status.text="The procedural roll is timed by movement. Select a clip to preview a replacement."
		return
	if not preview_player.has_animation(str(draft.clip)): return
	preview_player.stop()
	preview_upper_player.stop()
	if draft.upper_body:
		var library:=preview_upper_player.get_animation_library("preview")
		var key:=str(draft.clip).replace("/","_")
		if not library.has_animation(key):
			var clip: Animation=preview_player.get_animation(str(draft.clip)).duplicate(true)
			clip.loop_mode=Animation.LOOP_LINEAR if selected_action.begins_with("channel") else Animation.LOOP_NONE
			for track in range(clip.get_track_count()-1,-1,-1):
				var path: NodePath=clip.track_get_path(track)
				var bone:=str(path.get_subname(0)) if path.get_subname_count()>0 else ""
				if not ("Spine" in bone or "Clavicle" in bone or "UpperArm" in bone or "Forearm" in bone or "Hand" in bone or "Finger" in bone or "Neck" in bone or "Head" in bone): clip.remove_track(track)
			library.add_animation(key,clip)
		var idle: Dictionary=hud.game.player.animation_entry("idle",selected_weapon)
		preview_player.speed_scale=1; preview_player.play(str(idle.clip))
		preview_upper_player.play("preview/"+key,-1,float(draft.speed))
	else:
		preview_player.speed_scale=float(draft.speed)
		preview_player.play(str(draft.clip))
	status.text="Preview only: %s at %.2f×." % [draft.clip,draft.speed]

func _stop_preview() -> void:
	if not is_instance_valid(preview_player): return
	preview_player.stop()
	preview_upper_player.stop()
	var idle: Dictionary=hud.game.player.animation_entry("idle",selected_weapon)
	preview_player.speed_scale=1
	preview_player.play(str(idle.clip))
