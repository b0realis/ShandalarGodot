class_name WorldScreen
extends Control
## THE WORLD OF SHANDALAR, on the whole screen — a new adventure's world
## ([WorldGenerator]) drawn as the 1997 game drew it ([WorldView]), without
## the frame the original looked at it through (the owner, 2026-10-22:
## *"we will omit the original border around the world screen and try to
## render it full screen"*).
##
## WHAT IT DOES TODAY: it shows the adventure ([AdventurePlayer]) from where
## the hero stands, and the hero WALKS: a click on the map is where to go,
## the way there is found and walked at the 1997 pace ([HeroWalk]), the
## world's clock ticking every 60 ms as the original's did, the land the
## hero passes explored. The pointer is a small walking man, an open door
## over a site, the place's name by it. The arrows or a drag look around,
## the wheel zooms, Space stops the walk and comes back to the hero, a
## right click opens the options, Escape or Q asks "Ready to Quit?"
## ([method ask_quit]; the keys in full at [method _unhandled_input]).
## A pinch zooms and a touchpad's two-finger slide looks, and a finger
## does what the mouse does ([TouchControls]).
## The floating panel ([WorldHud]) shows what the hero carries; its World
## Magics are cast with a click or 1–5 ([WorldMagic]); its options save,
## load (over the world), return to the title and exit the game. A small
## map, the quest pane and the clues float in panes the player may move;
## guide arrows point to the places that call the hero ([WorldGuides]).
## A place walked to opens its pane ([VisitPane]) — a town's card shop, its
## trade, its wise man and its quest ([WiseManPane]), its deck builder, and
## the World Magic seller as it is left ([WorldMagicPane]) — and a lair
## walked onto opens its own ([LairPane], [WorldLairs]). F3 lists the towns
## visited ([CityListPane]); M is the map, the journal walked on it
## ([WorldMap]); Ctrl+S saves into ten slots ([SaveSlotsPane]).
## THE CREATURES roam the land round the hero and come for them
## ([WorldCreatures], part B): one that reaches the hero is MET ([method
## meet_creature]) — the game saved with it still there, its meeting's pane
## over the world ([WorldEncounters]), the slot spent once it is over.
## THE SIEGES ([Sieges], part B): the siege clock's step as the hero walks
## begins a wizard's siege or resolves it; its NEWS FLASH ([NewsFlashPane])
## stops the walk and holds the tick — the hero's step taken, the
## creatures' not yet, as 1997 showed it inside the step — until it is
## read ([method show_news]). The besieger met and beaten lifts the siege,
## met and not beaten lets the town fall at once ([method
## _after_siege_meeting]). THE END ([AdventureEndScreen]): the Spell of
## Dominion cast, or no card left to stake at a meeting or a ruled town —
## nothing saved from that moment, the end's words, then the title ([method
## show_end]; the saves as they were, so Resume takes the adventure up from
## before the fall, as 1997's did).
## A town's creature quest done there opens its reward, a card of the
## town's wares picked free ([CardTradePane], [constant CardTrade.REWARD]).
##
## A PANE HOLDS THE SCREEN (the lead's rulings of 2026-10-23, after 1997's
## modal town menu): while a place's pane, one over it, the deck builder or
## the saved adventures are up ([method modal]), the world's clock waits,
## the panel shows what the hero carries but does nothing ([method
## WorldHud.rest]), and a clear shield under the panes takes every click
## meant for the panel or the world — for a moment after the last pane
## closes too, so the second click of a double click on its Done walks no
## one. The map is a whole screen of its own, as 1997's was: while it is
## up only its keys, Escape and Ctrl+S act ([method _map_key]).
## THE CASTLES' AND THE DUNGEONS' DOORS ([DungeonDoors], 2026-10-27): a
## dungeon the hero knows of is drawn on the world and the small map; its
## pane's "Enter the dungeon", like a castle's "Yes, enter the castle.",
## goes in ([method _enter_board]) — the journal, the attempt counted, the
## roaming slots 0–4 emptied —, the board over the world while the hero is
## inside ([method on_board]: nothing saved), and out again ([method
## _board_done]): a dungeon moved, a castle left unbeaten on Wizard
## retaliated for, the game saved, the news. The board itself is part C's;
## until it is made the doors wait, disabled ([constant
## DungeonDoors.BOARD_READY]).

const LOOK_SPEED := 600.0   # screen pixels a second, at zoom 1
const ZOOM_STEP := 1.25
## A press that moves no further than this is a click, not a drag.
const CLICK_SLOP := 6.0
## Screen pixels a touchpad's two-finger slide looks for each unit of it.
const PAN_STEP := 24.0
## At most this many ticks in one frame, after a long one.
const MOST_TICKS := 20
## How long the shield stays after the last pane closes [ours]: the longest
## double click the desktops allow by default (Windows' 500 ms), so its
## second click, landing where the pane's Done was, never walks the hero.
const AFTER_PANE_MS := 500
## How long after the world opens its deck's pictures start decoding in
## the background ([method _warm_the_builder]): past the first frames, and
## the arrival's own work.
const WARM_AFTER := 1.0
## Said beside the panel when the adventure could not be written (the
## robustness pass, 2026-10-23: a whole adventure was played and lost on
## exit with no word of it).
const UNSAVED := "The adventure could not be saved."
## A pane's closing signal is heard once, after the frame's input: a second
## Leave or Escape in the same frame finds nothing left to close, and no
## pane is freed under its own click.
const CLOSING := CONNECT_DEFERRED | CONNECT_ONE_SHOT
## The places whose entering pushes the creatures back (1997's sites, flag
## 0x10: a village, a town, a city, a castle, as a wizard holds them or
## not; a dungeon never).
const PUSHING_PLACES := ["village", "town", "city", "ruled", "castle", "fallen"]
## The places whose tune comes to full voice as they are entered: a
## village, a town, a city — and a castle, standing or beaten [1997: every
## site's arrival set the place's channel to full, adventure_input.c 703–722
## and 835–840, a castle's own tune too].
const SWELLING_PLACES := ["village", "town", "city", "castle", "fallen"]

## The adventure: the hero and their world. Set before the screen enters
## the tree; when it is not, one is begun from [member record] and
## [member world] (without a save).
var player: AdventurePlayer
## The record a new adventure began from ([method AdventureSetup.resolve]),
## and its world.
var record: Dictionary = {}
var world: ShandalarWorld
## The hero's walk ([HeroWalk]).
var walk: HeroWalk

## A few lines greeting the hero on arrival ([method EmbarkScreen.summary]),
## shown for [constant ARRIVAL_SECONDS].
var arrival := ""
const ARRIVAL_SECONDS := 8.0

var view: WorldView
## The arrows to the places that call the hero ([WorldGuides]).
var guides: WorldGuides
var _map: WorldMap
## The floating icons ([WorldHud]): the purse, the amulets, the World
## Magics and the round buttons.
var hud: WorldHud
## The clear sheet over the world, the map and the panel, under every pane
## ([method _sync_rest]); and until when it stays after the last pane
## closed (`Time.get_ticks_msec`).
var _shield: Control
var _shield_until := 0
var _arrival: Label
var _dragging := false
## W and D pressed while the hero's pane was open: the pane's, not looked
## with until let go ([method _look_with_keys]).
var _pane_letters: Array[int] = []
var _pressed_at := Vector2.ZERO
var _dragged := false
var _leaving := false
var _tick_left := 0.0
var _pointer := -1
## The view the place under the pointer was last looked for in: camera and
## zoom ([method _point_again]).
var _pointed := Vector3.INF
## The saved adventures, open over the world from the options.
var _load_screen: LoadAdventureScreen
## The deck builder, open over the world ([AdventureBuilder]); and whether
## a town's Edit deck/Sell cards opened it, so Done comes back to the town.
var _builder: AdventureBuilder
var _deck_from_town := false
## The world's sounds ([WorldSoundscape]).
var soundscape: WorldSoundscape
## The place visited, its pane over the world ([VisitPane], a lair's
## [LairPane]), its tile, its card shop ([CardShopPane]) and the card trader
## ([CardTradePane]: a town's trade, the Nomad's Bazaar, the Diamond Mine).
var _visit: VisitPane
var _visit_tile := Vector2i(-1, -1)
## The place stood on opened again, not walked into ([method walk_to_tile]).
var _again := false
## THE PLACE ARRIVED AT, while the hero still stands on its tile (the entry
## latch, [method walk_to_tile]): set by an arrival ([method visit]),
## forgotten the moment the hero stands anywhere else ([method _process]) or
## the town is freed. (−1, −1) for none. Kept on the adventure as it changes
## ([member AdventurePlayer.entered_tile]), so it is saved, and taken back
## from it as an adventure is shown ([method show_player]): a Resume, a
## Load or the window closed inside a town made the next click on it a new
## arrival — a second "Visited", the quest offer drawn again on the dice
## the save had moved on (the bug campaign c12, h1-1, h1-2).
var _entered_tile := Vector2i(-1, -1):
	set(tile):
		_entered_tile = tile
		if player != null:
			player.entered_tile = tile
var _shop: CardShopPane
var _trade: CardTradePane
## A list of cards over a pane — a creature's deck, the copy's pick
## ([CardListPane]) — and the World Magic seller as a town is left
## ([WorldMagicPane]).
var _card_list: CardListPane
var _magic_seller: WorldMagicPane
var _city_list: CityListPane
var _save_slots: SaveSlotsPane
## The question asked when the adventure could not be saved as the hero
## leaves the world ([UnsavedAsk]), and "Ready to Quit?" ([QuitAsk]).
var _unsaved: UnsavedAsk
var _quit_ask: QuitAsk
## A CASTLE'S OR A DUNGEON'S BOARD over the world (part C's; [method
## _enter_board]) while the hero is inside — it holds the world, and no
## save is made while it is up, as 1997 saved nothing on the board.
var _board: Control
## The duel's full-screen card reader, for a card right-clicked in a pane
## ([method read_card]).
var reader: FullscreenCard
## A creature's meeting, its pane over the world ([method meet_creature]);
## whether the tick that met it waits for its end (the clock moves on as the
## meeting ends, as 1997's did after its modal meeting); whether a duel's
## screen covers the world ([method hold_for_duel]).
var _meeting: Control
var _tick_held := false
var _duel_held := false
## The news flash shown ([NewsFlashPane]), the news still to show after it,
## and whether the step that brought the news reached the walk's place (the
## place is visited once the news is read).
var _news: NewsFlashPane
var _news_queue: Array[Dictionary] = []
var _news_reached := false
## The adventure's end shown ([AdventureEndScreen]); and whether it is lost
## — from the moment it is, nothing is saved and the world never runs again.
var _end: AdventureEndScreen
var _lost := false
## Whether the world leaves for the title once no pane holds it ([method
## leave_after_panes]).
var _leave_after := false


