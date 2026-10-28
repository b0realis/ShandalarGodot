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
##    — 1997 kept those in its menus and had no help on the map. A right
##    click on the world opens the options at the pointer, as 1997's right
##    button opened its "Will you ..." menu ([method toggle_options_at]);
##    F6 opens the hero's pane on its Wizards tab ([method toggle_wizards]).
## The hero's name and difficulty stand under the panel (over it when the
## panel is at the bottom) in the hero's colour of magic. Rest the pointer
## on a part and its name and what it does float beside the panel. Without
## the 1997 pictures each part is its word.
## While a pane holds the world screen the panel RESTS ([method rest]): it
## shows what the hero carries, its numbers kept current, but answers
## nothing.

signal deck_pressed
signal map_pressed
signal hero_pressed
signal save_pressed
signal load_pressed
signal exit_pressed
## Return to main menu (the options).
signal menu_pressed
## The dungeon clues (the frame's gate, F4): the world screen opens their
## pane ([method WorldScreen.show_clues], [CluesPane]).
signal clues_pressed
## The options' City list (F3).
signal city_list_pressed
## The journal, to be walked on the map.
signal journal_map_pressed
## The small map was clicked: walk to [param tile].
signal walk_requested(tile: Vector2i)
## A World Magic's icon was clicked: cast key [param key] (1–5).
signal cast_pressed(key: int)
## Big buttons were switched (the options): the panel is to be made again
## at the other size.
signal big_switched
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
const ROW_LIT := 1
const ROW_PRESSED := 2
const ROW_KEYS := 3
## The round buttons: name, `Worlds.spr` frame (the lit one follows it),
## key, what it does.
const BUTTONS := [["Deck", 48, "F1", "Your cards and your deck."],
	["Map", 50, "M", "The map of the land you have seen."],
	["Clues", 52, "F4", "What you have learned of the dungeons."],
	["Hero", 54, "F5", "Your hero's journal and stats."]]
## What each World Magic does, for its tip: the 1997 words
## (`@WORLDMAGIC_EXPLAINS`).
const MAGIC_TIPS := {
	"Sleight of Hand": "A clever duelist can switch antes. An ethical one won't.",
	"Haggler's Coin": "Each village and city offers more cards for sale.",
	"Conjurer's Will": "Risk one black amulet to adjust your deck outdoors.",
	"Amulet of Swampwalk": "The Dragonfly provides a way to fly through swamps unslowed.",
	"Leap of Fate": "Risk one blue amulet to instantly cross any distance.",
	"Tome of Enlightenment": "The limit on duplicate spells in your deck is eased by one.",
	"Quickening": "Risk one green amulet for a temporary burst of speed.",
	"Fruit of Sustenance": "In the forests, you gain more food than you can eat.",
	"Staff of Thunder": "Risk one red amulet to destroy the nearest creature.",
	"Dwarven Pick": "Ancient power in this pick hastens mountain travels.",
	"Sword of Resistance": "Risk one white amulet to reach a city under siege.",
	"Ring of the Guardian": "The wizards now need 5 mana taps to cast Dominion.",
}
## The keys, for the help (?): what the line under the world once said —
## the world's keys ([method WorldScreen._unhandled_input]), 1997's where
## they were 1997's (adventure_input.c 304–503: F1–F6, L, Escape and Q,
## Space; the stats screen's W, J and D), [QoL] where they are ours: a
## click walks — the arrows look, where 1997's walked the hero — and the
## wheel, N, H and the panes' drag are new. Save stays Ctrl+S (the owner's
## ruling C-2: W A S D keep looking; 1997's S saved).
const KEYS := [["Click", "walk there; the way is found"],
	["Right click", "the options"],
	["Drag or arrows", "look around (W A S D too)"],
	["Wheel", "zoom (+ and - too)"],
	["Space", "back to your hero; stops the walk"],
	["1 to 5", "cast a World Magic (or click its icon)"],
	["M or F2", "the map (M or Escape closes it)"],
	["N", "the small map"],
	["F1", "your deck"],
	["F3", "the cities you have visited"],
	["F4", "the dungeon and castle clues"],
	["F5", "your hero's journal and stats"],
	["F6", "the wizards"],
	["W, J, D", "with your hero's pane open: the wizards, the journal; D closes it"],
	["Ctrl+S", "save the adventure"],
	["L", "load an adventure"],
	["H", "these keys"],
	["Drag a pane", "move it; it stays there"],
	["Escape or Q", "close what is open, or ask to leave the world (save and load there too)"]]
## The options' entries: name and words; the switches say how they stand
## ([method _option_words]). Save to Wizards are 1997's right-click menu's
## ("Will you ...", `@STARTUP` 1).
const OPTIONS := [["Save", "Save"], ["Load", "Load (L)"], ["Cities", "City list (F3)"],
	["Wizards", "Wizards (F6)"], ["Bar", ""], ["Minimap", ""],
	["Quest", ""], ["Guides", ""], ["Places", ""], ["Reader", ""], ["Big", ""], ["Pace", ""],
	["Transitions", ""], ["Music", ""], ["Sound", ""],
	["Menu", "Return to main menu"], ["Exit", "Exit game"]]
