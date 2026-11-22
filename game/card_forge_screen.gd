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
# The owner, 2026-11-22: "Card editor look tab should be right besides card tab!"
const TABS := ["Card", "Look", "Cost & type", "Rules"]
const KIND_WORDS := {"spell": "Spell effect", "modal": "Choose one", "activated": "Activated ability",
	"trigger": "Triggered ability", "mana": "Mana ability", "static": "Static ability",
	"enchant": "Aura"}

## The card being made, and its pictures (`{bytes, kind}`; {} for none).
var spec: Dictionary = {}
var art := {}
var icon := {}
var _art_texture: Texture2D = null
## The set icons given, tier → texture ([constant CommunityCards.ICON_TIERS]).
var _icon_textures: Dictionary = {}

var _preview: CardPreview
var _mini_holder: Control
var _problems: Label
## What the card may want looked at, though it saves ([method
## CommunityCard.warnings]): under the problems, in amber.
var _warnings: Label
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
## The card as last saved, opened or begun ({spec, art, icon}): Done and
## Escape ask first when the card differs from it.
var _clean: Dictionary = {}
## The shade under a prompt (nothing beneath it takes a click while the
## prompt is up) and the control of the prompt that holds the keyboard.
var _shade: Control = null
var _default: Control = null
## The saved name a Save is to rename away (the player chose Rename).
var _rename_from := ""
## TYPING IS ONE UNDO STEP: changes to the same text (or the same slider)
## within [member _merge_ms] of each other are kept as one.
const TEXT_KEYS := ["name", "set_name", "artist", "author", "cost", "flavor", "subtype", "named", "shared"]
var _merge_ms := 1000
var _last_path := ""
var _last_change_ms := 0
## Each footer button's own tooltip (a disabled one says why instead).
var _tips := {}
var _cost_buttons: Array[Button] = []
## Why [method load_spec] last refused a card ("" when it took it).
var _refusal := ""
## The folder the file box was last used in, and the Open list's order.
## THE TEST DUEL under way ([method test_duel]): what holds it, the duel,
## and the pool's own card of the draft's name (null: it had none) to put
## back when it ends.
var _test_host: Control = null
var _test_duel: Control = null
var _test_name := ""
var _test_had: CardData = null
static var _last_folder := ""
static var _open_sort := "name"
const OPEN_SORTS := [["name", "By name"], ["set", "By set"], ["color", "By color"], ["newest", "Newest first"]]
## The effect picker's groups; an effect in none of them is listed last.
const EFFECT_GROUPS := [
	["Damage and life", ["damage", "gain_life", "lose_life", "drain", "prevent", "fog", "shield"]],
	["Cards", ["draw", "draw_later", "discard", "discard_own", "discard_random", "mill", "search",
		"search_basic", "shuffle_in", "raise"]],
	["Creatures", ["pump", "mass_pump", "counters", "minus_counters", "token", "set_pt", "switch_pt",
		"landwalk", "lose_keyword", "regenerate", "animate"]],
	["Removal and control", ["destroy", "destroy_all", "exile", "bounce", "sacrifice", "sacrifice_self",
		"exile_self", "return_self", "steal", "borrow", "tap", "untap", "counter", "counter_ability"]],
	["Mana and turns", ["add_mana", "extra_mana", "extra_turn"]]]


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
	# Crisp lettering: see [method _crisp].
	get_tree().node_added.connect(_crisp)
	_ground()
	_build_previews()
	_build_tabs()
	_build_footer()
	new_card()
	# A zip or a picture dropped on the window; a prompt keeps the keyboard.
	get_tree().root.files_dropped.connect(drop_files)
	get_viewport().gui_focus_changed.connect(_keep_focus_in_prompt)


## PLAIN LETTERS (the owner, 2026-11-22: "The text ... is blurry - doubled?
## Fix! Do not use this method of double text in the future"). The menus'
## labels come with a pale seat two pixels off ([method UiChrome.shadowed]),
## made for dark ink on sandstone; on this screen's dark ground and its
## windows it drew every letter twice. Each label that enters this screen
## loses the seat and any other offset copy, and dark ink turns pale; a
## color set afterwards stands. The cards themselves (the large card, the
## small ones, the reader) letter as cards do and are left alone.
const PLAIN_INK := Color(0.93, 0.90, 0.82)