## THE ADVENTURE NOT SAVED: asked before the hero leaves the world when its
## save could not be written — Stay, or Leave without saving; Escape stays.
class UnsavedAsk extends PanelContainer:
	## [param leave] true for Leave without saving, false for Stay.
	signal answered(leave: bool)

	## The words over the choices.
	var words := ""
	## The size factor (the panel's big buttons, [constant WorldHud.BIG]).
	var k := 1.0
	var _choices: HBoxContainer

	func _ready() -> void:
		name = "UnsavedAsk"
		mouse_filter = Control.MOUSE_FILTER_STOP
		add_theme_stylebox_override("panel", PaneStyle.glass(16.0))
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", int(10 * k))
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(column)
		column.add_child(PaneStyle.title("Not saved", int(24 * k)))
		column.add_child(PaneStyle.wrapped(words, int(16 * k), 400.0 * k))
		var choices := HBoxContainer.new()
		_choices = choices
		choices.alignment = BoxContainer.ALIGNMENT_CENTER
		choices.add_theme_constant_override("separation", int(10 * k))
		choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var stay := PaneStyle.button("Stay", "Stay", k)
		stay.pressed.connect(func() -> void: answered.emit(false))
		choices.add_child(stay)
		var go := PaneStyle.button("Leave without saving", "LeaveUnsaved", k)
		go.pressed.connect(func() -> void: answered.emit(true))
		choices.add_child(go)
		column.add_child(choices)

	func _input(event: InputEvent) -> void:
		VisitPane.drop_letter(_choices, event)

	func _unhandled_input(input: InputEvent) -> void:
		if input.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			answered.emit(false)
		elif VisitPane.letter_choice(self, _choices, input):
			# A choice by its first letter (S, L), Enter takes it (C-5).
			get_viewport().set_input_as_handled()


## READY TO QUIT? — 1997's `@SHUTDOWN` ("Ready to Quit?\n No.\n Yes.\n",
## adventure_input.c 311–324), asked when Escape or Q finds nothing open:
## "No." stays, "Yes." leaves; Escape, or N, stays and Y leaves — the
## choices answer to their first letter, as 1997's text menus' did
## (`RunTextMenuAt`, adventure_ui.c 436–461, moved to the choice; ours
## takes it, the owner's ruling C-5). [ours, the owner (2026-10-27): "upon
## esc key not just question to quit but also offer save/load in the same
## popup!"] Under the question Save (S) and Load (L), as 1997's right-click
## "Will you ..." menu held them beside Quit.
class QuitAsk extends PanelContainer:
	## [param leave] true for "Yes.", false for "No.".
	signal answered(leave: bool)
	## Save or Load chosen instead: [param what] "save" or "load".
	signal chose(what: String)

	## `@SHUTDOWN`'s question.
	const WORDS := "Ready to Quit?"

	## The size factor (the panel's big buttons, [constant WorldHud.BIG]).
	var k := 1.0

	func _ready() -> void:
		name = "QuitAsk"
		mouse_filter = Control.MOUSE_FILTER_STOP
		add_theme_stylebox_override("panel", PaneStyle.glass(16.0))
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", int(12 * k))
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(column)
		var title := PaneStyle.title(WORDS, int(24 * k))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(title)
		var choices := HBoxContainer.new()
		choices.alignment = BoxContainer.ALIGNMENT_CENTER
		choices.add_theme_constant_override("separation", int(10 * k))
		choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var stay := PaneStyle.button("No.", "QuitNo", k)
		stay.pressed.connect(func() -> void: answered.emit(false))
		choices.add_child(stay)
		var go := PaneStyle.button("Yes.", "QuitYes", k)
		go.pressed.connect(func() -> void: answered.emit(true))
		choices.add_child(go)
		column.add_child(choices)
		var line := HSeparator.new()
		line.add_theme_stylebox_override("separator", _rule())
		column.add_child(line)
		var saves := HBoxContainer.new()
		saves.name = "QuitSaves"
		saves.alignment = BoxContainer.ALIGNMENT_CENTER
		saves.add_theme_constant_override("separation", int(10 * k))
		saves.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var save := PaneStyle.button("Save", "QuitSave", k)
		save.pressed.connect(func() -> void: chose.emit("save"))
		saves.add_child(save)
		var load_one := PaneStyle.button("Load", "QuitLoad", k)
		load_one.pressed.connect(func() -> void: chose.emit("load"))
		saves.add_child(load_one)
		column.add_child(saves)

	## A thin gold line between the question and the saves.
	static func _rule() -> StyleBoxLine:
		var rule := StyleBoxLine.new()
		rule.color = Color(PaneStyle.GOLD, 0.35)
		rule.thickness = 1
		return rule

	func _unhandled_input(input: InputEvent) -> void:
		if input.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			answered.emit(false)
			return
		var key := input as InputEventKey
		if key == null or not key.pressed or key.echo or key.ctrl_pressed:
			return
		if key.keycode == KEY_N or key.keycode == KEY_Y:
			get_viewport().set_input_as_handled()
			answered.emit(key.keycode == KEY_Y)
		elif key.keycode == KEY_S or key.keycode == KEY_L:
			get_viewport().set_input_as_handled()
			chose.emit("save" if key.keycode == KEY_S else "load")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if world == null and not record.is_empty():
		world = AdventureSetup.make_world(record)
	view = WorldView.new()
	view.name = "View"
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(view)
	guides = WorldGuides.new()
	guides.name = "Guides"
	guides.view = view
	guides.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(guides)
	_map = WorldMap.new()
	_map.name = "Map"
	_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map.visible = false
	_map.closed.connect(func() -> void:
		if _map.visible:
			toggle_map())
	_map.city_info_pressed.connect(func() -> void:
		var list := show_city_list()
		if list != null:
			list.done.connect(func() -> void: _map.show_mode(WorldMap.Mode.MAIN)))
	add_child(_map)
	_make_hud()
	_make_shield()
	reader = FullscreenCard.new()
	reader.name = "CardReader"
	add_child(reader)
	_arrival = Label.new()
	_arrival.name = "Arrival"
	_arrival.text = arrival
	_arrival.visible = arrival != ""
	_arrival.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arrival.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_arrival.position.y = 200
	_arrival.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_arrival.add_theme_font_size_override("font_size", 18)
	_arrival.add_theme_color_override("font_color", Color8(232, 190, 110))
	_arrival.add_theme_color_override("font_outline_color", Color8(30, 8, 6))
	_arrival.add_theme_constant_override("outline_size", 4)
	_arrival.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_arrival)
	if arrival != "" and is_inside_tree():
		var fade := create_tween()
		fade.tween_interval(ARRIVAL_SECONDS)
		fade.tween_property(_arrival, "modulate:a", 0.0, 1.5)
	if player == null and world != null:
		player = AdventurePlayer.begin(record, world)
	if player != null:
		show_player(player)
		# A new adventure's world comes into view block by block, as 1997's
		# did ([RevealDissolve]).
		if player.monster_timer == 0 and is_inside_tree():
			_reveal(null)
	if is_inside_tree():
		get_tree().create_timer(WARM_AFTER).timeout.connect(_warm_the_builder)


## THE DECK BUILDER'S PICTURES WARMED [QoL] (the owner, 2026-10-23: the
## first F1 of a session, "can we do something in the background before
## user even comes to f1 - in parallel?"). A second after the world opens,
## the hero's cards — the deck in use first — are decoded on a worker
## thread ([CardArtWarmer]), so the first spellbook or Edit deck of a
## session opens as quickly as the later ones.
func _warm_the_builder() -> void:
	if not is_inside_tree() or player == null:
		return
	CardArtWarmer.warm(self, _cards_to_warm())


## The hero's cards as the builder first shows them: the deck in use, then
## the others by name, the order of the cards along its bottom (the bug
## pass after the campaign, r1-2: in the order they were won, a long
## adventure warmed cards the first page never shows).
func _cards_to_warm() -> Array[String]:
	var in_use: Array[String] = []
	var others: Array[String] = []
	for entry in player.cards:
		var card_name := String(entry.get("card", ""))
		if (entry.get("decks", []) as Array).has(player.current_deck):
			in_use.append(card_name)
		elif not others.has(card_name):
			others.append(card_name)
	others.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	in_use.append_array(others)
	return in_use


## The floating panel ([WorldHud]) and what its parts do. Each part's
## handler refuses while a pane holds the screen (ruling A).
func _make_hud() -> void:
	hud = WorldHud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.map_pressed.connect(toggle_map)
	hud.city_list_pressed.connect(func() -> void: show_city_list())
	hud.journal_map_pressed.connect(walk_journal)
	hud.hero_pressed.connect(toggle_hero)
	hud.deck_pressed.connect(func() -> void: open_spellbook())
	hud.save_pressed.connect(save_now)
	hud.load_pressed.connect(open_load)
	hud.exit_pressed.connect(exit_game)
	hud.menu_pressed.connect(return_to_menu)
	hud.clues_pressed.connect(show_clues)
	hud.cast_pressed.connect(func(key: int) -> void: cast(key))
	hud.walk_requested.connect(func(tile: Vector2i) -> void: walk_to_tile(tile))
	hud.hovered.connect(func() -> void:
		_wear(WorldCursors.Kind.ARROW)
		hud.hide_place())
	hud.big_switched.connect(rebuild_hud, CONNECT_DEFERRED)


## THE SHIELD (ruling A): a clear sheet over the world, the map and the
## panel — just above the panel, so under every pane, the card reader and
## the arrival's words — that takes each click and hover meant for what
## lies beneath while it is up ([method _sync_rest]). Under it the pointer
## is the gold arrow.
func _make_shield() -> void:
	_shield = Control.new()
	_shield.name = "PaneShield"
	_shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shield.mouse_filter = Control.MOUSE_FILTER_STOP
	_shield.visible = false
	_shield.mouse_entered.connect(func() -> void: _wear(WorldCursors.Kind.ARROW))
	add_child(_shield)


## THE PANEL MADE AGAIN, at the size the options now ask (big buttons),
## where the old one stood among the screen's layers.
func rebuild_hud() -> void:
	var at := hud.get_index()
	var old := hud
	old.name = "OldHud"
	_make_hud()
	move_child(hud, at)
	old.queue_free()
	if player != null:
		hud.show_player(player)
		_show_hero()
	_sync_rest()