## The hero pane's tab 1997's wizards' window became ([HeroStats]).
const WIZARDS_TAB := "Wizards"
const HERO_TAB := "Hero"
## The switches that leave the options open, so the new setting shows.
const SWITCHES: Array[String] = ["Minimap", "Quest", "Guides", "Places", "Reader", "Pace", "Transitions",
	"Music", "Sound"]
## BIG BUTTONS, for a finger (the owner, 2026-10-23: *"touch-pad support?
## Maybe we can have bigger buttons on the pane with left and right arrows
## at the distal ends for touch"*) [QoL]: the panel and its options made
## [constant BIG] times the size, the panel's row scrolling under the
## finger between two red arrows at its ends. On by itself where the
## game's touch layer is ([TouchControls]); the options switch it,
## remembered.
const BIG_SETTING := "world_big_buttons"
const BIG := 1.6
## Where the panel stands, remembered for the next adventure.
const BAR_SETTING := "world_bar_at_bottom"
## Whether the small map, the quest pane and the guide arrows show,
## remembered.
const MINIMAP_SETTING := "world_minimap"
const QUEST_SETTING := "world_quest_pane"
const GUIDES_SETTING := "world_guides"
## Whether a place's kind and name float by the pointer over it (the owner,
## 2026-10-23: *"when you hover over a place with mouse a floating helper
## text with place category and name are displayed … turned on/off in
## menu drop down pane"*).
const PLACES_SETTING := "world_place_names"
## Whether a right click on a card in the shop, the card trader or a lair
## opens it full screen, as the duel's reader does (the owner, 2026-10-23:
## *"Right click on card should have large card render as in the duel! …
## And add to on/off to options dropdown"*).
const READER_SETTING := "world_card_reader"
## Where a pane was dragged to, by its name: `[x, y]` on the screen.
const PANE_SETTING := "world_pane_"
## A press that moves no further than this is a click on a pane.
const PANE_SLOP := 4.0
## How fast the world's clock runs against the 1997 game's 60 ms tick
## [QoL]: the hero walks faster, and everything else in the world keeps
## pace with them, so a day's march costs the same food.
const PACE_SETTING := "world_pace"
const PACES := [[1.0, "as in 1997"], [1.5, "brisk"], [2.0, "swift"]]
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
## The small map in the corner away from the panel ([WorldMinimap]).
var minimap: WorldMinimap
## Whether the panel is made for a finger ([constant BIG]); read as the
## panel is made, from [method big_wanted].
var big := false
var _row_scroll: ScrollContainer
var _arrows := {}
## The pane being dragged: `{pane, grip, from, moved}`.
var _drag := {}
## The notice's fade, stopped when a new notice comes.
var _notice_fade: Tween
## The hero line's colour, set when it changes; the hero pane's last look.
var _inked := ""
var _hero_seen := ""
var _quest_pane: PanelContainer
var _quest_lines: Label
## The quest's clock and the next duel's gifts beside its lines ([QuestClock]).
var _quest_clock: QuestClock
var _gift_icons: HBoxContainer
var _key_marks: Array[TextureRect] = []
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
## The hero's stats in their pane ([HeroStats]).
var hero_stats: HeroStats
var _help_panel: PanelContainer
var _options_menu: PanelContainer
var _notice: Label
var _tip: PanelContainer
var _tip_name: Label
var _tip_text: Label
var _place_tip: PanelContainer
var _place_name: Label
var _place_kind: Label
## The part under the pointer, and how long it has rested there.
var _hover: Control
var _rested := 0.0
## True while the panel rests under a pane ([method rest]).
var resting := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	big = big_wanted()
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
	# The row between its two arrows; it scrolls only with big buttons.
	var ends := HBoxContainer.new()
	ends.name = "Ends"
	ends.add_theme_constant_override("separation", 4)
	ends.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(ends)
	_row_scroll = ScrollContainer.new()
	_row_scroll.name = "RowScroll"
	_row_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_row_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER if big \
		else ScrollContainer.SCROLL_MODE_DISABLED
	_row_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	var row := HBoxContainer.new()
	row.name = "Row"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", int(10 * _k()))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row_scroll.add_child(row)
	for side in [-1, 1]:
		var arrow := RedArrow.new(side, _tall())
		arrow.name = "ArrowLeft" if side < 0 else "ArrowRight"
		arrow.focus_mode = Control.FOCUS_NONE
		arrow.visible = false
		arrow.pressed.connect(scroll_row.bind(side))
		_arrows[side] = arrow
	ends.add_child(_arrows[-1])
	ends.add_child(_row_scroll)
	ends.add_child(_arrows[1])
	_row_scroll.get_h_scroll_bar().changed.connect(_show_arrows)
	_row_scroll.get_h_scroll_bar().value_changed.connect(func(_value: float) -> void: _show_arrows())
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
		var icon := _frame_icon(key, _tall())
		slot.add_child(icon if icon != null else _label(STRIP_NAMES[key], int(13 * _k()), GOLD))
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
			icon.custom_minimum_size = MAGIC_CELL * (_tall() / MAGIC_CELL.y)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_rests_the_pointer(icon, "magic:%d" % i)
			# The key that casts it, over it while it can be cast (1.3 draws
			# the fourth row's number over the first row's icon).
			var mark := TextureRect.new()
			mark.name = "Key"
			mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mark.visible = false
			if _active(i):
				mark.texture = _cell("world_magics", ROW_KEYS * 12 + i)
			icon.add_child(mark)
			_key_marks.append(mark)
			var magic_index := i
			icon.gui_input.connect(func(event: InputEvent) -> void:
				var click := event as InputEventMouseButton
				if click != null and click.button_index == MOUSE_BUTTON_LEFT and not click.pressed \
						and not resting and _active(magic_index) \
						and Rect2(Vector2.ZERO, _magic_icons[magic_index].size).has_point(click.position):
					_hide_tip()
					# 1997 played the colour's sting as the icon was clicked,
					# when the magic is owned and an amulet of it is held.
					if WorldMagic.ready_to_cast(player, magic_index / 2):
						WorldSoundscape.play_from(self, "sfx_world_magic_" + AdventurePlayer.COLORS[magic_index / 2 - 1])
					cast_pressed.emit(magic_index / 2))
			magics.add_child(icon)
			_magic_icons.append(icon)
	else:
		_magic_names = _label("", int(13 * _k()), GOLD)
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
	buttons["Clues"].pressed.connect(func() -> void: clues_pressed.emit())
	buttons["Hero"].pressed.connect(func() -> void: hero_pressed.emit())
	# The panel's buttons click as 1997's frame buttons did (`Button2.wav`).
	for key in ["Deck", "Map", "Clues", "Hero"]:
		(buttons[key] as BaseButton).pressed.connect(func() -> void: WorldSoundscape.play_from(self, "sfx_click"))
	buttons["Options"].pressed.connect(toggle_options)
	buttons["Help"].pressed.connect(toggle_help)
	for key in buttons:
		var button: BaseButton = buttons[key]
		_rests_the_pointer(button, "button:" + key)
		button.pressed.connect(_hide_tip)
	minimap = WorldMinimap.new()
	minimap.name = "Minimap"
	add_child(minimap)
	minimap.visible = bool(Settings.get_value(MINIMAP_SETTING, true))
	_rests_the_pointer(minimap.land(), "minimap")
	minimap.land().mouse_default_cursor_shape = Control.CURSOR_MOVE
	minimap.land().gui_input.connect(func(event: InputEvent) -> void:
		_pane_input(minimap, event, func(at: Vector2) -> void:
			if resting:
				return
			close_panels()
			walk_requested.emit(minimap.tile_at(at))))
	_quest_pane = _panel("QuestPane")
	_quest_pane.add_theme_stylebox_override("panel", _glass(0.8, 0.45, 8))
	var quest_row := HBoxContainer.new()
	quest_row.add_theme_constant_override("separation", 8)
	quest_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_clock = QuestClock.new()
	quest_row.add_child(_quest_clock)
	var quest_column := VBoxContainer.new()
	quest_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_lines = _label("", 15)
	_quest_lines.name = "QuestLines"
	quest_column.add_child(_quest_lines)
	_gift_icons = HBoxContainer.new()
	_gift_icons.name = "DuelGifts"
	_gift_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quest_column.add_child(_gift_icons)
	quest_row.add_child(quest_column)
	_quest_pane.add_child(quest_row)
	_hero_panel = _panel("HeroPanel")
	hero_stats = HeroStats.new()
	hero_stats.journal_map_pressed.connect(func() -> void: journal_map_pressed.emit())
	# D or Space while the pane shows: done (1997's stats screen's Done).
	hero_stats.done_pressed.connect(func() -> void: close_panels())
	_hero_panel.add_child(hero_stats)
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
	_place_tip = PanelContainer.new()
	_place_tip.name = "PlaceTip"
	_place_tip.add_theme_stylebox_override("panel", _glass(0.86, 0.5, 6))
	_place_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place_tip.visible = false
	var place_lines := VBoxContainer.new()
	place_lines.add_theme_constant_override("separation", 0)
	place_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place_tip.add_child(place_lines)
	_place_name = _label("", 15, GOLD)
	_place_name.name = "PlaceTipName"
	place_lines.add_child(_place_name)
	_place_kind = _label("", 13)
	_place_kind.name = "PlaceTipKind"
	place_lines.add_child(_place_kind)
	add_child(_place_tip)
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
	var line := "%s · %s" % [player.name, player.difficulty_name()] if player.name != "" else ""
	if _name.text != line:
		_name.text = line
	if _inked != player.color:
		_inked = player.color
		var inks: Array = NAME_INKS.get(player.color, [INK, EDGE])
		_name.add_theme_color_override("font_color", inks[0])
		_name.add_theme_color_override("font_outline_color", inks[1])
	refresh_numbers()
	refresh_quest()
	# The hero's pane, open, follows what it shows — rebuilt only when that
	# changes, not every tick.
	if hero_shown():
		var seen := "%d|%d|%s|%d|%d|%s|%d" % [player.gold, player.food, str(player.amulets),
			WorldStatus.days_on_road(player), player.journal.size(), str(player.world_magics),
			player.cards.size()]
		if seen != _hero_seen:
			_hero_seen = seen
			hero_stats.refresh()