func _crisp(node: Node) -> void:
	if not node is Label or not is_ancestor_of(node):
		return
	var above := node.get_parent()
	while above != null and above != self:
		if above is CardPreview or above is MiniCard:
			return
		above = above.get_parent()
	var label := node as Label
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	label.add_theme_constant_override("shadow_outline_size", 0)
	if label.has_theme_color_override("font_color") \
			and label.get_theme_color("font_color").is_equal_approx(UiChrome.INK):
		label.add_theme_color_override("font_color", PLAIN_INK)


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_crisp):
		get_tree().node_added.disconnect(_crisp)
	_restore_pool()
	if is_instance_valid(_test_host):
		_test_host.queue_free()
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
	reader.position = Vector2(MARGIN + MiniCard.SIZE.x + 12, below)
	reader.pressed.connect(open_reader)
	add_child(reader)
	for row in [["Undo", "ForgeUndo", undo, 0.0], ["Redo", "ForgeRedo", redo, 78.0]]:
		var step := UiChrome.menu_button(String(row[0]), Vector2(72, 30), 14)
		step.name = String(row[1])
		step.tooltip_text = "%s the last change (Ctrl+%s)." % [row[0], "Z" if row[0] == "Undo" else "Y"]
		step.position = Vector2(MARGIN + MiniCard.SIZE.x + 12 + float(row[3]), below + 40)
		step.pressed.connect(row[2])
		step.add_theme_color_override("font_disabled_color", Color8(150, 140, 125))
		add_child(step)
		_buttons[String(row[1])] = step
	# THE TEST DUEL's button, under them (the footer is full).
	var test := UiChrome.menu_button("Test duel", Vector2(150, 26), 14)
	test.name = "ForgeTest"
	# Three rows in the small card's height, with room for the taller buttons
	# the game draws without the 1997 skin (they stood 3 px into the reasons).
	test.position = Vector2(MARGIN + MiniCard.SIZE.x + 12, below + 74)
	test.pressed.connect(test_duel)
	test.add_theme_color_override("font_disabled_color", Color8(150, 140, 125))
	test.tooltip_text = "Play the card as it stands against the computer: it is in your hand, with the lands to cast it. Nothing is saved."
	add_child(test)
	_buttons["ForgeTest"] = test
	_tips["ForgeTest"] = test.tooltip_text
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
	# A DARK seat on this dark ground (owner 2026-11-18: "unreadable
	# superimposed red/white"): the menus' pale seat, two pixels off, drew
	# every red letter twice.
	_problems.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_problems.add_theme_constant_override("shadow_offset_x", 1)
	_problems.add_theme_constant_override("shadow_offset_y", 1)
	var said := VBoxContainer.new()
	said.name = "ForgeProblemsBox"
	said.add_theme_constant_override("separation", 6)
	reasons.add_child(said)
	said.add_child(_problems)
	_warnings = UiChrome.body_label("", 13)
	_warnings.name = "ForgeWarnings"
	_warnings.custom_minimum_size.x = CardPreview.SIZE.x - 12
	_warnings.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warnings.add_theme_color_override("font_color", Color8(240, 200, 110))
	_warnings.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_warnings.add_theme_constant_override("shadow_offset_x", 1)
	_warnings.add_theme_constant_override("shadow_offset_y", 1)
	said.add_child(_warnings)


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
	_build_card_page(_page(TABS.find("Card")))
	_build_look_page(_page(TABS.find("Look")))
	_build_cost_page(_page(TABS.find("Cost & type")))
	_build_rules_page(_page(TABS.find("Rules")))


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
	# The line is short: what is cut off (a path) is read in its tooltip.
	_status.mouse_filter = Control.MOUSE_FILTER_PASS
	bar.add_child(_status)
	for row in [["New", "ForgeNew", ask_new], ["Open...", "ForgeOpen", open_list],
			["Import...", "ForgeImport", import_card], ["Validate", "ForgeValidate", validate_card],
			["Save", "ForgeSave", press_save], ["Save as...", "ForgeSaveAs", ask_save_as],
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
	for key in _buttons:
		_tips[key] = (_buttons[key] as Button).tooltip_text


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
	# THE SET ICON (owner 2026-11-18): one picture drawn white with a black
	# outline is colored for each rarity ([method CommunityCards.rarity_icons]);
	# one in color is every rarity's as it is.
	var one_row := _row(box, "Set icon")
	var choose_one := UiChrome.menu_button("Choose set icon...", Vector2(180, 32), 14)
	choose_one.name = "ForgeChooseIcon"
	choose_one.tooltip_text = "Draw it white with a black outline: it is colored for each rarity."
	choose_one.pressed.connect(func() -> void: _pick_file("icon"))
	one_row.add_child(choose_one)
	_label(one_row, "", 13).name = "ForgeIconLabel"
	# FOUR SET ICONS, by the game's set symbol tiers: one alone is every
	# rarity's; a rarity without its own wears the first one given, shown
	# faded in its slot; each can take a picture of its own.
	var icon_row := _row(box, "By rarity")
	for tier in CommunityCards.ICON_TIERS:
		var slot := HBoxContainer.new()
		slot.add_theme_constant_override("separation", 4)
		var shown := TextureRect.new()
		shown.name = "ForgeIconShown_" + tier
		shown.custom_minimum_size = Vector2(32, 32)
		shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.add_child(shown)
		var choose := UiChrome.menu_button(tier.capitalize() + "...", Vector2(100, 32), 14)
		choose.name = "ForgeChooseIcon_" + tier
		choose.tooltip_text = "The set icon of a %s card." % tier \
			if tier != "legendary" else "The set icon of a mythic or a legendary card."
		choose.pressed.connect(func() -> void: _pick_file("icon_" + tier))
		slot.add_child(choose)
		var clear := UiChrome.menu_button("x", Vector2(28, 32), 13)
		clear.name = "ForgeClearIcon_" + tier
		clear.tooltip_text = "No own %s icon" % tier
		clear.pressed.connect(func() -> void: clear_icon(tier))
		slot.add_child(clear)
		icon_row.add_child(slot)
	_guide(box, CommunityCards.ICON_WORDS + " Draw it white with a black outline and it is colored " \
		+ "for each rarity (white, silver, gold, purple); a picture in color is used as it is for every " \
		+ "rarity. Each rarity can also take a picture of its own.")
	_options(_row(box, "Rarity"), "rarity", CommunityCard.RARITIES)
	_line(_row(box, "Illustration (Illus.)"), "artist", 360, CommunityCard.LIMITS["artist"]) \
		.placeholder_text = "the name printed after Illus."
	# Who made the card, and which version of it this is: both optional,
	# neither is in the card's file when left empty.
	var author_row := _row(box, "Author")
	_line(author_row, "author", 360, 60).placeholder_text = "optional: who made the card"
	_label(author_row, "Version", 14)
	var version := _spin(author_row, "card_version", 0, 9999)
	version.tooltip_text = "Optional: raise it when you change the card. 0 is none."
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
		add.add_theme_color_override("font_disabled_color", Color8(150, 140, 125))
		cost_row.add_child(add)
		_cost_buttons.append(add)
	var clear := UiChrome.menu_button("Clear", Vector2(70, 30), 14)
	clear.name = "ForgeClearCost"
	clear.add_theme_color_override("font_disabled_color", Color8(150, 140, 125))
	_cost_buttons.append(clear)
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
	_begin_card()
	_say("A new card. Choose its set icon and its art on the Card page.")


## New, asking first when the card on screen has unsaved changes.
func ask_new() -> void:
	_guarded("Start a new card anyway?", new_card)


## ANOTHER CARD IS ON SCREEN (new, opened, an example, imported): it is
## clean, and Undo never steps back into the card that was here before.
func _begin_card() -> void:
	_history.clear()
	_future.clear()
	_last_path = ""
	_rename_from = ""
	_mark_clean()
	(_buttons["ForgeUndo"] as Button).disabled = true
	(_buttons["ForgeRedo"] as Button).disabled = true


## Put [param card] and its pictures in the screen: false when the card is
## refused (why is said, and kept in [member _refusal]) — the screen is
## then as it was.
func load_spec(card: Dictionary, p_art: Dictionary, p_icon: Dictionary) -> bool:
	# A card of the wrong shape is never put in the widgets (a zip is
	# untrusted; the Open list shows only whole cards, this is the guard).
	var shape := CommunityCard._shape_problems(card)
	if not shape.is_empty():
		_refusal = "This card cannot be opened: %s" % shape[0]
		_say(_refusal)
		return false
	_refusal = ""
	var old := spec
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
	# WHAT DID NOT CHANGE IS KEPT (an undo of a typed letter): the ability
	# panels and the card rules are built again only when theirs changed —
	# the panels write into the very arrays they were built over, so the
	# old ones stay in the card — and a picture is decoded again only when
	# it is another picture.
	var same_abilities: bool = not _rules_box.get_children().is_empty() and old.get("abilities") is Array \
		and old["abilities"] == spec["abilities"]
	var same_rules: bool = not _rules_box.get_children().is_empty() and old.get("rules") is Dictionary \
		and old["rules"] == spec["rules"]
	if same_abilities:
		spec["abilities"] = old["abilities"]
	if same_rules:
		spec["rules"] = old["rules"]
	if p_art != art or (_art_texture == null and not p_art.is_empty()):
		_art_texture = CommunityCards.texture_from(p_art["bytes"], String(p_art["kind"])) if not p_art.is_empty() else null
	var given := CommunityCards.icon_tiers(p_icon)
	if given != icon or (_icon_textures.size() != given.size()):
		_icon_textures = {}
		for tier in given:
			_icon_textures[tier] = CommunityCards.texture_from(given[tier]["bytes"], String(given[tier]["kind"]))
	art = p_art.duplicate()
	icon = given
	_fill()
	if not same_rules:
		_rebuild_rules()
	if not same_abilities:
		_rebuild_abilities()
	refresh()
	return true


func _fill() -> void:
	_filling = true
	for key in ["name", "set_name", "artist", "cost"]:
		(_fields[key] as LineEdit).text = String(spec.get(key, ""))
	(_fields["subtypes"] as LineEdit).text = " ".join(spec.get("subtypes", []))
	(_fields["author"] as LineEdit).text = String(spec.get("author", "")) if spec.get("author") is String else ""
	var version: Variant = spec.get("card_version", 0)
	(_fields["card_version"] as SpinBox).value = int(version) if (version is int or version is float) else 0
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
	(find_child("ForgeIconLabel", true, false) as Label).text = _icon_words()
	var first := ""
	for tier in CommunityCards.ICON_TIERS:
		if icon.has(tier):
			first = tier
			break
	for tier in CommunityCards.ICON_TIERS:
		var shown := find_child("ForgeIconShown_" + tier, true, false) as TextureRect
		shown.texture = _icon_textures.get(tier, _icon_textures.get(first))
		shown.modulate.a = 1.0 if icon.has(tier) else 0.35
		var clear := find_child("ForgeClearIcon_" + tier, true, false) as Button
		clear.disabled = not icon.has(tier)
		clear.modulate.a = 1.0 if icon.has(tier) else 0.0   # keeps its place, shows nothing
	_filling = false


## What the set icons are: none yet, one for every rarity, or which
## rarities have their own.
func _icon_words() -> String:
	if icon.is_empty():
		return "No set icon yet."
	if icon.size() == 1:
		return "One set icon for every rarity: %s" % _picture_words(icon.values()[0], "")
	var own: Array[String] = []
	var first := ""
	for tier in CommunityCards.ICON_TIERS:
		if icon.has(tier):
			own.append(tier)
			if first == "":
				first = tier
	var rest := CommunityCards.ICON_TIERS.size() - own.size()
	return "Own icons: %s.%s" % [", ".join(own),
		(" The other rarities use the %s one." % first) if rest > 0 else ""]


## Take back the [param tier] set icon: the rarity wears the first one
## given again.
func clear_icon(tier: String) -> void:
	if not icon.has(tier):
		return
	# A copy: the undo steps and the saved state hold the old one.
	icon = icon.duplicate()
	icon.erase(tier)
	_icon_textures = _icon_textures.duplicate()
	_icon_textures.erase(tier)
	_fill()
	refresh()


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
	# The maker's own keys are in the card only when they say something.
	var author := (_fields["author"] as LineEdit).text.strip_edges()
	if author != "":
		spec["author"] = author
	else:
		spec.erase("author")
	var version := int((_fields["card_version"] as SpinBox).value)
	if version > 0:
		spec["card_version"] = version
	else:
		spec.erase("card_version")
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
	var typed := String(spec.get("name", "")).strip_edges()
	var game_card := CardRegistry.game_name_like(typed) if typed != "" else ""
	_problems.text = "\n".join(found)
	_problems.visible = not found.is_empty()
	# Asked only of a whole card (it has none otherwise).
	var notes: Array[String] = []
	if own.is_empty():
		notes.assign(CommunityCard.warnings(spec))
	_warnings.text = "\n".join(notes)
	_warnings.visible = not notes.is_empty()
	(_buttons["ForgeSave"] as Button).disabled = not found.is_empty()
	(_buttons["ForgeSaveAs"] as Button).disabled = not found.is_empty()
	(_buttons["ForgeExport"] as Button).disabled = not found.is_empty()
	(_buttons["ForgeUndo"] as Button).disabled = _history.is_empty()
	(_buttons["ForgeRedo"] as Button).disabled = _future.is_empty()
	(_buttons["ForgeDelete"] as Button).disabled = CommunityCards.own_path_of(
		String(spec.get("name", "")).strip_edges()) == ""
	# A disabled button says why (the red list is far to the left).
	for key in ["ForgeSave", "ForgeSaveAs", "ForgeExport"]:
		(_buttons[key] as Button).tooltip_text = found[0] if not found.is_empty() else String(_tips.get(key, ""))
	(_buttons["ForgeValidate"] as Button).disabled = not own.is_empty()
	(_buttons["ForgeValidate"] as Button).tooltip_text = own[0] if not own.is_empty() \
		else String(_tips.get("ForgeValidate", ""))
	# The test duel plays any whole card but one named like a game card.
	var no_test := own[0] if not own.is_empty() else (("A card named %s is already in the game." % game_card)
		if game_card != "" else "")
	(_buttons["ForgeTest"] as Button).disabled = no_test != ""
	(_buttons["ForgeTest"] as Button).tooltip_text = no_test if no_test != "" else String(_tips.get("ForgeTest", ""))
	(_buttons["ForgeDelete"] as Button).tooltip_text = "No saved card of this name in your community_cards folder." \
		if (_buttons["ForgeDelete"] as Button).disabled else ""
	_gray()
	if not own.is_empty():
		return
	var data := card_data()
	CommunityCards.set_draft(spec, _art_texture, _icon_textures)
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


## WHAT THE CARD'S TYPES LEAVE NO USE FOR IS GRAY: a land's cost (it has
## none; the text stays, for when Land is unticked), power and toughness
## and the creature keywords of what is no creature. A box still ticked
## stays live, to untick it.
func _gray() -> void:
	var types: Array = spec["types"] if spec.get("types") is Array else []
	var land := types.has("land")
	var creature := types.has("creature")
	var cost := _fields["cost"] as LineEdit
	cost.editable = not land
	cost.modulate.a = 0.45 if land else 1.0
	for button in _cost_buttons:
		button.disabled = land
	for key in ["power", "toughness"]:
		var spin := _fields[key] as SpinBox
		spin.editable = creature
		spin.modulate.a = 1.0 if creature else 0.45
	for key in ["keywords", "protection", "landwalk"]:
		var checks: Dictionary = _fields[key]
		for item in checks:
			var check := checks[item] as CheckBox
			check.disabled = not creature and not check.button_pressed


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
			"count":
				# WHAT IT COUNTS, a choice (never a bare tick).
				var counted := OptionButton.new()
				counted.name = "ForgeRuleCount_" + String(id)
				# As wide as a short one: the longest would widen the page.
				counted.fit_to_longest_item = false
				counted.custom_minimum_size.x = 230
				counted.clip_text = true
				var labels: Dictionary = CommunityCard.count_labels()
				for count_id in CommunityCard.counts():
					counted.add_item(String(labels.get(count_id, count_id)).trim_prefix("for each "))
					counted.set_item_metadata(counted.item_count - 1, count_id)
				if rules.get(id) is String:
					_select(counted, String(rules[id]))
				counted.item_selected.connect(func(_i: int) -> void:
					if rules.has(id):
						rules[id] = _picked(counted)
						refresh())
				value = counted
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
					"count": rules[id] = _picked(value as OptionButton)
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
			# An Aura may give the ability to its creature.
			if _is_creature_aura():
				head.add_child(_flag(a, "enchanted", "Enchanted creature's"))
		"trigger":
			head.add_child(_catalog_pick(a, "when", CommunityCard.TRIGGERS, func(t: String) -> String:
				return t.replace("CARDNAME", "it")))
			# Must it, may it, or up to one target ("Always" is not written).
			var choices: Dictionary = CommunityCard.TRIGGER_CHOICES
			var choice_words := {}
			for choice in choices:
				choice_words[choice] = String(choices[choice]["label"])
			var choice_pick := _opt_pick(a, "choice", choices.keys(), choice_words, String(choices.keys()[0]))
			choice_pick.name = "ForgeChoice"
			head.add_child(choice_pick)
			# An Aura may watch its creature instead of itself.
			if _is_creature_aura() and (CommunityCard.HOST_TRIGGERS as Array).has(String(a.get("when", ""))):
				head.add_child(_flag(a, "enchanted", "Enchanted creature's"))
		"mana":
			head.add_child(_color_pick(a, "color", CommunityCard.MANA_CHOICES, {"any": "Any color"}))
			head.add_child(_small_spin(a, "amount", 1, 3, 1))
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
			var what := String(a.get("what", "anthem"))
			if info.get("spell_type", false):
				head.add_child(_color_pick(a, "spell_type",
					CommunityCard.COST_SPELL_TYPES if what == "cost_more" else CommunityCard.SPELL_TYPES,
					{"any": "Every spell"}))
			if info.get("spell_color", false):
				var colors: Array = [""]
				colors.append_array(CommunityCard.PROTECTIONS)
				var color_pick := _opt_pick(a, "spell_color", colors, {"": "of any color"}, "")
				color_pick.name = "ForgeSpellColor"
				head.add_child(color_pick)
			if info.get("who", false):
				var who_pick := _opt_pick(a, "who", CommunityCard.COST_WHO, CommunityCard.COST_WHO_WORDS,
					String(CommunityCard.COST_WHO[0]))
				who_pick.name = "ForgeWho"
				head.add_child(who_pick)
			if info.has("amount"):
				head.add_child(UiChrome.body_label(String({"cost_less": "less by", "cost_more": "more by"}.get(what, "pays")), 13))
				var toll := _small_spin(a, "amount", int(info["amount"][0]), int(info["amount"][1]), 1)
				toll.name = "ForgeStaticAmount"
				head.add_child(toll)
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
	_add_movers(head, spec["abilities"], index, "ability")
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
	pick.item_selected.connect(func(_i: int) -> void:
		holder[key] = _picked(pick)
		# The static's kind changes what its panel holds (and what of it
		# the new kind has no use for goes); the trigger's event whether
		# an Aura may watch its creature for it.
		if key == "what":
			_static_fit(holder)
			_rebuild_abilities()
		elif key == "when":
			if not (CommunityCard.HOST_TRIGGERS as Array).has(String(holder[key])):
				holder.erase("enchanted")
			_rebuild_abilities()
		refresh())
	return pick


## A static ability whose kind was just chosen: the keys only another kind
## reads go, and the spell type is one this kind offers.
static func _static_fit(a: Dictionary) -> void:
	var what := String(a.get("what", ""))
	var info: Dictionary = CommunityCard.static_info(what)
	for key in ["who", "spell_color"]:
		if not info.get(key, false):
			a.erase(key)
	if info.get("spell_type", false):
		var offered: Array = CommunityCard.COST_SPELL_TYPES if what == "cost_more" else CommunityCard.SPELL_TYPES
		if not offered.has(String(a.get("spell_type", ""))):
			a["spell_type"] = offered[0]
	else:
		a.erase("spell_type")
	if info.has("amount"):
		a["amount"] = clampi(int(a.get("amount", info["amount"][0])), int(info["amount"][0]), int(info["amount"][1]))
	else:
		a.erase("amount")


## Whether the card is an Aura on a creature (its abilities may then be
## the enchanted creature's).
func _is_creature_aura() -> bool:
	for a: Variant in spec.get("abilities", []):
		if a is Dictionary and String(a.get("kind", "")) == "enchant" \
				and String(a.get("enchant", "creature")) == "creature":
			return true
	return false


## A choice among [param values] writing [param key] — and taking the key
## out again at [param default], so a card that never used it never has
## it. [param rebuild]: the panels are built again after (what they hold
## depends on it).
func _opt_pick(holder: Dictionary, key: String, values: Array, words := {}, default := "",
		rebuild := false) -> OptionButton:
	var pick := OptionButton.new()
	for value in values:
		pick.add_item(String(words[value]) if words.has(value) else String(value))
		pick.set_item_metadata(pick.item_count - 1, value)
	_select(pick, String(holder.get(key, default)))
	pick.item_selected.connect(func(_i: int) -> void:
		var chosen := _picked(pick)
		if chosen == default:
			holder.erase(key)
		else:
			holder[key] = chosen
		if rebuild:
			_rebuild_abilities()
		refresh())
	return pick


func _effect_row(kind: String, effects: Array, e: Dictionary, index: int) -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_child(UiChrome.body_label("   •", 14))
	# THE EFFECT, chosen from a list with a search field ([method
	# ask_effect]): some forty effects were too many for a plain drop-down.
	var info: Dictionary = CommunityCard.EFFECTS.get(String(e.get("effect", "draw")), {})
	var pick := Button.new()
	pick.name = "ForgeEffectPick"
	pick.text = String(info.get("label", e.get("effect", "draw"))) + "  ..."
	pick.tooltip_text = "Choose another effect (with a search)."
	pick.pressed.connect(func() -> void: ask_effect(kind, e))
	row.add_child(pick)
	if info.has("targets"):
		var target := OptionButton.new()
		for t in info["targets"]:
			if t == "self" and kind == "spell":
				continue
			target.add_item(CommunityCard.target_words(String(t)))
			target.set_item_metadata(target.item_count - 1, t)
		_select(target, String(e.get("target", info["targets"][0])))
		target.item_selected.connect(func(_i: int) -> void:
			var was := String(e.get("target", ""))
			e["target"] = _picked(target)
			# The filter is for some targets only: it goes with them.
			var filtered: Array = CommunityCard.ONLY_TARGETS
			if info.get("only", false) and filtered.has(was) != filtered.has(e["target"]):
				e.erase("only")
				_rebuild_abilities()
			elif info.has("named") and (was == "a_named") != (e["target"] == "a_named"):
				_rebuild_abilities()   # the name field comes and goes
			refresh())
		row.add_child(target)
		if info.has("named") and String(e.get("target", "")) == "a_named":
			var named := LineEdit.new()
			named.name = "ForgeSearchName"
			named.placeholder_text = "card name"
			named.text = String(e.get("named", ""))
			named.custom_minimum_size.x = 170
			named.max_length = CommunityCard.LIMITS["name"]
			named.text_changed.connect(func(t: String) -> void:
				e["named"] = t.strip_edges()
				refresh())
			row.add_child(named)
	if info.get("only", false) and (CommunityCard.ONLY_TARGETS as Array).has(String(e.get("target", ""))):
		var only := _opt_pick(e, "only", CommunityCard.ONLY, {"": "any color or type"}, "")
		only.name = "ForgeOnly"
		only.tooltip_text = "Only these: \"destroy target white permanent\", \"all nonblack creatures\"."
		row.add_child(only)
	if info.has("amount"):
		row.add_child(_small_spin(e, "amount", int(info["amount"][0]), int(info["amount"][1]), 1))
	if info.get("per", false):
		var each: Array = [""]
		each.append_array(CommunityCard.counts())
		var each_words: Dictionary = CommunityCard.count_labels().duplicate()
		each_words[""] = "(not for each)"
		var per := _opt_pick(e, "per", each, each_words, "")
		per.name = "ForgePer"
		per.fit_to_longest_item = false
		per.custom_minimum_size.x = 260
		per.clip_text = true
		per.tooltip_text = "The amount once for each of these."
		row.add_child(per)
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
		row.add_child(_small_spin(e, "power", 0, 20, 2))
		row.add_child(UiChrome.body_label("T", 13))
		row.add_child(_small_spin(e, "toughness", 1, 20, 2))
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
	if info.has("from"):
		row.add_child(_color_pick(e, "from", CommunityCard.SHUFFLE_FROM, CommunityCard.SHUFFLE_FROM_WORDS))
	if info.has("where"):
		row.add_child(_color_pick(e, "where", CommunityCard.SEARCH_WHERE, CommunityCard.SEARCH_WHERE_WORDS))
	if info.has("token"):
		row.add_child(_small_spin(e, "power", 0, 20, 1))
		row.add_child(_small_spin(e, "toughness", 1, 20, 1))
		row.add_child(_color_pick(e, "color", ["colorless", "white", "blue", "black", "red", "green"]))
		row.add_child(_word_edit(e, "subtype", "creature type", "soldier"))
		row.add_child(_keyword_pick(e, true))
		var ends := _opt_pick(e, "ends", CommunityCard.TOKEN_ENDS, CommunityCard.TOKEN_ENDS_WORDS, "")
		ends.name = "ForgeEnds"
		row.add_child(ends)
	if info.has("color") and not info.has("token"):
		row.add_child(_color_pick(e, "color", ["white", "blue", "black", "red", "green", "colorless"]))
	_add_movers(row, effects, index, "effect")
	var remove := UiChrome.menu_button("x", Vector2(32, 28), 13)
	remove.tooltip_text = "Remove this effect"
	remove.pressed.connect(func() -> void:
		effects.remove_at(index)
		_rebuild_abilities()
		refresh())
	row.add_child(remove)
	return row


## Up and Down for item [param index] of [param list] (abilities, or the
## effects of one): none for a list of one.
func _add_movers(row: Container, list: Array, index: int, what: String) -> void:
	if list.size() < 2:
		return
	for step in [-1, 1]:
		var up: bool = step < 0
		var move := UiChrome.menu_button("Up" if up else "Down", Vector2(40 if up else 56, 28), 13)
		move.name = "ForgeMoveUp" if up else "ForgeMoveDown"
		move.tooltip_text = "Move this %s %s" % [what, "up" if up else "down"]
		move.disabled = index + step < 0 or index + step >= list.size()
		move.add_theme_color_override("font_disabled_color", Color8(150, 140, 125))
		move.pressed.connect(func() -> void: move_item(list, index, step))
		row.add_child(move)


## Swap item [param index] of [param list] with its neighbour [param step]
## away (one undo step, as every change).
func move_item(list: Array, index: int, step: int) -> void:
	var to := index + step
	if index < 0 or to < 0 or index >= list.size() or to >= list.size():
		return
	var held: Variant = list[index]
	list[index] = list[to]
	list[to] = held
	_rebuild_abilities()
	refresh()


## THE EFFECT PICKER: the effects [param kind] may use, in groups, under a
## search field (letters anywhere in the effect's name; Enter takes the
## first one left), to be effect [param e].
func ask_effect(kind: String, e: Dictionary) -> void:
	var dialog := OriginalDialog.create("Choose an effect", Vector2(440, 520))
	dialog.name = "ForgeEffectWindow"
	var search := LineEdit.new()
	search.name = "ForgeEffectSearch"
	search.placeholder_text = "Search: damage, draw, destroy ..."
	search.custom_minimum_size.x = 400
	search.clear_button_enabled = true
	dialog.body().add_child(search)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.name = "ForgeEffectList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 0)
	scroll.add_child(list)
	dialog.body().add_child(scroll)
	var grouped := {}
	var groups: Array = EFFECT_GROUPS.duplicate()
	for group in groups:
		for id in group[1]:
			grouped[id] = true
	var rest: Array = CommunityCard.EFFECTS.keys().filter(func(id: Variant) -> bool: return not grouped.has(id))
	if not rest.is_empty():
		groups.append(["Other", rest])
	var current := String(e.get("effect", ""))
	for group in groups:
		var ids: Array = (group[1] as Array).filter(func(id: Variant) -> bool:
			return CommunityCard.EFFECTS.has(id) and CommunityCard.effect_allowed(String(id), kind))
		if ids.is_empty():
			continue
		var header := UiChrome.body_label(String(group[0]), 13)
		header.modulate.a = 0.7
		header.set_meta("group", String(group[0]))
		list.add_child(header)
		for id in ids:
			var label := String(CommunityCard.EFFECTS[id]["label"])
			var line := OriginalDialog.choice_line("   " + label + ("  (now)" if id == current else ""))
			line.name = "ForgeEffect_" + String(id)
			line.set_meta("group", String(group[0]))
			line.set_meta("haystack", (label + " " + String(id).replace("_", " ") + " " + String(group[0])).to_lower())
			line.pressed.connect(func() -> void: set_effect(kind, e, String(id)))
			list.add_child(line)
	search.text_changed.connect(func(query: String) -> void: filter_effects(list, query))
	search.text_submitted.connect(func(_t: String) -> void:
		for line in list.get_children():
			if line is Button and (line as Control).visible:
				(line as Button).pressed.emit()
				return)
	GauntletOptions.fit(dialog.add_button("Cancel")).pressed.connect(_close_dialog)
	_show(dialog, search)


## Show only the effects with every word of [param query] in their name
## (or their group's), and the headers of the groups that still show one.
static func filter_effects(list: Container, query: String) -> void:
	var words := query.to_lower().split(" ", false)
	var live := {}
	for line in list.get_children():
		if line is Button:
			var haystack := String(line.get_meta("haystack", ""))
			(line as Control).visible = Array(words).all(func(w: String) -> bool: return haystack.contains(w))
			if (line as Control).visible:
				live[line.get_meta("group")] = true
	for line in list.get_children():
		if not line is Button:
			(line as Control).visible = live.has(line.get_meta("group"))


## Make effect [param e] the effect [param id], with that effect's own
## first values.
func set_effect(kind: String, e: Dictionary, id: String) -> void:
	_close_dialog()
	if String(e.get("effect", "")) == id or not CommunityCard.EFFECTS.has(id) \
			or not CommunityCard.effect_allowed(id, kind):
		return
	var fresh := CommunityCard.effect_defaults(id, kind)
	e.clear()
	e.merge(fresh)
	_rebuild_abilities()
	refresh()


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


## A number field over [param key]: shows [param fallback] (the builder's
## own default) for a missing key and writes only when changed — opening a
## card never changes it.
func _small_spin(holder: Dictionary, key: String, low: int, high: int, fallback := 0) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.set_value_no_signal(clampi(int(holder.get(key, fallback)), low, high))
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

## Say [param text] on the status line — the card's name first, it is cut
## short there; [param tip] (a path, a list) is read in the tooltip.
func _say(text: String, tip := "") -> void:
	_status.text = text
	_status.tooltip_text = text if tip == "" else text + "\n" + tip


# ------------------------------------------------------------ prompts --

## Put [param dialog] up as THE prompt: a shade under it takes every click
## meant for the screen beneath, and [param focus] (its default button, or
## its field) has the keyboard, so Enter answers it.
func _show(dialog: Control, focus: Control = null) -> void:
	_close_dialog()
	_shade = ColorRect.new()
	_shade.name = "ForgeShade"
	(_shade as ColorRect).color = Color(0, 0, 0, 0.45)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_shade)
	_dialog = dialog
	add_child(dialog)
	_default = focus
	_refocus()