## Show [param adventure]: its world, the hero where they stand.
func show_player(adventure: AdventurePlayer) -> void:
	player = adventure
	world = player.world
	# The entry latch as the adventure kept it (c12, h1-1): only for the tile
	# the hero stands on.
	_entered_tile = player.entered_tile if player.entered_tile == player.tile() else Vector2i(-1, -1)
	walk = HeroWalk.new(player)
	view.world = world
	view.hero_walker = player.walker
	view.hero_sheet = HeroColors.dressed(view.art, player.walker, player.figure_colors)
	world.explore_around(player.tile())
	_map.world = world
	if soundscape == null:
		soundscape = WorldSoundscape.new()
		add_child(soundscape)
	soundscape.player = player
	hud.show_player(player)
	_show_hero()
	view.camera = view.hero
	view.queue_redraw()


## The world's own adventure, begun from [param shown] (the screen's
## [member record]); for a world shown without a save.
func show_world(shown: ShandalarWorld) -> void:
	show_player(AdventurePlayer.begin(record, shown))


func _show_hero() -> void:
	view.hero = Vector2(player.position)
	view.lairs = WorldLairs.seen(player)
	var known := WorldClues.on_world(world)
	view.dungeons = known
	view.creatures = WorldCreatures.seen(player)
	view.hero_facing = player.facing
	view.hero_step = player.step
	_map.hero_tile = player.tile()
	_map.player = player
	var calling := WorldStatus.targets(player)
	hud.minimap.world = world
	hud.minimap.hero = Vector2(player.position)
	hud.minimap.marks = calling
	hud.minimap.dungeons = known
	var guided: Array[Dictionary] = []
	if WorldHud.guides_wanted():
		guided = calling
	guides.targets = guided
	guides.bar_at_bottom = hud.bar_at_bottom
	var covered: Array[Rect2] = []
	for pane in [hud.minimap, hud.find_child("QuestPane", false, false)]:
		if pane != null and (pane as Control).visible:
			covered.append((pane as Control).get_global_rect())
	guides.avoid = covered
	guides.visible = not guides.targets.is_empty()
	hud.refresh()


# ------------------------------------------------------- the panes' hold --

## Whether a pane holds the screen (ruling A): a place's pane or one over
## it ([method visiting]), the deck builder, the saved adventures, a
## creature's meeting and its duel, a news flash, a castle's or a dungeon's
## board — and, for good, the adventure lost ([method show_end]).
func modal() -> bool:
	return visiting() or building() or loading() or meeting() or _duel_held or news_shown() or on_board() \
		or _lost


## Whether the world waits: a pane holds the screen, or the map is up
## (ruling B).
func _world_waits() -> bool:
	return modal() or _map.visible


## THE PANEL AND THE SHIELD AS THE PANES STAND: the panel rests while a pane
## holds the screen ([method WorldHud.rest]); the shield is up as long, and
## [constant AFTER_PANE_MS] after the last one closed. Run before every
## input event ([method _input]), every frame, and as a pane opens or
## closes — so a click never meets the panel or the world in between.
func _sync_rest() -> void:
	if hud == null or _shield == null:
		return
	var held := modal()
	if hud.resting and not held:
		_shield_until = Time.get_ticks_msec() + AFTER_PANE_MS
	hud.rest(held)
	var up := held or Time.get_ticks_msec() < _shield_until
	if _shield.visible != up:
		_shield.visible = up


## A PANE NOW HOLDS THE SCREEN: the gold arrow worn, no drag left armed, and
## the panel at rest — its panes closed, its tips and the place's name gone
## — under the shield.
func _hold() -> void:
	_wear(WorldCursors.Kind.ARROW)
	_dragging = false
	_sync_rest()


## Every input event is met by the panes' hold as it now stands, before any
## control hears it; a W or D pressed while the hero's pane is open is the
## pane's until it is let go ([method _look_with_keys]).
func _input(event: InputEvent) -> void:
	_sync_rest()
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and hud != null and hud.hero_shown() \
			and key.keycode in [KEY_W, KEY_D] and not key.keycode in _pane_letters:
		_pane_letters.append(key.keycode)


# ------------------------------------------------------------ the saves --

## SAVE (the options' Save, Ctrl+S): the ten named slots over the world
## ([SaveSlotsPane]); a slot clicked and named is saved into. Not while a
## pane holds the screen (ruling A).
func save_now() -> SaveSlotsPane:
	if _alive(_save_slots):
		return _save_slots
	if player == null or modal():
		return null
	var slots := SaveSlotsPane.new()
	slots.player = player
	slots.k = WorldHud.BIG if hud.big else 1.0
	_save_slots = slots
	add_child(slots)
	PaneStyle.centre(slots)
	slots.saved.connect(func(_path: String) -> void: hud.say("Saved."))
	slots.done.connect(_close_pane.bind(slots), CLOSING)
	_hold()
	return slots


## The adventure saved into slot [param slot] (1–10) by [param slot_name]:
## the path written, or "".
func save_into_slot(slot: int, slot_name: String) -> String:
	var path := SaveSlots.save_into(player, slot, slot_name) if player != null else ""
	hud.say("Saved." if path != "" else UNSAVED)
	return path


## THE AUTOSAVE as the hero leaves a place or the world (Exit game, Return
## to main menu, the window closed; 1997 wrote its slot 3 so): the path
## written, or "" — "" too for an adventure that is not saved (no id), and
## for one lost ([method show_end]: the saves stay as they were). A save
## that could not be written is said beside the panel.
func autosave() -> String:
	if player == null or player.adventure_id == "" or _lost:
		return ""
	var path := _write_autosave()
	if path == "":
		hud.say(UNSAVED)
	return path


## The autosave written ([method AdventurePlayer.autosave]); a seam, so a
## test can make it fail.
func _write_autosave() -> String:
	return player.autosave()


## LOAD (the options): the saved adventures over the world, which waits
## under them; Back comes back to it, Continue takes the one chosen up
## instead. Not while a pane holds the screen (ruling A).
func open_load() -> LoadAdventureScreen:
	if loading():
		return _load_screen
	if modal():
		return null
	_wear(-1)
	_dragging = false
	_load_screen = load("res://game/adventure/load_adventure_screen.tscn").instantiate()
	add_child(_load_screen)
	_cover_world(true)
	_load_screen.tree_exited.connect(func() -> void:
		if is_inside_tree():
			_cover_world(false)
			_sync_rest())
	_sync_rest()
	return _load_screen


## A screen over the whole world (the deck builder, the saves): the panel,
## its panes and the arrows rest under it, drawing nothing. Gone, they come
## back as the map allows: under the map they stay hidden (ruling B).
func _cover_world(covered: bool) -> void:
	hud.visible = not covered and not _map.visible
	guides.visible = not covered and not _map.visible and not guides.targets.is_empty()
	view.visible = not covered


func loading() -> bool:
	return _alive(_load_screen)


# --------------------------------------------------- leaving the world --

## EXIT GAME (the options): the adventure saved as it stands, then the
## game ends — as `Exit game` ends it from a duel. Not while a pane holds
## the screen (ruling A).
func exit_game() -> void:
	if modal():
		return
	_save_and_end()


## The adventure saved, then the game ended (the options' Exit game, the
## deck builder's own).
func _save_and_end() -> void:
	_saved_or_ask(_end_process)


## RETURN TO MAIN MENU (the options): the adventure saved as it stands,
## then the title screen. Not while a pane holds the screen (ruling A).
func return_to_menu() -> void:
	if modal():
		return
	leave()


## Ends the process; a seam so a test can count the exit instead.
func _end_process() -> void:
	get_tree().quit()


## LEAVE THE WORLD for the title (Escape, Return to main menu): saved
## first, as Exit game does.
func leave() -> void:
	if _leaving:
		return
	_saved_or_ask(_go_to_title)


## THE WORLD LEFT WITHOUT A SAVE, for the title: a duel's "Return to main
## menu" ([WorldDuels], the owner's ruling 4) and the adventure's end
## ([method show_end]).
func leave_unsaved() -> void:
	_go_to_title()


## THE WORLD LEFT ONCE ITS PANES ARE DONE (a held duel's "Return to main
## menu" taken after the duel was over, [WorldDuels]): what the duel
## brought is shown first — its spoils, the town freed, a lair's end — then
## the adventure is saved and left for the title ([method leave]), as the
## world's own Return to main menu leaves; an adventure lost meanwhile ends
## at its own end screen instead.
func leave_after_panes() -> void:
	_leave_after = true


## The title screen, the world left as it is; a seam, so a test can count
## the leaving instead.
func _go_to_title() -> void:
	_leaving = true
	if is_inside_tree() and get_tree().current_scene == self:
		get_tree().change_scene_to_file("res://game/main.tscn")


## THE ADVENTURE SAVED BEFORE THE HERO LEAVES THE WORLD by [param go]: gone
## at once when it was written (or is not one that is saved); when it could
## not be, the player is told and asked first [ours] — Stay keeps them in
## the world, Leave without saving goes all the same ([UnsavedAsk]).
func _saved_or_ask(go: Callable) -> void:
	if player == null or player.adventure_id == "" or autosave() != "":
		go.call()
		return
	if _alive(_unsaved):
		return
	_unsaved = UnsavedAsk.new()
	_unsaved.words = UNSAVED + " Leave all the same, and lose what was done since it was last saved?"
	_unsaved.k = WorldHud.BIG if hud.big else 1.0
	add_child(_unsaved)
	PaneStyle.centre(_unsaved)
	var asked := _unsaved
	asked.answered.connect(func(leave_anyway: bool) -> void:
		if _alive(asked):
			asked.queue_free()
		_sync_rest()
		if leave_anyway:
			go.call(), CLOSING)
	_hold()


## The window's close button on the world: the adventure is saved before
## the game ends (the deck builder, open, answers it itself); a save that
## could not be written is said, for as long as the window stays.
func _notification(what: int) -> void:
	# Mid-meeting the save made as it began stands (the owner's ruling 4: as
	# 1997, quitting meets the creature again, nothing lost or won); so it
	# does mid-reward (a quest's card not yet picked: the quest is reported
	# again, as quitting 1997's browser left it), and a lost adventure saves
	# nothing ([method show_end]). Under a news flash too (the playtest of
	# part B, H2-4): the tick it holds is half taken — the hero's step, not
	# the creatures' — and a save then lost the news and skipped the rest of
	# the tick; the last save stands, and its dice bring the news again.
	# On a castle's or a dungeon's board neither: 1997 saved nothing there;
	# the last save stands, from before the hero went in.
	if what == NOTIFICATION_WM_CLOSE_REQUEST and player != null and not _leaving and not building() \
			and not meeting() and not _duel_held and not _lost and not rewarding() and not news_shown() \
			and not on_board():
		autosave()


# ------------------------------------------------------- a place visited --

