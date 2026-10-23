class_name WorldHud
extends Control
## THE WORLD SCREEN'S FLOATING ICONS (the owner, 2026-10-22: *"floating
## icons as a gui … a gold coin, a food ration and the five amulet gems,
## each with its count; the World Magics as small icons, lit when owned; a
## few floating buttons: map, journal or stats, deck, and save — base it on
## old 1997 frame icons for old feel"*; then *"put all in one row … a clean
## lean unobtrusive menu"*; then *"a floating rectangle panel with round
## corners, and inside icons, but the panel occupies whole horizontal
## space"*, with *"an options icon besides help … a dropdown menu — exit
## game, save, load, and an option to drop this panel to bottom of the
## screen"*). What the 1997 frame (`Advinter.pic`) held round its window,
## set free on one floating panel the width of the screen, as 1.3 drew it
## (`DrawAdventureInterfaceLayout`), in three groups the room shared out
## between them:
##  - what the hero carries: the frame's own strip — its painted gold,
##    food, ankh (the mana links, `CountDuelPoolEligibleTowns`) and book
##    (the deck, cards in use of cards owned), each a small tile of the
##    frame's glass with its number — and the five amulets (`Amsprite.spr`)
##    in the frame's order, black, blue, green, red, white;
##  - the twelve World Magics (`Worlds.spr`), lit when owned, an active one
##    whose colour has no amulet left pressed, as 1.3 shows it;
##  - the frame's round buttons (`Worlds.spr`): the deck's spellbook (F1),
##    the map's scroll (M) and the hero (F5, the journal and the stats) —
##    then ours: the frame's painted book for the options (save, load, the
##    panel to the top or the bottom, exit the game) and ? for the keys (H)
##    — 1997 kept those in its menus and had no help on the map.
## The hero's name and difficulty stand under the panel (over it when the
## panel is at the bottom) in the hero's colour of magic. Rest the pointer
## on a part and its name and what it does float beside the panel. Without
## the 1997 pictures each part is its word.

signal deck_pressed
signal map_pressed
signal hero_pressed
signal save_pressed
signal load_pressed
signal exit_pressed
## The pointer came over a part of the HUD: the world's pointers step aside.
signal hovered

## The frame's painted strip (`world_frame`, 1024 × 768): each icon on its
## own tile of glass.
const FRAME_ICONS := {"gold": Rect2i(58, 552, 84, 46), "food": Rect2i(206, 551, 78, 48),
	"ankh": Rect2i(326, 552, 70, 46), "book": Rect2i(454, 552, 80, 46)}
const STRIP: Array[String] = ["gold", "food", "ankh", "book"]
const STRIP_NAMES := {"gold": "Gold", "food": "Food", "ankh": "Mana links", "book": "Deck"}
const STRIP_TIPS := {"gold": "Buys cards, food and World Magics in the towns.",
	"food": "Eaten as you walk; with none left you walk slower.",
	"ankh": "Each town whose mana you have linked adds a life in your duels.",
	"book": "The cards in your deck, of all the cards you own."}
## `Amsprite.spr`'s frame for each colour (the file holds white, blue,
## black, red, green), in the frame's order.
const AMULETS := [["black", 2], ["blue", 1], ["green", 4], ["red", 3], ["white", 0]]
## `Worlds.spr` rows: the twelve icons normal, lit, pressed (the five
## active ones), their keys; then the menu buttons normal and lit.
const MAGIC_CELL := Vector2(52, 54)
const ROW_NORMAL := 0
const ROW_PRESSED := 2
## The round buttons: name, `Worlds.spr` frame (the lit one follows it),
## key, what it does.
const BUTTONS := [["Deck", 48, "F1", "Your cards and your deck."],
	["Map", 50, "M", "The map of the land you have seen."],
	["Hero", 54, "F5", "Your hero's journal and stats."]]