func _refocus() -> void:
	if not is_instance_valid(_dialog) or not is_inside_tree():
		return
	if is_instance_valid(_default) and _default.is_inside_tree():
		_default.grab_focus()
	else:
		get_viewport().gui_release_focus()


## The keyboard stays with the prompt: a field of the screen beneath never
## takes typing while one is up.
func _keep_focus_in_prompt(control: Control) -> void:
	if control == null or not is_instance_valid(_dialog) or control == _dialog \
			or _dialog.is_ancestor_of(control) or not is_ancestor_of(control):
		return
	_refocus.call_deferred()


## Ask before the card on screen is given up with unsaved changes: [param
## question] after its name, [param go] the button that goes on with
## [param then]. Stay is the default.
func _ask_unsaved(question: String, go: String, then: Callable) -> void:
	var dialog := OriginalDialog.create("Leave" if go == "Leave" else "Unsaved changes", Vector2(470, 190))
	dialog.name = "ForgeLeaveWindow"
	var words := UiChrome.body_label("%s has changes that are not saved. %s" \
		% [String(spec.get("name", "")).strip_edges(), question], 14)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size.x = 430
	dialog.body().add_child(words)
	var yes := GauntletOptions.fit(dialog.add_button(go))
	yes.name = "ForgeLeaveGo"
	yes.pressed.connect(func() -> void:
		_close_dialog()
		then.call())
	var stay := GauntletOptions.fit(dialog.add_button("Stay"))
	stay.pressed.connect(_close_dialog)
	_show(dialog, stay)


## [param then], asked about first when the card has unsaved changes.
func _guarded(question: String, then: Callable) -> void:
	if has_unsaved():
		_ask_unsaved(question, "Go on", then)
	else:
		then.call()


## The Save button: a saved card whose name was changed is renamed or kept
## beside the new one, as the player says; then [method save_card].
func press_save() -> void:
	_rename_from = ""
	if not problems().is_empty():
		return
	var card_name := String(spec["name"]).strip_edges()
	if _saved_name == "" or card_name.to_lower() == _saved_name.to_lower() \
			or CommunityCards.own_path_of(_saved_name) == "":
		save_card()
		return
	var old := _saved_name
	var dialog := OriginalDialog.create("Save", Vector2(480, 190))
	dialog.name = "ForgeRenameWindow"
	var words := UiChrome.body_label("Rename %s to %s, or keep both?" % [old, card_name], 14)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size.x = 440
	dialog.body().add_child(words)
	var rename := GauntletOptions.fit(dialog.add_button("Rename"))
	rename.name = "ForgeRenameYes"
	rename.pressed.connect(func() -> void:
		_close_dialog()
		_rename_from = old
		save_card())
	var both := GauntletOptions.fit(dialog.add_button("Keep both"))
	both.name = "ForgeRenameBoth"
	both.pressed.connect(func() -> void:
		_close_dialog()
		save_card())
	GauntletOptions.fit(dialog.add_button("Cancel")).pressed.connect(_close_dialog)
	_show(dialog, rename)


## Save into the community_cards folder; the card joins the set at once.
func save_card(replacing := "") -> void:
	if not problems().is_empty():
		return
	# A table open at LAN holds the card catalogue still (the packs' lock).
	var refusal := CardPacks.change_refusal()
	if refusal != "":
		_say(refusal.replace("changing or rescanning card packs", "saving a card"))
		return
	var card_name := String(spec["name"]).strip_edges()
	var other := CommunityCards.found_like(card_name)
	# Leave to go over another card is for the card the prompt named: a
	# name typed behind the prompt is asked about again.
	if other != "" and other.to_lower() != _saved_name.to_lower() and other.to_lower() != replacing.to_lower():
		_ask_overwrite(other, func() -> void: save_card(other))
		return
	var why := CommunityCards.save(spec, art, icon)
	if why != "":
		_say(why)
		return
	# Renamed (the player's choice): the copy under the old name goes, once
	# the new one is written.
	var gone := ""
	if _rename_from != "" and _rename_from.to_lower() != card_name.to_lower() \
			and CommunityCards.delete_own(_rename_from):
		gone = _rename_from
	_rename_from = ""
	_saved_name = card_name
	_mark_clean()
	CommunityCards.refresh()
	_say("%s saved%s — it is in the Community cards set now." % [card_name,
		(", %s renamed away" % gone) if gone != "" else ""],
		"Saved in %s." % GamePaths.shown(CommunityCards.own_folder()))
	refresh()


## Export the card — or its whole set — as one zip anywhere, to share.
func export_card() -> void:
	if not problems().is_empty():
		return
	var whole := set_cards()
	if whole.size() < 2:
		_export_box(false)
		return
	var dialog := OriginalDialog.create("Export", Vector2(480, 190))
	dialog.name = "ForgeExportWindow"
	var words := UiChrome.body_label("Export this card alone, or the whole set %s (%d cards) in one zip?" % [
		String(spec.get("set_name", "")).strip_edges(), whole.size()], 14)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size.x = 440
	dialog.body().add_child(words)
	var alone := GauntletOptions.fit(dialog.add_button("This card"))
	alone.pressed.connect(func() -> void:
		_close_dialog()
		_export_box(false))
	GauntletOptions.fit(dialog.add_button("The set")).pressed.connect(func() -> void:
		_close_dialog()
		_export_box(true))
	GauntletOptions.fit(dialog.add_button("Cancel")).pressed.connect(_close_dialog)
	_show(dialog, alone)