## THE PURSE, THE AMULETS AND THE WORLD MAGICS as the hero now stands —
## cheap enough for every frame, so what a place's pane changes under the
## resting panel (food bought, a card sold, an amulet paid) shows at once.
func refresh_numbers() -> void:
	if player == null or _name == null:
		return
	_numbers["gold"].text = str(player.gold)
	_numbers["food"].text = str(player.food)
	_numbers["ankh"].text = str(player.mana_links())
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


## Whether World Magic [param i] is working now: Quickening's burst of
## speed while it runs [QoL] (1997 showed no sign of it).
func magic_working(i: int) -> bool:
	return AdventurePlayer.WORLD_MAGICS[i] == "Quickening" and player.quickening > 0


func _show_magic(i: int) -> void:
	var icon := _magic_icons[i]
	var owned := player.owns(AdventurePlayer.WORLD_MAGICS[i])
	var row := ROW_NORMAL
	if magic_working(i):
		row = ROW_LIT
	elif owned and _active(i) and not magic_lit(i):
		row = ROW_PRESSED
	var shown := row * 12 + i
	if int(icon.get_meta("cell", -1)) != shown:
		icon.texture = _cell("world_magics", shown)
		icon.set_meta("cell", shown)
	icon.modulate = Color.WHITE if owned else Color(0.5, 0.47, 0.45, 0.72)
	_key_marks[i].visible = _active(i) and magic_lit(i) and not magic_working(i)
	icon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _active(i) and magic_lit(i) \
		else Control.CURSOR_ARROW



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
	# The small map in the corner away from the panel, the quest pane in
	# the other — unless the player has put them elsewhere.
	if not _place_remembered(minimap):
		var corner := WorldMinimap.SIZE
		minimap.anchor_left = 1.0
		minimap.anchor_right = 1.0
		minimap.anchor_top = 0.0 if at_bottom else 1.0
		minimap.anchor_bottom = minimap.anchor_top
		minimap.offset_left = -12.0 - corner.x
		minimap.offset_right = -12.0
		minimap.offset_top = 12.0 if at_bottom else -12.0 - corner.y
		minimap.offset_bottom = minimap.offset_top + corner.y
	# A pane put where the panel now stands is put back in its corner.
	var band := _bar.size.y + _under.size.y + 20.0
	for pane in [minimap, _quest_pane]:
		var at: Variant = remembered(pane)
		if at != null:
			var top: float = (at as Vector2).y
			if (at_bottom and top + (pane as Control).size.y > size.y - band) or (not at_bottom and top < band):
				Settings.clear_value(PANE_SETTING + (pane as Control).name)
				if pane == minimap:
					place_bar(at_bottom, remember)
					return
	refresh_quest()
	_refresh_options()
	if remember:
		Settings.set_value(BAR_SETTING, at_bottom)