## A PLACE VISITED: the pane of what stands at [param tile] — a town, a
## castle, a lair, a dungeon whose clues are known — over the world, which
## waits under it ([VisitPane]); null when nothing there is visited.
## [param write] false comes back to a town after one of its services:
## nothing of the arrival is written again.
func visit(tile: Vector2i, write := true) -> VisitPane:
	if visiting():
		return _visit
	var town := VisitPane.site_slot(world, tile)
	var arrived := {}
	# A new arrival, not the place stood on opened again (the entry latch).
	var fresh := write and not _again
	if fresh and town >= 0 and int(world.sites[town]["type"]) >= ShandalarWorld.VILLAGE \
			and int(world.sites[town]["type"]) < ShandalarWorld.CASTLE and not TownStatus.ruled(world, town):
		arrived = _arrive_in_town(town)
	var place := VisitPane.describe(player, tile)
	# A lair is entered by walking onto it ([method enter_lair]).
	if place.is_empty() or String(place["kind"]) == "lair":
		return null
	if fresh and String(place["kind"]) in PUSHING_PLACES:
		# The creatures near the hero fall back as they enter
		# (adventure_input.c 838–883).
		WorldCreatures.push_back(player)
	_visit = VisitPane.new()
	_visit.player = player
	_visit.place = place
	_visit.again = not fresh
	if fresh:
		_entered_tile = tile
	_visit.k = WorldHud.BIG if hud.big else 1.0
	add_child(_visit)
	_visit.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_visit.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_visit.grow_vertical = Control.GROW_DIRECTION_BOTH
	_visit.left.connect(_left_place, CLOSING)
	_visit.card_read.connect(read_card)
	_visit.deck_wanted.connect(show_creature_deck)
	_visit_tile = tile
	_hold()
	if write and String(place["kind"]) in SWELLING_PLACES:
		soundscape.swell()
	if String(place["kind"]) in ["castle", "fallen"]:
		# The castles the hero has stood before, for the city list (F3)
		# [ours: 1997 never marked a castle visited — its castle branches of
		# `VisitTownSlot` return before the town's mark (visitLocation.c
		# 4399, 4425; 4596) — so its list's castle rows were never reached;
		# the owner's ruling H5 of 2026-10-27].
		TownStatus.put(world, int(place["slot"]), TownStatus.VISITED)
	if not arrived.is_empty():
		# The quest done here: the keeper's words over the town, the quest
		# pane at once without it.
		_visit.say(Array(arrived["lines"]))
		play_sound(String(arrived["sound"]))
		hud.refresh()
		if arrived.has("pick"):
			# A creature's quest done at a town or a city: its card picked
			# over the town's pane, free, one to be taken.
			open_trade(CardTrade.REWARD, town, {"trade": int(arrived["pick"]),
				"words": " ".join(Array(arrived["lines"]))})
	return _visit


## THE HERO ARRIVES IN TOWN [param slot] (`VisitTownSlot`, and
## `RunTownServicesMenu` before its menu): the quest whose destination it is
## completed, the journal ("Completed quest at %s" or "Visited %s"), the
## town marked visited (the city list, F3); then what the town is this
## visit — the colour it favours, a new quest when it is not the last town
## visited, its cards, the seller's hint. What the quest's completion said,
## `{lines, sound}`, or `{}`.
func _arrive_in_town(slot: int) -> Dictionary:
	var arrived := Quests.complete_at(player, slot)
	var name := WorldNames.site_name(world, slot)
	if arrived.is_empty():
		player.log_event("visit", "Visited %s" % name)
	else:
		player.log_event("quest", "Completed quest at %s" % name, {"done": true})
	TownStatus.put(world, slot, TownStatus.VISITED)
	CardTrade.arrive(player, slot)
	if player.last_town != slot:
		Quests.arrive(player, slot)
	CardShop.offers(player, slot)
	CardHints.arrive(player, slot)
	return arrived


## Whether a place's pane, or a pane over the world (the shop, the trade, a
## list of cards, the seller, the city list, the saves, the question of a
## save not written, "Ready to Quit?"), is up.
func visiting() -> bool:
	return _alive(_visit) or shopping() or trading() or _alive(_card_list) or _alive(_magic_seller) \
		or _alive(_city_list) or _alive(_save_slots) or _alive(_unsaved) or _alive(_quit_ask)


## Whether [param node] stands on the screen still: there, and not on its
## way out. Untyped, so a pane already freed may be asked about.
static func _alive(node: Variant) -> bool:
	return is_instance_valid(node) and not (node as Node).is_queued_for_deletion()


## [param pane] closed (its Done, Escape): freed — once — and the world
## again.
func _close_pane(pane: Variant) -> void:
	if _alive(pane):
		(pane as Node).queue_free()
	_show_hero()
	_sync_rest()


## THE TOWN'S PANE CLOSED, [param then] what the hero chose ([signal
## VisitPane.left]): a service of the town over the world — the deck
## builder, the shop, the trade, the wise man —, a ruled town's duel, a
## castle or a dungeon entered (`enter`, [method _enter_board]), or the
## place left.
func _left_place(then: String) -> void:
	var place: Dictionary = _visit.place if _alive(_visit) else {}
	if _alive(_visit):
		_visit.queue_free()
	_visit = null
	_show_hero()
	if not place.is_empty():
		var slot := int(place["slot"])
		match then:
			"deck":
				_open_town_deck(place)
			"shop":
				open_shop(slot)
			"trade":
				_open_town_trade(slot)
			"quest", "wiseman":
				open_wise_man(slot, "quest" if then == "quest" else "talk")
			"duel":
				_open_ruled_duel(place)
			"enter":
				_enter_board(place)
			_:
				_leave_site(place)
	_sync_rest()


## A RULED TOWN'S CREATURE DUELED ([RuledTowns]): the town's duel over the
## world, held as a meeting is ([method meeting]); done — freed or not —
## the hero is back on the map, as 1997 returned there with no services;
## with no card left to stake ([constant WorldEncounters.GAME_OVER]), the
## adventure's end instead, nothing saved ([method show_end]).
func _open_ruled_duel(place: Dictionary) -> void:
	var pane := _open_ruled_pane(int(place["slot"]))
	if pane == null:
		_leave_site(place)
		return
	_meeting = pane
	# The town's tune rests under its duel and its pictures, as under a
	# meeting's [ours: 1997 slip — its ruled town ran the duel with the
	# town's tune still on (`RunDuelEngine` stops the duel's channel, not
	# the place's), two tunes over each other; the playtest of part B, H2-2].
	soundscape.rest(true)
	pane.connect(&"finished", func(result: int) -> void:
		_meeting = null
		if result == WorldEncounters.GAME_OVER:
			show_end(Array(CreatureMeeting.NO_ANTE))
		else:
			if result == WorldEncounters.WON:
				# Freed: the town is a town again, and a click on it now
				# arrives in it (its quest, its shop) — no longer the ruled
				# town the hero arrived at (the entry latch).
				_entered_tile = Vector2i(-1, -1)
			soundscape.rest(false)
			_leave_site(place)
		_sync_rest(), CONNECT_ONE_SHOT)
	_hold()


## The ruled town's duel for site [param slot] ([method RuledTowns.open]);
## a seam, so a test can stand its own pane in.
func _open_ruled_pane(slot: int) -> Control:
	return RuledTowns.open(self, slot)


# ------------------------------------------- the castles' and dungeons' doors --

## A CASTLE OR A DUNGEON ENTERED — [param place] the castle's pane ("Yes,
## enter the castle.") or the dungeon's ("Enter the dungeon"): the place's
## tune at rest (1997's `sound_stop(0x10)` before the castle's board,
## visitLocation.c 4390 [ours: 1997 slip D-s2 — a dungeon's walk-in left the
## place's tune playing under the board's]); the world side of going in
## ([method DungeonDoors.enter]: the journal, the attempt, roaming slots 0–4
## emptied); then the board over the world ([method _open_board]), which
## holds it ([method on_board]) until its `finished(result)` ([method
## _board_done]). With no board yet ([method _board_ready], part C) the
## place is only left — the doors wait, disabled, on the panes.
func _enter_board(place: Dictionary) -> void:
	var index := -1
	match String(place.get("kind", "")):
		"castle":
			index = DungeonDoors.castle_of(world, int(place.get("slot", -1)))
		"dungeon":
			index = int(place.get("slot", -1))
	if index < 0 or not _board_ready():
		_leave_site(place)
		return
	soundscape.rest(true)
	var setup := DungeonDoors.enter(player, index)
	var board := _open_board(setup)
	if board == null:
		# No board after all: out at once, as by the board's own door.
		_board_done({}, place, index)
		return
	_board = board
	board.connect(&"finished", _board_done.bind(place, index), CLOSING)
	_hold()


## THE BOARD LEFT with [param result] (`{beaten, booted}`, part C's; `{}`
## out by its door) for [param place], castle or dungeon [param index]: the
## world side of coming out ([method DungeonDoors.leave]: a dungeon moved,
## the gifts kept, a castle left unbeaten on Wizard retaliated for), the
## place's tune again, then the place left as any is — the game saved, the
## clock on to the next 32 ([method _leave_site]; 1997 saved after a
## castle, [ours: after a dungeon too — 1997 saved nothing until the next
## town or a quit; the owner's ruling D-3 of 2026-10-27]) — and the
## retaliation's news after that save, as 1997 showed it before saving the
## same state. `game_over` in the result — no card left to stake in a room's
## duel — is the adventure's end instead, nothing saved ([method show_end]).
func _board_done(result: Dictionary, place: Dictionary, index: int) -> void:
	if _alive(_board):
		_board.queue_free()
	_board = null
	if bool(result.get("game_over", false)):
		show_end(Array(CreatureMeeting.NO_ANTE))
		_sync_rest()
		return
	var news := DungeonDoors.leave(player, index, result)
	soundscape.rest(false)
	_leave_site(place)
	if not news.is_empty():
		show_news(news)
	_show_hero()
	view.queue_redraw()
	_sync_rest()


## Whether a castle's or a dungeon's board holds the world.
func on_board() -> bool:
	return _alive(_board)


## Whether the board exists ([constant DungeonDoors.BOARD_READY]); a seam,
## so a test can open the doors before part C.
func _board_ready() -> bool:
	return DungeonDoors.BOARD_READY


## THE BOARD for [param setup] ([method DungeonDoors.enter]: `{index,
## castle, color, tries}`), over the world: a pane with `finished(result:
## Dictionary)`. Part C's; null until it is made. A seam, so a test can
## stand its own board in.
func _open_board(_setup: Dictionary) -> Control:
	return null