## The cards of this card's set (its set name): the saved ones, with this
## card as it stands now in place of its saved copy.
func set_cards() -> Array[Dictionary]:
	var set_name := String(spec.get("set_name", "")).strip_edges()
	var card_name := String(spec.get("name", "")).strip_edges()
	var out: Array[Dictionary] = []
	if set_name == "":
		return out
	for card in CommunityCards.cards_of_set(set_name):
		var saved := String((card["spec"] as Dictionary).get("name", "")).strip_edges().to_lower()
		# This card stands in for its saved copy, renamed or not.
		if saved != card_name.to_lower() and saved != _saved_name.to_lower():
			out.append(card)
	out.append({"spec": spec, "art": art, "icon": icon})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["spec"]["name"]) < String(b["spec"]["name"]))
	return out


## The platform's file box, opening in the folder it was last used in.
func _file_box(box_name: String, mode: FileDialog.FileMode, filters: Array) -> FileDialog:
	var box := FileDialog.new()
	box.name = box_name
	box.file_mode = mode
	box.access = FileDialog.ACCESS_FILESYSTEM
	box.use_native_dialog = true
	box.filters = PackedStringArray(filters)
	if _last_folder != "" and DirAccess.dir_exists_absolute(_last_folder):
		box.current_dir = _last_folder
	box.file_selected.connect(func(path: String) -> void: _last_folder = path.get_base_dir())
	return box


func _export_box(whole_set: bool) -> void:
	var box := _file_box("ForgeExportBox", FileDialog.FILE_MODE_SAVE_FILE, ["*.zip ; Card zip"])
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
	# A document's address (a phone's file box) is written as it is given.
	if not AdventureTransfer.is_uri(path) and not path.to_lower().ends_with(".zip"):
		path += ".zip"
	var cards := set_cards()
	var why := CommunityCards.write_set_zip(path, String(spec.get("set_name", "")), cards)
	if why != "":
		_say(why)
		return
	_say("%s: %d cards exported to %s — share it: it goes in a community_cards folder." \
		% [String(spec.get("set_name", "")).strip_edges(), cards.size(), AdventureTransfer.shown_name(path)], GamePaths.shown(path))


func export_to(path: String) -> void:
	if not AdventureTransfer.is_uri(path) and not path.to_lower().ends_with(".zip"):
		path += ".zip"
	var why := CommunityCards.write_zip(path, spec, art, icon)
	if why != "":
		_say(why)
		return
	_say("%s exported to %s — share it: it goes in a community_cards folder." \
		% [String(spec.get("name", "")).strip_edges(), AdventureTransfer.shown_name(path)], GamePaths.shown(path))


func _pick_file(which: String) -> void:
	var box := _file_box("ForgePictureBox", FileDialog.FILE_MODE_OPEN_FILE,
		["*.png, *.webp ; Set icon"] if which.begins_with("icon") else ["*.png, *.jpg, *.jpeg, *.webp ; Art"])
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
	# Too big is said before the file is read into memory.
	var is_icon := which.begins_with("icon")
	var limit := int((CommunityCards.ICON_GUIDE if is_icon else CommunityCards.ART_GUIDE)["bytes"])
	var opened := FileAccess.open(path, FileAccess.READ)
	if opened != null and opened.get_length() > limit:
		var big := "The %s is at most %s (this one is %s)." % ["set icon" if is_icon else "art",
			PortableMode.size_words(limit), PortableMode.size_words(opened.get_length())]
		_say(big)
		return big
	opened = null
	var bytes := FileAccess.get_file_as_bytes(path)
	var why := CommunityCards.icon_problem(bytes, kind) if is_icon \
		else CommunityCards.art_problem(bytes, kind)
	if why != "":
		_say(why)
		return why
	var colored := false
	if which == "icon":
		# THE ONE SET ICON: black and white is colored for each rarity, a
		# picture in color is every rarity's as it is.
		colored = CommunityCards.is_outline_picture(bytes, kind)
		icon = CommunityCards.rarity_icons(bytes, kind) if colored \
			else {CommunityCards.ICON_TIERS[0]: {"bytes": bytes, "kind": kind}}
		_icon_textures = {}
		for tier in icon:
			_icon_textures[tier] = CommunityCards.texture_from(icon[tier]["bytes"], String(icon[tier]["kind"]))
	elif is_icon:
		var tier := which.trim_prefix("icon_")
		if not CommunityCards.ICON_TIERS.has(tier):
			return "No such set icon: %s." % tier
		icon = icon.duplicate()
		icon[tier] = {"bytes": bytes, "kind": kind}
		_icon_textures = _icon_textures.duplicate()
		_icon_textures[tier] = CommunityCards.texture_from(bytes, kind)
	else:
		art = {"bytes": bytes, "kind": kind}
		_art_texture = CommunityCards.texture_from(bytes, kind)
	_fill()
	refresh()
	if which == "icon":
		_say("Set icon: %s — %s." % [path.get_file(), "colored for each rarity" if colored
			else "in color, used as it is for every rarity (draw it white with a black outline to color it by rarity)"])
	else:
		_say("%s: %s." % ["Set icon" if is_icon else "Art", path.get_file()])
	return ""


## FILES DROPPED ON THE WINDOW: a zip is imported (as Import does, asking
## first about unsaved changes); a picture is the art — or, small and
## square, the set icon. The first file that is one of these is taken.
func drop_files(files: PackedStringArray) -> void:
	if not is_visible_in_tree() or is_instance_valid(_dialog) or is_instance_valid(_test_host):
		return
	for path in files:
		var kind := path.get_extension().to_lower()
		if kind == "zip":
			import_asked(path)
			return
		if kind in ["png", "jpg", "jpeg", "webp"]:
			take_picture(drop_role(path), path)
			return
	if not files.is_empty():
		_say("Drop a card zip, or a picture for the art or the set icon.")


## What a dropped picture is for: "icon" for a small square PNG or WEBP
## (the set icon's guidelines), else "art".
static func drop_role(path: String) -> String:
	var kind := path.get_extension().to_lower()
	if not (CommunityCards.ICON_GUIDE["kinds"] as Array).has(kind):
		return "art"
	var opened := FileAccess.open(path, FileAccess.READ)
	if opened == null or opened.get_length() > int(CommunityCards.ICON_GUIDE["bytes"]):
		return "art"
	var size := CommunityCards.picture_size(opened.get_buffer(opened.get_length()), kind)
	return "icon" if size.x > 0 and size.x == size.y and size.x <= int(CommunityCards.ICON_GUIDE["max"]) else "art"


# ------------------------------------------------------- the test duel --

## The basic land of each color, and the plain creatures a test gives each
## side when the card wants something to aim at (the first the pool holds).
const TEST_LANDS := {"W": "Plains", "U": "Island", "B": "Swamp", "R": "Mountain", "G": "Forest"}
const TEST_CREATURES := ["Grizzly Bears", "Gray Ogre", "Scathe Zombies", "Pearled Unicorn", "Hurloon Minotaur"]
const TEST_SPARE_LANDS := 3
const TEST_MAX_LANDS := 12


## The lands a test puts on the battlefield for [param card]: one for each
## mana of its cost (a colored one its color's, the rest shared among its
## colors; {X} counts two), [constant TEST_SPARE_LANDS] more, at most
## [constant TEST_MAX_LANDS].
static func test_lands(card: Dictionary) -> Array[String]:
	var colored: Array[String] = []
	var generic := 0
	var symbols := RegEx.create_from_string("\\{([^}]+)\\}")
	for hit in symbols.search_all(String(card.get("cost", ""))):
		var symbol := hit.get_string(1).to_upper()
		if symbol.is_valid_int():
			generic += int(symbol)
		elif symbol == "X":
			generic += 2
		else:
			for letter in symbol:
				if TEST_LANDS.has(letter):
					colored.append(String(TEST_LANDS[letter]))
					break
	var kinds: Array[String] = []
	for land in colored:
		if not kinds.has(land):
			kinds.append(land)
	if kinds.is_empty():
		kinds.append("Forest")
	var out: Array[String] = colored.duplicate()
	for i in generic + TEST_SPARE_LANDS:
		out.append(kinds[i % kinds.size()])
	return out.slice(0, TEST_MAX_LANDS)


## Whether [param card] wants something to aim at: an Aura, or an effect
## with a target.
static func test_wants_creatures(card: Dictionary) -> bool:
	var abilities: Variant = card.get("abilities")
	if not abilities is Array:
		return false
	for a: Variant in abilities:
		if not a is Dictionary:
			continue
		if String(a.get("kind", "")) == "enchant":
			return true
		var lists: Array = [a.get("effects")]
		if a.get("modes") is Array:
			for mode: Variant in a["modes"]:
				if mode is Dictionary:
					lists.append(mode.get("effects"))
		for effects: Variant in lists:
			if not effects is Array:
				continue
			for e: Variant in effects:
				if e is Dictionary and e.has("target"):
					return true
	return false


## The test duel's config for the card as it stands: you against the
## computer, your turn's first main phase, the card in your hand (two of
## it unless it is legendary), its lands untapped on your side, a plain
## creature on each side when it wants one, your library basic lands. A
## test position ([method DuelConfig.for_test]): one free duel that records
## nothing.
func test_config() -> DuelConfig:
	var card_name := String(spec.get("name", "")).strip_edges()
	var base := DuelConfig.vs_ai_default(AiProfile.wizard())
	var lands := test_lands(spec)
	var library: Array = []
	for i in 30:
		library.append(lands[i % lands.size()])
	base.decks[0] = library
	base.player_names[0] = "You"
	base.deck_names[0] = card_name
	base.apply_deck_colors()
	var position := DuelPosition.new()
	position.active_player = 0
	position.step = Mtg.Step.MAIN1
	position.random_cards[1] = 7
	for i in (1 if (spec.get("supertypes", []) as Array).has("legendary") else 2):
		position.add(0, DuelPosition.HAND, card_name)
	for land in lands:
		position.add(0, DuelPosition.TABLE, land)
	if test_wants_creatures(spec):
		for plain in TEST_CREATURES:
			if CardRegistry.has_card(plain):
				position.add(0, DuelPosition.TABLE, plain)
				position.add(1, DuelPosition.TABLE, plain)
				break
	return base.for_test(position, randi() | 1, false)


## TEST THIS CARD: a duel against the computer with the card as it stands
## ([method test_config]) — nothing is saved for it. The pool answers for
## the card's name with the draft while the duel lasts and is put back as
## it was when it ends ([method _end_test]); the screen waits hidden under
## the duel, the card, its undo steps and its unsaved state untouched.
func test_duel() -> Control:
	if is_instance_valid(_test_host) or not CommunityCard.problems(spec).is_empty():
		return null
	# A table open at LAN holds the card catalogue still (the packs' lock).
	var refusal := CardPacks.change_refusal()
	if refusal != "":
		_say(refusal.replace("changing or rescanning card packs", "testing a card"))
		return null
	_close_dialog()
	var data := card_data()
	# The game's own card of that name is never stood in for.
	if CardRegistry.game_name_like(data.card_name) != "":
		_say("A card named %s is already in the game." % data.card_name)
		return null
	CardRegistry.ensure_loaded()
	_test_name = data.card_name
	# Only the name's answer changes: no file, no set list, no revision.
	_test_had = CardRegistry._cards.get(_test_name)
	CardRegistry._cards[_test_name] = data
	CommunityCards.set_draft(spec, _art_texture, _icon_textures)
	var config := test_config()
	var refused := config.position.refusal()
	if refused != "":
		_restore_pool()
		_say(refused)
		return null
	_test_host = Control.new()
	_test_host.name = "CardForgeTest"
	_test_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(_test_host)
	get_viewport().gui_release_focus()
	_layer.visible = false
	_hold_duel(DuelScreen.held(config, "Test duel", "", "End the test duel and go back to your card?"))
	return _test_duel


## Hold [param duel] (the test, or its `Restart test`): every way out of it
## leads back here.
func _hold_duel(duel: DuelScreen) -> void:
	_test_duel = duel
	duel.handed_over.connect(_on_test_handed)
	duel.menu_confirmed.connect(_end_test)
	if duel.get_parent() == null:
		_test_host.add_child(duel)


## The test duel gave way to [param next]: itself again (`Restart test`),
## which is held as it was; or its bench (`Edit test`, the end of the
## duel), which here is the way back to the card.
func _on_test_handed(next: Control) -> void:
	if next is DuelScreen:
		_hold_duel(next as DuelScreen)
		return
	next.queue_free()
	_end_test()


func _restore_pool() -> void:
	if _test_name == "":
		return
	if _test_had != null:
		CardRegistry._cards[_test_name] = _test_had
	else:
		CardRegistry._cards.erase(_test_name)
	_test_name = ""
	_test_had = null


## Back from the test duel: the pool as it was, the screen as it was left.
func _end_test() -> void:
	if not is_instance_valid(_test_host):
		return
	_restore_pool()
	_test_host.queue_free()
	_test_host = null
	_test_duel = null
	if is_instance_valid(_layer):
		_layer.visible = true
	var music := get_node_or_null(^"/root/ShellMusic")
	if music != null:
		music.call(&"play")
	_restoring = true   # the card shown again is no change
	refresh()
	_restoring = false
	_say("Back from the test duel. Nothing was saved.")


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
	# Typing on in the same field is the same step (a 200-letter flavor
	# text used up the whole history, a letter a step).
	var path := _changed_path(_now["spec"], snap["spec"]) \
		if snap["art"] == _now["art"] and snap["icon"] == _now["icon"] else ""
	var at := Time.get_ticks_msec()
	var merge := path != "" and path == _last_path and at - _last_change_ms <= _merge_ms \
		and not _history.is_empty()
	_last_path = path
	_last_change_ms = at
	if merge:
		_future.clear()
		_now = snap
		return
	_history.append(_now)
	if _history.size() > HISTORY:
		_history.pop_front()
	_future.clear()
	_now = snap