## What each World Magic does, for its tip.
const MAGIC_TIPS := {
	"Sleight of Hand": "Before a duel, you may draw a new hand once.",
	"Haggler's Coin": "Cards sell for more in the towns.",
	"Conjurer's Will": "Change your deck out in the wilds (spends a black amulet).",
	"Amulet of Swampwalk": "Swamps no longer slow you.",
	"Leap of Fate": "Leap to a place on the map at random (spends a blue amulet).",
	"Tome of Enlightenment": "One more copy of a card allowed in your deck.",
	"Quickening": "Walk at double pace for a while (spends a green amulet).",
	"Fruit of Sustenance": "Forests feed you as you walk.",
	"Staff of Thunder": "Strike the nearest roaming creature from the map (spends a red amulet).",
	"Dwarven Pick": "Mountains no longer slow you.",
	"Sword of Resistance": "Go at once to a town under siege (spends a white amulet).",
	"Ring of the Guardian": "The wizards need more towns before they can win.",
}
## The keys, for the help (?): what the line under the world once said.
const KEYS := [["Click", "walk there; the way is found"],
	["Drag or arrows", "look around (W A S D too)"],
	["Wheel", "zoom (+ and - too)"],
	["Space", "back to your hero"],
	["M", "the map (M or Escape closes it)"],
	["F1", "your deck"],
	["F5", "your hero's journal and stats"],
	["Ctrl+S", "save the adventure"],
	["H", "these keys"],
	["Escape", "close what is open, or leave the world"]]
## The options' entries: name and words. `Bar` says where the panel goes.
const OPTIONS := [["Save", "Save"], ["Load", "Load"], ["Bar", ""], ["Exit", "Exit game"]]
## Where the panel stands, remembered for the next adventure.
const BAR_SETTING := "world_bar_at_bottom"
## The hero's name in their colour of magic, each with the edge it reads
## on over the land.
const NAME_INKS := {"white": [Color8(250, 246, 232), Color8(20, 10, 8)],
	"blue": [Color8(96, 160, 255), Color8(10, 12, 30)],
	"black": [Color8(26, 20, 30), Color8(214, 204, 188)],
	"red": [Color8(242, 78, 54), Color8(24, 6, 4)],
	"green": [Color8(86, 206, 98), Color8(6, 20, 8)]}
## The icons' height in the row.
const HEIGHT := 28.0
## How long the pointer rests on a part before its name floats beside the
## panel.
const HOVER_SECONDS := 0.6
## How long a notice stays.
const NOTICE_SECONDS := 3.5
const INK := Color8(236, 222, 196)
const GOLD := Color8(232, 190, 110)
const LIT := Color8(255, 236, 170)
const EDGE := Color8(20, 10, 8)