## EDIT DECK/SELL CARDS: the town's deck builder, which buys cards too; its
## Done comes back to the town, as 1997's `OpenTownDeckBuilder` returned to
## the town's menu — and with no cards yet, the town at once.
func _open_town_deck(place: Dictionary) -> void:
	var town := int(place["slot"]) if String(place.get("kind", "")) in VisitPane.KINDS else -1
	if show_deck(town) != null:
		_deck_from_town = true
	else:
		_back_to_town()


## THE TOWN'S TRADE ([CardTrade]) at site [param slot]; nothing on offer
## after all, the town again.
func _open_town_trade(slot: int) -> void:
	var offer := CardTrade.town_offer(player, slot)
	if offer.is_empty():
		_back_to_town()
	else:
		open_trade(CardTrade.TOWN, slot, offer)


## BACK IN THE TOWN after one of its services (the shop, the trade, the wise
## man, the deck builder): its pane again, nothing of the arrival written
## twice — no new quest, trade colour or journal line — as 1997's
## `RunTownServicesMenu` looped back to its menu.
func _back_to_town() -> void:
	if _visit_tile.x >= 0:
		visit(_visit_tile, false)


## THE HERO LEAVES A PLACE (after 1.3's `VisitTownSlot`): a town is the last
## one visited; leaving a town or city brings the World Magic seller's offer
## ([WorldMagicShop]); then the game is saved and the clock goes on to the
## next 32 ticks, as 1997 did on leaving any place.
func _leave_site(place: Dictionary) -> void:
	_visit_tile = Vector2i(-1, -1)
	var slot := int(place.get("slot", -1))
	if String(place.get("kind", "")) in VisitPane.KINDS:
		player.last_town = slot
		var offer := WorldMagicShop.offer(player, slot)
		if not offer.is_empty():
			open_magic_seller(offer)
			return
	_after_leaving()


func _after_leaving() -> void:
	player.monster_timer |= 0x1F
	autosave()
	_show_hero()


## THE WORLD MAGIC SELLER over the world ([WorldMagicPane]) for
## [param offer]; closed, the hero is on their way.
func open_magic_seller(offer: Dictionary) -> WorldMagicPane:
	var seller := WorldMagicPane.new()
	seller.player = player
	seller.offer = offer
	seller.k = WorldHud.BIG if hud.big else 1.0
	_magic_seller = seller
	add_child(seller)
	PaneStyle.centre(seller)
	seller.done.connect(_left_magic_seller.bind(seller), CLOSING)
	_hold()
	return seller


func _left_magic_seller(seller: Variant) -> void:
	if _alive(seller):
		(seller as Node).queue_free()
	hud.refresh()
	_after_leaving()
	_sync_rest()


## THE WISE MAN of town [param slot] ([WiseManPane]): [param mode] `talk`
## for his words, `quest` for the town's quest; left, the town again.
func open_wise_man(slot: int, mode: String) -> WiseManPane:
	var pane := WiseManPane.new()
	pane.player = player
	pane.mode = mode
	pane.place = WiseManPane.place_of(player, slot)
	pane.k = WorldHud.BIG if hud.big else 1.0
	_visit = pane
	add_child(pane)
	PaneStyle.centre(pane)
	pane.left.connect(_left_wise_man.bind(pane, slot), CLOSING)
	pane.deck_wanted.connect(show_creature_deck)
	pane.card_read.connect(read_card)
	pane.copying.connect(func(color: int) -> void:
		var list := open_card_list("Pick a spell",
			"A copy of it for three %s amulets." % WiseMan.COLOR_WORDS[clampi(color, 1, 5) - 1],
			_copyable(CardListPane.counted(player.cards.map(func(c: Dictionary) -> String: return String(c["card"])))), true)
		list.picked.connect(func(card_name: String) -> void:
			_close_card_list()
			pane.copied(card_name)))
	_hold()
	return pane


## The hero's cards [param counted] the wise man may copy: under the Classic
## MTG rules none the hero holds every copy of they allow ([method
## CardShop.classic_rule]).
func _copyable(counted: Dictionary) -> Dictionary:
	var rule := CardShop.classic_rule(player)
	if rule.is_empty():
		return counted
	var out := {}
	for card_name in counted:
		if CardShop.classic_allows(rule, String(card_name)):
			out[card_name] = counted[card_name]
	return out


## THE WISE MAN LEFT ([param pane], of town [param slot]): the town has
## heard its wise man this visit — 1997 set `g_last_town_services_town_index`
## at the end of `VisitTownWiseman` for his talk and the town's quest alike
## (visitLocation.c ~996), so the next "Speak to Wise Man" here is no fresh
## talk with a gift — and the town's pane again.
func _left_wise_man(_then: String, pane: Variant, slot: int) -> void:
	if _alive(pane):
		(pane as Node).queue_free()
	if _visit == pane:
		_visit = null
	player.last_town = slot
	hud.refresh()
	_show_hero()
	_back_to_town()
	_sync_rest()


## A CREATURE'S DECK SEEN ([CreatureBook] row [param index]) — a wise man's
## gift or the Guardian's Ghost: its cards listed over the pane, which goes
## on once it is closed.
func show_creature_deck(index: int) -> CardListPane:
	var deck := CreatureBook.deck(index)
	var cards := CardListPane.counted(deck.cards if deck != null else [])
	var list := open_card_list("The deck of %s" % CreatureBook.called(index), "Opponent library", cards, false)
	var under := _visit
	list.done.connect(func() -> void:
		if _alive(under) and under.has_method("deck_seen"):
			under.call("deck_seen"), CLOSING)
	return list


## A LIST OF CARDS over the pane under it ([CardListPane]): [param cards]
## by name with their counts; [param picking] for a pick. Closed, the pane
## under it is shown again.
func open_card_list(title: String, subtitle: String, cards: Dictionary, picking: bool) -> CardListPane:
	_close_card_list()
	_card_list = CardListPane.new()
	_card_list.title = title
	_card_list.subtitle = subtitle
	_card_list.cards = cards
	_card_list.picking = picking
	_card_list.k = WorldHud.BIG if hud.big else 1.0
	if _alive(_visit):
		_visit.visible = false
	add_child(_card_list)
	PaneStyle.centre(_card_list)
	_card_list.card_read.connect(read_card)
	_card_list.done.connect(_close_card_list, CLOSING)
	_hold()
	return _card_list


func _close_card_list() -> void:
	if _alive(_card_list):
		_card_list.queue_free()
	_card_list = null
	if _alive(_visit):
		_visit.visible = true
	_sync_rest()


## A ONE-SHOT SOUND by its skin key ("" none) ([method WorldSoundscape.play]).
func play_sound(key: String) -> void:
	if soundscape != null:
		soundscape.play(key)


## THE TOWN'S CARD SHOP over the world ([CardShopPane]); Done goes back to
## the town's pane.
func open_shop(slot: int) -> CardShopPane:
	if shopping():
		return _shop
	_shop = CardShopPane.new()
	_shop.player = player
	_shop.slot = slot
	_shop.k = WorldHud.BIG if hud.big else 1.0
	add_child(_shop)
	_shop.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_shop.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_shop.grow_vertical = Control.GROW_DIRECTION_BOTH
	_shop.done.connect(_left_shop, CLOSING)
	_shop.card_read.connect(read_card)
	_hold()
	return _shop


func shopping() -> bool:
	return _alive(_shop)


func _left_shop() -> void:
	if shopping():
		_shop.queue_free()
	_shop = null
	_show_hero()
	_back_to_town()
	_sync_rest()


## THE CARD TRADER over the world ([CardTradePane]): [param way] a town's
## trade at site [param slot] ([param offer] its [method
## CardTrade.town_offer]), a creature quest's reward there ([constant
## CardTrade.REWARD]: [param offer] `{trade, words}` — a card of the town's
## wares, free, one to be taken), or a lair's — the pane of the place waits
## under it.
func open_trade(way: String, slot := -1, offer := {}) -> CardTradePane:
	if trading():
		return _trade
	_trade = CardTradePane.new()
	_trade.player = player
	_trade.way = way
	_trade.slot = slot
	_trade.k = WorldHud.BIG if hud.big else 1.0
	match way:
		CardTrade.TOWN:
			_trade.trade = int(offer.get("trade", 0))
			_trade.color = String(offer.get("color", ""))
			_trade.who = "%s trades %s for %s amulets." % [WorldNames.site_name(world, slot),
				CardTrade.wares(_trade.trade), _trade.color]
		CardTrade.REWARD:
			_trade.trade = int(offer.get("trade", 0))
			_trade.who = String(offer.get("words", ""))
		CardTrade.BAZAAR:
			_trade.who = "The Nomad's Bazaar: any card, for gold."
		_:
			_trade.who = "The Diamond Mine: any card, for amulets of any color."
	if _alive(_visit):
		_visit.visible = false
	add_child(_trade)
	_trade.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_trade.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_trade.grow_vertical = Control.GROW_DIRECTION_BOTH
	_trade.done.connect(_left_trade, CLOSING)
	_trade.card_read.connect(read_card)
	_hold()
	return _trade


## A CARD READ FULL SCREEN (a right click on it in a pane; the options
## switch it, [method WorldHud.reader_wanted]): true when it opened.
func read_card(card_name: String) -> bool:
	if not WorldHud.reader_wanted() or not CardRegistry.has_card(card_name):
		return false
	return reader.open_instance(CardInstance.new(CardRegistry.get_card(card_name), -1, 0))


func trading() -> bool:
	return _alive(_trade)


## Whether a creature quest's reward is being picked ([constant
## CardTrade.REWARD]).
func rewarding() -> bool:
	return trading() and _trade.way == CardTrade.REWARD


func _left_trade() -> void:
	var way := _trade.way if trading() else ""
	var slot := _trade.slot if trading() else -1
	var said := _trade.said if trading() else ""
	if trading():
		_trade.queue_free()
	_trade = null
	_show_hero()
	if way == CardTrade.TOWN:
		# The town's trade is done for a while, a card traded or not.
		CardTrade.traded(player, slot)
		_back_to_town()
	elif _alive(_visit):
		_visit.visible = true
		if _visit is LairPane:
			(_visit as LairPane).traded()
		elif way == CardTrade.REWARD and said != "":
			# The quest's reward taken: what came of it, under the keeper's
			# words.
			var lines: Array = Array(_visit.place.get("lines", []))
			lines.append(said)
			_visit.say(lines)
	_sync_rest()