## Where [param a] and [param b] differ, when that is one text (a key of
## [constant TEXT_KEYS], a card rule's cost, the subtypes) or one of the
## art sliders: its path, else "" (anything else is a step of its own).
static func _changed_path(a: Variant, b: Variant, at := "") -> String:
	if a is Dictionary and b is Dictionary:
		if (a as Dictionary).size() != (b as Dictionary).size():
			return ""
		var found := ""
		for key in b:
			if not (a as Dictionary).has(key):
				return ""
			if a[key] != b[key]:
				if found != "":
					return ""
				found = _changed_path(a[key], b[key], at + "/" + str(key))
				if found == "":
					return ""
		return found
	if a is Array and b is Array:
		if at == "/subtypes":
			return at
		if (a as Array).size() != (b as Array).size():
			return ""
		var found := ""
		for i in (b as Array).size():
			if a[i] != b[i]:
				if found != "":
					return ""
				found = _changed_path(a[i], b[i], at + "/" + str(i))
				if found == "":
					return ""
		return found
	if a is String and b is String:
		return at if TEXT_KEYS.has(at.get_slice("/", at.get_slice_count("/") - 1)) or at.begins_with("/rules/") else ""
	if (a is float or a is int) and (b is float or b is int) and at.begins_with("/look/art/"):
		return at
	return ""


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
	_last_path = ""


# ------------------------------------------------------ import, save as --

## Take a shared card zip (or a set zip) into the community_cards folder.
func import_card() -> void:
	var dialog := OriginalDialog.create("Import", Vector2(470, 170))
	dialog.name = "ForgeImportChoice"
	var words := UiChrome.body_label("A shared card or set zip, or one of the game's own cards to start from?", 14)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size.x = 430
	dialog.body().add_child(words)
	var from_file := GauntletOptions.fit(dialog.add_button("From a file..."))
	from_file.name = "ForgeImportFile"
	from_file.pressed.connect(func() -> void:
		_close_dialog()
		import_file_box())
	var from_game := GauntletOptions.fit(dialog.add_button("From a game card..."))
	from_game.name = "ForgeImportGame"
	from_game.disabled = _importer() == null
	from_game.pressed.connect(open_game_cards)
	GauntletOptions.fit(dialog.add_button("Cancel")).pressed.connect(_close_dialog)
	_show(dialog, from_file)


## The file box for a shared card zip or set zip.
func import_file_box() -> void:
	var box := _file_box("ForgeImportBox", FileDialog.FILE_MODE_OPEN_FILE, ["*.zip ; Card or set zip"])
	box.file_selected.connect(func(path: String) -> void:
		import_asked(path)
		box.queue_free())
	box.canceled.connect(box.queue_free)
	add_child(box)
	box.popup_centered_ratio(0.6)


# ------------------------------------------------- from a game card --

## THE GAME'S SOURCES a card may be started from, as the Deck Builder's
## Extras window lists them ([constant FilterBar.SOURCE_KEYS], its order
## and its medallions) and titles them; the cards players made are not
## among them.
const SOURCE_TITLES := {"Original": "1997", "Pack1": "tDotP Pack 1", "Pack2": "Fallen E. Pack 2",
	"Pack3": "Ice Age Pack 3", "Pack4": "Homelands Pack 4", "Pack5": "Alliances Pack 5",
	"Pack6": "Portal Pack 6", "SecondAge": "Second Age Pack 6", "Pack7": "Fifth Ed. Pack 7",
	"Pack8": "Mirage Pack 8", "Visions": "Visions Pack 8", "Weatherlight": "Weatherlight Pack 8",
	"Pack9": "Tempest Pack 9", "Stronghold": "Stronghold Pack 9", "Exodus": "Exodus Pack 9",
	"Pack10": "Urza's Saga Pack 10", "Legacy": "Urza's Legacy Pack 10", "Destiny": "Urza's Destiny Pack 10"}
const IMPORT_SCRIPT := "res://engine/community/card_import.gd"
## What reads a game card into a draft (`from_card`, `can_start`,
## `quality`): the engine's, or the one a test puts here.
static var importer_override: Variant = null
## The source last chosen, for the session.
static var _last_source := "Original"
## How a card comes over, by [code]quality[/code]: its words and its mark.
const QUALITY_WORDS := ["frame only", "comes over in part", "comes over whole"]
const QUALITY_COLORS := [Color8(150, 150, 150), Color8(240, 190, 80), Color8(120, 210, 120)]
const GAME_COLORS := [["W", "White", "white"], ["U", "Blue", "blue"], ["B", "Black", "black"],
	["R", "Red", "red"], ["G", "Green", "green"], ["C", "Colorless", "colorless"]]
## The window's parts while it is up, and the run of its lazy tile maker.
var _game_grid: GridContainer = null
var _game_scroll: ScrollContainer = null
var _game_browse: Control = null
var _game_detail: Control = null
var _game_search: LineEdit = null
var _game_count: Label = null
var _game_colors := {}
var _game_run := 0


static func _importer() -> Variant:
	if importer_override != null:
		return importer_override
	return load(IMPORT_SCRIPT) if ResourceLoader.exists(IMPORT_SCRIPT) else null


## The sources in the Deck Builder's order: `{id, title, available,
## names}` each — a pack not switched on is listed, without cards.
static func game_sources() -> Array[Dictionary]:
	CardRegistry.ensure_loaded()
	var extra := CardRegistry.extra_set_order()
	var out: Array[Dictionary] = []
	for id: String in FilterBar.SOURCE_KEYS:
		if not SOURCE_TITLES.has(id):
			continue   # the cards players made
		var names: Array[String] = []
		var available := true
		if id == "Original":
			for card_name: String in CardRegistry.all_names():
				if CardRegistry.has_community(card_name) or CardRegistry.is_completion_card(card_name):
					continue
				if CardRegistry.SET_ORDER.has(CardRegistry.get_card(card_name).set_code):
					names.append(card_name)
		elif id == "Pack1":
			available = CardRegistry.optional_pack_enabled()
			if available:
				for card_name: String in CardRegistry.all_names():
					if CardRegistry.is_completion_card(card_name):
						names.append(card_name)
		else:
			var code := String(FilterBar.SOURCE_KEYS[id])
			available = extra.has(code)
			if available:
				names = CardRegistry.names_in_set(code)
				names.sort()
		out.append({"id": id, "title": String(SOURCE_TITLES[id]), "available": available, "names": names})
	return out


## START FROM A GAME CARD: one window — the sources on the left, the
## chosen one's cards on the right under a search field and a color row;
## a card chosen shows, in the same window, what of it comes over
## ([method show_game_card]).
func open_game_cards() -> void:
	if _importer() == null:
		_say("The game's cards cannot be read here.")
		return
	var dialog := OriginalDialog.create("Start from a game card", Vector2(1216, 640))
	dialog.name = "ForgeGameCardWindow"
	_game_browse = HBoxContainer.new()
	_game_browse.name = "ForgeGameBrowse"
	_game_browse.add_theme_constant_override("separation", 14)
	_game_browse.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog.body().add_child(_game_browse)
	_game_detail = HBoxContainer.new()
	_game_detail.name = "ForgeGameDetail"
	_game_detail.add_theme_constant_override("separation", 18)
	_game_detail.visible = false
	dialog.body().add_child(_game_detail)
	# The sources.
	var sets_scroll := ScrollContainer.new()
	sets_scroll.custom_minimum_size = Vector2(290, 454)
	sets_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sets_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sets_scroll.follow_focus = true
	var sets := VBoxContainer.new()
	sets.name = "ForgeGameSets"
	sets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sets.add_theme_constant_override("separation", 2)
	sets_scroll.add_child(sets)
	_game_browse.add_child(sets_scroll)
	var sources := game_sources()
	var group := ButtonGroup.new()
	var first: Button = null
	var chosen: Button = null
	for source in sources:
		var id := String(source["id"])
		var row := Button.new()
		row.name = "ForgeGameSet_" + id
		row.toggle_mode = true
		row.button_group = group
		row.custom_minimum_size = Vector2(250, 44)
		row.disabled = not bool(source["available"])
		row.tooltip_text = "%s — %d cards" % [source["title"], (source["names"] as Array).size()] \
			if bool(source["available"]) else "%s is not switched on (Options, Card packs)." % source["title"]
		var line := HBoxContainer.new()
		line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		line.offset_left = 6
		line.offset_right = -12
		line.add_theme_constant_override("separation", 8)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var medal := Button.new()
		FilterBar.dress_source_medallion(medal, id)
		# Plain letters: no seat under the medallion's numerals.
		medal.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		medal.add_theme_constant_override("shadow_offset_x", 0)
		medal.add_theme_constant_override("shadow_offset_y", 0)
		medal.custom_minimum_size = Vector2(36, 36)
		medal.add_theme_font_size_override("font_size", 17)
		medal.focus_mode = Control.FOCUS_NONE
		medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		medal.toggle_mode = true
		medal.button_pressed = bool(source["available"])
		line.add_child(medal)
		var title := UiChrome.body_label(String(source["title"]), 14)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.clip_text = true
		line.add_child(title)
		var amount := UiChrome.body_label(str((source["names"] as Array).size()) if bool(source["available"]) else "off", 13)
		amount.modulate.a = 0.75
		line.add_child(amount)
		line.modulate.a = 1.0 if bool(source["available"]) else 0.45
		row.add_child(line)
		row.pressed.connect(func() -> void: pick_game_source(source))
		sets.add_child(row)
		if bool(source["available"]):
			if first == null:
				first = row
			if id == _last_source:
				chosen = row
	# The cards.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	_game_browse.add_child(right)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	right.add_child(top)
	_game_search = LineEdit.new()
	_game_search.name = "ForgeGameSearch"
	_game_search.placeholder_text = "Search: a name, a type, a word of the rules"
	_game_search.custom_minimum_size.x = 400
	_game_search.clear_button_enabled = true
	_game_search.text_changed.connect(func(_t: String) -> void: _filter_game_cards())
	_game_search.text_submitted.connect(func(_t: String) -> void:
		var seen := _game_grid.get_children().filter(func(t: Node) -> bool: return (t as Control).visible)
		if seen.size() == 1:
			(seen[0] as Button).pressed.emit())
	top.add_child(_game_search)
	_game_colors = {}
	for color in GAME_COLORS:
		var chip := Button.new()
		chip.name = "ForgeGameColor_" + String(color[2])
		chip.text = String(color[0])
		chip.tooltip_text = "%s cards only" % color[1]
		chip.toggle_mode = true
		chip.custom_minimum_size = Vector2(34, 30)
		chip.toggled.connect(func(_on: bool) -> void: _filter_game_cards())
		top.add_child(chip)
		_game_colors[String(color[2])] = chip
	_game_count = UiChrome.body_label("", 13)
	_game_count.name = "ForgeGameCount"
	_game_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_game_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_game_count)
	_game_scroll = ScrollContainer.new()
	_game_scroll.name = "ForgeGameScroll"
	_game_scroll.custom_minimum_size = Vector2(6 * (MiniCard.SIZE.x + 10) + 6, 454)
	_game_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_game_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_game_scroll.follow_focus = true
	_game_grid = GridContainer.new()
	_game_grid.name = "ForgeGameGrid"
	_game_grid.columns = 6
	_game_grid.add_theme_constant_override("h_separation", 10)
	_game_grid.add_theme_constant_override("v_separation", 10)
	_game_scroll.add_child(_game_grid)
	_game_scroll.get_v_scroll_bar().value_changed.connect(func(_v: float) -> void: _dress_game_tiles())
	right.add_child(_game_scroll)
	GauntletOptions.fit(dialog.add_button("Cancel")).pressed.connect(_close_dialog)
	_show(dialog, _game_search)
	var start := chosen if chosen != null else first
	if start != null:
		start.button_pressed = true
		start.pressed.emit()


## Show the cards of [param source] (a row of [method game_sources]): a
## bare tile each at once — its small card is made when it scrolls into
## view ([method _dress_game_tiles]), so a set of 600 opens at once.
func pick_game_source(source: Dictionary) -> void:
	if not is_instance_valid(_game_grid):
		return
	_last_source = String(source["id"])
	for tile in _game_grid.get_children():
		_game_grid.remove_child(tile)
		tile.queue_free()
	for card_name: String in source["names"]:
		var data := CardRegistry.get_card(card_name)
		var tile := Button.new()
		tile.name = "ForgeGame_" + CommunityCards.file_name(card_name)
		tile.custom_minimum_size = MiniCard.SIZE
		tile.tooltip_text = card_name
		var types: Array[String] = []
		for word: String in CommunityCard.TYPES:
			if data.types & int(CommunityCard.TYPES[word]):
				types.append(word)
		tile.set_meta("haystack", _haystack(data, {"types": types, "subtypes": data.subtypes}))
		tile.set_meta("card", card_name)
		var mask := data.color_mask()
		var colors: Array[String] = []
		for color in GAME_COLORS:
			if CommunityCard.COLORS.has(color[2]) and mask & int(CommunityCard.COLORS[color[2]]):
				colors.append(String(color[2]))
		tile.set_meta("colors", colors if not colors.is_empty() else ["colorless"])
		tile.pressed.connect(func() -> void: show_game_card(card_name))
		_game_grid.add_child(tile)
	_game_scroll.scroll_vertical = 0
	_filter_game_cards()


## The search and the color row over the tiles; then the ones in view get
## their small cards.
func _filter_game_cards() -> void:
	if not is_instance_valid(_game_grid):
		return
	filter_open_list(_game_grid, _game_search.text)
	var wanted: Array[String] = []
	for color: String in _game_colors:
		if (_game_colors[color] as Button).button_pressed:
			wanted.append(color)
	var seen := 0
	for tile in _game_grid.get_children():
		var shown := (tile as Control).visible
		if shown and not wanted.is_empty():
			var colors: Array = tile.get_meta("colors", [])
			shown = wanted.any(func(color: String) -> bool: return colors.has(color))
			(tile as Control).visible = shown
		if shown:
			seen += 1
	var all := _game_grid.get_child_count()
	_game_count.text = ("%d of %d" % [seen, all]) if seen != all else ("1 card" if all == 1 else "%d cards" % all)
	_dress_game_tiles()