var player: AdventurePlayer
var art := WorldArt.new()
var buttons := {}
## True while the panel stands at the bottom of the screen.
var bar_at_bottom := false
var _top: VBoxContainer
var _bar: PanelContainer
var _under: MarginContainer
var _name: Label
var _numbers := {}
var _amulet_numbers := {}
var _magic_icons: Array[TextureRect] = []
var _magic_names: Label
var _hero_panel: PanelContainer
var _hero_text: Label
var _help_panel: PanelContainer
var _options_menu: PanelContainer
var _notice: Label
var _tip: PanelContainer
var _tip_name: Label
var _tip_text: Label
## The part under the pointer, and how long it has rested there.
var _hover: Control
var _rested := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top = VBoxContainer.new()
	_top.name = "Top"
	_top.add_theme_constant_override("separation", 3)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top)
	_bar = PanelContainer.new()
	_bar.name = "Bar"
	var face := _glass(0.62, 0.35, 8)
	face.content_margin_left = 10
	face.content_margin_right = 10
	face.content_margin_top = 4
	face.content_margin_bottom = 4
	_bar.add_theme_stylebox_override("panel", face)
	# The panel's gaps take a click too: it never walks the hero.
	_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_bar.mouse_entered.connect(func() -> void: hovered.emit())
	_top.add_child(_bar)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(row)
	_name = _label("", 16)
	_name.name = "HeroLine"
	_name.add_theme_constant_override("outline_size", 4)
	_name.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_under = MarginContainer.new()
	_under.name = "Under"
	_under.add_theme_constant_override("margin_left", 6)
	_under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_under.add_child(_name)
	_top.add_child(_under)
	for key in STRIP:
		var slot := _slot("Strip_" + key, "strip:" + key)
		var icon := _frame_icon(key, HEIGHT)
		slot.add_child(icon if icon != null else _label(STRIP_NAMES[key], 13, GOLD))
		_numbers[key] = _number(slot)
		row.add_child(slot)
	row.add_child(_divider())
	for gem in AMULETS:
		var slot := _slot("Amulet_" + gem[0], "amulet:" + gem[0])
		slot.add_child(_amulet_icon(gem[0], int(gem[1])))
		_amulet_numbers[gem[0]] = _number(slot)
		row.add_child(slot)
	row.add_child(_room("RoomBeforeMagics"))
	var magics := HBoxContainer.new()
	magics.name = "WorldMagics"
	magics.add_theme_constant_override("separation", 1)
	magics.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if art.texture("world_magics") != null:
		for i in AdventurePlayer.WORLD_MAGICS.size():
			var icon := TextureRect.new()
			icon.name = "Magic_%d" % i
			icon.custom_minimum_size = MAGIC_CELL * (HEIGHT / MAGIC_CELL.y)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_rests_the_pointer(icon, "magic:%d" % i)
			magics.add_child(icon)
			_magic_icons.append(icon)
	else:
		_magic_names = _label("", 13, GOLD)
		_magic_names.name = "MagicNames"
		magics.add_child(_magic_names)
	row.add_child(magics)
	row.add_child(_room("RoomBeforeButtons"))
	var round_buttons := HBoxContainer.new()
	round_buttons.name = "Buttons"
	round_buttons.add_theme_constant_override("separation", 4)
	round_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for button_row in BUTTONS:
		round_buttons.add_child(_round_button(button_row[0], int(button_row[1])))
	round_buttons.add_child(_options_button())
	round_buttons.add_child(_help_button())
	row.add_child(round_buttons)
	buttons["Deck"].pressed.connect(func() -> void: deck_pressed.emit())
	buttons["Map"].pressed.connect(func() -> void: map_pressed.emit())
	buttons["Hero"].pressed.connect(func() -> void: hero_pressed.emit())
	buttons["Options"].pressed.connect(toggle_options)
	buttons["Help"].pressed.connect(toggle_help)
	for key in buttons:
		var button: BaseButton = buttons[key]
		_rests_the_pointer(button, "button:" + key)
		button.pressed.connect(_hide_tip)
	_hero_panel = _panel("HeroPanel")
	_hero_text = _label("", 15)
	_hero_text.name = "HeroText"
	_hero_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_hero_panel.add_child(_hero_text)
	_help_panel = _panel("HelpPanel")
	_help_panel.add_child(_keys_grid())
	_options_menu = _panel("OptionsMenu")
	var face_menu := _glass(0.9, 0.6, 8)
	face_menu.set_content_margin_all(6)
	_options_menu.add_theme_stylebox_override("panel", face_menu)
	var entries := VBoxContainer.new()
	entries.add_theme_constant_override("separation", 1)
	for entry in OPTIONS:
		entries.add_child(_menu_entry(entry[0], entry[1]))
	_options_menu.add_child(entries)
	_notice = _label("", 17, GOLD)
	_notice.name = "Notice"
	_notice.add_theme_stylebox_override("normal", _glass(0.75, 0.0, 6))
	_notice.visible = false
	add_child(_notice)
	_tip = PanelContainer.new()
	_tip.name = "Tip"
	_tip.add_theme_stylebox_override("panel", _glass(0.86, 0.5, 6))
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 0)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_child(lines)
	_tip_name = _label("", 15, GOLD)
	_tip_name.name = "TipName"
	lines.add_child(_tip_name)
	_tip_text = _label("", 13)
	_tip_text.name = "TipText"
	lines.add_child(_tip_text)
	add_child(_tip)
	set_process(false)
	place_bar(bool(Settings.get_value(BAR_SETTING, false)), false)
	if player != null:
		refresh()