## A LAIR ENTERED: the lair in roaming slot [param slot] ([WorldLairs]) —
## what it holds drawn ([LairEvent]), and the lair SPENT AT ONCE: gone from
## the map and counted explored before the game is saved, as 1997 saved it
## on entering (the lead's ruling C, 2026-10-23: no save may hold a lair the
## hero is inside, so a window closed mid-riddle forfeits the card still
## waiting, as quitting 1997 mid-event lost it). Its pane over the world
## ([LairPane]), the nearby place's tune silent under it (1997's
## `StopWorldLocationMusic`); null when the slot holds no lair.
func enter_lair(slot: int) -> LairPane:
	if modal():
		return null
	var held := WorldLairs.held_in(player, slot)
	if String(held.get("kind", "")) != "lair":
		return null
	walk.stop()
	var event := LairEvent.begin(player, held)
	WorldLairs.explored(player, slot)
	autosave()
	soundscape.rest(true)
	var pane := LairPane.new()
	pane.player = player
	pane.event = event
	pane.place = LairPane.place_of(event)
	pane.k = WorldHud.BIG if hud.big else 1.0
	_visit = pane
	_visit_tile = Vector2i(-1, -1)
	add_child(pane)
	pane.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pane.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pane.grow_vertical = Control.GROW_DIRECTION_BOTH
	pane.left.connect(_left_lair.bind(slot), CLOSING)
	pane.trading.connect(func(way: String) -> void: open_trade(way))
	pane.card_read.connect(read_card)
	pane.deck_wanted.connect(show_creature_deck)
	_hold()
	return pane


## THE LAIR LEFT ([param _slot] its roaming slot, spent as it was entered):
## the world again, the nearby place's tune heard again, the game saved
## with what the lair gave.
func _left_lair(_then: String, _slot: int) -> void:
	if _alive(_visit):
		_visit.queue_free()
	_visit = null
	soundscape.rest(false)
	autosave()
	_show_hero()
	view.queue_redraw()
	_sync_rest()


## A CREATURE MET: the creature in roaming slot [param slot] ([WorldCreatures])
## reached the hero — the walk stopped, the nearby place's tune resting, THE
## GAME SAVED WITH THE CREATURE STILL THERE (the owner's ruling 4, as 1997
## saved before every meeting: quitting mid-meeting or mid-duel meets it
## again, nothing lost or won), then its meeting over the world
## ([WorldEncounters]), which holds the world while it lasts. Its end spends
## the slot ([method _after_meeting]); null when no meeting could be held —
## the slot is spent at once, as met with no duel.
func meet_creature(slot: int) -> Control:
	if modal() or player == null:
		return null
	if not WorldCreatures.is_creature(WorldLairs.held_in(player, slot)):
		return null
	walk.stop()
	soundscape.rest(true)
	autosave()
	var pane := _open_meeting(slot)
	if pane == null:
		_after_meeting(WorldCreatures.NO_DUEL, slot)
		return null
	_meeting = pane
	pane.connect(&"finished", _after_meeting.bind(slot), CLOSING)
	_hold()
	return pane


## The meeting's pane for slot [param slot] ([method WorldEncounters.open]);
## a seam, so a test can stand its own pane in.
func _open_meeting(slot: int) -> Control:
	return WorldEncounters.open(self, slot)


## Whether a creature's meeting holds the world.
func meeting() -> bool:
	return _alive(_meeting)


## THE MEETING OVER with [param result] ([constant WorldCreatures.WON],
## LOST, DRAWN or NO_DUEL) for the creature of slot [param slot]: the slot
## spent — stamped, emptied, the clock on to the next 32 ([method
## WorldCreatures.met]) —, the tick that met it ended, the besieger's end
## handed on ([method _after_siege_meeting]), the place's tune again and
## the game saved, as 1997 saved after. [constant WorldEncounters.GAME_OVER]
## — no card left to stake — is the adventure's end instead: nothing spent,
## nothing saved ([method show_end]).
func _after_meeting(result: int, slot: int) -> void:
	if _alive(_meeting):
		_meeting.queue_free()
	_meeting = null
	if result == WorldEncounters.GAME_OVER:
		_tick_held = false
		show_end(Array(CreatureMeeting.NO_ANTE))
		_sync_rest()
		return
	var outcome := WorldCreatures.met(player, slot, result)
	if _tick_held:
		_tick_held = false
		walk.end_tick()
	if String(outcome["siege"]) != "":
		_after_siege_meeting(outcome)
	soundscape.rest(false)
	autosave()
	_show_hero()
	view.queue_redraw()
	_sync_rest()


## THE BESIEGER'S MEETING OVER ([method WorldCreatures.met]'s [param
## outcome]: `siege` "lifted" on a win, "falls" otherwise, with its
## `creature`, `color` and `town`; the slot already spent) — THE SIEGES'
## HOOK (world_lair_monster_slots.c 941–950): a win lifts the siege, "Saved
## %s" in the journal ([method Sieges.lifted]); a loss, a draw or no duel
## lets the town fall at once ([method Sieges.resolve]), its news shown —
## and the end after it, when the Spell of Dominion is cast.
func _after_siege_meeting(outcome: Dictionary) -> void:
	match String(outcome.get("siege", "")):
		"lifted":
			Sieges.lifted(player, outcome)
		"falls":
			var news := Sieges.resolve(player, outcome)
			if not news.is_empty():
				show_news(news)


## A DUEL'S SCREEN OVER THE WORLD ([param on]; the meeting's duel host calls
## it as the duel opens and closes): the world, the panel and the arrows
## hidden under it and the world held; gone, they come back.
func hold_for_duel(on: bool) -> void:
	_duel_held = on
	if on:
		_wear(-1)
		_dragging = false
		hud.hide_place()
	_cover_world(on)
	_sync_rest()


## THE CITY LIST (F3, the options, the map's City Info): every town and
## city the hero has visited ([CityListPane]) over the world; closed, the
## world again. Not while a pane holds the screen (ruling A).
func show_city_list() -> CityListPane:
	if modal():
		return null
	var list := CityListPane.new()
	list.player = player
	list.k = WorldHud.BIG if hud.big else 1.0
	_city_list = list
	add_child(list)
	PaneStyle.centre(list)
	list.done.connect(_close_pane.bind(list), CLOSING)
	_hold()
	return list


func city_list_shown() -> bool:
	return _alive(_city_list)


# ----------------------------------------------------- the panel's parts --

## THE CLUES (the frame's gate, F4): what the hero has learned of the
## castles and the dungeons ([WorldClues]). Not while the world waits.
func show_clues() -> void:
	if _world_waits():
		return
	hud.toggle_clues()


## THE HERO (the frame's faces, F5): the journal and the stats. Not while
## the world waits.
func toggle_hero() -> void:
	if _world_waits():
		return
	hud.toggle_hero()


## THE KEYS (?, H). Not while the world waits.
func toggle_help() -> void:
	if _world_waits():
		return
	hud.toggle_help()


## THE SPELLBOOK (the frame's book, F1): the deck builder that only looks,
## as 1997's did outdoors ([method show_deck]). Not while the world waits.
func open_spellbook() -> AdventureBuilder:
	if _world_waits():
		return null
	return show_deck(-1, true)


## CAST the World Magic of key [param key] (1–5, or a click on its icon)
## ([WorldMagic]): the hero set down elsewhere when it moves them, its
## words beside the panel. What [method WorldMagic.cast] answered; `{}`
## while the world waits (a pane holds the screen, or the map is up).
func cast(key: int) -> Dictionary:
	if player == null or _world_waits():
		return {}
	# Leap of Fate and Sword of Resistance show the new place block by
	# block over the old ([RevealDissolve]) — the screen read back only for
	# a cast that will move the hero.
	var before := _picture_for_reveal() if _cast_moves(key) and TileReveal.wanted() else null
	var result := WorldMagic.cast(player, key)
	if result["moved"]:
		walk.stop()
		world.explore_around(player.tile())
		view.camera = Vector2(player.position)
		_reveal(before)
	_show_hero()
	view.queue_redraw()
	if result["deck"]:
		var builder := show_deck()
		if builder != null:
			builder._say(String(result["said"]))
	elif String(result["said"]) != "":
		hud.say(result["said"])
	return result


## Whether casting key [param key] will set the hero down elsewhere, by
## [WorldMagic]'s own rules: Leap of Fate whenever it can be cast, Sword of
## Resistance when a town is besieged.
func _cast_moves(key: int) -> bool:
	if not WorldMagic.ready_to_cast(player, key):
		return false
	return key == 2 or (key == 5 and not WorldMagic.siege_creature(player).is_empty())


## The screen as it stands, for the reveal ([method RevealDissolve.picture_of]);
## a seam, so a test can count the pictures taken.
func _picture_for_reveal() -> Texture2D:
	return RevealDissolve.picture_of(self)


## The world view shown block by block over [param before] (black for
## null), the panel live above it.
func _reveal(before: Texture2D) -> void:
	var cover := RevealDissolve.over(self, before)
	move_child(cover, view.get_index() + 1)


## THE DECK (the frame's spellbook, F1, and Conjurer's Will): the
## adventure's deck builder over the world, which waits under it
## ([AdventureBuilder]); Done writes the decks back to the hero. As in 1997
## the spellbook only looks ([param looking]); a town's Edit deck/Sell
## cards ([param sell_site]) and Conjurer's Will change the decks. Null,
## and said so, with no cards yet.
func show_deck(sell_site := -1, looking := false) -> AdventureBuilder:
	if building():
		return _builder
	if player.cards.is_empty():
		hud.say("No cards yet.")
		return null
	_wear(-1)
	_dragging = false
	_cover_world(true)
	_builder = AdventureBuilder.new()
	_builder.name = "DeckBuilder"
	_builder.player = player
	_builder.sell_site = sell_site
	_builder.looking = looking
	_builder.closed.connect(_deck_closed, CONNECT_ONE_SHOT)
	_builder.exit_requested.connect(_save_and_end)
	add_child(_builder)
	soundscape.rest(true)
	_sync_rest()
	return _builder


func building() -> bool:
	return _alive(_builder)


## The builder is done: the world again, its music, the deck's count — and
## the town again when the town's Edit deck/Sell cards opened it.
func _deck_closed() -> void:
	if building():
		_builder.queue_free()
	_builder = null
	_cover_world(false)
	var music := get_node_or_null(^"/root/ShellMusic")
	if music != null:
		music.call(&"play")
	soundscape.rest(false)
	_show_hero()
	hud.say("Deck %d: %d cards" % [player.current_deck + 1, hud.cards_in_deck()])
	if _deck_from_town:
		_deck_from_town = false
		_back_to_town()
	_sync_rest()


# ------------------------------------------------------------- the walk --