## Give the tiles in view (and a row past it) their small card and their
## mark, a few a frame (about 8 ms each frame, from the next frame on: the
## grid is laid out by then).
func _dress_game_tiles() -> void:
	_game_run += 1
	set_process(true)


func _process(_delta: float) -> void:
	if not is_instance_valid(_game_grid) or not is_instance_valid(_game_scroll):
		set_process(false)
		return
	var start := Time.get_ticks_msec()
	var top := float(_game_scroll.scroll_vertical) - MiniCard.SIZE.y
	var bottom := float(_game_scroll.scroll_vertical) + _game_scroll.size.y + MiniCard.SIZE.y
	for tile in _game_grid.get_children():
		var one := tile as Button
		if one.is_queued_for_deletion() or not one.visible or one.has_meta("dressed") \
				or one.position.y + one.size.y < top or one.position.y > bottom:
			continue
		_dress_game_tile(one)
		if Time.get_ticks_msec() - start > 8:
			return   # the rest next frame
	set_process(false)


func _dress_game_tile(tile: Button) -> void:
	tile.set_meta("dressed", true)
	var card_name := String(tile.get_meta("card"))
	var data := CardRegistry.get_card(card_name)
	var mini := MiniCard.new(CardInstance.new(data, -1, 0))
	mini.size = MiniCard.SIZE
	mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini.focus_mode = Control.FOCUS_NONE
	tile.add_child(mini)
	mini.refresh()
	var importer: Variant = _importer()
	var able := bool(importer.can_start(data))
	var level := game_quality(int(importer.quality(data))) if able else 0
	var mark := Panel.new()
	mark.name = "ForgeGameMark"
	var dot := StyleBoxFlat.new()
	dot.bg_color = QUALITY_COLORS[level]
	dot.set_corner_radius_all(7)
	dot.set_border_width_all(2)
	dot.border_color = Color(0, 0, 0, 0.8)
	mark.add_theme_stylebox_override("panel", dot)
	mark.size = Vector2(14, 14)
	mark.position = Vector2(4, MiniCard.SIZE.y - 18)   # clear of the power and toughness
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(mark)
	tile.set_meta("quality", level)
	tile.tooltip_text = "%s — %s" % [card_name, QUALITY_WORDS[level] if able else "cannot be started from"]
	tile.modulate.a = 1.0 if able else 0.5


## A quality (0 to 100) as one of three: 0 frame only, 1 in part, 2 whole.
static func game_quality(quality: int) -> int:
	return 2 if quality >= 100 else (1 if quality > 0 else 0)


## WHAT COMES OVER of the game card [param card_name], in the same window:
## the draft as it would look (no picture: the game's are never copied),
## the clauses kept, the ones left out in the card's own words, and Start.
func show_game_card(card_name: String) -> void:
	if not is_instance_valid(_game_detail) or not CardRegistry.has_card(card_name):
		return
	var data := CardRegistry.get_card(card_name)
	var importer: Variant = _importer()
	if not bool(importer.can_start(data)):
		_say("%s cannot be started from." % card_name)
		return
	var result: Dictionary = importer.from_card(data)
	var card: Dictionary = result.get("spec", {})
	for child in _game_detail.get_children():
		_game_detail.remove_child(child)
		child.queue_free()
	var seat := Control.new()
	seat.custom_minimum_size = CardPreview.SIZE
	_game_detail.add_child(seat)
	if CommunityCard.problems(card).is_empty():
		var built := CommunityCard.build(card)
		built.set_code = CommunityCard.SET_CODE
		var big := CardPreview.new()
		big.docked = true
		seat.add_child(big)
		big.show_card(CardInstance.new(built, -1, 0))
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(760, 454)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var words := VBoxContainer.new()
	words.name = "ForgeGameWords"
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 12)
	scroll.add_child(words)
	_game_detail.add_child(scroll)
	var kept: Array = result.get("kept", [])
	var dropped: Array = result.get("dropped", [])
	var head := UiChrome.body_label("%s — %s" % [card_name, "comes over whole" if bool(result.get("exact", false))
		else ("comes over in part" if not kept.is_empty() else "frame only: its name, cost and types")], 18)
	head.name = "ForgeGameHead"
	words.add_child(head)
	_game_list(words, "ForgeGameKept", "Comes over", kept, Color8(150, 220, 140))
	_game_list(words, "ForgeGameDropped", "Left out — add them yourself or leave them", dropped, Color8(240, 190, 80))
	_game_list(words, "ForgeGameNotes", "", result.get("notes", []), Color8(190, 185, 172))
	var note := UiChrome.body_label("The picture is not copied: the draft needs art and a set icon of your own, and a name of its own.", 13)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 720
	note.modulate.a = 0.75
	words.add_child(note)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	var start := UiChrome.menu_button("Start from this", Vector2(170, 36), 15)
	start.name = "ForgeGameStart"
	start.pressed.connect(func() -> void:
		_close_dialog()
		_guarded("Start from %s anyway?" % card_name, func() -> void: start_from_game(card_name)))
	buttons.add_child(start)
	var back := UiChrome.menu_button("Back", Vector2(110, 36), 15)
	back.name = "ForgeGameBack"
	back.pressed.connect(game_cards_back)
	buttons.add_child(back)
	words.add_child(buttons)
	_game_browse.visible = false
	_game_detail.visible = true
	_default = start
	_refocus()


func _game_list(box: Container, list_name: String, title: String, lines: Array, color: Color) -> void:
	if lines.is_empty():
		return
	var list := VBoxContainer.new()
	list.name = list_name
	list.add_theme_constant_override("separation", 2)
	if title != "":
		list.add_child(UiChrome.body_label(title, 15))
	for text in lines:
		var line := UiChrome.body_label(("• " if title != "" else "") + String(text), 15)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size.x = 720
		line.add_theme_color_override("font_color", color)
		list.add_child(line)
	box.add_child(list)


## One level back in the window: from a card to the cards. False when the
## cards are showing already (Escape then closes the window).
func game_cards_back() -> bool:
	if not is_instance_valid(_game_detail) or not _game_detail.visible:
		return false
	_game_detail.visible = false
	_game_browse.visible = true
	_default = _game_search
	_refocus()
	return true


## A NEW CARD begun from the game's [param card_name]: what of it comes
## over, with no picture and no saved name; the keyboard in the Name field,
## the name selected — it needs one of its own.
func start_from_game(card_name: String) -> bool:
	var importer: Variant = _importer()
	if importer == null or not CardRegistry.has_card(card_name):
		return false
	var result: Dictionary = importer.from_card(CardRegistry.get_card(card_name))
	CommunityCards.clear_draft()
	if not load_spec(result.get("spec", {}), {}, {}):
		refresh()
		return false
	_saved_name = ""
	_begin_card()
	_tabs.current_tab = 0
	var name_field := _fields["name"] as LineEdit
	name_field.grab_focus()
	name_field.select_all()
	_say("Started from %s — give it a name of its own and your own art." % card_name)
	return true


## Import the zip at [param path] as the Import button and a drop do:
## asking first when the card on screen has unsaved changes (the first
## card taken is opened in its place).
func import_asked(path: String) -> void:
	_guarded("Import %s and open its card anyway?" % path.get_file(), func() -> void: import_from(path))


## Import the zip at [param path] (asking first before replacing the
## player's own copies): what happened is said on the status line — how
## many were taken, how many not, those listed in a window — and the first
## card taken is opened.
func import_from(path: String, replace := false) -> Dictionary:
	var refusal := CardPacks.change_refusal()
	if refusal != "":
		_say(refusal.replace("changing or rescanning card packs", "importing a card"))
		return {}
	var done := CommunityCards.import_file(path, replace)
	var names: Array = done["names"]
	var opened := true
	if not names.is_empty():
		CommunityCards.refresh()
		opened = open_card(String(names[0]))
	var missed: Array = done["problems"]
	var waiting: Array = done["here"] if not replace else []
	var said := "Imported %s" % ("nothing" if names.is_empty() else String(names[0]) if names.size() == 1
		else "%d cards" % names.size())
	if not missed.is_empty():
		said += ", %d not taken" % missed.size()
	if not waiting.is_empty():
		said += ", %d here already" % waiting.size()
	said += "."
	if not opened:
		said += " " + _refusal
	var lines := import_lines(done)
	if not waiting.is_empty():
		_ask_replace(path, waiting, lines)
	elif not missed.is_empty() or not (done.get("notes", []) as Array).is_empty():
		_show_not_taken(names.size(), lines, missed.size())
	_say(said if not (names.is_empty() and missed.is_empty() and waiting.is_empty()) else "Nothing imported.",
		"\n".join(PackedStringArray(missed)))
	return done