## Show [param adventure]'s purse, amulets and World Magics.
func show_player(adventure: AdventurePlayer) -> void:
	player = adventure
	if is_node_ready():
		refresh()


## The numbers and the lit icons, as the hero now stands.
func refresh() -> void:
	if player == null or _name == null:
		return
	_name.text = "%s · %s" % [player.name, player.difficulty_name()] if player.name != "" else ""
	var inks: Array = NAME_INKS.get(player.color, [INK, EDGE])
	_name.add_theme_color_override("font_color", inks[0])
	_name.add_theme_color_override("font_outline_color", inks[1])
	_numbers["gold"].text = str(player.gold)
	_numbers["food"].text = str(player.food)
	_numbers["ankh"].text = str(player.mana_links.size())
	_numbers["book"].text = "%d/%d" % [cards_in_deck(), player.cards.size()]
	for gem in AMULETS:
		_amulet_numbers[gem[0]].text = str(int(player.amulets.get(gem[0], 0)))
	for i in _magic_icons.size():
		_show_magic(i)
	if _magic_names != null:
		_magic_names.text = "World Magics: " + (", ".join(player.world_magics) if not player.world_magics.is_empty() else "none")


func cards_in_deck() -> int:
	var count := 0
	for card in player.cards:
		if (card as Dictionary).get("decks", []).has(player.current_deck):
			count += 1
	return count


## Whether World Magic [param i] shows lit: owned, and for an active one
## an amulet of its colour left to spend.
func magic_lit(i: int) -> bool:
	var magic: String = AdventurePlayer.WORLD_MAGICS[i]
	if not player.owns(magic):
		return false
	if _active(i):
		return int(player.amulets.get(_amulet_of(i), 0)) > 0
	return true


## The five World Magics that spend an amulet: every second one from the
## third, black's to white's.
static func _active(i: int) -> bool:
	return i >= 2 and i % 2 == 0


static func _amulet_of(i: int) -> String:
	return AdventurePlayer.COLORS[i / 2 - 1]


func _show_magic(i: int) -> void:
	var icon := _magic_icons[i]
	var owned := player.owns(AdventurePlayer.WORLD_MAGICS[i])
	var row := ROW_PRESSED if owned and _active(i) and not magic_lit(i) else ROW_NORMAL
	icon.texture = _cell("world_magics", row * 12 + i)
	icon.modulate = Color.WHITE if owned else Color(0.5, 0.47, 0.45, 0.72)


# ------------------------------------------------------ where it stands --

## THE PANEL AT THE TOP OR THE BOTTOM of the screen (the options), the name
## on the side away from the edge; remembered unless [param remember] is
## false.
func place_bar(at_bottom: bool, remember := true) -> void:
	bar_at_bottom = at_bottom
	close_panels()
	_hide_tip()
	if at_bottom:
		_top.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		_top.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_top.offset_top = -8
		_top.offset_bottom = -8
		_top.move_child(_under, 0)
	else:
		_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
		_top.grow_vertical = Control.GROW_DIRECTION_END
		_top.offset_top = 8
		_top.offset_bottom = 8
		_top.move_child(_under, 1)
	_top.offset_left = 12
	_top.offset_right = -12
	var entry := _options_menu.find_child("Option_Bar", true, false) as Button
	entry.text = "Panel at the top" if at_bottom else "Panel at the bottom"
	if remember:
		Settings.set_value(BAR_SETTING, at_bottom)


# ------------------------------------------------------- the panels --