## Walk to [param tile] (the way is found); true when there is a way. The
## place the hero stands on is visited again. Not while a pane holds the
## screen (ruling A: the small map's click under a pane walks no one).
func walk_to_tile(tile: Vector2i) -> bool:
	if walk == null or modal():
		return false
	if tile == player.tile() and not walk.is_walking():
		# THE ENTRY LATCH [ours] (the bug pass of part B): the place the hero
		# arrived at and still stands on opens again — our QoL; 1997 entered a
		# place only as the hero stepped onto it — but not as a new arrival: no
		# creature is pushed back again, the town's arrival is not run again, a
		# ruled town keeps the creature it drew. A place the hero stands on
		# but never arrived at (a walk stopped on it by a meeting or the news,
		# a teleport onto it, a town just freed) is arrived at now.
		_again = tile == _entered_tile
		var pane := visit(tile)
		_again = false
		return pane != null
	var going := walk.walk_to(tile)
	if going:
		view.camera = view.hero
	return going


## The world's clock run for [param seconds]: a tick every
## [constant HeroWalk.TICK] in 1997's order (shandalar.c 625–655) — the
## hero's step and the land they pass explored, the footsteps, the place
## walked to visited (1997 entered a town within the step), the roaming
## slots ([WorldCreatures]: refilled, walked, met, crying), then the clock
## on ([method HeroWalk.end_tick]). A lair reached is entered, a creature
## met: the tick stops there. A siege's news brought by the step
## ([method HeroWalk.take_news]) stops it before the creatures: the rest
## of the tick waits for the news to be read ([method show_news]).
func advance(seconds: float) -> void:
	if walk == null:
		return
	_tick_left += seconds
	var ticks := 0
	while _tick_left >= HeroWalk.TICK and ticks < MOST_TICKS:
		_tick_left -= HeroWalk.TICK
		ticks += 1
		var walking := walk.is_walking()
		if walk.step():
			world.explore_around(player.tile())
			Quests.note_heading(player)
		soundscape.tick(walk)
		if walking:
			view.camera = Vector2(player.position)
		var reached := walking and not walk.is_walking() and player.tile() == walk.destination
		var news := walk.take_news()
		if not news.is_empty():
			# 1997 showed the news inside the hero's step, the creatures
			# not yet moved: the tick waits for it.
			_tick_held = true
			show_news(news, reached)
			break
		if _rest_of_tick(reached):
			break
	if ticks == MOST_TICKS:
		_tick_left = 0.0
	if ticks > 0:
		# Not while the tick waits for the news: the place that step reached
		# is entered first ([method _after_news]) — a letter delivered on its
		# last day, not failed for the news read before it (the bug pass of
		# part B, q3-3; 1997 entered the town inside the step).
		if not _tick_held:
			_check_quest()
		_show_hero()
		view.queue_redraw()
		if _map.visible:
			_map.queue_redraw()


## THE TICK'S SECOND HALF, after the hero's step: the place walked to
## visited ([param reached] the step reached it) — [QoL: only the place
## walked to; 1997 entered every town stepped on, and a way found for the
## hero would wander into towns not chosen], the creatures resting that
## tick [ours: 1997 walked them after the town, already pushed back] — or
## the roaming slots ([WorldCreatures]: refilled, walked, met, crying); a
## lair reached entered, a creature met; then the clock on. True when the
## clock's run stops here (a place opened, a lair, a meeting).
func _rest_of_tick(reached: bool) -> bool:
	var opened := reached and visit(player.tile()) != null
	var slots := {} if opened else WorldCreatures.tick(player)
	_cry(slots.get("cries", []))
	var met := int(slots.get("met", -1))
	if met >= 0:
		view.camera = Vector2(player.position)
		if String(slots["kind"]) == "lair":
			enter_lair(met)
		else:
			# The clock moves on as the meeting ends ([method
			# _after_meeting]): 1997's meeting held the tick, its stamp is
			# this tick's.
			_tick_held = true
			meet_creature(met)
			if _tick_held and not meeting():
				_tick_held = false
				walk.end_tick()
			return true
	walk.end_tick()
	return opened or met >= 0


# ---------------------------------------------------------- the sieges --

## THE NEWS FLASH ([NewsFlashPane]) of [param news] ([method
## Sieges.on_step], [method Sieges.resolve]), one pane after another over
## the world, which waits under them; the walk stopped [QoL]. News that ends
## the adventure (the Spell of Dominion) loses it at once — nothing is saved
## from then — and its end follows the news ([method show_end]). Read, the
## held tick goes on ([param reached]: the step had reached the walk's
## place, visited then). The pane shown, or null.
func show_news(news: Array, reached := false) -> NewsFlashPane:
	if walk != null:
		walk.stop()
	for one in news:
		_news_queue.append(one)
	_news_reached = _news_reached or reached
	if Sieges.ends(news):
		_lost = true
	return _next_news()


## Whether a news flash holds the screen.
func news_shown() -> bool:
	return _alive(_news)


## The next news shown; none left, the end when the adventure is lost, else
## the tick that waited goes on.
func _next_news() -> NewsFlashPane:
	if news_shown():
		return _news
	while not _news_queue.is_empty():
		var one: Dictionary = _news_queue.pop_front()
		if String(one.get("kind", "")) == "dominion":
			_news_queue.clear()
			show_end(Array(one.get("lines", [])))
			return null
		var pane := NewsFlashPane.new()
		pane.player = player
		pane.news = one
		pane.k = WorldHud.BIG if hud.big else 1.0
		_news = pane
		add_child(pane)
		pane.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		pane.grow_horizontal = Control.GROW_DIRECTION_BOTH
		pane.grow_vertical = Control.GROW_DIRECTION_BOTH
		pane.left.connect(_news_read.bind(pane), CLOSING)
		_hold()
		return pane
	_after_news()
	return null


## A news flash read ([param pane]): the next, or the world again.
func _news_read(_then: String, pane: Variant) -> void:
	if _alive(pane):
		(pane as Node).queue_free()
	if _news == pane:
		_news = null
	_next_news()
	_sync_rest()


## Every news read: the tick that waited for it goes on — the place walked
## to visited, the creatures' turn, the clock on — and the world again.
func _after_news() -> void:
	var reached := _news_reached
	_news_reached = false
	if _tick_held and not _lost:
		_tick_held = false
		_rest_of_tick(reached)
		_check_quest()
	_show_hero()
	view.queue_redraw()
	_sync_rest()


## The quest's deadline looked at ([method WorldStatus.check_quest]): a
## quest run out of time failed, and said beside the panel.
func _check_quest() -> void:
	var lost := WorldStatus.check_quest(player)
	if lost != "":
		hud.say(lost)


## THE ADVENTURE'S END ([AdventureEndScreen]) with [param lines], the
## 1997 words: the adventure lost — no save from now on, the world never
## runs again —, the end over everything; read, the title, the saves as
## they were ([method leave_unsaved]).
func show_end(lines: Array) -> AdventureEndScreen:
	_lost = true
	if walk != null:
		walk.stop()
	if _alive(_end):
		return _end
	_end = AdventureEndScreen.new()
	_end.lines = lines
	add_child(_end)
	_end.closed.connect(leave_unsaved, CLOSING)
	if soundscape != null:
		soundscape.rest(true)
	_hold()
	return _end


## Whether the adventure's end is shown.
func ended() -> bool:
	return _alive(_end)


## Whether the adventure is lost ([method show_end]).
func lost() -> bool:
	return _lost


## The creatures that may cry this tick ([method WorldCreatures.tick]'s
## `cries`): each heard, maybe, from where it stands on the screen
## ([method WorldSoundscape.cry], on its own dice).
func _cry(cries: Array) -> void:
	for one in cries:
		var at := view.drawn_at(Vector2(int(one["x"]), int(one["y"])))
		soundscape.cry(int(one["creature"]), int(one["distance"]), at)


## The tile under [param point] on the view.
func tile_at(point: Vector2) -> Vector2i:
	# Where the land is DRAWN under the point, the glide included.
	var at := view.unproject_drawn(point)
	return Vector2i(floori(at.x / 32.0), floori(at.y / 32.0))


## The place the hero can see and visit at [param tile] ([method
## VisitPane.describe]), or `{}`: on land seen, or a known dungeon drawn on
## land not yet seen [QoL: it is drawn there (the owner's ruling A-1 of
## 2026-10-27, [method WorldClues.on_world]), so the pointer names it too].
func place_at(tile: Vector2i) -> Dictionary:
	if player == null or world == null:
		return {}
	if not world.is_explored(tile.x, tile.y) and DungeonDoors.at(world, tile) < 0:
		return {}
	return VisitPane.describe(player, tile)


## The pointer over [param tile]: the place there ([constant
## WorldCursors.FOR_PLACE]), the walking man elsewhere.
func pointer_for(tile: Vector2i) -> WorldCursors.Kind:
	var place := place_at(tile)
	if place.is_empty():
		return WorldCursors.Kind.WALK
	return WorldCursors.FOR_PLACE.get(String(place["kind"]), WorldCursors.Kind.WALK)


func _wear(kind: int) -> void:
	if kind == _pointer:
		return
	_pointer = kind
	if kind < 0:
		WorldCursors.take_off()
	else:
		WorldCursors.wear(kind)


func _exit_tree() -> void:
	_wear(-1)


## THE PLACE UNDER THE POINTER at [param point]: its pointer worn, its kind
## and name floating by it — none while a drag looks around.
func _hover_world(point: Vector2) -> void:
	var place := place_at(tile_at(point))
	_wear(WorldCursors.FOR_PLACE.get(String(place.get("kind", "")), WorldCursors.Kind.WALK))
	if place.is_empty() or _dragged:
		hud.hide_place()
	else:
		hud.show_place(String(place["name"]), String(place["subtitle"]), point)


## THE POINTER LOOKED AT AGAIN when the land moved under it — a walk, a
## look, a zoom, a leap: the place now under a still pointer named and its
## pointer worn, as a motion would, while the pointer rests on the world.
func _point_again() -> void:
	if _world_waits():
		return
	var looked := Vector3(view.camera.x, view.camera.y, view.zoom)
	if looked == _pointed:
		return
	_pointed = looked
	var under := get_viewport().gui_get_hovered_control()
	if under == view or under == self:
		_hover_world(get_local_mouse_position())


## Look by [param pixels] on the screen.
func look(pixels: Vector2) -> void:
	var p := pixels / view.zoom
	view.camera += Vector2(p.x / 4.0 - p.y / 2.0, p.x / 4.0 + p.y / 2.0)
	var limit := float(ShandalarWorld.TILES * 32)
	view.camera = view.camera.clamp(Vector2(-256, -256), Vector2(limit + 256, limit + 256))
	view.queue_redraw()