## THE SMALL MAP shown or hidden (the options, N), remembered.
func show_minimap(shown: bool) -> void:
	minimap.visible = shown
	_drag = {}
	Settings.set_value(MINIMAP_SETTING, shown)
	_refresh_options()


func minimap_shown() -> bool:
	return minimap != null and minimap.visible


## THE QUEST PANE shown or hidden (the options), remembered: it shows when
## something calls the hero — a quest, a siege, a bonus for the next duel,
## a wizard's mana taps — as the 1997 frame's quest panel did.
func show_quest_pane(shown: bool) -> void:
	Settings.set_value(QUEST_SETTING, shown)
	refresh_quest()
	_refresh_options()


func quest_pane_wanted() -> bool:
	return bool(Settings.get_value(QUEST_SETTING, true))


func quest_pane_shown() -> bool:
	return _quest_pane != null and _quest_pane.visible


## The quest pane's lines, as the hero now stands ([WorldStatus]).
func refresh_quest() -> void:
	if _quest_pane == null:
		return
	var lines := WorldStatus.lines(player)
	var text := "\n".join(lines)
	_quest_clock.player = player
	_quest_clock.visible = _quest_clock.wanted()
	_quest_clock.queue_redraw()
	var gifts := QuestClock.gifts(player)
	var marks := ",".join(gifts.map(func(gift: Array) -> String: return str(gift[0])))
	if _quest_lines.text != text or String(_gift_icons.get_meta("marks", "")) != marks:
		_quest_lines.text = text
		_gift_icons.set_meta("marks", marks)
		for child in _gift_icons.get_children():
			child.queue_free()
		if art.texture("world_magics") != null:
			for gift in gifts:
				var icon := TextureRect.new()
				var cut := _cell("world_magics", int(gift[0]))
				cut.region = Rect2(cut.region.position, Vector2(28, 37))
				icon.texture = cut
				icon.tooltip_text = String(gift[1])
				icon.mouse_filter = Control.MOUSE_FILTER_PASS
				_gift_icons.add_child(icon)
		_quest_pane.reset_size()
	var shown := quest_pane_wanted() and not lines.is_empty()
	_quest_pane.visible = shown
	if not shown:
		if _drag.get("pane") == _quest_pane:
			_drag = {}
		return
	# In its corner away from the panel, its foot or head kept there as it
	# grows; or where it was put, kept on the screen — never while dragged.
	if _drag.get("pane") == _quest_pane:
		return
	if not _place_remembered(_quest_pane):
		var y := size.y - 12.0 - _quest_pane.size.y if not bar_at_bottom else 12.0
		_quest_pane.position = Vector2(12.0, maxf(y, 8.0))