## THE HERO (the frame's faces, F5): the journal and the stats, floating
## beside the panel; again to close it.
func toggle_hero() -> void:
	_hero_text.text = "\n".join(hero_lines())
	_open(_hero_panel, not _hero_panel.visible, buttons["Hero"])


func hero_shown() -> bool:
	return _hero_panel != null and _hero_panel.visible


## THE KEYS (?, H): what the line under the world once said.
func toggle_help() -> void:
	_open(_help_panel, not _help_panel.visible, buttons["Help"])


func help_shown() -> bool:
	return _help_panel != null and _help_panel.visible


## THE OPTIONS (the painted book): save, load, the panel to the other
## edge, exit.
func toggle_options() -> void:
	_open(_options_menu, not _options_menu.visible, buttons["Options"])


func options_shown() -> bool:
	return _options_menu != null and _options_menu.visible


## Close the options; true when they were open.
func close_options() -> bool:
	var was := options_shown()
	_options_menu.visible = false
	return was


## Close the hero's panel, the keys and the options; true when one was
## open.
func close_panels() -> bool:
	var was := hero_shown() or help_shown() or options_shown()
	for panel in [_hero_panel, _help_panel, _options_menu]:
		(panel as Control).visible = false
	return was


## What the hero's panel says: who they are, what they carry, their record
## and the clocks.
func hero_lines() -> Array[String]:
	var lines: Array[String] = []
	if player == null:
		return lines
	var color := AdventureSetup.color_row(player.color)
	lines.append("%s, a %s mage" % [player.name, String(color.get("name", player.color)).to_lower()])
	lines.append("%s: %s" % [player.difficulty_name(), AdventureSetup.difficulty_phrase(player.difficulty)])
	lines.append("")
	lines.append("%d gold · %d food · %d mana %s" % [player.gold, player.food, player.mana_links.size(),
		"link" if player.mana_links.size() == 1 else "links"])
	var gems: Array[String] = []
	for gem in AMULETS:
		gems.append("%s %d" % [gem[0], int(player.amulets.get(gem[0], 0))])
	lines.append("Amulets: " + ", ".join(gems))
	lines.append("World Magics: " + (", ".join(player.world_magics) if not player.world_magics.is_empty() else "none"))
	lines.append("Cards: %d" % player.cards.size() + ("" if not player.cards.is_empty() else " (the starting deck is yet to come)"))
	lines.append("")
	var record := player.duel_record()
	lines.append("Duels: %d won, %d lost · lairs explored: %d" % [record["won"], record["lost"], player.lairs_explored])
	var seconds := int(player.monster_timer * HeroWalk.TICK)
	lines.append("In the world: %d min %02d s" % [seconds / 60, seconds % 60])
	lines.append("World seed %s" % player.world_seed_text)
	lines.append("")
	if player.journal.is_empty():
		lines.append("Journal: nothing written yet.")
	else:
		lines.append("Journal:")
		for entry in player.journal.slice(maxi(player.journal.size() - 6, 0)):
			lines.append("  " + str(entry))
	return lines


## A short notice beside the panel, gone after [constant NOTICE_SECONDS].
func say(text: String) -> void:
	_notice.text = text
	_notice.visible = true
	_notice.modulate.a = 1.0
	_notice.reset_size()
	var bar := _bar_rect()
	var x := _fit_x(bar.end.x - _notice.size.x, _notice.size.x)
	if bar_at_bottom:
		var above := bar.position.y
		for panel in [_hero_panel, _help_panel]:
			if (panel as Control).visible:
				above = minf(above, (panel as Control).position.y)
		_notice.position = Vector2(x, above - 6 - _notice.size.y)
	else:
		var under := bar.end.y
		for panel in [_hero_panel, _help_panel]:
			if (panel as Control).visible:
				under = maxf(under, (panel as Control).position.y + (panel as Control).size.y)
		_notice.position = Vector2(x, under + 6)
	if is_inside_tree():
		var fade := create_tween()
		fade.tween_interval(NOTICE_SECONDS)
		fade.tween_property(_notice, "modulate:a", 0.0, 0.8)
		fade.tween_callback(func() -> void: _notice.visible = false)