func set_zoom(value: float) -> void:
	view.zoom = clampf(value, WorldView.ZOOM_MIN, WorldView.ZOOM_MAX)
	view.queue_redraw()


func back_to_hero() -> void:
	view.camera = view.hero
	view.queue_redraw()


## THE JOURNAL WALKED ON THE MAP ([method WorldMap.walk_journal]). Not while
## a pane holds the screen.
func walk_journal() -> void:
	if modal():
		return
	hud.close_panels()
	if not _map.visible:
		toggle_map()
	_map.walk_journal()


## THE MAP (the frame's scroll, M, F2) opened or closed. Not while a pane
## holds the screen (ruling A).
func toggle_map() -> void:
	if modal():
		return
	_map.visible = not _map.visible
	# The map is a whole screen, as 1997's was: the panel and its panes
	# rest under it.
	hud.visible = not _map.visible
	if _map.visible and _map.mode == WorldMap.Mode.JOURNAL:
		_map.show_mode(WorldMap.Mode.MAIN)
	_dragging = false
	hud.hide_place()
	guides.visible = not _map.visible and not guides.targets.is_empty()
	_arrival.visible = not _map.visible and arrival != ""
	if _map.visible:
		_wear(-1)
	_map.queue_redraw()


func _process(delta: float) -> void:
	_sync_rest()
	if world == null:
		return
	if _leave_after and not modal():
		# A held duel's Return to main menu taken once it was over ([method
		# leave_after_panes]): what it brought seen, saved and left.
		_leave_after = false
		if not _lost:
			leave()
		return
	if _entered_tile.x >= 0 and player != null and player.tile() != _entered_tile:
		_entered_tile = Vector2i(-1, -1)
	if _map.visible or modal():
		# The world waits under it; what a pane changes — food bought, a card
		# sold, an amulet paid, a meeting's tribute, a link lost to the news —
		# shows on the panel at once (the playtest of part B, P4-5: under a
		# meeting it lagged until the meeting was over). Not under a duel's
		# screen, which hides the panel.
		if (visiting() or meeting() or news_shown()) and not _duel_held:
			hud.refresh_numbers()
		# The hero stands where the last tick left them, not a step short.
		view.frame(1.0)
		return
	advance(delta * WorldHud.pace())
	# A walk's last step opened a place's pane this tick: the world waits
	# from now, as above, and the pointer is not read again under the pane
	# (the bug pass after the campaign, r3-1: the place's name and its
	# pointer came back beside the pane).
	if _world_waits():
		view.frame(1.0)
		return
	# THE GLIDE [QoL]: the clock ticks every [constant HeroWalk.TICK], the
	# hero and the view slide between its ticks ([method WorldView.frame]).
	view.frame(_tick_left / HeroWalk.TICK)
	_look_with_keys(delta)
	_point_again()


## The arrows (W A S D too) look around; Ctrl+S saves, so with Ctrl held
## they never look down. While the hero's pane is open W and D are the
## pane's — W the Wizards, D closes it (J the Journal), as 1997's stats
## screen took them (adventureStats.c 136–138; the owner's ruling C-3) — so
## they look no more until it closes, nor while the key that closed it is
## still held ([member _pane_letters]); A, S and the arrows still do.
## [QoL: the arrows look where 1997's walked the hero — a click walks here.]
func _look_with_keys(delta: float) -> void:
	for code in _pane_letters.duplicate():
		if not Input.is_key_pressed(code):
			_pane_letters.erase(code)
	if Input.is_key_pressed(KEY_CTRL):
		return
	var pane := hud.hero_shown()
	var w := Input.is_key_pressed(KEY_W) and not pane and not KEY_W in _pane_letters
	var d := Input.is_key_pressed(KEY_D) and not pane and not KEY_D in _pane_letters
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		direction.x -= 1
	if Input.is_key_pressed(KEY_RIGHT) or d:
		direction.x += 1
	if Input.is_key_pressed(KEY_UP) or w:
		direction.y -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		direction.y += 1
	if direction != Vector2.ZERO:
		look(direction.normalized() * LOOK_SPEED * delta)


func _gui_input(event: InputEvent) -> void:
	if _map.visible or modal():
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_dragging = true
				_dragged = false
				_pressed_at = button.position
			else:
				_dragging = false
				# A press let go where it was made is a click: walk there —
				# unless it closes the options, as a click outside a menu does.
				if not _dragged and not hud.close_options():
					walk_to_tile(tile_at(button.position))
		elif button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
			# THE RIGHT CLICK: the options at the pointer — 1997's right
			# button on the world opened its "Will you ..." menu (`@STARTUP`
			# 1: Save, Load, Quit, the deck, the map, the city list, the
			# clues, the stats, the wizards; adventure_input.c 31–94), whose
			# entries the options hold (the owner's ruling C-4). Again closes.
			_dragging = false
			hud.hide_place()
			hud.toggle_options_at(button.position)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoom(view.zoom * ZOOM_STEP)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom(view.zoom / ZOOM_STEP)
	elif event is InputEventMagnifyGesture:
		# A pinch on a touchpad or a touchscreen zooms.
		set_zoom(view.zoom * (event as InputEventMagnifyGesture).factor)
	elif event is InputEventPanGesture:
		# Two fingers sliding on a touchpad look around.
		look((event as InputEventPanGesture).delta * PAN_STEP)
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _dragging and motion.button_mask & MOUSE_BUTTON_MASK_LEFT == 0:
			_dragging = false
		if _dragging:
			if not _dragged and motion.position.distance_to(_pressed_at) > CLICK_SLOP:
				_dragged = true
			if _dragged:
				look(-motion.relative)
		_hover_world(motion.position)


## The world's keys ([constant WorldHud.KEYS] says them): M or F2 the map,
## F1 the deck, F3 the cities, F4 the clues, F5 the hero, F6 the wizards,
## 1–5 a World Magic, N the small map, H the keys, L the saved adventures,
## Ctrl+S the slots, Space stops the walk and comes back to the hero, Home
## comes back, + and − zoom; Escape or Q closes what is open, else asks
## "Ready to Quit?". A pane that holds the screen hears its own keys
## (ruling A); the map takes its own ([method _map_key], ruling B). For a
## moment after the last pane closed ([constant AFTER_PANE_MS], the
## shield's) the world hears none of them: the playtest of part B (H2-1,
## P1-1) — Escape reads a news flash and goes on at every spoils' picture,
## so one press too many saved and left for the title unasked, and a digit
## cast a World Magic. Under the map its keys act as ever (none leaves).
func _unhandled_input(event: InputEvent) -> void:
	if _leaving or modal():
		return
	if not _map.visible and Time.get_ticks_msec() < _shield_until:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _map.visible:
			toggle_map()
		else:
			_close_or_ask()
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if _map.visible:
		_map_key(key)
		return
	match key.keycode:
		KEY_M, KEY_F2:
			toggle_map()
		KEY_F1:
			open_spellbook()
		KEY_F3:
			show_city_list()
		KEY_F4:
			show_clues()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			cast(key.keycode - KEY_0)
		KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5:
			cast(key.keycode - KEY_KP_0)
		KEY_N:
			hud.show_minimap(not hud.minimap_shown())
		KEY_F5:
			toggle_hero()
		KEY_F6:
			toggle_wizards()
		KEY_H:
			toggle_help()
		KEY_L:
			open_load()
		KEY_Q:
			_close_or_ask()
		KEY_S:
			if key.ctrl_pressed:
				save_now()
			else:
				return
		KEY_SPACE:
			stop_and_back()
		KEY_HOME:
			back_to_hero()
		KEY_PLUS, KEY_KP_ADD, KEY_EQUAL:
			set_zoom(view.zoom * ZOOM_STEP)
		KEY_MINUS, KEY_KP_SUBTRACT:
			set_zoom(view.zoom / ZOOM_STEP)
		_:
			return
	get_viewport().set_input_as_handled()


## ESCAPE OR Q: what the panel has open closed (its panes, the options, the
## keys), else "Ready to Quit?" ([method ask_quit]).
func _close_or_ask() -> void:
	if not hud.close_panels():
		ask_quit()


## READY TO QUIT? (Escape or Q with nothing open; 1997's `@SHUTDOWN`,
## adventure_input.c 311–324 — the owner's ruling C-1 of 2026-10-27):
## "Yes." saves and leaves for the title ([method leave]); "No." or Escape
## stays — a walk under way goes on, as 1997's way held through its
## question; Save and Load put the question away and open the ten slots
## ([method save_now]) or the saved adventures ([method open_load]) [ours]. [ours: 1997 wrote its slot 3 after the question whatever the
## answer; here staying saves nothing — the save made as the hero left the
## last place stands.] The world waits while it is asked. Not while a pane
## holds the screen. The question shown, or null.
func ask_quit() -> QuitAsk:
	if _alive(_quit_ask):
		return _quit_ask
	if player == null or modal():
		return null
	var asked := QuitAsk.new()
	asked.k = WorldHud.BIG if hud.big else 1.0
	_quit_ask = asked
	add_child(asked)
	PaneStyle.centre(asked)
	asked.answered.connect(func(leave_now: bool) -> void:
		if _alive(asked):
			asked.queue_free()
		_sync_rest()
		if leave_now:
			leave(), CLOSING)
	asked.chose.connect(func(what: String) -> void:
		if _alive(asked):
			asked.queue_free()
		_sync_rest()
		if what == "save":
			save_now()
		else:
			open_load(), CLOSING)
	_hold()
	return asked


## Whether "Ready to Quit?" is asked.
func quit_asked() -> bool:
	return _alive(_quit_ask)


## THE WIZARDS (F6, the options' "Wizards (F6)"): the hero's pane on its
## Wizards tab ([method WorldHud.toggle_wizards]) — 1997's F6 opened the
## wizards' window (`ShowStatsWindow(0, −1)`, adventure_input.c 373–396).
## Not while the world waits.
func toggle_wizards() -> void:
	if _world_waits():
		return
	hud.toggle_wizards()


## SPACE: the walk stopped — 1997's Space set the way to none and the hero
## stood (adventure_input.c 328–353) — and the camera back on the hero, as
## Space brought it back before [1997 + ours].
func stop_and_back() -> void:
	if walk != null and walk.is_walking():
		walk.stop()
		_show_hero()
	back_to_hero()


## THE KEYS WHILE THE MAP IS UP (ruling B: the map is a whole screen, as
## 1997's was): its own ([method WorldMap.key] — its maps, City Info, Done)
## and Ctrl+S act; no other key reaches the world under it.
func _map_key(key: InputEventKey) -> void:
	if _map.key(key.keycode):
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_S and key.ctrl_pressed:
		save_now()
		get_viewport().set_input_as_handled()