## What an import did, a line a card: taken, here already (and how the
## one here differs from the zip's), or not taken and why; then what else
## the zip had to say. An import refused whole has its reason alone.
static func import_lines(done: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var differs := {"identical": "identical to yours", "look": "only the look differs from yours",
		"plays": "plays differently from yours"}
	for card: Variant in done.get("cards", []):
		if not card is Dictionary:
			continue
		var card_name := String(card.get("name", ""))
		match String(card.get("result", "")):
			"taken":
				out.append("%s — taken." % card_name)
			"here":
				var how := String(differs.get(String(card.get("differs", "")), ""))
				out.append("%s — here already%s." % [card_name, (" (%s)" % how) if how != "" else ""])
			_:
				out.append("%s — not taken: %s" % [card_name if card_name != "" else "A card", String(card.get("problem", ""))])
	if out.is_empty():
		for why in done.get("problems", []):
			out.append(String(why))
	for note in done.get("notes", []):
		out.append(String(note))
	return out


## The list of what an import did, card by card.
func _show_not_taken(taken: int, missed: Array, refused := -1) -> void:
	var dialog := OriginalDialog.create("Import", Vector2(560, 360))
	dialog.name = "ForgeImportWindow"
	dialog.body().add_child(UiChrome.body_label("Imported %s, %d not taken:" % [
		"nothing" if taken == 0 else "1 card" if taken == 1 else "%d cards" % taken,
		refused if refused >= 0 else missed.size()], 14))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.name = "ForgeNotTaken"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	_not_taken_lines(box, missed)
	dialog.body().add_child(scroll)
	var close_it := GauntletOptions.fit(dialog.add_button("Close"))
	close_it.pressed.connect(_close_dialog)
	_show(dialog, close_it)
	_fit_dialog(dialog, scroll, clampf(missed.size() * 40.0, 60, 300))


func _not_taken_lines(box: Container, missed: Array) -> void:
	for why in missed:
		var line := UiChrome.body_label("• " + String(why), 13)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size.x = 500
		box.add_child(line)


func _ask_replace(path: String, here: Array, missed: Array = []) -> void:
	var dialog := OriginalDialog.create("Import", Vector2(480, 200))
	dialog.name = "ForgeReplaceWindow"
	var shown := ", ".join(here.slice(0, 4)) + (" and %d more" % (here.size() - 4) if here.size() > 4 else "")
	var words := UiChrome.body_label("%s %s here already. Replace your own %s with the imported %s?" % [
		shown, "is" if here.size() == 1 else "are", "copy" if here.size() == 1 else "copies",
		"one" if here.size() == 1 else "ones"], 14)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size.x = 440
	dialog.body().add_child(words)
	if not missed.is_empty():
		# Each card of the zip: taken, here (and how it differs), not taken.
		dialog.body().add_child(UiChrome.body_label("Card by card:", 14))
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(440, clampf(missed.size() * 40.0, 60, 200))
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var box := VBoxContainer.new()
		box.name = "ForgeNotTaken"
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(box)
		_not_taken_lines(box, missed)
		dialog.body().add_child(scroll)
		dialog.size.y += scroll.custom_minimum_size.y + 30
	GauntletOptions.fit(dialog.add_button("Replace")).pressed.connect(func() -> void:
		_close_dialog()
		import_from(path, true))
	var keep := GauntletOptions.fit(dialog.add_button("Keep mine"))
	keep.pressed.connect(_close_dialog)
	_show(dialog, keep)
	if not missed.is_empty():
		dialog.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
		dialog.fit_height()


## Save a copy under another name (asked for).
func ask_save_as() -> void:
	if not problems().is_empty():
		return
	_rename_from = ""
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
	# Enter in the field saves, as the button does.
	edit.text_submitted.connect(func(text: String) -> void: save_as(text))
	_show(dialog, edit)
	edit.select_all()


## Save the card as [param new_name] (the old one stays as it was saved;
## a card already of that name is replaced only when asked).
func save_as(new_name: String, replacing := "") -> void:
	var refusal := CardPacks.change_refusal()
	if refusal != "":
		_say(refusal.replace("changing or rescanning card packs", "saving a card"))
		return
	_rename_from = ""
	var was := String(spec.get("name", ""))
	spec["name"] = new_name.strip_edges()
	var found := problems()
	if not found.is_empty():
		spec["name"] = was
		_say(found[0])
		return
	var other := CommunityCards.found_like(String(spec["name"]))
	if other != "" and other.to_lower() != _saved_name.to_lower() and other.to_lower() != replacing.to_lower():
		spec["name"] = was
		_ask_overwrite(other, func() -> void: save_as(new_name, other))
		return
	_close_dialog()
	_fill()
	refresh()
	save_card(other)


## Ask before a save goes over [param other], another saved card.
func _ask_overwrite(other: String, then: Callable) -> void:
	var dialog := OriginalDialog.create("Save", Vector2(470, 190))
	dialog.name = "ForgeOverwriteWindow"
	var words := UiChrome.body_label("A card named %s is saved already. Replace it with this one?" % other, 14)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size.x = 430
	dialog.body().add_child(words)
	GauntletOptions.fit(dialog.add_button("Replace")).pressed.connect(func() -> void:
		_close_dialog()
		then.call())
	var cancel := GauntletOptions.fit(dialog.add_button("Cancel"))
	cancel.pressed.connect(_close_dialog)
	_show(dialog, cancel)


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
	_default = null
	add_child(shade)
	_refocus()


## The colors of the suggestions, by level (on the dialog's dark stone;
## the red is the duel's warning red).
const ADVICE_COLORS := {CardBalance.OK: Color8(150, 220, 140), CardBalance.LOW: Color8(140, 190, 255),
	CardBalance.HIGH: Color8(255, 180, 80), CardBalance.VERY_HIGH: Color8(255, 100, 100),
	CardBalance.NOT_COMPARED: Color8(190, 185, 172), CardBalance.RARE: Color8(140, 190, 255),
	"invalid": Color8(255, 100, 100)}
## The rows' order, the worst first; a verdict not listed comes last.
const ADVICE_ORDER := {CardBalance.VERY_HIGH: 0, CardBalance.HIGH: 1, CardBalance.NOT_COMPARED: 2,
	CardBalance.LOW: 3, CardBalance.RARE: 4, CardBalance.OK: 5}


## ONE NUMBER FOR THE CARD ([method CardBalance.power], 0 to 100) and a
## word for it.
static func power_words(power: int) -> String:
	if power <= 0:
		return "Power: nothing on it could be measured"
	var word := "weak" if power < 35 else "usual" if power < 60 else "strong" if power <= 70 \
		else "among the game's strongest" if power <= 85 else "beyond every card of the game"
	return "Power %d of 100 — %s" % [power, word]


## THE VALIDATOR: the card beside the game's own cards ([CardBalance]) —
## suggestions only, as a TABLE (owner 2026-11-18: "more like in table so
## it is easier to read"): the summary on top in its level's color, then
## one row a suggestion — Verdict, Check, the card's own number and the
## game's cards — the worst first, the rows striped.
func validate_card() -> void:
	if not CommunityCard.problems(spec).is_empty():
		return
	show_advice(CardBalance.advice(spec))


## The suggestions table over [param rows] ([method CardBalance.advice]:
## the summary first). A row may be no level at all ("Not compared") and
## may have no number of the card's own: both are shown plainly.
func show_advice(rows: Array) -> void:
	rows = rows.duplicate()
	var summary: Dictionary = rows.pop_front()
	var dialog := OriginalDialog.create("Suggestions", Vector2(860, 600))
	dialog.name = "ForgeValidateWindow"
	var banner := PanelContainer.new()
	banner.name = "ForgeAdviceSummary"
	var level := String(summary["level"])
	banner.add_theme_stylebox_override("panel", _advice_box(Color(0, 0, 0, 0.32),
		ADVICE_COLORS.get(level, Color.WHITE)))
	var said := UiChrome.body_label(String(summary["text"]), 15)
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	said.custom_minimum_size.x = 780
	said.add_theme_color_override("font_color", ADVICE_COLORS.get(level, Color.WHITE))
	banner.add_child(said)
	dialog.body().add_child(banner)
	# The card's one number, and the same look at its whole set.
	var tools := HBoxContainer.new()
	tools.name = "ForgeAdviceTools"
	tools.add_theme_constant_override("separation", 12)
	var measured: Array[Dictionary] = []
	measured.assign(rows)
	var power := UiChrome.body_label(power_words(CardBalance.power_of(measured)), 14)
	power.name = "ForgeAdvicePower"
	power.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	power.tooltip_text = "About 50 is a usual card of its cost, 70 the strongest the game has, past 85 beyond every card."
	tools.add_child(power)
	var whole := UiChrome.menu_button("Validate set...", Vector2(150, 28), 13)
	whole.name = "ForgeValidateSet"
	whole.tooltip_text = "Every card of this card's set, one line each, and the set as a whole."
	whole.pressed.connect(validate_set)
	tools.add_child(whole)
	dialog.body().add_child(tools)
	var header := _advice_line(["Verdict", "Check", "Yours", "The game's cards"], Color(0, 0, 0, 0.45))
	header.name = "ForgeAdviceHeader"
	dialog.body().add_child(header)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(800, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.name = "ForgeAdvice"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 0)
	scroll.add_child(box)
	dialog.body().add_child(scroll)
	var ranked: Array = []
	for i in rows.size():
		ranked.append([int(ADVICE_ORDER.get(String(rows[i]["level"]), 9)), i])
	ranked.sort_custom(func(a: Array, b: Array) -> bool:
		return int(a[0]) < int(b[0]) or (int(a[0]) == int(b[0]) and int(a[1]) < int(b[1])))
	for pair in ranked:
		var row: Dictionary = rows[int(pair[1])]
		var shade := Color(1, 1, 1, 0.07) if box.get_child_count() % 2 == 0 else Color(0, 0, 0, 0.0)
		# A row with no number of the card's own leaves its column empty.
		var line := _advice_line([_level_words(String(row["level"])),
			String(row.get("topic", "")), String(row.get("yours", "")), CardBalance.game_words(row)], shade)
		((line.get_child(0) as HBoxContainer).get_child(0) as Label).add_theme_color_override(
			"font_color", ADVICE_COLORS.get(String(row["level"]), ADVICE_PLAIN))
		box.add_child(line)
	var close_it := GauntletOptions.fit(dialog.add_button("Close"))
	close_it.pressed.connect(_close_dialog)
	_show(dialog, close_it)
	# As tall as its rows (about 60 letters a line in the last column),
	# never past the screen.
	var height := 0.0
	for pair in ranked:
		height += 10.0 + 19.0 * ceilf(CardBalance.game_words(rows[int(pair[1])]).length() / 60.0)
	# The summary and the header stand above the scrolling rows.
	scroll.custom_minimum_size.y = clampf(height, 80, 400)
	dialog.size.y = scroll.custom_minimum_size.y + 250
	dialog.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	dialog.fit_height()


## THE WHOLE SET beside the game's cards ([method CardBalance.set_advice])
## — the saved cards of this card's set, with this one as it stands: one
## line a card, the worst first, then what the set as a whole lacks.
func validate_set() -> void:
	var specs: Array = []
	for card in set_cards():
		specs.append(card["spec"])
	show_set_advice(String(spec.get("set_name", "")).strip_edges(), CardBalance.set_advice(specs))


## The set's table over [param rows] ([method CardBalance.set_advice]).
func show_set_advice(set_name: String, rows: Array) -> void:
	var cards := rows.filter(func(row: Dictionary) -> bool: return String(row.get("kind", "")) == "card")
	var dialog := OriginalDialog.create("%s — %s" % [set_name if set_name != "" else "The set",
		"1 card" if cards.size() == 1 else "%d cards" % cards.size()], Vector2(860, 600))
	dialog.name = "ForgeSetAdviceWindow"
	var header := _advice_line(["Verdict", "Card", "Power", "What stands out"], Color(0, 0, 0, 0.45))
	dialog.body().add_child(header)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(800, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.name = "ForgeSetAdvice"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 0)
	scroll.add_child(box)
	dialog.body().add_child(scroll)
	var height := 0.0
	for row: Dictionary in rows:
		var level := String(row.get("level", ""))
		var is_card := String(row.get("kind", "")) == "card"
		var cells: Array
		if is_card:
			var topic := String(row.get("topic", ""))
			cells = ["Problem" if level == "invalid" else _level_words(level), String(row.get("name", "")),
				str(int(row["power"])) if int(row.get("power", -1)) >= 0 else "",
				String(row.get("text", "")) if topic in ["", "Summary", "Problem"] else "%s: %s" % [topic, String(row.get("text", ""))]]
		else:
			cells = ["Gap" if level == CardBalance.LOW else "", String(row.get("topic", "")), "", String(row.get("text", ""))]
		var shade := Color(1, 1, 1, 0.07) if box.get_child_count() % 2 == 0 else Color(0, 0, 0, 0.0)
		var line := _advice_line(cells, shade if is_card else Color(0, 0, 0, 0.3))
		line.name = ("ForgeSetCard%d" if is_card else "ForgeSetRemark%d") % box.get_child_count()
		((line.get_child(0) as HBoxContainer).get_child(0) as Label).add_theme_color_override(
			"font_color", ADVICE_COLORS.get(level, ADVICE_PLAIN))
		box.add_child(line)
		height += 10.0 + 19.0 * maxf(ceilf(String(cells[3]).length() / 60.0), ceilf(String(cells[1]).length() / 20.0))
	var back := GauntletOptions.fit(dialog.add_button("Back"))
	back.tooltip_text = "The card's own suggestions again."
	back.pressed.connect(validate_card)
	var close_it := GauntletOptions.fit(dialog.add_button("Close"))
	close_it.pressed.connect(_close_dialog)
	_show(dialog, close_it)
	scroll.custom_minimum_size.y = clampf(height, 80, 400)
	dialog.size.y = scroll.custom_minimum_size.y + 170
	dialog.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	dialog.fit_height()


## The table's columns, in pixels; the last one takes the rest.
const ADVICE_COLUMNS: Array[int] = [100, 150, 84, 426]
## The color of a verdict that is no level ("Not compared"): plain, muted.
const ADVICE_PLAIN := Color8(190, 185, 172)


## A verdict's words: the level's, or — a verdict that is no level, as
## "not_compared" — its own, spelled out.
static func _level_words(level: String) -> String:
	if CardBalance.LEVEL_WORDS.has(level):
		return String(CardBalance.LEVEL_WORDS[level])
	var words := level.replace("_", " ")
	return words.left(1).to_upper() + words.substr(1)


## One row of the suggestions table: [param cells] in the four columns on
## a [param shade] ground, the last cell wrapping.
func _advice_line(cells: Array, shade: Color) -> PanelContainer:
	var line := PanelContainer.new()
	line.add_theme_stylebox_override("panel", _advice_box(shade, Color(0, 0, 0, 0)))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	line.add_child(columns)
	for i in cells.size():
		var cell := UiChrome.body_label(String(cells[i]), 14)
		cell.custom_minimum_size.x = ADVICE_COLUMNS[i]
		cell.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cell.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		cell.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		if i == cells.size() - 1:
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(cell)
	return line


## A row's ground: [param fill], with a 4-pixel bar of [param edge] down
## its left side when that is not clear.
static func _advice_box(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.content_margin_left = 10
	box.content_margin_right = 8
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	if edge.a > 0.0:
		box.border_width_left = 4
		box.border_color = edge
	return box


## The cards found, as small cards, to open one.
func open_list() -> void:
	_close_dialog()
	# The saved cards as saved: the card being made is set aside while the
	# list is up ([method _close_dialog] shows it again).
	CommunityCards.clear_draft()
	var dialog := OriginalDialog.create("Open a card", Vector2(640, 520))
	dialog.name = "ForgeOpenWindow"
	# The search, how many cards it leaves, and the order they stand in.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	dialog.body().add_child(top)
	var search := LineEdit.new()
	search.name = "ForgeOpenSearch"
	search.placeholder_text = "Search: a name, a set, a type, a color, a word of the rules"
	search.tooltip_text = search.placeholder_text
	search.custom_minimum_size.x = 370
	search.clear_button_enabled = true
	top.add_child(search)
	var count := UiChrome.body_label("", 13)
	count.name = "ForgeOpenCount"
	count.custom_minimum_size.x = 96
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(count)
	var sort := OptionButton.new()
	sort.name = "ForgeOpenSort"
	sort.custom_minimum_size.x = 118
	for row in OPEN_SORTS:
		sort.add_item(String(row[1]))
		sort.set_item_metadata(sort.item_count - 1, row[0])
	_select(sort, _open_sort)
	top.add_child(sort)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 400)
	var grid := GridContainer.new()
	grid.name = "ForgeOpenGrid"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	dialog.body().add_child(scroll)
	# The game's own examples first, to start from — but an example saved
	# under its own name is that saved card now, shown once below (owner
	# 2026-11-18: "the saved one overwrites the preset").
	for row in CommunityCards.examples():
		if CommunityCards.found_like(String(row["spec"].get("name", ""))) != "":
			continue
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
			_close_dialog()
			_guarded("Open the example %s anyway?" % data.card_name, func() -> void: open_example(example)))
		tile.set_meta("haystack", " example" + _haystack(data, row["spec"]))
		tile.set_meta("example", true)
		_sort_metas(tile, data, row["spec"], 0)
		# Told apart from the player's own cards.
		var ribbon := Label.new()
		ribbon.name = "ForgeExampleRibbon"
		ribbon.text = "Example"
		ribbon.add_theme_font_size_override("font_size", 12)
		ribbon.add_theme_color_override("font_color", Color8(255, 240, 200))
		var band := StyleBoxFlat.new()
		band.bg_color = Color(0.35, 0.1, 0.45, 0.92)
		band.set_corner_radius_all(4)
		band.content_margin_left = 6
		band.content_margin_right = 6
		ribbon.add_theme_stylebox_override("normal", band)
		ribbon.position = Vector2(4, 4)
		ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(ribbon)
		grid.add_child(tile)
	# Art not made yet is filled in over the next frames (a hundred cards'
	# pictures decoded first kept the list from showing).
	var later: Array = []
	for row in CommunityCards.playable():
		var card_name := String(row["name"])
		# A zip named like a game card is left out: the pool has the game's.
		if not CardRegistry.has_community(card_name):
			continue
		var data := CardRegistry.get_card(card_name)
		var tile := Button.new()
		tile.name = "ForgeOpen_" + CommunityCards.file_name(card_name)
		tile.custom_minimum_size = MiniCard.SIZE
		tile.tooltip_text = "%s%s" % [card_name, CommunityCards.tooltip_extra(data)]
		var mini := MiniCard.new(CardInstance.new(data, -1, 0))
		mini.art_override = CommunityCards.made_art(card_name)
		if mini.art_override == null:
			mini.art_override = _no_art()
			later.append([mini, card_name])
		mini.size = MiniCard.SIZE
		mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mini.focus_mode = Control.FOCUS_NONE
		tile.add_child(mini)
		mini.refresh()
		tile.pressed.connect(func() -> void:
			_close_dialog()
			_guarded("Open %s anyway?" % card_name, func() -> void: open_card(card_name)))
		var card_spec := CommunityCards.spec_of(card_name)
		tile.set_meta("haystack", _haystack(data, card_spec))
		_sort_metas(tile, data, card_spec, FileAccess.get_modified_time(String(row["path"])))
		# The player's own saved card can be deleted from here (asked first).
		if CommunityCards.own_path_of(card_name) != "":
			var drop := UiChrome.menu_button("x", Vector2(24, 22), 12)
			drop.name = "ForgeOpenDelete"
			drop.tooltip_text = "Delete %s..." % card_name
			drop.focus_mode = Control.FOCUS_NONE
			drop.position = Vector2(MiniCard.SIZE.x - 27, 3)
			drop.pressed.connect(func() -> void: ask_delete(card_name, true))
			tile.add_child(drop)
		grid.add_child(tile)
	if grid.get_child_count() == 0:
		dialog.body().add_child(UiChrome.body_label("No community card found yet.", 14))
	# Cards left out because the game has a card of their name.
	var skipped := CommunityCards.skipped_notice()
	if skipped != "":
		var left_out := UiChrome.body_label(skipped, 13)
		left_out.name = "ForgeOpenSkipped"
		left_out.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		left_out.custom_minimum_size.x = 600
		left_out.add_theme_color_override("font_color", Color8(240, 200, 110))
		dialog.body().add_child(left_out)
	var tell := func() -> void:
		var all := grid.get_child_count()
		var seen := grid.get_children().filter(func(t: Node) -> bool: return (t as Control).visible).size()
		count.text = ("%d of %d" % [seen, all]) if seen != all else ("1 card" if all == 1 else "%d cards" % all)
	search.text_changed.connect(func(query: String) -> void:
		filter_open_list(grid, query)
		tell.call())
	# Enter opens the card when the search leaves one.
	search.text_submitted.connect(func(_t: String) -> void:
		var seen := grid.get_children().filter(func(t: Node) -> bool: return (t as Control).visible)
		if seen.size() == 1:
			(seen[0] as Button).pressed.emit())
	sort.item_selected.connect(func(_i: int) -> void:
		_open_sort = _picked(sort)
		sort_open_list(grid, _open_sort))
	if _open_sort != "name":
		sort_open_list(grid, _open_sort)
	tell.call()
	# The set-aside shelf: cards moved out of play (a LAN table's doing).
	var aside := CommunityCards.set_aside_count()
	var shelf := GauntletOptions.fit(dialog.add_button("Set aside (%d)..." % aside))
	shelf.name = "ForgeOpenShelf"
	shelf.tooltip_text = "Cards moved out of play to a set-aside folder: put one back, or delete it."
	shelf.pressed.connect(open_shelf)
	GauntletOptions.fit(dialog.add_button("Cancel")).pressed.connect(_close_dialog)
	_show(dialog, search)
	var rows := ceili(grid.get_child_count() / 4.0)
	_fit_dialog(dialog, scroll, clampf(rows * (MiniCard.SIZE.y + 10), MiniCard.SIZE.y, 400))
	if not later.is_empty():
		_fill_art_later(later)