## THE PLACE'S NAME by the pointer over it: [param called] and its kind
## ([param kind]) floating at [param at], kept on the screen; with the
## place names switched off, nothing.
func show_place(called: String, kind: String, at: Vector2) -> void:
	if not places_wanted():
		hide_place()
		return
	if _place_name.text != called or _place_kind.text != kind:
		_place_name.text = called
		_place_kind.text = kind
		_place_tip.reset_size()
	_place_tip.visible = true
	var spot := at + Vector2(22, 20)
	_place_tip.position = Vector2(clampf(spot.x, 4.0, maxf(4.0, size.x - _place_tip.size.x - 4.0)),
		clampf(spot.y, 4.0, maxf(4.0, size.y - _place_tip.size.y - 4.0)))


func hide_place() -> void:
	if _place_tip != null:
		_place_tip.visible = false


func place_shown() -> String:
	return _place_name.text if _place_tip != null and _place_tip.visible else ""


static func places_wanted() -> bool:
	return bool(Settings.get_value(PLACES_SETTING, true))


## Whether a right click on a card opens it full screen (on until switched).
static func reader_wanted() -> bool:
	return bool(Settings.get_value(READER_SETTING, true))


## THE GUIDE ARROWS shown or hidden (the options), remembered.
static func guides_wanted() -> bool:
	return bool(Settings.get_value(GUIDES_SETTING, true))


func show_guides(shown: bool) -> void:
	Settings.set_value(GUIDES_SETTING, shown)
	_refresh_options()


# ------------------------------------------------------- moving panes --