func notice() -> String:
	return _notice.text if _notice != null and _notice.visible else ""


func _open(panel: PanelContainer, shown: bool, beside: Control) -> void:
	close_panels()
	panel.visible = shown
	if shown:
		panel.reset_size()
		_float(panel, _rect_of(beside).end.x - panel.size.x, 6.0)


## [param part] floating beside the panel — under it, or over it when the
## panel is at the bottom — from [param x], [param gap] away.
func _float(part: Control, x: float, gap: float) -> void:
	var bar := _bar_rect()
	var y := bar.position.y - gap - part.size.y if bar_at_bottom else bar.end.y + gap
	part.position = Vector2(_fit_x(x, part.size.x), y)


func _panel(panel_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name
	var face := _glass(0.86, 0.6, 8)
	face.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", face)
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_entered.connect(func() -> void: hovered.emit())
	add_child(panel)
	return panel


func _keys_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.name = "Keys"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 2)
	for pair in KEYS:
		grid.add_child(_label(pair[0], 15, GOLD))
		grid.add_child(_label(pair[1], 15))
	return grid


## The keys as the help shows them, a line each.
func key_lines() -> Array[String]:
	var lines: Array[String] = []
	for pair in KEYS:
		lines.append("%s: %s" % pair)
	return lines


## One of the options: lettered like the panels, lit under the pointer.
func _menu_entry(entry_name: String, words: String) -> Button:
	var entry := Button.new()
	entry.name = "Option_" + entry_name
	entry.text = words
	entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
	entry.focus_mode = Control.FOCUS_NONE
	entry.custom_minimum_size = Vector2(170, 0)
	var face := GameSkin.font("font_title")
	if face != null:
		entry.add_theme_font_override("font", face)
	entry.add_theme_font_size_override("font_size", 16)
	entry.add_theme_color_override("font_color", INK)
	entry.add_theme_color_override("font_hover_color", LIT)
	entry.add_theme_color_override("font_pressed_color", LIT)
	var rest := StyleBoxFlat.new()
	rest.bg_color = Color(0, 0, 0, 0)
	rest.set_corner_radius_all(4)
	rest.content_margin_left = 10
	rest.content_margin_right = 10
	rest.content_margin_top = 3
	rest.content_margin_bottom = 3
	var lit := rest.duplicate() as StyleBoxFlat
	lit.bg_color = Color(GOLD, 0.18)
	entry.add_theme_stylebox_override("normal", rest)
	entry.add_theme_stylebox_override("hover", lit)
	entry.add_theme_stylebox_override("pressed", lit)
	entry.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	entry.pressed.connect(func() -> void: _choose(entry_name))
	return entry


## What an option does when chosen.
func _choose(entry_name: String) -> void:
	close_options()
	match entry_name:
		"Save":
			save_pressed.emit()
		"Load":
			load_pressed.emit()
		"Bar":
			place_bar(not bar_at_bottom)
		"Exit":
			exit_pressed.emit()


# ---------------------------------------------------------- the tips --

## [param part] shows its name after the pointer rests on it, and takes
## its click from the world.
func _rests_the_pointer(part: Control, tip: String) -> void:
	part.mouse_filter = Control.MOUSE_FILTER_STOP
	part.set_meta("tip", tip)
	part.mouse_entered.connect(func() -> void:
		hovered.emit()
		_hover = part
		_rested = 0.0
		_tip.visible = false
		set_process(true))
	part.mouse_exited.connect(func() -> void:
		if _hover == part:
			_hide_tip())


