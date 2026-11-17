class_name CardForgeScreen
extends Control
## THE CARD CREATOR — a card made from scratch, in a screen laid out like
## the Deck Builder: the card itself on the left, live, as the large card
## and as the small one the table shows (and the card reader on a click);
## what it is made of in four pages on the right (the card, its cost and
## type, its rules, its look); New, Open, Save, Export, Delete and Done
## along the bottom.
##
## A card is plain data ([CommunityCard]) and its two pictures, the art
## and the set icon, which follow guidelines ([constant
## CommunityCards.ART_GUIDE], [constant CommunityCards.ICON_GUIDE]). The
## rules text is written by the game from the blocks. Save puts it in the
## community_cards folder and it joins the Community cards set at once;
## Export writes the same zip anywhere, to share. Every page of the rules is
## drawn from the builder's catalogues ([constant CommunityCard.EFFECTS],
## [constant CommunityCard.TRIGGERS], [constant CommunityCard.STATICS],
## [constant CommunityCard.CARD_RULES]).

signal left

const MARGIN := 10.0
const FOOTER_H := 50.0
const TABS := ["Card", "Cost & type", "Rules", "Look"]
const KIND_WORDS := {"spell": "Spell effect", "modal": "Choose one", "activated": "Activated ability",
	"trigger": "Triggered ability", "mana": "Mana ability", "static": "Static ability",
	"enchant": "Aura"}

## The card being made, and its pictures (`{bytes, kind}`; {} for none).
var spec: Dictionary = {}
var art := {}
var icon := {}
var _art_texture: Texture2D = null
var _icon_texture: Texture2D = null

var _preview: CardPreview
var _mini_holder: Control
var _problems: Label
var _status: Label
var _tabs: TabContainer
var _abilities_box: VBoxContainer
var _rules_box: VBoxContainer
var _buttons := {}
var _filling := false
var _fields := {}
var _dialog: Control
var _layer: CanvasLayer
var _previous: Control
## UNDO: the card as it was before each change ({spec, art, icon}), the
## newest last; redo the ones undone. [member _now] is the card as shown.
const HISTORY := 200
var _history: Array[Dictionary] = []
var _future: Array[Dictionary] = []
var _now: Dictionary = {}
var _restoring := false
## The saved card the screen holds (opened, imported or saved last; "" for
## a new card or an example): Save goes over it, never over another card
## unasked.
var _saved_name := ""


## Open the creator over everything, [param previous] (Options) hidden
## under it until Done.
static func open_on(previous: Control) -> CardForgeScreen:
	var screen := CardForgeScreen.new()
	screen._previous = previous
	screen._layer = CanvasLayer.new()
	screen._layer.name = "CardForgeLayer"
	screen._layer.layer = 90
	screen._layer.add_child(screen)
	previous.get_viewport().gui_release_focus()
	previous.visible = false
	previous.get_tree().root.add_child(screen._layer)
	return screen


func _ready() -> void:
	name = "CardForgeScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ground()
	_build_previews()
	_build_tabs()
	_build_footer()
	new_card()


func _exit_tree() -> void:
	CommunityCards.clear_draft()


# ------------------------------------------------------------ the frame --

func _ground() -> void:
	var tile_art := GameSkin.texture("deck_tile_slate")
	var ground: Control
	if tile_art != null:
		var tile := TextureRect.new()
		tile.texture = tile_art
		tile.stretch_mode = TextureRect.STRETCH_TILE
		tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ground = tile
	else:
		var flat := ColorRect.new()
		flat.color = Color(0.11, 0.13, 0.17)
		ground = flat
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)


func _panel_style() -> StyleBox:
	var bar := GameSkin.texture("deck_bar_ground")
	if bar != null:
		var box := StyleBoxTexture.new()
		box.texture = bar
		box.content_margin_left = 12
		box.content_margin_right = 12
		box.content_margin_top = 10
		box.content_margin_bottom = 10
		return box
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0.16, 0.32, 0.36)
	flat.set_content_margin_all(10)
	return flat


## The large card, and under it the small one with the card reader's button.
func _build_previews() -> void:
	_preview = CardPreview.new()
	_preview.docked = true
	_preview.position = Vector2(MARGIN, MARGIN)
	add_child(_preview)
	var below := MARGIN + CardPreview.SIZE.y + 10
	_mini_holder = Control.new()
	_mini_holder.name = "ForgeMini"
	_mini_holder.position = Vector2(MARGIN, below)
	_mini_holder.size = MiniCard.SIZE
	_mini_holder.custom_minimum_size = MiniCard.SIZE
	add_child(_mini_holder)
	var reader := UiChrome.menu_button("Card reader", Vector2(150, 34), 15)
	reader.name = "ForgeReader"
	reader.tooltip_text = "The card as the card reader shows it, large."
	reader.position = Vector2(MARGIN + MiniCard.SIZE.x + 12, below + 4)
	reader.pressed.connect(open_reader)
	add_child(reader)
	for row in [["Undo", "ForgeUndo", undo, 0.0], ["Redo", "ForgeRedo", redo, 78.0]]:
		var step := UiChrome.menu_button(String(row[0]), Vector2(72, 30), 14)
		step.name = String(row[1])
		step.tooltip_text = "%s the last change (Ctrl+%s)." % [row[0], "Z" if row[0] == "Undo" else "Y"]
		step.position = Vector2(MARGIN + MiniCard.SIZE.x + 12 + float(row[3]), below + 46)
		step.pressed.connect(row[2])
		step.add_theme_color_override("font_disabled_color", Color8(150, 140, 125))
		add_child(step)
		_buttons[String(row[1])] = step
	# The reasons scroll above the footer, however many there are.
	var reasons := ScrollContainer.new()
	reasons.name = "ForgeProblemsScroll"
	reasons.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	reasons.offset_left = MARGIN
	reasons.offset_top = below + MiniCard.SIZE.y + 6
	reasons.offset_right = MARGIN + CardPreview.SIZE.x
	reasons.anchor_bottom = 1.0
	reasons.offset_bottom = -FOOTER_H - MARGIN
	add_child(reasons)
	_problems = UiChrome.body_label("", 13)
	_problems.name = "ForgeProblems"
	_problems.custom_minimum_size.x = CardPreview.SIZE.x - 12
	_problems.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_problems.add_theme_color_override("font_color", Color(1.0, 0.62, 0.55))
	reasons.add_child(_problems)


func _build_tabs() -> void:
	_tabs = TabContainer.new()
	_tabs.name = "ForgeTabs"
	_tabs.anchor_right = 1.0
	_tabs.anchor_bottom = 1.0
	_tabs.offset_left = MARGIN * 2 + CardPreview.SIZE.x
	_tabs.offset_top = MARGIN
	_tabs.offset_right = -MARGIN
	_tabs.offset_bottom = -FOOTER_H - MARGIN
	add_child(_tabs)
	for title in TABS:
		var scroll := ScrollContainer.new()
		scroll.name = title
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.add_theme_stylebox_override("panel", _panel_style())
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 8)
		scroll.add_child(box)
		_tabs.add_child(scroll)
	_build_card_page(_page(0))
	_build_cost_page(_page(1))
	_build_rules_page(_page(2))
	_build_look_page(_page(3))


func _page(index: int) -> VBoxContainer:
	return _tabs.get_child(index).get_child(0) as VBoxContainer


func _build_footer() -> void:
	var bar := HBoxContainer.new()
	bar.name = "ForgeFooter"
	bar.anchor_top = 1.0
	bar.anchor_right = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = MARGIN
	bar.offset_right = -MARGIN
	bar.offset_top = -FOOTER_H
	bar.offset_bottom = -MARGIN
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)
	_status = UiChrome.body_label("", 13)
	_status.name = "ForgeStatus"
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.custom_minimum_size.x = 260
	_status.clip_text = true
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(_status)
	for row in [["New", "ForgeNew", new_card], ["Open...", "ForgeOpen", open_list],
			["Import...", "ForgeImport", import_card], ["Validate", "ForgeValidate", validate_card],
			["Save", "ForgeSave", save_card], ["Save as...", "ForgeSaveAs", ask_save_as],
			["Export...", "ForgeExport", export_card],
			["Delete", "ForgeDelete", ask_delete], ["Done", "ForgeDone", close]]:
		var button := UiChrome.menu_button(String(row[0]), Vector2(98, 36), 15)
		button.name = String(row[1])
		button.pressed.connect(row[2])
		# A disabled button (Delete before a save) still says what it is.
		button.add_theme_color_override("font_disabled_color", Color8(150, 140, 125))
		bar.add_child(button)
		_buttons[String(row[1])] = button
	# Done in the Deck Builder arrows' purple (the owner, 2026-11-17): the
	# way out, told apart from the stone of the work buttons.
	CardArea._dress_purple(_buttons["ForgeDone"] as Button)
	(_buttons["ForgeSave"] as Button).tooltip_text = "Save the card in the community_cards folder; it joins the Community cards set."
	(_buttons["ForgeExport"] as Button).tooltip_text = "Write the card as one zip anywhere, to share it."
	(_buttons["ForgeValidate"] as Button).tooltip_text = "Set the card beside the game's own cards: suggestions only."
	(_buttons["ForgeImport"] as Button).tooltip_text = "Take a shared card zip or set zip into the community_cards folder."
	(_buttons["ForgeSaveAs"] as Button).tooltip_text = "Save a copy of the card under another name."