## What the Open list is ordered by, kept on a tile: its card's name, set,
## color (white, blue, black, red, green, many, none) and when it was saved.
static func _sort_metas(tile: Control, data: CardData, card_spec: Dictionary, saved_at: int) -> void:
	var mask := data.color_mask()
	var colors := 0
	var rank := 6
	var order := ["white", "blue", "black", "red", "green"]
	for i in order.size():
		if mask & int(CommunityCard.COLORS[order[i]]):
			colors += 1
			rank = i
	tile.set_meta("sort", {"name": data.card_name.to_lower(),
		"set": String(card_spec.get("set_name", "")).strip_edges().to_lower(),
		"color": rank if colors == 1 else (5 if colors > 1 else 6), "newest": -saved_at})


## Put the Open list's tiles in the order [param by] (a key of [constant
## OPEN_SORTS]): the examples first, then by it, then by name.
static func sort_open_list(grid: Container, by: String) -> void:
	var tiles := grid.get_children()
	var key := func(tile: Node) -> Array:
		var metas: Dictionary = tile.get_meta("sort", {})
		return [0 if tile.get_meta("example", false) else 1, metas.get(by, 0), String(metas.get("name", ""))]
	tiles.sort_custom(func(a: Node, b: Node) -> bool: return key.call(a) < key.call(b))
	for i in tiles.size():
		grid.move_child(tiles[i], i)


## THE SET-ASIDE SHELF: the zips moved out of play, each with its size,
## the day it was set aside and why it would be refused (if it would);
## Put back takes it into play again as any zip is taken, Delete (asked
## first) removes it for good.
func open_shelf() -> void:
	var rows := CommunityCards.set_aside_list()
	var dialog := OriginalDialog.create("Set aside — %s, %s" % [
		"1 card" if rows.size() == 1 else "%d cards" % rows.size(),
		PortableMode.size_words(CommunityCards.set_aside_size())], Vector2(700, 480))
	dialog.name = "ForgeShelfWindow"
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(660, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.name = "ForgeShelf"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	scroll.add_child(box)
	dialog.body().add_child(scroll)
	if rows.is_empty():
		box.add_child(UiChrome.body_label("Nothing is set aside.", 14))
	for row in rows:
		var file := String(row["file"])
		var line := HBoxContainer.new()
		line.name = "ForgeShelfRow%d" % box.get_child_count()
		line.add_theme_constant_override("separation", 8)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_theme_constant_override("separation", 0)
		var title := UiChrome.body_label("%s%s" % [String(row["name"]), " (a set zip)" if bool(row["set"]) else ""], 14)
		title.clip_text = true
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.tooltip_text = file
		title.mouse_filter = Control.MOUSE_FILTER_PASS
		words.add_child(title)
		var about := UiChrome.body_label("%s, set aside %s" % [PortableMode.size_words(int(row["bytes"])),
			Time.get_date_string_from_unix_time(int(row["when"]))], 12)
		about.modulate.a = 0.75
		words.add_child(about)
		if String(row["problem"]) != "":
			var problem := UiChrome.body_label(String(row["problem"]), 12)
			problem.name = "ForgeShelfProblem"
			problem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			problem.add_theme_color_override("font_color", Color(1.0, 0.62, 0.55))
			words.add_child(problem)
		line.add_child(words)
		var back := UiChrome.menu_button("Put back", Vector2(96, 30), 13)
		back.name = "ForgeShelfBack"
		back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		back.pressed.connect(func() -> void: shelf_put_back(file))
		line.add_child(back)
		var drop := UiChrome.menu_button("Delete", Vector2(80, 30), 13)
		drop.name = "ForgeShelfDelete"
		drop.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		drop.pressed.connect(func() -> void: ask_delete_aside(file, String(row["name"])))
		line.add_child(drop)
		box.add_child(line)
	var to_list := GauntletOptions.fit(dialog.add_button("Back"))
	to_list.pressed.connect(open_list)
	GauntletOptions.fit(dialog.add_button("Close")).pressed.connect(_close_dialog)
	_show(dialog, to_list)
	_fit_dialog(dialog, scroll, clampf(rows.size() * 52.0, 60, 320))


## Put the set-aside [param file] back into play (what happened is said;
## the shelf is shown again).
func shelf_put_back(file: String) -> void:
	var refusal := CardPacks.change_refusal()
	if refusal != "":
		_close_dialog()
		_say(refusal.replace("changing or rescanning card packs", "putting a card back"))
		return
	var why := CommunityCards.put_back(file)
	open_shelf()
	_say(why if why != "" else "%s is back in play." % file.get_basename())


## Delete the set-aside [param file] for good (asked first).
func ask_delete_aside(file: String, card_name: String) -> void:
	var dialog := OriginalDialog.create("Delete a card", Vector2(460, 180))
	dialog.name = "ForgeShelfDeleteWindow"
	var words := UiChrome.body_label("Delete the set-aside %s for good? It cannot be put back after." % card_name, 14)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size.x = 420
	dialog.body().add_child(words)
	GauntletOptions.fit(dialog.add_button("Delete")).pressed.connect(func() -> void:
		var gone := CommunityCards.delete_aside(file)
		open_shelf()
		_say("%s was deleted." % card_name if gone else "%s could not be deleted." % file))
	var cancel := GauntletOptions.fit(dialog.add_button("Cancel"))
	cancel.pressed.connect(open_shelf)
	_show(dialog, cancel)


## The empty picture a tile shows until its art is made.
static var _blank: Texture2D = null


static func _no_art() -> Texture2D:
	if _blank == null:
		var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		_blank = ImageTexture.create_from_image(image)
	return _blank


## Make the Open list's art a few pictures a frame (about 8 ms each frame),
## stopping when the list is gone.
func _fill_art_later(later: Array) -> void:
	var start := Time.get_ticks_msec()
	for item in later:
		if Time.get_ticks_msec() - start > 8:
			await get_tree().process_frame
			start = Time.get_ticks_msec()
		var held: Variant = item[0]
		if not is_instance_valid(held) or (held as Node).is_queued_for_deletion():
			return
		var mini := held as MiniCard
		var made := CommunityCards.art_texture(String(item[1]))
		if made != null:
			mini.art_override = made
			mini.refresh()


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
	if not load_spec(row["spec"], files.get("art", {}), files.get("icon", {})):
		refresh()   # the card that was on screen stays, shown again
		return
	_saved_name = ""
	_begin_card()
	_say("The example %s — change it, then Save to play it." % String(row["spec"]["name"]))


## Open the saved [param card_name]: false when it cannot be opened (said
## on the status line; the card on screen stays as it was).
func open_card(card_name: String) -> bool:
	# The saved card, not the one being made under the same name.
	CommunityCards.clear_draft()
	var found := CommunityCards.spec_of(card_name)
	var files := CommunityCards.files_of(card_name)
	if not load_spec(found, files.get("art", {}), files.get("icon", {})):
		refresh()   # the card that was on screen stays, shown again
		return false
	_saved_name = card_name
	_begin_card()
	_say("%s opened." % card_name)
	return true


## Delete a card saved in the own folder (asked first): the one on screen,
## or [param card_name] from the Open list ([param from_list]: the list is
## shown again after).
func ask_delete(card_name := "", from_list := false) -> void:
	if card_name == "":
		card_name = String(spec.get("name", "")).strip_edges()
	if CommunityCards.own_path_of(card_name) == "":
		return
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
		# The card on screen was that one: it is saved nowhere now, so it
		# is no clean card (Done asks) and Save writes it as a new one.
		var open_one := card_name.to_lower() == _saved_name.to_lower() \
			or card_name.to_lower() == String(spec.get("name", "")).strip_edges().to_lower()
		if open_one:
			_saved_name = ""
			_rename_from = ""
			_clean = {"spec": {}, "art": {}, "icon": {}}
			_say("%s was deleted. It is still on screen — Save to keep it." % card_name)
		else:
			_say("%s was deleted." % card_name)
		refresh()
		if from_list:
			open_list())
	var cancel := GauntletOptions.fit(dialog.add_button("Cancel"))
	cancel.pressed.connect(func() -> void:
		_close_dialog()
		if from_list:
			open_list())
	_show(dialog, cancel)


func _close_dialog() -> void:
	var was_list := is_instance_valid(_dialog) and _dialog.name == "ForgeOpenWindow"
	if is_instance_valid(_dialog):
		if _dialog.name == &"ForgeGameCardWindow":
			_game_run += 1   # its tile maker stops
			_game_grid = null
			_game_scroll = null
			_game_browse = null
			_game_detail = null
			_game_search = null
			_game_count = null
		# It is freed at the frame's end: the next prompt of the same kind,
		# put up before then, keeps its own name.
		_dialog.name = "ForgeClosed"
		if _dialog is OriginalDialog:
			(_dialog as OriginalDialog).dismiss()
		else:
			_dialog.queue_free()
	_dialog = null
	_default = null
	if is_instance_valid(_shade):
		_shade.name = "ForgeShadeClosed"
		_shade.queue_free()
	_shade = null
	if was_list:
		refresh()


func _mark_clean() -> void:
	_last_path = ""   # typing after a save is a step of its own
	_clean = {"spec": spec.duplicate(true), "art": art, "icon": icon}


## Whether the card differs from the one last saved, opened or begun.
func has_unsaved() -> bool:
	return not _clean.is_empty() and (_clean["spec"] != spec or _clean["art"] != art or _clean["icon"] != icon)


## Leave the creator — asking first when the card has unsaved changes
## (one Escape, an Android back gesture, never throws work away).
func close(force := false) -> void:
	if not force and has_unsaved():
		_ask_unsaved("Leave the card creator anyway?", "Leave", func() -> void: close(true))
		return
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
	if not is_visible_in_tree() or is_instance_valid(_dialog) or is_instance_valid(_test_host) \
			or not event is InputEventKey:
		return
	if event.is_action_pressed("ui_redo", false, true):
		get_viewport().set_input_as_handled()
		redo()
	elif event.is_action_pressed("ui_undo", false, true):
		get_viewport().set_input_as_handled()
		undo()


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_test_host):
		return   # the duel on top has the keys
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if is_instance_valid(_dialog):
			# One level at a time: a game card's summary, then its window.
			if not game_cards_back():
				_close_dialog()
		else:
			close()
