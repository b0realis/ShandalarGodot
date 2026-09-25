class_name CardPacksScreen
extends Control
## Options > Card Packs — availability, compatibility, enablement and the
## exact local folder. Pack ZIPs are user-built/user-supplied and are never
## release payloads.

const PANEL_WIDTH := 620.0

var _status: Label
var _enable: Button
var _disable: Button
var _warning: Control
var _second_status: Label
var _second_enable: Button
var _second_disable: Button
var _third_status: Label
var _third_enable: Button
var _third_disable: Button
var _fourth_status: Label
var _fourth_enable: Button
var _fourth_disable: Button
var _fifth_status: Label
var _fifth_enable: Button
var _fifth_disable: Button
var _sixth_status: Label
var _sixth_enable: Button
var _sixth_disable: Button
var _seventh_status: Label
var _seventh_enable: Button
var _seventh_disable: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.08, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title_bg := GameSkin.texture("title_background")
	if title_bg != null:
		var art := TextureRect.new()
		art.texture = title_bg
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.modulate = Color(0.5, 0.5, 0.5)
		add_child(art)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.add_child(UiChrome.body_label("Card Packs", 26))
	var folder := UiChrome.body_label(
		"Folder: %s" % GamePaths.shown(GamePaths.cardpacks_folder()), 13)
	folder.name = "CardPacksFolder"
	folder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(folder)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 10)
	var open := UiChrome.menu_button("Open Folder", Vector2(140, 32), 13)
	open.name = "OpenFolder"
	open.disabled = OS.has_feature("web")
	open.pressed.connect(CardPacks.open_folder)
	tools.add_child(open)
	var rescan := UiChrome.menu_button("Rescan", Vector2(110, 32), 13)
	rescan.name = "Rescan"
	rescan.pressed.connect(CardPacks.rescan)
	tools.add_child(rescan)
	content.add_child(tools)

	var heading := UiChrome.body_label("1-tDotP — Pack 1: DotP Complete", 18)
	heading.name = "Pack1Heading"
	content.add_child(heading)
	_status = UiChrome.body_label("", 14)
	_status.name = "Pack1Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	_enable = UiChrome.menu_button("Enable", Vector2(120, 34), 13)
	_enable.name = "EnablePack1"
	_enable.pressed.connect(CardPacks.set_enabled.bind(CardPacks.ID, true))
	actions.add_child(_enable)
	_disable = UiChrome.menu_button("Disable", Vector2(120, 34), 13)
	_disable.name = "DisablePack1"
	_disable.pressed.connect(_request_disable)
	actions.add_child(_disable)
	content.add_child(actions)

	content.add_child(UiChrome.body_label("2-FEM — Pack 2: Fallen Empires", 18))
	_second_status = UiChrome.body_label("", 14)
	_second_status.name = "Pack2Status"
	_second_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_second_status)
	var second_actions := HBoxContainer.new()
	second_actions.add_theme_constant_override("separation", 10)
	_second_enable = UiChrome.menu_button("Enable", Vector2(120, 34), 13)
	_second_enable.name = "EnablePack2"
	_second_enable.pressed.connect(CardPacks.set_enabled.bind(FallenEmpiresPack.ID, true))
	second_actions.add_child(_second_enable)
	_second_disable = UiChrome.menu_button("Disable", Vector2(120, 34), 13)
	_second_disable.name = "DisablePack2"
	_second_disable.pressed.connect(_request_disable.bind(FallenEmpiresPack.ID))
	second_actions.add_child(_second_disable)
	content.add_child(second_actions)

	content.add_child(UiChrome.body_label("3-ICE — Pack 3: Ice Age", 18))
	_third_status = UiChrome.body_label("", 14)
	_third_status.name = "Pack3Status"
	_third_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_third_status)
	var third_actions := HBoxContainer.new()
	third_actions.add_theme_constant_override("separation", 10)
	_third_enable = UiChrome.menu_button("Enable", Vector2(120, 34), 13)
	_third_enable.name = "EnablePack3"
	_third_enable.pressed.connect(CardPacks.set_enabled.bind(IceAgePack.ID, true))
	third_actions.add_child(_third_enable)
	_third_disable = UiChrome.menu_button("Disable", Vector2(120, 34), 13)
	_third_disable.name = "DisablePack3"
	_third_disable.pressed.connect(_request_disable.bind(IceAgePack.ID))
	third_actions.add_child(_third_disable)
	content.add_child(third_actions)
	content.add_child(UiChrome.body_label("4-HML — Pack 4: Homelands", 18))
	_fourth_status = UiChrome.body_label("", 14)
	_fourth_status.name = "Pack4Status"
	_fourth_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_fourth_status)
	var fourth_actions := HBoxContainer.new()
	fourth_actions.add_theme_constant_override("separation", 10)
	_fourth_enable = UiChrome.menu_button("Enable", Vector2(120, 34), 13)
	_fourth_enable.name = "EnablePack4"
	_fourth_enable.pressed.connect(CardPacks.set_enabled.bind(HomelandsPack.ID, true))
	fourth_actions.add_child(_fourth_enable)
	_fourth_disable = UiChrome.menu_button("Disable", Vector2(120, 34), 13)
	_fourth_disable.name = "DisablePack4"
	_fourth_disable.pressed.connect(_request_disable.bind(HomelandsPack.ID))
	fourth_actions.add_child(_fourth_disable)
	content.add_child(fourth_actions)

	content.add_child(UiChrome.body_label("5-ALL — Pack 5: Alliances", 18))
	_fifth_status = UiChrome.body_label("", 14)
	_fifth_status.name = "Pack5Status"
	_fifth_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_fifth_status)
	var fifth_actions := HBoxContainer.new()
	fifth_actions.add_theme_constant_override("separation", 10)
	_fifth_enable = UiChrome.menu_button("Enable", Vector2(120, 34), 13)
	_fifth_enable.name = "EnablePack5"
	_fifth_enable.pressed.connect(CardPacks.set_enabled.bind(AlliancesPack.ID, true))
	fifth_actions.add_child(_fifth_enable)
	_fifth_disable = UiChrome.menu_button("Disable", Vector2(120, 34), 13)
	_fifth_disable.name = "DisablePack5"
	_fifth_disable.pressed.connect(_request_disable.bind(AlliancesPack.ID))
	fifth_actions.add_child(_fifth_disable)
	content.add_child(fifth_actions)
	content.add_child(UiChrome.body_label("6-POR — Pack 6: Portal", 18))
	_sixth_status = UiChrome.body_label("", 14)
	_sixth_status.name = "Pack6Status"
	_sixth_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_sixth_status)
	var sixth_actions := HBoxContainer.new()
	sixth_actions.add_theme_constant_override("separation", 10)
	_sixth_enable = UiChrome.menu_button("Enable", Vector2(120, 34), 13)
	_sixth_enable.name = "EnablePack6"
	_sixth_enable.pressed.connect(CardPacks.set_enabled.bind(PortalPack.ID, true))
	sixth_actions.add_child(_sixth_enable)
	_sixth_disable = UiChrome.menu_button("Disable", Vector2(120, 34), 13)
	_sixth_disable.name = "DisablePack6"
	_sixth_disable.pressed.connect(_request_disable.bind(PortalPack.ID))
	sixth_actions.add_child(_sixth_disable)
	content.add_child(sixth_actions)
	content.add_child(UiChrome.body_label("7-5ED — Pack 7: Fifth Edition", 18))
	_seventh_status = UiChrome.body_label("", 14)
	_seventh_status.name = "Pack7Status"
	_seventh_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_seventh_status)
	var seventh_actions := HBoxContainer.new()
	seventh_actions.add_theme_constant_override("separation", 10)
	_seventh_enable = UiChrome.menu_button("Enable", Vector2(120, 34), 13)
	_seventh_enable.name = "EnablePack7"
	_seventh_enable.pressed.connect(CardPacks.set_enabled.bind(FifthEditionPack.ID, true))
	seventh_actions.add_child(_seventh_enable)
	_seventh_disable = UiChrome.menu_button("Disable", Vector2(120, 34), 13)
	_seventh_disable.name = "DisablePack7"
	_seventh_disable.pressed.connect(_request_disable.bind(FifthEditionPack.ID))
	seventh_actions.add_child(_seventh_disable)
	content.add_child(seventh_actions)

	var local_only := UiChrome.body_label(
		"Packs are not distributed with the game. Build them locally with "
		+ "tools/pack_1_dotp_complete.py, tools/pack_2_fallen_empires.py, "
		+ "tools/pack_3_ice_age.py, tools/pack_4_homelands.py, tools/pack_5_alliances.py, tools/pack_6_portal.py or tools/pack_7_fifth_edition.py, "
		+ "place the exact ZIP here, then Rescan.", 13)
	local_only.name = "LocalOnly"
	local_only.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(local_only)

	var back := UiChrome.menu_button("Back", Vector2(180, 40))
	back.name = "Back"
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://game/options_screen.tscn"))
	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	back_row.add_child(back)

	# Keep every pack reachable at the game's minimum window height.
	var scroll := ScrollContainer.new()
	scroll.name = "PackListScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(PANEL_WIDTH - 40, 560)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	page.add_child(scroll)
	page.add_child(back_row)
	var panel := UiChrome.panel_around(page, 20.0)
	panel.custom_minimum_size.x = PANEL_WIDTH
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	CardPacks.changed.connect(_on_pack_changed)
	CardPacks.rescanned.connect(_refresh)
	CardPacks.locks_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var seventh := CardPacks.status(FifthEditionPack.ID)
	_seventh_enable.disabled = not seventh.available or seventh.enabled
	_seventh_disable.disabled = not seventh.available or not seventh.enabled
	if seventh.available:
		_seventh_status.text = "Status: %s — Version: %s — Minimum game: %s\n" % [
			"Enabled" if seventh.enabled else "Disabled", seventh.version, seventh.minimum_game_version]
		_seventh_status.text += "434 names · 449 printings · 0 new identities\nDeck Builder filter: Extras > Fifth Edition"
	else:
		_seventh_status.text = "Status: Not available\nExpected: %s\nReason: %s" % [
			FifthEditionPack.FILE_NAME, seventh.rejection]
	var sixth := CardPacks.status(PortalPack.ID)
	_sixth_enable.disabled = not sixth.available or sixth.enabled
	_sixth_disable.disabled = not sixth.available or not sixth.enabled
	if sixth.available:
		_sixth_status.text = "Status: %s — Version: %s — Minimum game: %s\n" % [
			"Enabled" if sixth.enabled else "Disabled", sixth.version, sixth.minimum_game_version]
		_sixth_status.text += "200 names · 215 printings · 173 new identities\nDeck Builder filter: Extras > Portal"
	else:
		_sixth_status.text = "Status: Not available\nExpected: %s\nReason: %s" % [
			PortalPack.FILE_NAME, sixth.rejection]
	var fifth := CardPacks.status(AlliancesPack.ID)
	_fifth_enable.disabled = not fifth.available or fifth.enabled
	_fifth_disable.disabled = not fifth.available or not fifth.enabled
	if fifth.available:
		_fifth_status.text = "Status: %s — Version: %s — Minimum game: %s\n" % [
			"Enabled" if fifth.enabled else "Disabled", fifth.version, fifth.minimum_game_version]
		_fifth_status.text += "144 names · 199 printings · 144 new identities\nDeck Builder filter: Extras > Alliances"
	else:
		_fifth_status.text = "Status: Not available\nExpected: %s\nReason: %s" % [
			AlliancesPack.FILE_NAME, fifth.rejection]
	var fourth := CardPacks.status(HomelandsPack.ID)
	_fourth_enable.disabled = not fourth.available or fourth.enabled
	_fourth_disable.disabled = not fourth.available or not fourth.enabled
	if fourth.available:
		_fourth_status.text = "Status: %s — Version: %s — Minimum game: %s\n" % [
			"Enabled" if fourth.enabled else "Disabled", fourth.version, fourth.minimum_game_version]
		_fourth_status.text += "115 names · 140 printings · 115 new identities\nDeck Builder filter: Extras > Homelands"
	else:
		_fourth_status.text = "Status: Not available\nExpected: %s\nReason: %s" % [
			HomelandsPack.FILE_NAME, fourth.rejection]
	var third := CardPacks.status(IceAgePack.ID)
	_third_enable.disabled = not third.available or third.enabled
	_third_disable.disabled = not third.available or not third.enabled
	if third.available:
		_third_status.text = "Status: %s — Version: %s — Minimum game: %s\n" % [
			"Enabled" if third.enabled else "Disabled", third.version, third.minimum_game_version]
		_third_status.text += "373 names · 383 printings · 346 new identities\nDeck Builder filter: Extras > Ice Age"
	else:
		_third_status.text = "Status: Not available\nExpected: %s\nReason: %s" % [
			IceAgePack.FILE_NAME, third.rejection]
	var second := CardPacks.status(FallenEmpiresPack.ID)
	_second_enable.disabled = not second.available or second.enabled
	_second_disable.disabled = not second.available or not second.enabled
	if second.available:
		_second_status.text = "Status: %s — Version: %s — Minimum game: %s\n" % [
			"Enabled" if second.enabled else "Disabled", second.version, second.minimum_game_version]
		_second_status.text += "102 unique cards · 187 printings\nDeck Builder filter: Extras > Fallen Empires"
	else:
		_second_status.text = "Status: Not available\nExpected: %s\nReason: %s" % [
			FallenEmpiresPack.FILE_NAME, second.rejection]
	var state := CardPacks.status(CardPacks.ID)
	var available := bool(state.get("available", false))
	var enabled := bool(state.get("enabled", false))
	_enable.disabled = not available or enabled
	_disable.disabled = not available or not enabled
	if available:
		var counts: Dictionary = state.get("counts", {})
		_status.text = "Status: %s\nVersion: %s\nMinimum game version: %s\n" % [
			"Enabled" if enabled else "Disabled",
			String(state.get("version", "unknown")),
			String(state.get("minimum_game_version", "unknown"))]
		_status.text += "%s set entries · %d unique cards\n%s" % [
			_grouped(int(counts.get("named_set_entries", 0))),
			int(counts.get("distinct_cards", 0)),
			GamePaths.shown(String(state.get("path", "")))]
	else:
		_status.text = "Status: Not available\nExpected: %s\n%s\nReason: %s" % [
			CardPacks.FILE_NAME, GamePaths.shown(String(state.get("path", ""))),
			String(state.get("rejection", "not found"))]
	var refusal := CardPacks.change_refusal()
	var rescan := find_child("Rescan", true, false) as Button
	rescan.disabled = not refusal.is_empty()
	rescan.tooltip_text = refusal
	for button in [_enable, _disable, _second_enable, _second_disable,
		_third_enable, _third_disable, _fourth_enable, _fourth_disable, _fifth_enable, _fifth_disable, _sixth_enable, _sixth_disable]:
		button.disabled = button.disabled or not refusal.is_empty()
		button.tooltip_text = refusal
	if not refusal.is_empty(): _status.text += "\n" + refusal


func _on_pack_changed(_id: String, _enabled: bool) -> void:
	_refresh()


func _request_disable(id := CardPacks.ID) -> void:
	var warning := CardPacks.disable_warning(id)
	if warning == "":
		CardPacks.set_enabled(id, false)
		return
	if is_instance_valid(_warning):
		return
	_warning = UiChrome.action_popup(self, "Current deck uses " + CardPacks.label_for(id), warning, [
		{"label": "Keep enabled", "name": "KeepEnabled"},
		{"label": "Disable anyway", "name": "DisableAnyway",
			"callable": CardPacks.set_enabled.bind(id, false)},
	], 570.0)
	_warning.tree_exited.connect(func() -> void: _warning = null)


static func _grouped(value: int) -> String:
	var digits := str(value)
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(-3)
	return digits + out