func _process(delta: float) -> void:
	if _hover == null or not is_instance_valid(_hover) or not _hover.is_visible_in_tree():
		_hide_tip()
		return
	_rested += delta
	if _rested >= HOVER_SECONDS and not _tip.visible:
		show_tip(_hover)


## The name of [param part] and what it does, floating beside the panel by
## it.
func show_tip(part: Control) -> void:
	var lines := tip_for(String(part.get_meta("tip", "")))
	if lines.is_empty():
		return
	_tip_name.text = lines[0]
	_tip_text.text = lines[1]
	_tip_text.visible = lines[1] != ""
	_tip.visible = true
	_tip.reset_size()
	_float(_tip, _rect_of(part).get_center().x - _tip.size.x * 0.5, 4.0)


func tip_shown() -> String:
	return _tip_name.text if _tip != null and _tip.visible else ""


func _hide_tip() -> void:
	_hover = null
	_rested = 0.0
	if _tip != null:
		_tip.visible = false
	set_process(false)


## `[name, what it does]` for a part's [param tip] key.
func tip_for(tip: String) -> Array[String]:
	var kind := tip.get_slice(":", 0)
	var key := tip.get_slice(":", 1)
	match kind:
		"strip":
			return [STRIP_NAMES[key], STRIP_TIPS[key]]
		"amulet":
			var spends := ""
			for i in AdventurePlayer.WORLD_MAGICS.size():
				if _active(i) and _amulet_of(i) == key:
					spends = AdventurePlayer.WORLD_MAGICS[i]
			return ["%s amulet" % key.capitalize(), "Each one powers %s once." % spends]
		"magic":
			var i := int(key)
			var magic: String = AdventurePlayer.WORLD_MAGICS[i]
			var state := ""
			if player != null and not player.owns(magic):
				state = " Not yours yet."
			elif player != null and _active(i) and not magic_lit(i):
				state = " No %s amulet left to power it." % _amulet_of(i)
			return [magic, MAGIC_TIPS[magic] + state]
		"button":
			match key:
				"Options":
					return ["Options", "Save, load, the panel at the top or the bottom, exit the game."]
				"Help":
					return ["Keys (H)", "How to walk, look and the keys."]
			for button_row in BUTTONS:
				if button_row[0] == key:
					return ["%s (%s)" % [key, button_row[2]], String(button_row[3])]
	return []


# ------------------------------------------------------------ the parts --

func _label(text: String, size: int, color := INK) -> Label:
	var label := Label.new()
	label.text = text
	var face := GameSkin.font("font_title")
	if face != null and size >= 15:
		label.add_theme_font_override("font", face)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Dark glass, as the floating parts wear it.
func _glass(alpha: float, rim: float, corner: int) -> StyleBoxFlat:
	var face := StyleBoxFlat.new()
	face.bg_color = Color(0.05, 0.03, 0.03, alpha)
	if rim > 0.0:
		face.border_color = Color(GOLD, rim)
		face.set_border_width_all(1)
	face.set_corner_radius_all(corner)
	face.content_margin_left = 8
	face.content_margin_right = 8
	face.content_margin_top = 3
	face.content_margin_bottom = 3
	return face


func _slot(slot_name: String, tip: String) -> HBoxContainer:
	var slot := HBoxContainer.new()
	slot.name = slot_name
	slot.add_theme_constant_override("separation", 3)
	_rests_the_pointer(slot, tip)
	return slot


func _number(slot: HBoxContainer) -> Label:
	var number := _label("0", 16)
	number.name = "Number"
	slot.add_child(number)
	return number


## The room between the three groups: the panel's width left over, shared
## out evenly.
func _room(room_name: String) -> Control:
	var room := Control.new()
	room.name = room_name
	room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return room