## A press, a drag or a let-go on [param pane] (the owner, 2026-10-23:
## panes *"with rounded corners that can be moved at will"*): dragged
## further than [constant PANE_SLOP] it moves, and is found there next
## time; a press let go where it was made is a click, given to
## [param on_click] with the point on the part pressed.
func _pane_input(pane: Control, event: InputEvent, on_click := Callable()) -> void:
	var mouse := event as InputEventMouse
	if mouse == null:
		return
	var at := mouse.global_position - get_global_rect().position
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_drag = {"pane": pane, "grip": at - _rect_of(pane).position, "from": at, "moved": false}
		elif _drag.get("pane") == pane:
			var moved: bool = _drag["moved"]
			_drag = {}
			if moved:
				remember_pane(pane)
			elif on_click.is_valid():
				on_click.call(button.position)
		return
	if event is InputEventMouseMotion and _drag.get("pane") == pane:
		# The button let go where this pane did not hear it (it was hidden
		# under the press): the drag is over.
		if (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT == 0:
			_drag = {}
			return
		if not _drag["moved"] and at.distance_to(_drag["from"]) > PANE_SLOP:
			_drag["moved"] = true
			_hide_tip()
		if _drag["moved"]:
			place_pane(pane, at - _drag["grip"])


## [param pane] at [param at] on the screen, kept on it.
func place_pane(pane: Control, at: Vector2) -> void:
	var held := pane.size
	pane.set_anchors_preset(Control.PRESET_TOP_LEFT)
	pane.size = held
	pane.position = Vector2(clampf(at.x, 4.0, maxf(4.0, size.x - held.x - 4.0)),
		clampf(at.y, 4.0, maxf(4.0, size.y - held.y - 4.0)))


## Remember where [param pane] stands.
func remember_pane(pane: Control) -> void:
	Settings.set_value(PANE_SETTING + pane.name, [pane.position.x, pane.position.y])


## Where [param pane] was dragged to last, or null.
func remembered(pane: Control) -> Variant:
	var at: Variant = Settings.get_value(PANE_SETTING + pane.name, null)
	if at is Array and (at as Array).size() == 2:
		return Vector2(float(at[0]), float(at[1]))
	return null


func _place_remembered(pane: Control) -> bool:
	var at: Variant = remembered(pane)
	if at == null:
		return false
	place_pane(pane, at)
	return true


## Whether the panel should be made with big buttons: as the options
## last set it, or else wherever the game's touch layer is on.
static func big_wanted() -> bool:
	var chosen: Variant = Settings.get_value(BIG_SETTING, null)
	if chosen is bool:
		return chosen
	return TouchControls.should_be_active()


## The size factor of the panel's parts: 1, or [constant BIG].
func _k() -> float:
	return BIG if big else 1.0


## The icons' height in the row, at this panel's size.
func _tall() -> float:
	return HEIGHT * _k()


## SCROLL THE ROW toward [param side] (-1 left, 1 right) by most of what
## shows — the red arrows at the panel's ends, with big buttons.
func scroll_row(side: int) -> void:
	var step := int(_row_scroll.size.x * 0.7)
	_row_scroll.scroll_horizontal = clampi(_row_scroll.scroll_horizontal + side * step, 0,
		maxi(0, int(_row_scroll.get_h_scroll_bar().max_value - _row_scroll.size.x)))
	_show_arrows()


## The arrows show while the row is wider than the panel, each dimmed at
## its end.
func _show_arrows() -> void:
	if _arrows.is_empty():
		return
	var bar := _row_scroll.get_h_scroll_bar()
	var overflow := big and bar.max_value - bar.page > 1.0
	for side in _arrows:
		var arrow: RedArrow = _arrows[side]
		arrow.visible = overflow
		arrow.disabled = (side < 0 and bar.value <= 0.5) or (side > 0 and bar.value >= bar.max_value - bar.page - 0.5)


func row_scroll() -> ScrollContainer:
	return _row_scroll


## How many times the 1997 pace the world's clock runs (the options).
static func pace() -> float:
	return float(PACES[pace_index()][0])


static func pace_index() -> int:
	return clampi(int(Settings.get_value(PACE_SETTING, 0)), 0, PACES.size() - 1)


# ------------------------------------------------------- the panels --

## THE PANEL AT REST (the lead's ruling A, 2026-10-23, after 1997's modal
## town menu): while a place's pane, the deck builder or the saves hold the
## world screen ([method WorldScreen.modal]) the panel still shows what the
## hero carries, but its panes close, its tips and the place's name go, and
## its buttons, icons, options and small map answer nothing — the screen's
## shield takes the pointer over it. [param on] false wakes it.
func rest(on: bool) -> void:
	if on == resting:
		return
	resting = on
	if on:
		close_panels()
		_hide_tip()
		hide_place()
		_drag = {}


## THE HERO (the frame's faces, F5): the hero's pane on its Hero tab, the
## stats, floating beside the panel (1997's F5, `RunAdventureStatsMenu`);
## on another tab it turns to the Hero tab, on the Hero tab it closes. Not
## while the panel rests.
func toggle_hero() -> void:
	if resting:
		return
	if hero_shown() and hero_stats.tab == HERO_TAB:
		close_panels()
		return
	_show_hero_tab(HERO_TAB)


## THE WIZARDS (F6, the options' "Wizards (F6)"): the hero's pane on its
## Wizards tab — 1997's wizards' window (`ShowStatsWindow(0, −1)`, the
## Statwin window, adventure_input.c 373–396), nobody ringed, heard once as
## it opens ([method HeroStats.show_wizards] plays `Statscrn.wav`); on
## another tab it turns to the Wizards, on the Wizards tab it closes. Not
## while the panel rests.
func toggle_wizards() -> void:
	if resting:
		return
	if hero_shown() and hero_stats.tab == WIZARDS_TAB:
		close_panels()
		return
	_show_hero_tab(WIZARDS_TAB)


## The hero's pane open on [param tab] ([method HeroStats.show_tab], the
## Wizards through [method HeroStats.show_wizards]), or turned to it when it
## is open.
func _show_hero_tab(tab: String) -> void:
	hero_stats.player = player
	if tab == WIZARDS_TAB:
		hero_stats.show_wizards()
	else:
		hero_stats.show_tab(tab)
	if not hero_shown():
		_open(_hero_panel, true, buttons["Hero"])


func hero_shown() -> bool:
	return _hero_panel != null and _hero_panel.visible


## THE KEYS (?, H): what the line under the world once said. Not while the
## panel rests.
func toggle_help() -> void:
	if resting:
		return
	_open(_help_panel, not _help_panel.visible, buttons["Help"])


func help_shown() -> bool:
	return _help_panel != null and _help_panel.visible


## THE OPTIONS (the painted book): save, load, the panel to the other
## edge, exit. Not while the panel rests.
func toggle_options() -> void:
	if resting:
		return
	_open(_options_menu, not _options_menu.visible, buttons["Options"])


## THE OPTIONS AT THE POINTER (a right click on the world, 1997's "Will
## you ..." menu): opened with its corner at [param at], kept whole on the
## screen — not remembered there; again to close it. Not while the panel
## rests.
func toggle_options_at(at: Vector2) -> void:
	if resting:
		return
	if options_shown():
		close_options()
		return
	close_panels()
	_options_menu.visible = true
	_options_menu.reset_size()
	var room := size - _options_menu.size - Vector2(4, 4)
	_options_menu.position = at.clamp(Vector2(4, 4), Vector2(maxf(4.0, room.x), maxf(4.0, room.y)))


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
	if _drag.get("pane") != minimap and _drag.get("pane") != _quest_pane:
		_drag = {}
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
	var links := player.mana_links()
	lines.append("%d gold · %d food · %d mana %s" % [player.gold, player.food, links,
		"link" if links == 1 else "links"])
	var gems: Array[String] = []
	for gem in AMULETS:
		gems.append("%s %d" % [gem[0], int(player.amulets.get(gem[0], 0))])
	lines.append("Amulets: " + ", ".join(gems))
	lines.append("World Magics: " + (", ".join(player.world_magics) if not player.world_magics.is_empty() else "none"))
	lines.append("Cards: %d, %d in the deck" % [player.cards.size(), cards_in_deck()])
	lines.append("")
	var record := player.duel_record()
	lines.append("Duels: %d won, %d lost · lairs explored: %d" % [record["won"], record["lost"], player.lairs_explored])
	var days := WorldStatus.days_on_road(player)
	lines.append("Days on the road: %d" % days)
	var bonus := WorldStatus.next_duel_line(player)
	if bonus != "":
		lines.append(bonus)
	var quest := WorldStatus.quest_lines(player)
	lines.append("Quest: " + (", ".join(quest) if not quest.is_empty() else "none"))
	var taps := WorldStatus.tap_lines(player)
	lines.append("The wizards: " + (", ".join(taps) if not taps.is_empty()
		else "no city tapped yet (%d taps cast Dominion)" % WorldStatus.dominion(player)))
	lines.append("World seed %s" % player.world_seed_text)
	lines.append("")
	if player.journal.is_empty():
		lines.append("Journal: nothing written yet.")
	else:
		lines.append("Journal:")
		for entry in player.journal.slice(maxi(player.journal.size() - 6, 0)):
			lines.append("  " + String((entry as Dictionary).get("text", str(entry))))
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
	_notice.position.y = clampf(_notice.position.y, 4.0, maxf(4.0, size.y - _notice.size.y - 4.0))
	if is_inside_tree():
		if _notice_fade != null and _notice_fade.is_valid():
			_notice_fade.kill()
		_notice_fade = create_tween()
		_notice_fade.tween_interval(NOTICE_SECONDS)
		_notice_fade.tween_property(_notice, "modulate:a", 0.0, 0.8)
		_notice_fade.tween_callback(func() -> void: _notice.visible = false)


func notice() -> String:
	return _notice.text if _notice != null and _notice.visible else ""


func _open(panel: PanelContainer, shown: bool, beside: Control) -> void:
	close_panels()
	panel.visible = shown
	if shown:
		panel.reset_size()
		if not _place_remembered(panel):
			_float(panel, _rect_of(beside).end.x - panel.size.x, 6.0)
		_refit(panel, beside)


## [param panel], opened beside [param beside], fitted again once its page
## is laid out: a page built while the pane was closed — the hero's pane
## opened straight on its Wizards tab (F6) — measures its wrapping lines
## before they have their width, and the pane came out the screen's
## height, over the panel.
func _refit(panel: PanelContainer, beside: Control) -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_instance_valid(panel) or not panel.visible or _drag.get("pane") == panel:
		return
	panel.reset_size()
	if not _place_remembered(panel):
		_float(panel, _rect_of(beside).end.x - panel.size.x, 6.0)
	else:
		place_pane(panel, panel.position)


## [param part] floating beside the panel — under it, or over it when the
## panel is at the bottom — from [param x], [param gap] away.
func _float(part: Control, x: float, gap: float) -> void:
	var bar := _bar_rect()
	var y := bar.position.y - gap - part.size.y if bar_at_bottom else bar.end.y + gap
	part.position = Vector2(_fit_x(x, part.size.x), clampf(y, 4.0, maxf(4.0, size.y - part.size.y - 4.0)))


## [param pane] kept whole on the screen after it changed its size or the
## screen did: by the panel where it floats, or where it was put.
func _keep_on_screen(pane: Control) -> void:
	if not pane.visible or _drag.get("pane") == pane:
		return
	if remembered(pane) == null and pane != minimap:
		_float(pane, pane.position.x, 6.0)
	else:
		place_pane(pane, pane.position)


func _notification(what: int) -> void:
	# The screen changed its size (a window, a turned device): the panes
	# that were placed by hand stay on it.
	if what == NOTIFICATION_RESIZED and _bar != null:
		for pane in [_hero_panel, _help_panel]:
			_keep_on_screen(pane)
		if minimap != null and remembered(minimap) != null:
			_keep_on_screen(minimap)
		refresh_quest()


func _panel(panel_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name
	var face := _glass(0.86, 0.6, 8)
	face.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", face)
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_MOVE
	panel.mouse_entered.connect(func() -> void: hovered.emit())
	panel.gui_input.connect(func(event: InputEvent) -> void: _pane_input(panel, event))
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
	entry.custom_minimum_size = Vector2(170, 0) * _k()
	var face := GameSkin.font("font_title")
	if face != null:
		entry.add_theme_font_override("font", face)
	entry.add_theme_font_size_override("font_size", int(16 * _k()))
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


## What an option does when chosen. A switch leaves the options open, so
## the new setting shows. Nothing while the panel rests.
func _choose(entry_name: String) -> void:
	if resting:
		close_options()
		return
	if not entry_name in SWITCHES:
		close_options()
	match entry_name:
		"Save":
			save_pressed.emit()
		"Load":
			load_pressed.emit()
		"Cities":
			city_list_pressed.emit()
		"Wizards":
			toggle_wizards()
		"Bar":
			place_bar(not bar_at_bottom)
		"Minimap":
			show_minimap(not minimap_shown())
		"Quest":
			show_quest_pane(not quest_pane_wanted())
		"Guides":
			show_guides(not guides_wanted())
		"Places":
			Settings.set_value(PLACES_SETTING, not places_wanted())
			hide_place()
		"Reader":
			Settings.set_value(READER_SETTING, not reader_wanted())
		"Big":
			Settings.set_value(BIG_SETTING, not big)
			big_switched.emit()
		"Pace":
			Settings.set_value(PACE_SETTING, (pace_index() + 1) % PACES.size())
		"Transitions":
			# The Options screen's switch too ([TileReveal]).
			Settings.set_value(TileReveal.SETTING, not Settings.transitions())
		"Music":
			Settings.set_value("music_enabled", not Settings.music_enabled())
			var music := get_node_or_null(^"/root/ShellMusic")
			if music != null:
				music.call(&"play")
		"Sound":
			Settings.set_value("sound_enabled", not Settings.sound_enabled())
			GameAudio.apply_settings()
		"Menu":
			menu_pressed.emit()
		"Exit":
			exit_pressed.emit()
	_refresh_options()


## The words of option [param entry_name], a switch saying how it stands.
func _option_words(entry_name: String) -> String:
	match entry_name:
		"Bar":
			return "Panel at the top" if bar_at_bottom else "Panel at the bottom"
		"Minimap":
			return "Small map: " + ("on" if minimap_shown() else "off")
		"Quest":
			return "Quest pane: " + ("on" if quest_pane_wanted() else "off")
		"Guides":
			return "Guide arrows: " + ("on" if guides_wanted() else "off")
		"Places":
			return "Place names: " + ("on" if places_wanted() else "off")
		"Reader":
			return "Large card on right-click: " + ("on" if reader_wanted() else "off")
		"Big":
			return "Big buttons: " + ("on" if big else "off")
		"Pace":
			return "Pace: " + String(PACES[pace_index()][1])
		"Transitions":
			return "Transitions: " + ("on" if Settings.transitions() else "off")
		"Music":
			return "Music: " + ("on" if Settings.music_enabled() else "off")
		"Sound":
			return "Sound: " + ("on" if Settings.sound_enabled() else "off")
	for entry in OPTIONS:
		if entry[0] == entry_name:
			return entry[1]
	return entry_name


func _refresh_options() -> void:
	if _options_menu == null:
		return
	for entry in OPTIONS:
		var button := _options_menu.find_child("Option_" + entry[0], true, false) as Button
		if button != null:
			button.text = _option_words(entry[0])


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
		if _tip != null:
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


## The name of [param part] and what it does, floating by it: beside the
## panel for a part of its row, beside the part itself for one away from
## it (the small map).
func show_tip(part: Control) -> void:
	var lines := tip_for(String(part.get_meta("tip", "")))
	if lines.is_empty():
		return
	_tip_name.text = lines[0]
	_tip_text.text = lines[1]
	_tip_text.visible = lines[1] != ""
	_tip.visible = true
	_tip.reset_size()
	if _bar.is_ancestor_of(part):
		_float(_tip, _rect_of(part).get_center().x - _tip.size.x * 0.5, 4.0)
	else:
		_float_by(_tip, part, 6.0)


## [param pane] floating by [param part], a part away from the panel: over
## it when it stands in the screen's lower half, under it otherwise, its
## middle over the part's, kept on the screen.
func _float_by(pane: Control, part: Control, gap: float) -> void:
	var at := _rect_of(part)
	var y := at.position.y - gap - pane.size.y if at.get_center().y > size.y * 0.5 else at.end.y + gap
	pane.position = Vector2(_fit_x(at.get_center().x - pane.size.x * 0.5, pane.size.x),
		clampf(y, 4.0, maxf(4.0, size.y - pane.size.y - 4.0)))


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
		"minimap":
			return ["Small map (N)", "The land round your hero. Click on it to walk there."]
		"amulet":
			var spends := ""
			for i in AdventurePlayer.WORLD_MAGICS.size():
				if _active(i) and _amulet_of(i) == key:
					spends = AdventurePlayer.WORLD_MAGICS[i]
			return ["%s amulet" % key.capitalize(), "Casting %s risks one." % spends]
		"magic":
			var i := int(key)
			var magic: String = AdventurePlayer.WORLD_MAGICS[i]
			var state := ""
			if player != null and not player.owns(magic):
				state = " Not yours yet."
			elif player != null and magic_working(i):
				state = " Working now."
			elif player != null and _active(i) and not magic_lit(i):
				state = " No %s amulet left to power it." % _amulet_of(i)
			elif player != null and _active(i):
				state = " Click, or press %d." % (i / 2)
			return [magic, MAGIC_TIPS[magic] + state]
		"button":
			match key:
				"Options":
					return ["Options", "Save, load, the panel, the panes and the guide arrows, the pace, music and sound, the main menu, exit."]
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
	var number := _label("0", int(16 * _k()))
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
	line.custom_minimum_size = Vector2(1, _tall() - 6)
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
		# Without the sheet, the stone's colour on a small disc ([method
		# WorldArt.amulet_disc], as the map and the city list draw it).
		var disc := WorldArt.amulet_disc(AdventurePlayer.COLORS.find(color), 12.0 * _k())
		disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return disc
	var icon := TextureRect.new()
	icon.texture = _cell("world_amulets", frame)
	icon.custom_minimum_size = Vector2(12, 17) * (_tall() - 4.0) / 17.0
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
		round.custom_minimum_size = MAGIC_CELL * ((_tall() + 2.0) / MAGIC_CELL.y)
		button = round
	else:
		button = UiChrome.menu_button(button_name, Vector2(54, _tall()), int(12 * _k()))
	button.name = button_name
	button.focus_mode = Control.FOCUS_NONE
	buttons[button_name] = button
	return button


## The options: the frame's painted book on its glass (the owner: *"keep
## the save icon … but the icon now means options"*).
func _options_button() -> BaseButton:
	var button: BaseButton
	var icon := _frame_icon("book", _tall())
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
		button = UiChrome.menu_button("Options", Vector2(64, _tall()), int(12 * _k()))
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
	button.custom_minimum_size = Vector2(22, _tall()) * Vector2(_k(), 1.0)
	var face := GameSkin.font("font_title")
	if face != null:
		button.add_theme_font_override("font", face)
	button.add_theme_font_size_override("font_size", int(24 * _k()))
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