# ------------------------------------------------------- page building --

func _label(box: Container, text: String, size := 14) -> Label:
	var label := UiChrome.body_label(text, size)
	box.add_child(label)
	return label


func _row(box: Container, title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := UiChrome.body_label(title, 14)
	label.custom_minimum_size.x = 170
	row.add_child(label)
	box.add_child(row)
	return row


func _line(row: Container, key: String, width := 360.0, max_length := 60) -> LineEdit:
	var edit := LineEdit.new()
	edit.name = "Forge_" + key
	edit.custom_minimum_size.x = width
	edit.max_length = max_length
	edit.text_changed.connect(func(_t: String) -> void: _changed())
	row.add_child(edit)
	_fields[key] = edit
	return edit


func _options(row: Container, key: String, items: Array, labels := {}) -> OptionButton:
	var pick := OptionButton.new()
	pick.name = "Forge_" + key
	for item in items:
		pick.add_item(String(labels.get(item, String(item).replace("_", " ").capitalize())))
		pick.set_item_metadata(pick.item_count - 1, item)
	pick.item_selected.connect(func(_i: int) -> void: _changed())
	row.add_child(pick)
	_fields[key] = pick
	return pick


func _spin(row: Container, key: String, low: int, high: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.name = "Forge_" + key
	spin.min_value = low
	spin.max_value = high
	spin.value_changed.connect(func(_v: float) -> void: _changed())
	row.add_child(spin)
	_fields[key] = spin
	return spin


func _slider(row: Container, key: String, low: float, high: float) -> HSlider:
	var slider := HSlider.new()
	slider.name = "Forge_" + key
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.01
	slider.custom_minimum_size = Vector2(320, 24)
	slider.value_changed.connect(func(_v: float) -> void: _changed())
	row.add_child(slider)
	_fields[key] = slider
	return slider


func _checks(box: Container, key: String, items: Array, per_row := 5, words := {}) -> void:
	var grid := GridContainer.new()
	grid.columns = per_row
	grid.add_theme_constant_override("h_separation", 14)
	box.add_child(grid)
	var checks := {}
	for item in items:
		var check := CheckBox.new()
		check.text = String(words.get(item, String(item).replace("_", " ").capitalize()))
		check.name = "Forge_%s_%s" % [key, item]
		check.toggled.connect(func(_on: bool) -> void: _changed())
		grid.add_child(check)
		checks[item] = check
	_fields[key] = checks


func _guide(box: Container, text: String) -> void:
	var words := UiChrome.body_label(text, 12)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size.x = 640
	words.modulate.a = 0.75
	box.add_child(words)


func _build_card_page(box: VBoxContainer) -> void:
	_line(_row(box, "Name"), "name", 360, CommunityCard.LIMITS["name"])
	_line(_row(box, "Set name"), "set_name", 360, CommunityCard.LIMITS["set_name"])
	var icon_row := _row(box, "Set icon")
	var icon_shown := TextureRect.new()
	icon_shown.name = "ForgeIconShown"
	icon_shown.custom_minimum_size = Vector2(32, 32)
	icon_shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_shown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_row.add_child(icon_shown)
	var choose_icon := UiChrome.menu_button("Choose set icon...", Vector2(180, 32), 14)
	choose_icon.name = "ForgeChooseIcon"
	choose_icon.pressed.connect(func() -> void: _pick_file("icon"))
	icon_row.add_child(choose_icon)
	_label(icon_row, "", 13).name = "ForgeIconLabel"
	_guide(box, CommunityCards.ICON_WORDS)
	_options(_row(box, "Rarity"), "rarity", CommunityCard.RARITIES)
	_line(_row(box, "Illustration (Illus.)"), "artist", 360, CommunityCard.LIMITS["artist"]) \
		.placeholder_text = "the name printed after Illus."
	var art_row := _row(box, "Art")
	var choose_art := UiChrome.menu_button("Choose art...", Vector2(180, 32), 14)
	choose_art.name = "ForgeChooseArt"
	choose_art.pressed.connect(func() -> void: _pick_file("art"))
	art_row.add_child(choose_art)
	_label(art_row, "", 13).name = "ForgeArtLabel"
	_guide(box, CommunityCards.ART_WORDS)
	_label(box, "Flavor")
	var flavor := TextEdit.new()
	flavor.name = "Forge_flavor"
	flavor.custom_minimum_size = Vector2(620, 70)
	flavor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	flavor.text_changed.connect(_changed)
	box.add_child(flavor)
	_fields["flavor"] = flavor


func _build_cost_page(box: VBoxContainer) -> void:
	var cost_row := _row(box, "Mana cost")
	_line(cost_row, "cost", 180, 40)
	for symbol in ["{1}", "{W}", "{U}", "{B}", "{R}", "{G}", "{X}"]:
		var add := UiChrome.menu_button(symbol, Vector2(46, 30), 14)
		add.name = "ForgeAdd" + symbol
		add.pressed.connect(func() -> void: _add_symbol(symbol))
		cost_row.add_child(add)
	var clear := UiChrome.menu_button("Clear", Vector2(70, 30), 14)
	clear.name = "ForgeClearCost"
	clear.pressed.connect(func() -> void:
		(_fields["cost"] as LineEdit).text = ""
		_changed())
	cost_row.add_child(clear)
	_label(box, "Types")
	_checks(box, "types", CommunityCard.TYPES.keys(), 6)
	_checks(box, "supertypes", ["legendary"], 1)
	_line(_row(box, "Subtypes"), "subtypes", 360, 64).placeholder_text = "words, e.g. goblin warrior"
	var pt := _row(box, "Power / toughness")
	_spin(pt, "power", 0, 99)
	_spin(pt, "toughness", 0, 99)


func _build_rules_page(box: VBoxContainer) -> void:
	_label(box, "Keywords (creatures)")
	_checks(box, "keywords", CommunityCard.KEYWORDS.keys(), 5, CommunityCard.KEYWORD_WORDS)
	_label(box, "Protection from")
	_checks(box, "protection", CommunityCard.PROTECTIONS, 6)
	_label(box, "Landwalk")
	_checks(box, "landwalk", CommunityCard.LANDS, 5)
	_label(box, "Card rules")
	_rules_box = VBoxContainer.new()
	_rules_box.name = "ForgeCardRules"
	box.add_child(_rules_box)
	_label(box, "Abilities — the rules text is written from these")
	var adds := HFlowContainer.new()
	adds.add_theme_constant_override("h_separation", 8)
	adds.add_theme_constant_override("v_separation", 6)
	box.add_child(adds)
	for kind in ["spell", "modal", "activated", "trigger", "mana", "static", "enchant"]:
		var add := UiChrome.menu_button("+ " + String(KIND_WORDS[kind]).replace(" ability", ""), Vector2(128, 32), 14)
		add.name = "ForgeAdd_" + kind
		add.pressed.connect(func() -> void: add_ability(kind))
		adds.add_child(add)
	_abilities_box = VBoxContainer.new()
	_abilities_box.name = "ForgeAbilities"
	_abilities_box.add_theme_constant_override("separation", 10)
	box.add_child(_abilities_box)


func _build_look_page(box: VBoxContainer) -> void:
	_options(_row(box, "Border"), "border", CommunityCard.BORDERS)
	_options(_row(box, "Frame"), "frame", CommunityCard.FRAMES, {"auto": "By its colors"})
	_label(box, "Art placement — guidelines-sized art fits as it is; this is for the rest")
	_slider(_row(box, "Zoom"), "zoom", 1.0, 3.0)
	_slider(_row(box, "Left to right"), "art_x", 0.0, 1.0)
	_slider(_row(box, "Top to bottom"), "art_y", 0.0, 1.0)
	var center := UiChrome.menu_button("Center it", Vector2(140, 30), 14)
	center.name = "ForgeCenterArt"
	center.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	center.pressed.connect(func() -> void:
		_filling = true
		(_fields["zoom"] as HSlider).value = 1.0
		(_fields["art_x"] as HSlider).value = 0.5
		(_fields["art_y"] as HSlider).value = 0.5
		_filling = false
		_changed())
	box.add_child(center)


# ------------------------------------------------------------- the card --

## A fresh card to start from.
static func blank() -> Dictionary:
	return {"format": CommunityCard.FORMAT, "version": CommunityCard.VERSION, "name": "My Card",
		"cost": "{1}{R}", "types": ["creature"], "supertypes": [], "subtypes": ["goblin"],
		"power": 2, "toughness": 2, "rarity": "common", "artist": "", "set_name": "My set",
		"look": {"border": "black", "frame": "auto", "art": {"zoom": 1.0, "x": 0.5, "y": 0.5}},
		"flavor": "", "keywords": [], "protection": [], "landwalk": [], "rules": {}, "abilities": []}


func new_card() -> void:
	_saved_name = ""
	load_spec(blank(), {}, {})
	_say("A new card. Choose its set icon and its art on the Card page.")


## Put [param card] and its pictures in the screen.
func load_spec(card: Dictionary, p_art: Dictionary, p_icon: Dictionary) -> void:
	# A card of the wrong shape is never put in the widgets (a zip is
	# untrusted; the Open list shows only whole cards, this is the guard).
	var shape := CommunityCard._shape_problems(card)
	if not shape.is_empty():
		_say("This card cannot be opened: %s" % shape[0])
		return
	spec = card.duplicate(true)
	for key in ["supertypes", "subtypes", "keywords", "protection", "landwalk", "abilities"]:
		if not spec.get(key) is Array:
			spec[key] = []
	if not spec.get("rules") is Dictionary:
		spec["rules"] = {}
	if not spec.get("look") is Dictionary:
		spec["look"] = {}
	if not (spec["look"] as Dictionary).get("art") is Dictionary:
		spec["look"]["art"] = {"zoom": 1.0, "x": 0.5, "y": 0.5}
	art = p_art.duplicate()
	icon = p_icon.duplicate()
	_art_texture = CommunityCards.texture_from(art["bytes"], String(art["kind"])) if not art.is_empty() else null
	_icon_texture = CommunityCards.texture_from(icon["bytes"], String(icon["kind"])) if not icon.is_empty() else null
	_fill()
	_rebuild_rules()
	_rebuild_abilities()
	refresh()


func _fill() -> void:
	_filling = true
	for key in ["name", "set_name", "artist", "cost"]:
		(_fields[key] as LineEdit).text = String(spec.get(key, ""))
	(_fields["subtypes"] as LineEdit).text = " ".join(spec.get("subtypes", []))
	(_fields["flavor"] as TextEdit).text = String(spec.get("flavor", ""))
	_select(_fields["rarity"], String(spec.get("rarity", "common")))
	_select(_fields["border"], String(spec["look"].get("border", "black")))
	_select(_fields["frame"], String(spec["look"].get("frame", "auto")))
	var crop := CommunityCards.crop_of(spec)
	(_fields["zoom"] as HSlider).value = crop["zoom"]
	(_fields["art_x"] as HSlider).value = crop["x"]
	(_fields["art_y"] as HSlider).value = crop["y"]
	(_fields["power"] as SpinBox).value = int(spec.get("power", 2))
	(_fields["toughness"] as SpinBox).value = int(spec.get("toughness", 2))
	for key in ["types", "supertypes", "keywords", "protection", "landwalk"]:
		var checks: Dictionary = _fields[key]
		for item in checks:
			(checks[item] as CheckBox).button_pressed = (spec.get(key, []) as Array).has(item)
	(find_child("ForgeArtLabel", true, false) as Label).text = _picture_words(art, "No art yet.")
	(find_child("ForgeIconLabel", true, false) as Label).text = _picture_words(icon, "No set icon yet.")
	(find_child("ForgeIconShown", true, false) as TextureRect).texture = _icon_texture
	_filling = false


func _picture_words(picture: Dictionary, none: String) -> String:
	if picture.is_empty():
		return none
	var shape := CommunityCards.picture_size(picture["bytes"], String(picture["kind"]))
	var size := "%d x %d, " % [shape.x, shape.y] if shape.x > 0 else ""
	return "%s picture, %s%s." % [String(picture["kind"]).to_upper(), size,
		PortableMode.size_words((picture["bytes"] as PackedByteArray).size())]


static func _select(pick: OptionButton, value: String) -> void:
	for i in pick.item_count:
		if String(pick.get_item_metadata(i)) == value:
			pick.select(i)
			return


static func _picked(pick: OptionButton) -> String:
	return String(pick.get_item_metadata(pick.selected)) if pick.selected >= 0 else ""


## The widgets read back into [member spec], then the card shown again.
func _changed() -> void:
	if _filling:
		return
	for key in ["name", "set_name", "artist"]:
		spec[key] = (_fields[key] as LineEdit).text
	spec["cost"] = (_fields["cost"] as LineEdit).text.strip_edges()
	spec["subtypes"] = Array((_fields["subtypes"] as LineEdit).text.strip_edges().to_lower().split(" ", false))
	spec["flavor"] = (_fields["flavor"] as TextEdit).text
	spec["rarity"] = _picked(_fields["rarity"])
	spec["look"] = {"border": _picked(_fields["border"]), "frame": _picked(_fields["frame"]),
		"art": {"zoom": snappedf((_fields["zoom"] as HSlider).value, 0.01),
			"x": snappedf((_fields["art_x"] as HSlider).value, 0.01),
			"y": snappedf((_fields["art_y"] as HSlider).value, 0.01)}}
	spec["power"] = int((_fields["power"] as SpinBox).value)
	spec["toughness"] = int((_fields["toughness"] as SpinBox).value)
	var had_subtypes := _takes_subtypes(spec.get("types", []))
	for key in ["types", "supertypes", "keywords", "protection", "landwalk"]:
		var on: Array = []
		var checks: Dictionary = _fields[key]
		for item in checks:
			if (checks[item] as CheckBox).button_pressed:
				on.append(item)
		spec[key] = on
	if (spec["types"] as Array).has("land"):
		spec["cost"] = ""
	# A creature turned into an instant leaves its creature types behind.
	if had_subtypes and not _takes_subtypes(spec["types"]):
		spec["subtypes"] = []
		_filling = true
		(_fields["subtypes"] as LineEdit).text = ""
		_filling = false
	refresh()


static func _takes_subtypes(types: Variant) -> bool:
	return types is Array and ((types as Array).has("creature") or (types as Array).has("land"))


func _add_symbol(symbol: String) -> void:
	var edit := _fields["cost"] as LineEdit
	if symbol == "{1}":
		var re := RegEx.create_from_string("^\\{([0-9]+)\\}")
		var hit := re.search(edit.text)
		edit.text = ("{%d}" % (int(hit.get_string(1)) + 1) + edit.text.substr(hit.get_end())) \
			if hit != null else "{1}" + edit.text
	else:
		edit.text += symbol
	_changed()


## Every reason the card cannot be saved now ([] when it can).
func problems() -> Array[String]:
	return _all_problems(CommunityCard.problems(spec))


## The card's own problems ([param own]) and the screen's: a name the game
## has (in any case), the set icon still to choose.
func _all_problems(own: Array[String]) -> Array[String]:
	var out := own.duplicate()
	var card_name := String(spec.get("name", "")).strip_edges()
	var game_card := CardRegistry.game_name_like(card_name) if card_name != "" else ""
	if game_card != "":
		out.append("A card named %s is already in the game." % game_card)
	if icon.is_empty():
		out.append("Choose the set icon (Card page).")
	return out


## Show the card as it stands — large, small — or why it cannot be one.
func refresh() -> void:
	_remember()
	var own := CommunityCard.problems(spec)
	var found := _all_problems(own)
	_problems.text = "\n".join(found)
	(_buttons["ForgeSave"] as Button).disabled = not found.is_empty()
	(_buttons["ForgeSaveAs"] as Button).disabled = not found.is_empty()
	(_buttons["ForgeExport"] as Button).disabled = not found.is_empty()
	(_buttons["ForgeUndo"] as Button).disabled = _history.is_empty()
	(_buttons["ForgeRedo"] as Button).disabled = _future.is_empty()
	(_buttons["ForgeValidate"] as Button).disabled = not own.is_empty()
	(_buttons["ForgeDelete"] as Button).disabled = CommunityCards.own_path_of(
		String(spec.get("name", "")).strip_edges()) == ""
	if not own.is_empty():
		return
	var data := card_data()
	CommunityCards.set_draft(spec, _art_texture, _icon_texture)
	_preview.show_card(CardInstance.new(data, -1, 0))
	# One small card, shown each card made (not one made per keystroke).
	var mini := _mini_holder.get_child(0) as MiniCard if _mini_holder.get_child_count() > 0 else null
	if mini == null:
		mini = MiniCard.new(CardInstance.new(data, -1, 0))
		mini.size = MiniCard.SIZE
		mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mini.focus_mode = Control.FOCUS_NONE
		_mini_holder.add_child(mini)
	else:
		mini.instance = CardInstance.new(data, -1, 0)
	mini.art_override = CommunityCards.art_texture(data.card_name)
	mini.refresh()
	_mini_holder.tooltip_text = "%s\n%s%s" % [data.card_name, data.oracle_text, CommunityCards.tooltip_extra(data)]


## The card being made, built (a whole spec only).
func card_data() -> CardData:
	var data := CommunityCard.build(spec)
	data.set_code = CommunityCard.SET_CODE
	data.artist = String(spec.get("artist", ""))
	return data


# --------------------------------------------------------- card rules --

func _rebuild_rules() -> void:
	for child in _rules_box.get_children():
		_rules_box.remove_child(child)
		child.queue_free()
	var rules: Dictionary = spec.get("rules", {})
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	_rules_box.add_child(grid)
	for id in CommunityCard.CARD_RULES:
		var info: Dictionary = CommunityCard.CARD_RULES[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var check := CheckBox.new()
		check.name = "ForgeRule_" + String(id)
		check.text = String(info["label"])
		check.button_pressed = rules.has(id)
		check.custom_minimum_size.x = 230
		row.add_child(check)
		var value: Control = null
		match String(info.get("kind", "flag")):
			"amount":
				var spin := SpinBox.new()
				spin.min_value = int(info["range"][0])
				spin.max_value = int(info["range"][1])
				spin.value = int(rules.get(id, info["range"][0]))
				spin.value_changed.connect(func(v: float) -> void:
					if rules.has(id):
						rules[id] = int(v)
						refresh())
				value = spin
			"cost":
				var edit := LineEdit.new()
				edit.custom_minimum_size.x = 100
				edit.placeholder_text = "{1}{R}"
				edit.text = String(rules.get(id, ""))
				edit.text_changed.connect(func(t: String) -> void:
					if rules.has(id):
						rules[id] = t.strip_edges()
						refresh())
				value = edit
		if value != null:
			row.add_child(value)
		check.toggled.connect(func(on: bool) -> void:
			if on:
				match String(info.get("kind", "flag")):
					"amount": rules[id] = int((value as SpinBox).value)
					"cost":
						var edit := value as LineEdit
						if edit.text.strip_edges() == "":
							edit.text = "{1}"
						rules[id] = edit.text.strip_edges()
					_: rules[id] = true
			else:
				rules.erase(id)
			refresh())
		row.tooltip_text = String(info.get("tip", ""))
		grid.add_child(row)


# -------------------------------------------------------- the abilities --

func add_ability(kind: String) -> void:
	var ability := {"kind": kind}
	match kind:
		"spell":
			ability["effects"] = [{"effect": "damage", "amount": 2, "target": "any"}]
		"modal":
			ability["modes"] = [{"effects": [{"effect": "damage", "amount": 2, "target": "any"}]},
				{"effects": [{"effect": "draw", "amount": 1}]}]
		"activated":
			ability.merge({"cost": "{1}", "tap": true, "sacrifice": false, "life": 0,
				"effects": [{"effect": "draw", "amount": 1}]})
		"trigger":
			ability.merge({"when": "enters", "effects": [{"effect": "gain_life", "amount": 2}]})
		"mana":
			ability.merge({"color": "green", "amount": 1})
		"static":
			ability.merge({"what": "anthem_others", "power": 1, "toughness": 1, "keywords": []})
		"enchant":
			ability.merge({"enchant": "creature", "power": 2, "toughness": 2, "keywords": []})
	(spec["abilities"] as Array).append(ability)
	_rebuild_abilities()
	refresh()


func _rebuild_abilities() -> void:
	for child in _abilities_box.get_children():
		_abilities_box.remove_child(child)
		child.queue_free()
	var abilities: Array = spec.get("abilities", [])
	for i in abilities.size():
		_abilities_box.add_child(_ability_panel(abilities[i], i))


func _ability_panel(a: Dictionary, index: int) -> Control:
	var panel := PanelContainer.new()
	panel.name = "ForgeAbility%d" % index
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0.28)
	flat.set_corner_radius_all(6)
	flat.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", flat)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var head := HFlowContainer.new()
	head.add_theme_constant_override("h_separation", 8)
	box.add_child(head)
	head.add_child(UiChrome.body_label("%d. %s" % [index + 1, KIND_WORDS.get(a["kind"], a["kind"])], 15))
	match String(a["kind"]):
		"activated":
			head.add_child(UiChrome.body_label("Cost", 13))
			var cost := LineEdit.new()
			cost.text = String(a.get("cost", ""))
			cost.custom_minimum_size.x = 110
			cost.text_changed.connect(func(t: String) -> void:
				a["cost"] = t.strip_edges()
				refresh())
			head.add_child(cost)
			for flag in [["tap", "{T}"], ["sacrifice", "Sacrifice it"]]:
				var check := CheckBox.new()
				check.text = String(flag[1])
				check.button_pressed = bool(a.get(flag[0], false))
				check.toggled.connect(func(on: bool) -> void:
					a[flag[0]] = on
					refresh())
				head.add_child(check)
			head.add_child(UiChrome.body_label("Life", 13))
			head.add_child(_small_spin(a, "life", 0, 20))
			head.add_child(_color_pick(a, "sacrifice_what", [""] + CommunityCard.SACRIFICES.keys(),
				{"": "no other sacrifice", "creature": "Sacrifice a creature", "land": "Sacrifice a land",
					"artifact": "Sacrifice an artifact"}))
			head.add_child(UiChrome.body_label("Discard", 13))
			head.add_child(_small_spin(a, "discard", 0, 2))
			head.add_child(UiChrome.body_label("Remove +1/+1", 13))
			head.add_child(_small_spin(a, "remove_counters", 0, 3))
			if CommunityCard.TIMINGS.size() > 1:
				head.add_child(_catalog_pick(a, "timing", CommunityCard.TIMINGS))
			head.add_child(UiChrome.body_label("Shared with", 13))
			var shared := LineEdit.new()
			shared.name = "ForgeShared"
			shared.placeholder_text = "no type"
			shared.tooltip_text = "Slivers: every creature of this type has the ability, both players'."
			shared.text = String(a.get("shared", ""))
			shared.custom_minimum_size.x = 140
			shared.text_changed.connect(func(t: String) -> void:
				if t.strip_edges() == "":
					a.erase("shared")
				else:
					a["shared"] = t.strip_edges().to_lower()
				refresh())
			head.add_child(shared)
		"trigger":
			head.add_child(_catalog_pick(a, "when", CommunityCard.TRIGGERS, func(t: String) -> String:
				return t.replace("CARDNAME", "it")))
		"mana":
			head.add_child(_color_pick(a, "color", CommunityCard.MANA_CHOICES, {"any": "Any color"}))
			head.add_child(_small_spin(a, "amount", 1, 3))
			head.add_child(UiChrome.body_label("Cost", 13))
			var mana_cost := LineEdit.new()
			mana_cost.placeholder_text = "none"
			mana_cost.text = String(a.get("cost", ""))
			mana_cost.custom_minimum_size.x = 80
			mana_cost.text_changed.connect(func(t: String) -> void:
				a["cost"] = t.strip_edges()
				refresh())
			head.add_child(mana_cost)
			head.add_child(_flag(a, "sacrifice", "Sacrifice it"))
			head.add_child(UiChrome.body_label("Damage to you", 13))
			head.add_child(_small_spin(a, "pain", 0, 2))
		"static":
			head.add_child(_catalog_pick(a, "what", CommunityCard.STATICS, func(t: String) -> String:
				return t.replace("+P/+T", "...")))
			var info: Dictionary = CommunityCard.static_info(String(a.get("what", "anthem")))
			if info.get("subtype", false):
				var sub := LineEdit.new()
				sub.placeholder_text = "creature type"
				sub.text = String(a.get("subtype", ""))
				sub.custom_minimum_size.x = 110
				sub.text_changed.connect(func(t: String) -> void:
					a["subtype"] = t.strip_edges().to_lower()
					refresh())
				head.add_child(sub)
			if info.get("spell_type", false):
				head.add_child(_color_pick(a, "spell_type", CommunityCard.SPELL_TYPES))
				head.add_child(UiChrome.body_label("less by", 13))
				head.add_child(_small_spin(a, "amount", int(info["amount"][0]), int(info["amount"][1])))
			if info.get("pt", true):
				_pt_and_keywords(head, a)
		"enchant":
			head.add_child(UiChrome.body_label("Enchant", 13))
			head.add_child(_color_pick(a, "enchant", CommunityCard.ENCHANTS, {}, "", "", func() -> void:
				if String(a["enchant"]) != "creature":
					for key in ["power", "toughness", "keywords", "protection", "pacify"]:
						a.erase(key)
				_rebuild_abilities()))
			if String(a.get("enchant", "creature")) == "creature":
				_pt_and_keywords(head, a)
				head.add_child(_color_pick(a, "protection", [""] + CommunityCard.PROTECTIONS,
					{"": "no protection"}, "protection from "))
				head.add_child(_flag(a, "pacify", "Can't attack or block"))
			head.add_child(_flag(a, "frozen", "Doesn't untap"))
			head.add_child(_flag(a, "control", "You control it"))
	var remove := UiChrome.menu_button("Remove", Vector2(90, 28), 13)
	remove.pressed.connect(func() -> void:
		(spec["abilities"] as Array).remove_at(index)
		_rebuild_abilities()
		refresh())
	head.add_child(remove)
	if a.has("effects"):
		_effects_rows(box, String(a["kind"]), a["effects"])
	if a.has("modes"):
		var modes: Array = a["modes"]
		for m in modes.size():
			var mode: Dictionary = modes[m]
			var title := HBoxContainer.new()
			title.add_theme_constant_override("separation", 8)
			title.add_child(UiChrome.body_label("   Mode %d" % (m + 1), 14))
			if modes.size() > CommunityCard.MODES[0]:
				var drop := UiChrome.menu_button("Remove mode", Vector2(120, 26), 13)
				drop.pressed.connect(func() -> void:
					modes.remove_at(m)
					_rebuild_abilities()
					refresh())
				title.add_child(drop)
			box.add_child(title)
			if not mode.get("effects") is Array:
				mode["effects"] = []
			_effects_rows(box, "spell", mode["effects"])
		if modes.size() < CommunityCard.MODES[1]:
			var add_mode := UiChrome.menu_button("+ Mode", Vector2(100, 28), 13)
			add_mode.name = "ForgeAddMode"
			add_mode.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			add_mode.pressed.connect(func() -> void:
				modes.append({"effects": [{"effect": "draw", "amount": 1}]})
				_rebuild_abilities()
				refresh())
			box.add_child(add_mode)
	return panel


## The effect rows of one ability (or one mode: [param kind] "spell") and
## its "+ Effect" button.
func _effects_rows(box: Container, kind: String, effects: Array) -> void:
	for j in effects.size():
		box.add_child(_effect_row(kind, effects, effects[j], j))
	if effects.size() < CommunityCard.LIMITS["effects"]:
		var more := UiChrome.menu_button("+ Effect", Vector2(100, 28), 13)
		more.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		more.pressed.connect(func() -> void:
			effects.append({"effect": "draw", "amount": 1})
			_rebuild_abilities()
			refresh())
		box.add_child(more)


## A checkbox writing [param key] of [param holder] (left out when off).
func _flag(holder: Dictionary, key: String, text: String) -> CheckBox:
	var check := CheckBox.new()
	check.name = "ForgeFlag_" + key
	check.text = text
	check.button_pressed = bool(holder.get(key, false))
	check.toggled.connect(func(on: bool) -> void:
		if on:
			holder[key] = true
		else:
			holder.erase(key)
		refresh())
	return check


## An OptionButton over a catalogue ({id: text or {label}}), writing [param key].
func _catalog_pick(holder: Dictionary, key: String, catalog: Dictionary, words := Callable()) -> OptionButton:
	var pick := OptionButton.new()
	for id in catalog:
		var entry: Variant = catalog[id]
		var text := String(entry.get("label", id)) if entry is Dictionary else String(entry)
		pick.add_item(words.call(text) if words.is_valid() else text)
		pick.set_item_metadata(pick.item_count - 1, id)
	_select(pick, String(holder.get(key, catalog.keys()[0])))
	holder[key] = _picked(pick)
	pick.item_selected.connect(func(_i: int) -> void:
		holder[key] = _picked(pick)
		# Only the static's kind changes what its panel holds.
		if key == "what":
			_rebuild_abilities()
		refresh())
	return pick


func _effect_row(kind: String, effects: Array, e: Dictionary, index: int) -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_child(UiChrome.body_label("   •", 14))
	var pick := OptionButton.new()
	for id in CommunityCard.EFFECTS:
		if not CommunityCard.effect_allowed(String(id), kind):
			continue
		pick.add_item(String(CommunityCard.EFFECTS[id]["label"]))
		pick.set_item_metadata(pick.item_count - 1, id)
	_select(pick, String(e.get("effect", "draw")))
	pick.item_selected.connect(func(_i: int) -> void:
		var fresh := CommunityCard.effect_defaults(_picked(pick), kind)
		e.clear()
		e.merge(fresh)
		_rebuild_abilities()
		refresh())
	row.add_child(pick)
	var info: Dictionary = CommunityCard.EFFECTS.get(String(e.get("effect", "draw")), {})
	if info.has("targets"):
		var target := OptionButton.new()
		for t in info["targets"]:
			if t == "self" and kind == "spell":
				continue
			target.add_item(CommunityCard.target_words(String(t)))
			target.set_item_metadata(target.item_count - 1, t)
		_select(target, String(e.get("target", info["targets"][0])))
		target.item_selected.connect(func(_i: int) -> void:
			e["target"] = _picked(target)
			refresh())
		row.add_child(target)
	if info.has("amount"):
		row.add_child(_small_spin(e, "amount", int(info["amount"][0]), int(info["amount"][1])))
	if info.get("x", false) and kind != "trigger":
		var x := CheckBox.new()
		x.name = "ForgeX"
		x.text = "X"
		x.tooltip_text = "The amount (the power for +P/+T) is the X paid — put {X} in the cost."
		x.button_pressed = bool(e.get("x", false))
		x.toggled.connect(func(on: bool) -> void:
			if on:
				e["x"] = true
			else:
				e.erase("x")
			refresh())
		row.add_child(x)
	if info.has("pt"):
		_pt_and_keywords(row, e)
	if info.has("base"):
		row.add_child(UiChrome.body_label("P", 13))
		row.add_child(_small_spin(e, "power", 0, 20))
		row.add_child(UiChrome.body_label("T", 13))
		row.add_child(_small_spin(e, "toughness", 1, 20))
	if info.has("subtype") and not info.has("token"):
		row.add_child(_word_edit(e, "subtype", "creature type"))
	if info.has("unless"):
		row.add_child(UiChrome.body_label("unless they pay", 13))
		row.add_child(_small_spin(e, "unless", int(info["unless"][0]), int(info["unless"][1])))
	if info.has("land"):
		row.add_child(_color_pick(e, "land", CommunityCard.LANDS, {}, "", "walk"))
	if info.has("lose"):
		row.add_child(_keyword_pick(e, false))
	if info.has("shield"):
		row.add_child(_color_pick(e, "color", CommunityCard.PROTECTIONS, {}, "from a ", " source"))
	if info.has("token"):
		row.add_child(_small_spin(e, "power", 0, 20))
		row.add_child(_small_spin(e, "toughness", 1, 20))
		row.add_child(_color_pick(e, "color", ["colorless", "white", "blue", "black", "red", "green"]))
		row.add_child(_word_edit(e, "subtype", "creature type", "soldier"))
		row.add_child(_keyword_pick(e, true))
	if info.has("color") and not info.has("token"):
		row.add_child(_color_pick(e, "color", ["white", "blue", "black", "red", "green", "colorless"]))
	var remove := UiChrome.menu_button("x", Vector2(32, 28), 13)
	remove.tooltip_text = "Remove this effect"
	remove.pressed.connect(func() -> void:
		effects.remove_at(index)
		_rebuild_abilities()
		refresh())
	row.add_child(remove)
	return row


## A one-word field writing [param key] lower-cased.
func _word_edit(holder: Dictionary, key: String, hint: String, fallback := "") -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = hint
	edit.text = String(holder.get(key, fallback))
	edit.custom_minimum_size.x = 110
	edit.max_length = 20
	edit.text_changed.connect(func(t: String) -> void:
		holder[key] = t.strip_edges().to_lower()
		refresh())
	return edit


## One keyword in [param holder]'s keywords ([param optional]: or none).
func _keyword_pick(holder: Dictionary, optional: bool) -> OptionButton:
	var keyword := OptionButton.new()
	if optional:
		keyword.add_item("no keyword")
		keyword.set_item_metadata(0, "")
	for k in CommunityCard.KEYWORDS:
		keyword.add_item(String(CommunityCard.KEYWORD_WORDS[k]))
		keyword.set_item_metadata(keyword.item_count - 1, k)
	var had: Array = holder.get("keywords", [])
	_select(keyword, String(had[0]) if not had.is_empty() else ("" if optional else "flying"))
	if not optional and had.is_empty():
		holder["keywords"] = [_picked(keyword)]
	keyword.item_selected.connect(func(_i: int) -> void:
		var k := _picked(keyword)
		holder["keywords"] = [k] if k != "" else []
		refresh())
	return keyword


func _small_spin(holder: Dictionary, key: String, low: int, high: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.value = clampi(int(holder.get(key, low)), low, high)
	holder[key] = int(spin.value)
	spin.value_changed.connect(func(v: float) -> void:
		holder[key] = int(v)
		refresh())
	return spin


## A choice among [param colors] (any words) writing [param key]; each
## shown as its [param words] entry, else capitalized between [param before]
## and [param after].
func _color_pick(holder: Dictionary, key: String, colors: Array, words := {}, before := "",
		after := "", then := Callable()) -> OptionButton:
	var pick := OptionButton.new()
	for c in colors:
		var shown := String(c).capitalize() if before == "" else String(c)
		pick.add_item(String(words[c]) if words.has(c) else before + shown + after)
		pick.set_item_metadata(pick.item_count - 1, c)
	_select(pick, String(holder.get(key, colors[0])))
	holder[key] = _picked(pick)
	pick.item_selected.connect(func(_i: int) -> void:
		holder[key] = _picked(pick)
		# What else the choice changes, before the card is shown (one undo).
		if then.is_valid():
			then.call()
		refresh())
	return pick


## +P/+T and a keyword (an anthem, an Aura, a pump).
func _pt_and_keywords(row: Container, holder: Dictionary) -> void:
	row.add_child(UiChrome.body_label("+P", 13))
	row.add_child(_small_spin(holder, "power", -10, 10))
	row.add_child(UiChrome.body_label("+T", 13))
	row.add_child(_small_spin(holder, "toughness", -10, 10))
	var keyword := OptionButton.new()
	keyword.add_item("no keyword")
	keyword.set_item_metadata(0, "")
	for k in CommunityCard.KEYWORDS:
		keyword.add_item(String(CommunityCard.KEYWORD_WORDS[k]))
		keyword.set_item_metadata(keyword.item_count - 1, k)
	var had: Array = holder.get("keywords", [])
	_select(keyword, String(had[0]) if not had.is_empty() else "")
	keyword.item_selected.connect(func(_i: int) -> void:
		var k := _picked(keyword)
		holder["keywords"] = [k] if k != "" else []
		refresh())
	row.add_child(keyword)


# ---------------------------------------------------------- the actions --

func _say(text: String) -> void:
	_status.text = text


## Save into the community_cards folder; the card joins the set at once.
func save_card(replace := false) -> void:
	if not problems().is_empty():
		return
	# A table open at LAN holds the card catalogue still (the packs' lock).
	var refusal := CardPacks.change_refusal()
	if refusal != "":
		_say(refusal.replace("changing or rescanning card packs", "saving a card"))
		return
	var card_name := String(spec["name"]).strip_edges()
	var other := CommunityCards.found_like(card_name)
	if not replace and other != "" and other.to_lower() != _saved_name.to_lower():
		_ask_overwrite(other, func() -> void: save_card(true))
		return
	var why := CommunityCards.save(spec, art, icon)
	if why != "":
		_say(why)
		return
	_saved_name = card_name
	CommunityCards.refresh()
	_say("Saved in %s. %s is in the Community cards set now." % [
		GamePaths.shown(CommunityCards.own_folder()), String(spec["name"]).strip_edges()])
	refresh()


## Export the card — or its whole set — as one zip anywhere, to share.
func export_card() -> void:
	if not problems().is_empty():
		return
	var whole := set_cards()
	if whole.size() < 2:
		_export_box(false)
		return
	_close_dialog()
	var dialog := OriginalDialog.create("Export", Vector2(480, 190))
	dialog.name = "ForgeExportWindow"
	var words := UiChrome.body_label("Export this card alone, or the whole set %s (%d cards) in one zip?" % [
		String(spec.get("set_name", "")).strip_edges(), whole.size()], 14)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size.x = 440
	dialog.body().add_child(words)
	GauntletOptions.fit(dialog.add_button("This card")).pressed.connect(func() -> void:
		_close_dialog()
		_export_box(false))
	GauntletOptions.fit(dialog.add_button("The set")).pressed.connect(func() -> void:
		_close_dialog()
		_export_box(true))
	GauntletOptions.fit(dialog.add_button("Cancel")).pressed.connect(_close_dialog)
	_dialog = dialog
	add_child(dialog)


## The cards of this card's set (its set name): the saved ones, with this
## card as it stands now in place of its saved copy.
func set_cards() -> Array[Dictionary]:
	var set_name := String(spec.get("set_name", "")).strip_edges()
	var card_name := String(spec.get("name", "")).strip_edges()
	var out: Array[Dictionary] = []
	if set_name == "":
		return out
	for card in CommunityCards.cards_of_set(set_name):
		if String((card["spec"] as Dictionary).get("name", "")).strip_edges() != card_name:
			out.append(card)
	out.append({"spec": spec, "art": art, "icon": icon})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["spec"]["name"]) < String(b["spec"]["name"]))
	return out


func _export_box(whole_set: bool) -> void:
	var box := FileDialog.new()
	box.name = "ForgeExportBox"
	box.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	box.access = FileDialog.ACCESS_FILESYSTEM
	box.use_native_dialog = true
	box.filters = PackedStringArray(["*.zip ; Card zip"])
	var base := CommunityCards.file_name(String(spec["set_name"] if whole_set else spec["name"]))
	box.current_file = (base if base != "" else ("set" if whole_set else "card")) + ".zip"
	box.file_selected.connect(func(path: String) -> void:
		if whole_set:
			export_set_to(path)
		else:
			export_to(path)
		box.queue_free())
	box.canceled.connect(box.queue_free)
	add_child(box)
	box.popup_centered_ratio(0.6)


func export_set_to(path: String) -> void:
	if not path.to_lower().ends_with(".zip"):
		path += ".zip"
	var cards := set_cards()
	var why := CommunityCards.write_set_zip(path, String(spec.get("set_name", "")), cards)
	_say(why if why != "" else "Exported %d cards of %s to %s — share it: it goes in a community_cards folder." \
		% [cards.size(), String(spec.get("set_name", "")).strip_edges(), GamePaths.shown(path)])


func export_to(path: String) -> void:
	if not path.to_lower().ends_with(".zip"):
		path += ".zip"
	var why := CommunityCards.write_zip(path, spec, art, icon)
	_say(why if why != "" else "Exported to %s — share it: it goes in a community_cards folder." \
		% GamePaths.shown(path))


func _pick_file(which: String) -> void:
	var box := FileDialog.new()
	box.name = "ForgePictureBox"
	box.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	box.access = FileDialog.ACCESS_FILESYSTEM
	box.use_native_dialog = true
	box.filters = PackedStringArray(["*.png, *.webp ; Set icon"] if which == "icon"
		else ["*.png, *.jpg, *.jpeg, *.webp ; Art"])
	box.file_selected.connect(func(path: String) -> void:
		take_picture(which, path)
		box.queue_free())
	box.canceled.connect(box.queue_free)
	add_child(box)
	box.popup_centered_ratio(0.6)


## Take the picture at [param path] as the card's art or its set icon
## ([param which]), if it follows the guidelines: "" when taken, else why
## not (also said on the status line).
func take_picture(which: String, path: String) -> String:
	var kind := path.get_extension().to_lower()
	if kind == "jpeg":
		kind = "jpg"
	var bytes := FileAccess.get_file_as_bytes(path)
	var why := CommunityCards.icon_problem(bytes, kind) if which == "icon" \
		else CommunityCards.art_problem(bytes, kind)
	if why != "":
		_say(why)
		return why
	if which == "icon":
		icon = {"bytes": bytes, "kind": kind}
		_icon_texture = CommunityCards.texture_from(bytes, kind)
	else:
		art = {"bytes": bytes, "kind": kind}
		_art_texture = CommunityCards.texture_from(bytes, kind)
	_fill()
	refresh()
	_say("%s: %s." % ["Set icon" if which == "icon" else "Art", path.get_file()])
	return ""


# ----------------------------------------------------------------- undo --

## Keep the card as it was before this change (each change shows the card
## again, so each passes here once).
func _remember() -> void:
	var snap := {"spec": spec.duplicate(true), "art": art, "icon": icon}
	if _restoring or _now.is_empty():
		_now = snap
		return
	if snap["spec"] == _now["spec"] and snap["art"] == _now["art"] and snap["icon"] == _now["icon"]:
		return
	_history.append(_now)
	if _history.size() > HISTORY:
		_history.pop_front()
	_future.clear()
	_now = snap


func undo() -> void:
	if _history.is_empty():
		return
	_future.append(_now)
	_step_to(_history.pop_back())
	_say("Undone.")


func redo() -> void:
	if _future.is_empty():
		return
	_history.append(_now)
	_step_to(_future.pop_back())
	_say("Redone.")


func _step_to(snap: Dictionary) -> void:
	_restoring = true
	load_spec(snap["spec"], snap["art"], snap["icon"])
	_restoring = false
	_now = snap


# ------------------------------------------------------ import, save as --

## Take a shared card zip (or a set zip) into the community_cards folder.
func import_card() -> void:
	var box := FileDialog.new()
	box.name = "ForgeImportBox"
	box.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	box.access = FileDialog.ACCESS_FILESYSTEM
	box.use_native_dialog = true
	box.filters = PackedStringArray(["*.zip ; Card or set zip"])
	box.file_selected.connect(func(path: String) -> void:
		import_from(path)
		box.queue_free())
	box.canceled.connect(box.queue_free)
	add_child(box)
	box.popup_centered_ratio(0.6)


## Import the zip at [param path] (asking first before replacing the
## player's own copies): what happened is said on the status line, and
## the first card taken is opened.
func import_from(path: String, replace := false) -> Dictionary:
	var refusal := CardPacks.change_refusal()
	if refusal != "":
		_say(refusal.replace("changing or rescanning card packs", "importing a card"))
		return {}
	var done := CommunityCards.import_file(path, replace)
	var names: Array = done["names"]
	if not names.is_empty():
		CommunityCards.refresh()
		open_card(String(names[0]))
	var words: Array[String] = []
	if not names.is_empty():
		words.append("Imported %s." % (String(names[0]) if names.size() == 1 else "%d cards" % names.size()))
	if not (done["problems"] as Array).is_empty():
		words.append("Not taken: %s" % String(done["problems"][0]))
	if not (done["here"] as Array).is_empty() and not replace:
		_ask_replace(path, done["here"])
	_say(" ".join(words) if not words.is_empty() else "Nothing imported.")
	return done


func _ask_replace(path: String, here: Array) -> void:
	_close_dialog()
	var dialog := OriginalDialog.create("Import", Vector2(480, 200))
	dialog.name = "ForgeReplaceWindow"
	var shown := ", ".join(here.slice(0, 4)) + (" and %d more" % (here.size() - 4) if here.size() > 4 else "")
	var words := UiChrome.body_label("%s %s here already. Replace your own %s with the imported %s?" % [
		shown, "is" if here.size() == 1 else "are", "copy" if here.size() == 1 else "copies",
		"one" if here.size() == 1 else "ones"], 14)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size.x = 440
	dialog.body().add_child(words)
	GauntletOptions.fit(dialog.add_button("Replace")).pressed.connect(func() -> void:
		_close_dialog()
		import_from(path, true))
	GauntletOptions.fit(dialog.add_button("Keep mine")).pressed.connect(_close_dialog)
	_dialog = dialog
	add_child(dialog)


## Save a copy under another name (asked for).
func ask_save_as() -> void:
	if not problems().is_empty():
		return
	_close_dialog()
	var dialog := OriginalDialog.create("Save as", Vector2(460, 190))
	dialog.name = "ForgeSaveAsWindow"
	var edit := LineEdit.new()
	edit.name = "ForgeSaveAsName"
	edit.max_length = CommunityCard.LIMITS["name"]
	edit.custom_minimum_size.x = 400
	# The copy's name fits the name's limit (and so is never the card's own).
	edit.text = String(spec.get("name", "")).strip_edges().left(CommunityCard.LIMITS["name"] - 3).strip_edges() + " II"
	dialog.body().add_child(UiChrome.body_label("The copy's name:", 14))
	dialog.body().add_child(edit)
	GauntletOptions.fit(dialog.add_button("Save")).pressed.connect(func() -> void:
		save_as(edit.text))
	GauntletOptions.fit(dialog.add_button("Cancel")).pressed.connect(_close_dialog)
	_dialog = dialog
	add_child(dialog)
	edit.grab_focus()
	edit.select_all()


## Save the card as [param new_name] (the old one stays as it was saved;
## a card already of that name is replaced only when asked).
func save_as(new_name: String, replace := false) -> void:
	var refusal := CardPacks.change_refusal()
	if refusal != "":
		_say(refusal.replace("changing or rescanning card packs", "saving a card"))
		return
	var was := String(spec.get("name", ""))
	spec["name"] = new_name.strip_edges()
	var found := problems()
	if not found.is_empty():
		spec["name"] = was
		_say(found[0])
		return
	var other := CommunityCards.found_like(String(spec["name"]))
	if not replace and other != "" and other.to_lower() != _saved_name.to_lower():
		spec["name"] = was
		_ask_overwrite(other, func() -> void: save_as(new_name, true))
		return
	_close_dialog()
	_fill()
	refresh()
	save_card(true)


## Ask before a save goes over [param other], another saved card.
func _ask_overwrite(other: String, then: Callable) -> void:
	_close_dialog()
	var dialog := OriginalDialog.create("Save", Vector2(470, 190))
	dialog.name = "ForgeOverwriteWindow"
	var words := UiChrome.body_label("A card named %s is saved already. Replace it with this one?" % other, 14)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size.x = 430
	dialog.body().add_child(words)
	GauntletOptions.fit(dialog.add_button("Replace")).pressed.connect(func() -> void:
		_close_dialog()
		then.call())
	GauntletOptions.fit(dialog.add_button("Cancel")).pressed.connect(_close_dialog)
	_dialog = dialog
	add_child(dialog)


## The card as the card reader shows it: large, over the screen.
func open_reader() -> void:
	if not CommunityCard.problems(spec).is_empty():
		return
	_close_dialog()
	var shade := ColorRect.new()
	shade.name = "ForgeReaderShade"
	shade.color = Color(0, 0, 0, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var big := CardPreview.new()
	big.docked = true
	var scale_to := minf(1.7, (get_viewport_rect().size.y - 60.0) / CardPreview.SIZE.y)
	big.scale = Vector2.ONE * scale_to
	big.position = (get_viewport_rect().size - CardPreview.SIZE * scale_to) / 2.0
	shade.add_child(big)
	big.show_card(CardInstance.new(card_data(), -1, 0))
	shade.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_close_dialog())
	_dialog = shade
	add_child(shade)


## The colors of the suggestions, by level (on the dialog's dark stone;
## the red is the duel's warning red).
const ADVICE_COLORS := {CardBalance.OK: Color8(150, 220, 140), CardBalance.LOW: Color8(140, 190, 255),
	CardBalance.HIGH: Color8(255, 180, 80), CardBalance.VERY_HIGH: Color8(255, 100, 100)}


## THE VALIDATOR: the card beside the game's own cards ([CardBalance]) —
## suggestions only, one a line, the worst colored red.
func validate_card() -> void:
	if not CommunityCard.problems(spec).is_empty():
		return
	_close_dialog()
	var dialog := OriginalDialog.create("Suggestions", Vector2(720, 560))
	dialog.name = "ForgeValidateWindow"
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(680, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.name = "ForgeAdvice"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	dialog.body().add_child(scroll)
	for row in CardBalance.advice(spec):
		var level := String(row["level"])
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		var tag := UiChrome.body_label(String(CardBalance.LEVEL_WORDS.get(level, level)), 14)
		tag.custom_minimum_size.x = 86
		tag.add_theme_color_override("font_color", ADVICE_COLORS.get(level, Color.BLACK))
		line.add_child(tag)
		var words := UiChrome.body_label("%s: %s" % [row["topic"], row["text"]], 14)
		words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.custom_minimum_size.x = 560
		line.add_child(words)
		box.add_child(line)
	GauntletOptions.fit(dialog.add_button("Close")).pressed.connect(_close_dialog)
	_dialog = dialog
	add_child(dialog)
	# As tall as its lines (about 80 letters a line), never past the screen.
	var lines := 0
	for row in box.get_children():
		lines += ceili(((row as Control).get_child(1) as Label).text.length() / 80.0)
	_fit_dialog(dialog, scroll, clampf(lines * 21 + box.get_child_count() * 6, 80, 440))


## The cards found, as small cards, to open one.
func open_list() -> void:
	_close_dialog()
	# The saved cards as saved: the card being made is set aside while the
	# list is up ([method _close_dialog] shows it again).
	CommunityCards.clear_draft()
	var dialog := OriginalDialog.create("Open a card", Vector2(640, 520))
	dialog.name = "ForgeOpenWindow"
	var search := LineEdit.new()
	search.name = "ForgeOpenSearch"
	search.placeholder_text = "Search: a name, a set, a type, a color, a word of the rules"
	search.custom_minimum_size.x = 600
	search.clear_button_enabled = true
	dialog.body().add_child(search)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 400)
	var grid := GridContainer.new()
	grid.name = "ForgeOpenGrid"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	dialog.body().add_child(scroll)
	# The game's own examples first, to start from.
	for row in CommunityCards.examples():
		var example := row
		var data := CommunityCard.build(row["spec"])
		data.set_code = CommunityCard.SET_CODE
		data.artist = String(row["spec"].get("artist", ""))
		var tile := _open_tile(data, CommunityCards.cropped(CommunityCards.texture_from(
			row["files"]["art"]["bytes"], String(row["files"]["art"]["kind"])), row["spec"])
			if (row["files"] as Dictionary).has("art") else null)
		tile.name = "ForgeOpenExample_" + CommunityCards.file_name(data.card_name)
		tile.tooltip_text = "%s\nAn example card: open it to start from it; Save puts it in your Community cards." \
			% data.card_name
		tile.pressed.connect(func() -> void:
			open_example(example)
			_close_dialog())
		tile.set_meta("haystack", " example" + _haystack(data, row["spec"]))
		grid.add_child(tile)
	for row in CommunityCards.playable():
		var card_name := String(row["name"])
		if not CardRegistry.has_card(card_name):
			continue
		var data := CardRegistry.get_card(card_name)
		var tile := Button.new()
		tile.name = "ForgeOpen_" + CommunityCards.file_name(card_name)
		tile.custom_minimum_size = MiniCard.SIZE
		tile.tooltip_text = "%s%s" % [card_name, CommunityCards.tooltip_extra(data)]
		var mini := MiniCard.new(CardInstance.new(data, -1, 0))
		mini.art_override = CommunityCards.art_texture(card_name)
		mini.size = MiniCard.SIZE
		mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mini.focus_mode = Control.FOCUS_NONE
		tile.add_child(mini)
		mini.refresh()
		tile.pressed.connect(func() -> void:
			open_card(card_name)
			_close_dialog())
		tile.set_meta("haystack", _haystack(data, CommunityCards.spec_of(card_name)))
		grid.add_child(tile)
	if grid.get_child_count() == 0:
		dialog.body().add_child(UiChrome.body_label("No community card found yet.", 14))
	search.text_changed.connect(func(query: String) -> void: filter_open_list(grid, query))
	GauntletOptions.fit(dialog.add_button("Cancel")).pressed.connect(_close_dialog)
	_dialog = dialog
	add_child(dialog)
	var rows := ceili(grid.get_child_count() / 4.0)
	_fit_dialog(dialog, scroll, clampf(rows * (MiniCard.SIZE.y + 10), MiniCard.SIZE.y, 400))


## What the Open list's search reads of a card: its name, set, types,
## colors, subtypes and rules, in lower case.
static func _haystack(data: CardData, card_spec: Dictionary) -> String:
	var words: Array[String] = [data.card_name, String(card_spec.get("set_name", ""))]
	for key in ["types", "subtypes", "keywords", "supertypes"]:
		for w in CommunityCard._list(card_spec.get(key)):
			words.append(w)
	for color in ["white", "blue", "black", "red", "green"]:
		if data.color_mask() & int(CommunityCard.COLORS[color]):
			words.append(color)
	if data.color_mask() == 0:
		words.append("colorless")
	# The rules text after a bar: its words are matched whole ("bat" is
	# no "battlefield"), the name's, set's and types' by their beginning.
	return " " + " ".join(_words(" ".join(words))) + " | " + " ".join(_words(data.oracle_text)) + " "


## The words of [param text], lower case, letters and digits only.
static func _words(text: String) -> PackedStringArray:
	var plain := ""
	for ch in text.to_lower():
		plain += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else " "
	return plain.split(" ", false)


## Show only the tiles whose card has a word beginning with each word of
## [param query] ("red" finds red cards, not "countered").
static func filter_open_list(grid: Container, query: String) -> void:
	var words := _words(query)
	for tile in grid.get_children():
		var haystack := String((tile as Control).get_meta("haystack", ""))
		var head := haystack.get_slice("|", 0)
		var rules := haystack.get_slice("|", 1)
		(tile as Control).visible = Array(words).all(func(w: String) -> bool:
			return head.contains(" " + w) or rules.contains(" " + w + " "))


## A window as tall as its scrolled content ([param height]) and its
## title and buttons; centred.
static func _fit_dialog(dialog: OriginalDialog, scroll: ScrollContainer, height: float) -> void:
	scroll.custom_minimum_size.y = height
	dialog.size.y = height + 130
	dialog.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	dialog.fit_height()


## A small card as an Open list tile.
func _open_tile(data: CardData, picture: Texture2D) -> Button:
	var tile := Button.new()
	tile.custom_minimum_size = MiniCard.SIZE
	var mini := MiniCard.new(CardInstance.new(data, -1, 0))
	mini.art_override = picture
	mini.size = MiniCard.SIZE
	mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini.focus_mode = Control.FOCUS_NONE
	tile.add_child(mini)
	mini.refresh()
	return tile


## Start from an example card (`{spec, files}` of [method
## CommunityCards.examples]); it is the player's once saved.
func open_example(row: Dictionary) -> void:
	CommunityCards.clear_draft()
	var files: Dictionary = row["files"]
	load_spec(row["spec"], files.get("art", {}), files.get("icon", {}))
	_saved_name = ""
	_say("The example %s — change it, then Save to play it." % String(row["spec"]["name"]))


func open_card(card_name: String) -> void:
	# The saved card, not the one being made under the same name.
	CommunityCards.clear_draft()
	var found := CommunityCards.spec_of(card_name)
	var files := CommunityCards.files_of(card_name)
	load_spec(found, files.get("art", {}), files.get("icon", {}))
	_saved_name = card_name
	_say("Opened %s." % card_name)


## Delete the card saved in the own folder (asked first).
func ask_delete() -> void:
	var card_name := String(spec.get("name", "")).strip_edges()
	if CommunityCards.own_path_of(card_name) == "":
		return
	_close_dialog()
	var dialog := OriginalDialog.create("Delete a card", Vector2(460, 180))
	dialog.name = "ForgeDeleteWindow"
	var words := UiChrome.body_label("Delete %s from the community_cards folder? Decks that hold it will show it as a proxy." % card_name, 14)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size.x = 420
	dialog.body().add_child(words)
	GauntletOptions.fit(dialog.add_button("Delete")).pressed.connect(func() -> void:
		var refusal := CardPacks.change_refusal()
		if refusal != "":
			_close_dialog()
			_say(refusal.replace("changing or rescanning card packs", "deleting a card"))
			return
		CommunityCards.delete_own(card_name)
		CommunityCards.refresh()
		_close_dialog()
		_say("%s was deleted." % card_name)
		refresh())
	GauntletOptions.fit(dialog.add_button("Cancel")).pressed.connect(_close_dialog)
	_dialog = dialog
	add_child(dialog)


func _close_dialog() -> void:
	var was_list := is_instance_valid(_dialog) and _dialog.name == "ForgeOpenWindow"
	if is_instance_valid(_dialog):
		if _dialog is OriginalDialog:
			(_dialog as OriginalDialog).dismiss()
		else:
			_dialog.queue_free()
	_dialog = null
	if was_list:
		refresh()


func close() -> void:
	CommunityCards.clear_draft()
	if is_instance_valid(_previous):
		_previous.visible = true
	left.emit()
	if is_instance_valid(_layer):
		_layer.queue_free()
	else:
		queue_free()


## UNDO AND REDO before any field sees them (Ctrl+Z, Ctrl+Y; Cmd on a
## Mac): a field's own undo would bring back text of a card opened
## earlier, the screen's knows the whole card.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or is_instance_valid(_dialog) or not event is InputEventKey:
		return
	if event.is_action_pressed("ui_redo", false, true):
		get_viewport().set_input_as_handled()
		redo()
	elif event.is_action_pressed("ui_undo", false, true):
		get_viewport().set_input_as_handled()
		undo()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if is_instance_valid(_dialog):
			_close_dialog()
		else:
			close()