## A thin gold line between the purse and the amulets.
func _divider() -> Control:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(1, HEIGHT - 6)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.color = Color(GOLD, 0.3)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _frame_icon(key: String, tall: float) -> TextureRect:
	var frame := GameSkin.texture("world_frame")
	if frame == null:
		return null
	var cut := AtlasTexture.new()
	cut.atlas = frame
	cut.region = Rect2(FRAME_ICONS[key])
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = cut
	icon.custom_minimum_size = Vector2(FRAME_ICONS[key].size) * (tall / FRAME_ICONS[key].size.y)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _amulet_icon(color: String, frame: int) -> Control:
	var sheet := art.texture("world_amulets")
	if sheet == null:
		var disc := ColorRect.new()
		disc.custom_minimum_size = Vector2(12, 12)
		disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		disc.color = {"black": Color8(60, 50, 60), "blue": Color8(60, 120, 220), "green": Color8(50, 160, 70),
			"red": Color8(210, 50, 40), "white": Color8(240, 236, 220)}[color]
		disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return disc
	var icon := TextureRect.new()
	icon.texture = _cell("world_amulets", frame)
	icon.custom_minimum_size = Vector2(12, 17) * (HEIGHT - 4.0) / 17.0
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _cell(key: String, frame: int) -> AtlasTexture:
	var cut := AtlasTexture.new()
	cut.atlas = art.texture(key)
	cut.region = art.frame_rect(key, frame)
	return cut


## A round button from `Worlds.spr`: its frame at rest, the next one lit.
func _round_button(button_name: String, frame: int) -> BaseButton:
	var button: BaseButton
	if art.texture("world_magics") != null:
		var round := TextureButton.new()
		round.texture_normal = _cell("world_magics", frame)
		round.texture_hover = _cell("world_magics", frame + 1)
		round.texture_pressed = _cell("world_magics", frame + 1)
		round.ignore_texture_size = true
		round.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		round.custom_minimum_size = MAGIC_CELL * ((HEIGHT + 2.0) / MAGIC_CELL.y)
		button = round
	else:
		button = UiChrome.menu_button(button_name, Vector2(54, HEIGHT), 12)
	button.name = button_name
	button.focus_mode = Control.FOCUS_NONE
	buttons[button_name] = button
	return button


## The options: the frame's painted book on its glass (the owner: *"keep
## the save icon … but the icon now means options"*).
func _options_button() -> BaseButton:
	var button: BaseButton
	var icon := _frame_icon("book", HEIGHT)
	if icon != null:
		var book := TextureButton.new()
		book.texture_normal = icon.texture
		book.ignore_texture_size = true
		book.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		book.custom_minimum_size = icon.custom_minimum_size
		book.mouse_entered.connect(func() -> void: book.modulate = Color(1.25, 1.18, 1.0))
		book.mouse_exited.connect(func() -> void: book.modulate = Color.WHITE)
		button = book
		icon.free()
	else:
		button = UiChrome.menu_button("Options", Vector2(64, HEIGHT), 12)
	button.name = "Options"
	button.focus_mode = Control.FOCUS_NONE
	buttons["Options"] = button
	return button


## ?: the keys, lettered in the title face as the buttons' gold.
func _help_button() -> Button:
	var button := Button.new()
	button.name = "Help"
	button.text = "?"
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(22, HEIGHT)
	var face := GameSkin.font("font_title")
	if face != null:
		button.add_theme_font_override("font", face)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", GOLD)
	button.add_theme_color_override("font_hover_color", LIT)
	button.add_theme_color_override("font_pressed_color", LIT)
	button.add_theme_color_override("font_outline_color", EDGE)
	button.add_theme_constant_override("outline_size", 4)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	buttons["Help"] = button
	return button


# ------------------------------------------------------------ placing --

func _rect_of(part: Control) -> Rect2:
	var rect := part.get_global_rect()
	rect.position -= get_global_rect().position
	return rect


func _bar_rect() -> Rect2:
	return _rect_of(_bar)


## [param x] kept so [param width] stays on the screen.
func _fit_x(x: float, width: float) -> float:
	return clampf(x, 8.0, maxf(8.0, size.x - width - 8.0))
