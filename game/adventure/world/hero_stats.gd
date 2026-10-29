class_name HeroStats
extends VBoxContainer
## THE HERO'S STATS (the owner, 2026-10-23: *"a player stats panel (modern
## but reuse some elements from 1997)"*) — the 1997 stats screen (F5,
## `RunAdventureStatsMenu`, 00549002 in 1.3, on `Statbak.pic`) in one of
## the world's floating panes ([WorldHud]), its three tabs as the 1997
## screen's buttons ("Wiz Stats", "Journal", and the stats themselves):
##  - THE HERO: the face in a frame of their colour, the name and the
##    difficulty, what they carry (the frame's gold, food, ankh and book,
##    the five amulets), the World Magics owned — the five that are cast on
##    the top row, as 1997 set them, the rest under — and the record under
##    the 1997 captions (`@STATS`): "Wizard's Castles Conquered" (the five
##    castles, a beaten wizard's lit, "Attempts at Each Castle" under each),
##    "Cities Saved", "Cities Recovered", "Quest Record", "Overall
##    Won/Loss", "Dungeon Treasures" and "Record vs the Creatures of
##    Shandalar" (the creature page, below); ours beside them: the days on
##    the road, the lairs explored. A BEATEN wizard's castle answers a
##    click (1997's castle buttons, adventureStats.c 541–556, live only for
##    a beaten wizard; case 10–14, 1651–1662): the Wizards tab, that wizard
##    ringed, his own room shown ([method show_wizards]). An unbeaten one
##    stays inert, as 1997's.
##  - THE WIZARDS: 1997's wizards' window (F6, `Statwin.dll`) — the hall
##    with each wizard, his staff, his gems and the skulls of the hero's
##    wins ([WizardsPicture], when the skin holds Statwin's stills), and
##    under it each wizard's life in his stronghold, the mana domes he
##    controls and the wins against his colour, in the wise man's words
##    ([method WorldStatus.wizard_rows]) [ours: the window had no words];
##    `Statscrn.wav` (`sfx_wizards`) as it is opened by F6, W or a castle,
##    never as it is only drawn again. It is never opened by itself (the
##    owner, 2026-10-27: "Never pop" — 1997 popped it after a world win and
##    a town's fall).
##  - THE JOURNAL: what has happened, newest first, in the 1997 words
##    (`@LOGSTRINGS`); 1997 walked it on the map — "On the map" does, where
##    a map waits under the pane ([member journal_map]; the finale's record
##    after the win has none).
## THE END ON THE RECORD (part C) [ours: 1997's stats screen showed no
## score — its `@STATS` captions have none (Advstrings.txt 853–863), and it
## computed the score only after the fifth wizard fell]: under the 1997
## captions, "Arzakon Banished" — the years the battles so far would
## banish him for ([method AdventurePlayer.score_so_far], no lower than 0,
## as @CASTLEWIN 7 shows it: "368 years so far"), the final score once the
## adventure is won ("2368 years") — the owner's Q-RANK, *"the score so far
## shown on the hero's record page"*; and "Final Battles Lost", the battles
## lost at Arzakon's door under "Reload allowed" ([member
## AdventurePlayer.final_attempts]), once there is one.
## The counts are read from the journal as 1997 rebuilt them
## (`RebuildStatsJournalCounts`, [method record]).
##
## THE CREATURE PAGE (`RenderStatsCreatureGridPage`, adventureStats.c
## 731–824): each creature fought, in the creature table's order (Witch …
## Arzakon), its picture from `Creatures640.pic` ([method creature_cell],
## `creature_thumbs`), its wins / losses beside it in 1997's own inks
## ([method record_ink], [constant RECORD_INKS]) and its name under, three
## across and two rows in sight, a row a wheel step as 1997's bar stepped.
## [Ours: only the creatures met, where 1997 left a blank cell for each
## never fought — the switch on the page itself, "All creatures", shows
## the whole grid so, blank cells and all (the owner, 2026-10-27).] Without
## the pictures the page is a list of words, four rows in sight.
##
## KEYS while the pane is open ([method key]; 1997's stats screen, its
## hotkeys "Ww", "Jj", "Dd", adventureStats.c 136–138): W the wizards, J the
## journal, D done ([signal done_pressed], when the host listens). The pane
## hears them itself, before the world does ([method _unhandled_key_input]);
## the world looks with W and D no more while it is open (decision C-3,
## [method WorldScreen._look_with_keys]); with the pane hidden — closed, or
## under the map — they are the world's again.
##
## The floating panel asks for the page again whenever what it shows
## changes ([method WorldHud.refresh]) — food drops every few steps. The page
## is built anew only when what it is built from has changed ([method
## _shape]); otherwise the Hero page's numbers are written again where they
## stand and the journal takes only its new lines, on top. The journal's
## lines are made a hundred at a time, older ones as the reader scrolls down
## to them; a scroll outlives a rebuild ([method _scroll]): what is being
## read stays where it is. (Built whole at every food step, a journal of
## 2,000 lines took near half a second each time, and jumped to its top.)

const TABS: Array[String] = ["Hero", "Wizards", "Journal"]
const GOLD := Color8(232, 190, 110)
const INK := Color8(236, 222, 196)
const DIM := Color8(160, 146, 128)
## 1997's inks for a creature's record (aS:753–757, palette indices 0xBF,
## 0xBC, 0xB7, 0xF4, 0xF6 of `Advfac64.pic`): losing badly (dark teal),
## losing (red), even or few games (slate — the names wear it too),
## winning (blue), winning big (bright blue). Not reds and greens.
const RECORD_INKS := [Color8(15, 79, 71), Color8(191, 35, 15), Color8(91, 99, 151), Color8(0, 75, 187),
	Color8(0, 123, 255)]
## The pale chip a record is lettered on in its ink, so 1997's dark inks
## read on the pane's glass [ours: 1997 lettered them on its black cells];
## and the names' slate, lifted for the glass [ours].
const RECORD_CHIP := Color8(226, 218, 200)
const NAME_INK := Color8(160, 168, 220)
## The end on the record (the class's notes) [ours]: its two captions and
## the years' words.
const BANISHED := "Arzakon Banished"
const FINAL_LOST := "Final Battles Lost"
const YEARS_SO_FAR := "%d years so far"
const YEARS := "%d years"
const PORTRAIT := Vector2(96, 118)
const ICON := 26.0
## The creature record's rows shown before it scrolls: words, and pictures
## (1997's two rows).
const CREATURE_ROWS := 4
const PICTURE_ROWS := 2
## A creature's picture on `Creatures640.pic`: 8 cells a row of 80 × 64, of
## which 1997 copied 78 × 59 — past the cell's 1-pixel line and a 3-pixel
## band at its top (aS:801–807).
const CREATURE_SHEET_COLUMNS := 8
const CREATURE_CELL := Vector2(80, 64)
const CREATURE_PICTURE := Vector2(78, 59)
## The creatures of the grid: table rows 1 (the Witch) … 55 (Arzakon).
const CREATURE_LAST := 55
## The journal's lines made at a time, and how near the end of those made,
## in pixels, the reader comes before the next older ones are made.
const JOURNAL_STEP := 100
const JOURNAL_NEAR := 400.0

## The journal is to be walked on the map ([method WorldMap.walk_journal]).
signal journal_map_pressed
## D or Space: the pane is to be closed ([method key]).
signal done_pressed

var player: AdventurePlayer
var art := WorldArt.new()
## The wizard ringed on the Wizards tab, by colour word; "" for none.
var highlighted := ""
## The beaten wizard whose room the Wizards tab shows; "" for the hall.
var room_shown := ""
## Whether the creature page shows the whole grid, the creatures never
## fought as blank cells (the page's own switch).
var show_all_creatures := false
## How often the wizards' sound was asked for ([method show_wizards]).
var sounded := 0
## Whether the journal offers "On the map" ([signal journal_map_pressed]):
## the world's pane, yes; a pane with no map under it (the finale's record
## after the win), no. Set before the pane is shown.
var journal_map := true
var _sound: AudioStreamPlayer
## Each sprite's painted part, found once: `"key#frame"` → its region.
static var _trims := {}
var tab := "Hero"
## The Hero page's size, which every tab keeps.
var page_size := Vector2.ZERO
var _tabs := {}
var _page: VBoxContainer
## The page's scrolls set aside during a rebuild, by name, for the new page
## to take again ([method _scroll]).
var _kept_scrolls := {}
## What the page shown was built from ([method _shape]).
var _built := ""
## The Hero page's numbers by what they count (`gold`, `food`, `ankh`,
## `book`, each amulet's colour, `road`), written again in place ([method
## _fill_numbers]).
var _numbers := {}
## The journal's lines on the page, newest first; how many entries, counted
## from the newest, they have gone through; the newest entry among them
## (the journal's own Dictionary); the width they wrap at.
var _journal: VBoxContainer
var _journal_depth := 0
var _journal_newest := {}
var _journal_width := 0.0


func _ready() -> void:
	name = "HeroStats"
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := HBoxContainer.new()
	bar.name = "Tabs"
	bar.add_theme_constant_override("separation", 4)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for key in TABS:
		var button := Button.new()
		button.name = "Tab_" + key
		button.text = key
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		_dress(button)
		# The Wizards tab is 1997's "Wiz Stats" button: the window opened.
		button.pressed.connect(show_wizards if key == "Wizards" else show_tab.bind(key))
		bar.add_child(button)
		_tabs[key] = button
	add_child(bar)
	_page = VBoxContainer.new()
	_page.name = "Page"
	_page.add_theme_constant_override("separation", 8)
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_page)
	_sound = AudioStreamPlayer.new()
	_sound.name = "WizardsSound"
	GameAudio.ensure_buses()
	_sound.bus = GameAudio.SFX_BUS
	add_child(_sound)
	refresh()


func _notification(what: int) -> void:
	# The pane closed: the hall's sound with it, as 1997's window stopped it.
	if what == NOTIFICATION_VISIBILITY_CHANGED and _sound != null and not is_visible_in_tree():
		_sound.stop()


## Show [param key]'s tab ("Hero", "Wizards" or "Journal"). Turning to the
## Wizards tab from another rings nobody (F6's window, `ShowStatsWindow(0,
## −1)`); the Wizards tab shown again keeps its wizard.
func show_tab(key: String) -> void:
	_turn_to(key, "")


## THE WIZARDS' WINDOW OPENED (F6, W, the Wizards tab, a beaten castle's
## click): the Wizards tab, [param color]'s wizard ringed ("" for none, as
## F6), the room of a beaten one shown when the skin has it, and
## `Statscrn.wav` — once, here, never as the page is only drawn again
## (1997's `show_status_window` played it as the window opened, SW 1858),
## stopped as the pane closes or turns to another tab.
func show_wizards(color := "") -> void:
	var opening := tab != "Wizards" or color != "" or not is_visible_in_tree()
	_turn_to("Wizards", color)
	if opening:
		_fanfare()


func _turn_to(key: String, color: String) -> void:
	if key != "Wizards" and _sound != null:
		_sound.stop()
	# Turned to, a wizard asked for, or the pane opened again (F6 rings
	# nobody, whatever it showed when it closed).
	if key == "Wizards" and (tab != "Wizards" or color != "" or not is_visible_in_tree()):
		highlighted = color
		room_shown = color if player != null and color in player.defeated_wizards else ""
	tab = key
	refresh()


## Ring [param color]'s wizard on the Wizards tab ("" for none) [ours].
func highlight(color: String) -> void:
	highlighted = color
	refresh()


## A KEY while the pane is open: W the wizards, J the journal, D done
## ([signal done_pressed]); true when it was the pane's. D is the world's
## while nothing listens for the pane's done; Space is always the world's
## (it stops the walk, the pane left open).
func key(keycode: int) -> bool:
	match keycode:
		KEY_W:
			if tab != "Wizards":
				show_wizards()
		KEY_J:
			show_tab("Journal")
		KEY_D:
			if done_pressed.get_connections().is_empty():
				return false
			done_pressed.emit()
		_:
			return false
	return true


## The pane's letters, heard before the world's keys ([method key]): only
## while the pane shows, and never with Ctrl, Alt or Meta held (Ctrl+S
## saves).
func _unhandled_key_input(event: InputEvent) -> void:
	var press := event as InputEventKey
	if press == null or not press.pressed or press.echo or not is_visible_in_tree():
		return
	if press.ctrl_pressed or press.alt_pressed or press.meta_pressed:
		return
	if key(press.keycode):
		get_viewport().set_input_as_handled()


## `Statscrn.wav`, the wizards' window's sound, from the start.
func _fanfare() -> void:
	sounded += 1
	if _sound == null or DisplayServer.get_name() == "headless":
		return
	var stream := GameSkin.sound("sfx_wizards")
	if stream == null:
		return
	_sound.stream = stream
	_sound.play()


## The page shown, as the hero now stands: built anew when what it is
## built from has changed ([method _shape]); else the Hero page's numbers
## written again in place, the journal's new lines put on top.
func refresh() -> void:
	if _page == null:
		return
	for key in _tabs:
		(_tabs[key] as Button).set_pressed_no_signal(key == tab)
	if player == null:
		_clear_page()
		_drop_kept_scrolls()
		_built = ""
		return
	if _shape() != _built:
		_rebuild()
	elif tab == "Hero":
		_fill_numbers()
	elif tab == "Journal" and not _journal_news():
		_rebuild()


## WHAT THE PAGE SHOWN IS BUILT FROM, beyond the numbers written in place
## and the journal's new lines: the tab and the hero; on the Hero page the
## journal (the record), the World Magics, the castles, the face and the
## name; on the Wizards' page the taps toward Dominion.
func _shape() -> String:
	var parts: Array = [tab, player.get_instance_id()]
	match tab:
		"Hero":
			parts.append_array([player.journal.size(), player.journal.back() if not player.journal.is_empty() else {},
				player.world_magics, player.defeated_wizards, player.portrait, player.name, player.color,
				player.difficulty, _castle_tries(), show_all_creatures, banished_words(player),
				player.final_attempts])
		"Wizards":
			parts.append_array([WorldStatus.wizard_rows(player), WorldStatus.dominion(player),
				player.owns("Ring of the Guardian"), highlighted, room_shown])
	return str(parts)


## The page built anew.
func _rebuild() -> void:
	_clear_page()
	# EVERY TAB THE HERO TAB'S SIZE (the owner, 2026-10-23: *"Hero, wizards,
	# journal should have the same size as hero pane so it does not switch
	# size under the eyes"*): the Hero page is laid out first and measured,
	# and the page keeps that size whichever tab is shown.
	_page.custom_minimum_size = Vector2.ZERO
	_hero_page()
	page_size = _page.get_combined_minimum_size()
	_page.custom_minimum_size = page_size
	match tab:
		"Wizards":
			_clear_page()
			_wizards_page()
		"Journal":
			_clear_page()
			_journal_page()
	_drop_kept_scrolls()
	_read_back.clear()
	_built = _shape()


## The page emptied: its parts taken away safely ([method PaneStyle.drop] —
## the On the map button may be the one being pressed), its scrolls set
## aside for the page built next ([method _scroll]).
func _clear_page() -> void:
	for child in _page.get_children():
		if child is ScrollContainer:
			_page.remove_child(child)
			_kept_scrolls[String(child.name)] = child
		else:
			PaneStyle.drop(child)


## A SCROLL NAMED [param scroll_name] for the page being built: the one the
## last page had by that name, emptied — so it is still scrolled where the
## reader left it — or a new one. Not yet on the page.
func _scroll(scroll_name: String) -> ScrollContainer:
	var scroll := _kept_scrolls.get(scroll_name) as ScrollContainer
	if scroll != null:
		_kept_scrolls.erase(scroll_name)
		PaneStyle.drop_children(scroll)
		return scroll
	scroll = ScrollContainer.new()
	scroll.name = scroll_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	return scroll


## The scrolls set aside that the new page did not take: gone, so a tab
## opened again starts at its top.
func _drop_kept_scrolls() -> void:
	for scroll_name in _kept_scrolls:
		PaneStyle.drop(_kept_scrolls[scroll_name])
	_kept_scrolls.clear()


# ------------------------------------------------------------- the record --

## THE RECORD as 1997 counted it from the journal: `{saved, recovered,
## quests_done, quests_failed, won, lost, treasures, creatures: {name:
## [won, lost]}, rows: {row: [won, lost]}}` — the creatures tallied by
## name, and by their table row as 1997 tallied them (`arg & 0x7F`,
## aS:665–728): a line's own `row`, else the row its name is (an older
## save's lines carry no row); a name the table does not know has none.
static func record(hero: AdventurePlayer) -> Dictionary:
	var out := {"saved": 0, "recovered": 0, "quests_done": 0, "quests_failed": 0,
		"treasures": 0, "creatures": {}, "rows": {}}
	var duels := hero.duel_record()
	out["won"] = duels["won"]
	out["lost"] = duels["lost"]
	for entry in hero.journal:
		var line := entry as Dictionary
		match String(line.get("event", "")):
			"saved":
				out["saved"] += 1
			"freed":
				out["recovered"] += 1
			"quest":
				if bool(line.get("done", false)):
					out["quests_done"] += 1
				else:
					out["quests_failed"] += 1
			"treasure":
				out["treasures"] += 1
			"duel":
				var creature := String(line.get("creature", ""))
				var side := 0 if bool(line.get("won", false)) else 1
				if creature != "":
					var tally: Array = (out["creatures"] as Dictionary).get(creature, [0, 0])
					tally[side] += 1
					out["creatures"][creature] = tally
				var row := int(line["row"]) if line.has("row") else CreatureBook.row_named(creature)
				if row == CREATURE_LAST + 1:
					# Arzakon's second row (the Spectral Arena's copy): his
					# one cell, as 1997 logged him (`0xB7`, row 55).
					row = CREATURE_LAST
				if row >= 1 and row <= CREATURE_LAST:
					var by_row: Array = (out["rows"] as Dictionary).get(row, [0, 0])
					by_row[side] += 1
					out["rows"][row] = by_row
	return out


## THE INK OF A CREATURE'S RECORD, exactly as 1997 chose it (aS:785–812),
## on an INTEGER share `won·100 / games` rounded down: losing (fewer wins
## than losses) — badly when more than five behind at 25% or less, even
## with under five games or above 40%, else losing; winning or level —
## big when more than five ahead at 75% or more, even with under five games
## or at 60% or less, else winning. So exactly 40% (five games or more) is
## losing, and 60% to under 61% even.
static func record_ink(won: int, lost: int) -> Color:
	var games := won + lost
	var pct := won * 100 / maxi(games, 1)
	if won < lost:
		if lost - won > 5 and pct <= 25:
			return RECORD_INKS[0]
		return RECORD_INKS[2] if games < 5 or pct > 40 else RECORD_INKS[1]
	if won - lost > 5 and pct >= 75:
		return RECORD_INKS[4]
	return RECORD_INKS[2] if games < 5 or pct <= 60 else RECORD_INKS[3]


## Creature [param row]'s picture on `Creatures640.pic` (`creature_thumbs`):
## the cell `row − 1`, eight to a line, 78 × 59 from its corner past the
## line and the band (aS:801–807). Row 1, the Witch: (1, 4); row 55,
## Arzakon: (481, 388).
static func creature_cell(row: int) -> Rect2:
	var cell := row - 1
	return Rect2(CREATURE_CELL.x * (cell % CREATURE_SHEET_COLUMNS) + 1,
		CREATURE_CELL.y * (cell / CREATURE_SHEET_COLUMNS) + 4, CREATURE_PICTURE.x, CREATURE_PICTURE.y)


# --------------------------------------------------------------- the hero --

func _hero_page() -> void:
	_numbers.clear()
	var inks: Array = WorldHud.NAME_INKS.get(player.color, [INK, Color.BLACK])
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face := PanelContainer.new()
	face.name = "Portrait"
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0, 0, 0, 0.6)
	frame.border_color = inks[0]
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(6)
	frame.set_content_margin_all(3)
	face.add_theme_stylebox_override("panel", frame)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var picture := TextureRect.new()
	picture.texture = PortraitLibrary.texture(player.portrait) if player.portrait != "" else null
	picture.custom_minimum_size = PORTRAIT
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(picture)
	head.add_child(face)
	var who := VBoxContainer.new()
	who.add_theme_constant_override("separation", 2)
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var called := _label(player.name, 22, inks[0])
	called.name = "HeroName"
	called.add_theme_color_override("font_outline_color", inks[1])
	called.add_theme_constant_override("outline_size", 4)
	who.add_child(called)
	var color := AdventureSetup.color_row(player.color)
	who.add_child(_label("A %s mage · %s: %s" % [String(color.get("name", player.color)).to_lower(),
		player.difficulty_name(), AdventureSetup.difficulty_phrase(player.difficulty)], 14))
	who.add_child(_carried())
	who.add_child(_amulets())
	who.add_child(_number("road", 13, DIM))
	_fill_numbers()
	head.add_child(who)
	_page.add_child(head)
	_page.add_child(_caption("World Magics"))
	_page.add_child(_magics())
	_page.add_child(_caption("Wizard's Castles Conquered"))
	_page.add_child(_castles())
	var kept := record(player)
	var grid := GridContainer.new()
	grid.name = "Record"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 2)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pairs: Array = [["Cities Saved", str(kept["saved"])], ["Cities Recovered", str(kept["recovered"])],
			["Quest Record", "%d/%d" % [kept["quests_done"], kept["quests_failed"]]],
			["Overall Won/Loss", "%d/%d" % [kept["won"], kept["lost"]]],
			["Dungeon Treasures", str(kept["treasures"])], [BANISHED, banished_words(player)]]
	if player.final_attempts > 0:
		pairs.append([FINAL_LOST, str(player.final_attempts)])
	for pair in pairs:
		grid.add_child(_label(pair[0], 14, GOLD))
		var value := _label(pair[1], 14)
		value.name = "Value_" + String(pair[0]).replace(" ", "_").replace("/", "_").replace("'", "")
		grid.add_child(value)
	_page.add_child(grid)
	_creature_page(kept)


## "368 years so far" — the years the battles so far would banish Arzakon
## for, no lower than 0 ([method AdventurePlayer.score_so_far], [method
## FinalBattle.shown]) — or, the adventure won, its final score: "2368
## years" (the class's notes).
static func banished_words(hero: AdventurePlayer) -> String:
	if hero.ended == AdventurePlayer.ENDED_WON:
		return YEARS % int(hero.final.get("score", 0))
	return YEARS_SO_FAR % FinalBattle.shown(hero.score_so_far())


# ------------------------------------------------------- the creature page --

## THE CREATURE PAGE under its caption and its switch (see the class doc).
func _creature_page(kept: Dictionary) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_caption("Record vs the Creatures of Shandalar"))
	var all := Button.new()
	all.name = "AllCreatures"
	all.text = "All creatures"
	all.toggle_mode = true
	all.focus_mode = Control.FOCUS_NONE
	all.tooltip_text = "Every creature of Shandalar, a blank cell for each never fought, as 1997 showed them"
	_dress(all)
	all.add_theme_font_size_override("font_size", 13)
	all.set_pressed_no_signal(show_all_creatures)
	all.toggled.connect(func(on: bool) -> void:
		show_all_creatures = on
		refresh())
	head.add_child(all)
	_page.add_child(head)
	var cells := creature_cells(kept)
	if cells.is_empty():
		_page.add_child(_label("No creature fought yet.", 14, DIM))
		return
	var pictures := art.texture("creature_thumbs") != null
	var list := GridContainer.new()
	list.name = "Creatures"
	list.columns = 3
	list.add_theme_constant_override("h_separation", 16)
	list.add_theme_constant_override("v_separation", 4)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for cell in cells:
		list.add_child(_creature(cell, pictures))
	# Many creatures: two rows of pictures show (four of words), the rest
	# scroll a row a wheel step, so the pane stays on the screen.
	var rows := PICTURE_ROWS if pictures and int(cells[0]["row"]) >= 1 else CREATURE_ROWS
	if ceili(cells.size() / 3.0) > rows:
		var scroll := _scroll("CreatureScroll")
		scroll.add_child(list)
		_page.add_child(scroll)
		# Measured once on the page, where the rows have their letters.
		scroll.custom_minimum_size = Vector2(0, _rows_height(list, rows))
		scroll.scroll_vertical_custom_step = (list.get_child(0) as Control).get_combined_minimum_size().y \
			+ list.get_theme_constant("v_separation")
	else:
		_page.add_child(list)


## THE CELLS of the creature page, in order: `{row, name, won, lost,
## fought}` — the creatures fought in the table's order (row 0 for a name
## the table does not know, after them, as fought); with the switch on,
## every creature of the table, those never fought blank (`fought` false).
func creature_cells(kept: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var by_row: Dictionary = kept.get("rows", {})
	for row in range(1, CREATURE_LAST + 1):
		if by_row.has(row):
			var tally: Array = by_row[row]
			out.append({"row": row, "name": CreatureBook.name_of(row), "won": int(tally[0]),
				"lost": int(tally[1]), "fought": true})
		elif show_all_creatures:
			out.append({"row": row, "name": CreatureBook.name_of(row), "won": 0, "lost": 0, "fought": false})
	var by_name: Dictionary = kept.get("creatures", {})
	for creature in by_name:
		var known := CreatureBook.row_named(String(creature))
		if known < 1 or known > CREATURE_LAST:
			var tally: Array = by_name[creature]
			out.append({"row": 0, "name": String(creature), "won": int(tally[0]), "lost": int(tally[1]),
				"fought": true})
	return out


## One creature's cell: its picture with its wins / losses to its right and
## its name under (1997's: the record at the picture's right, aS:771, the
## name over its foot, aS:772) — or, without the picture, "W/L Name" in
## the record's ink; a blank cell for one never fought.
func _creature(cell: Dictionary, pictures: bool) -> Control:
	var row := int(cell["row"])
	var won := int(cell["won"])
	var lost := int(cell["lost"])
	if not pictures or row < 1:
		var said := _label("%d/%d %s" % [won, lost, cell["name"]] if cell["fought"] else "", 14,
			record_ink(won, lost))
		said.name = "Creature_%d" % row if row >= 1 else "Creature_" + String(cell["name"]).replace(" ", "_")
		if cell["fought"]:
			_chip(said)
		return said
	var box := VBoxContainer.new()
	box.name = "Creature_%d" % row
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := PanelContainer.new()
	var well := StyleBoxFlat.new()
	well.bg_color = Color(0.0, 0.06, 0.0, 0.85)
	well.set_corner_radius_all(3)
	frame.add_theme_stylebox_override("panel", well)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var picture := TextureRect.new()
	picture.name = "Picture"
	picture.custom_minimum_size = CREATURE_PICTURE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if cell["fought"]:
		var cut := AtlasTexture.new()
		cut.atlas = art.texture("creature_thumbs")
		cut.region = creature_cell(row)
		picture.texture = cut
	frame.add_child(picture)
	top.add_child(frame)
	var score := _label("%d/%d" % [won, lost] if cell["fought"] else "", 14, record_ink(won, lost))
	score.name = "Score"
	score.custom_minimum_size = Vector2(40, 0)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if cell["fought"]:
		_chip(score)
	top.add_child(score)
	box.add_child(top)
	var called := _label(String(cell["name"]) if cell["fought"] else "", 12, NAME_INK)
	called.name = "Name"
	called.custom_minimum_size = Vector2(CREATURE_PICTURE.x, 0)
	called.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	called.clip_text = true
	box.add_child(called)
	return box


## A record lettered in its ink on a pale chip ([constant RECORD_CHIP]).
func _chip(label: Label) -> void:
	var face := StyleBoxFlat.new()
	face.bg_color = RECORD_CHIP
	face.set_corner_radius_all(4)
	face.content_margin_left = 4
	face.content_margin_right = 4
	label.add_theme_stylebox_override("normal", face)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))


## The height of the first [param rows] rows of [param grid], the gaps
## between them counted: a row as tall as its first cell asks.
func _rows_height(grid: GridContainer, rows: int) -> float:
	var row := (grid.get_child(0) as Control).get_combined_minimum_size().y
	return rows * row + (rows - 1) * grid.get_theme_constant("v_separation")


## Gold, food, mana links and the deck, on the frame's own painted tiles.
func _carried() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Carried"
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for key in WorldHud.STRIP:
		var frame := GameSkin.texture("world_frame")
		if frame != null:
			var cut := AtlasTexture.new()
			cut.atlas = frame
			cut.region = Rect2(WorldHud.FRAME_ICONS[key])
			row.add_child(_icon(cut, Vector2(WorldHud.FRAME_ICONS[key].size) * (ICON / WorldHud.FRAME_ICONS[key].size.y)))
		else:
			row.add_child(_label(WorldHud.STRIP_NAMES[key], 13, GOLD))
		row.add_child(_number(key, 16))
	return row


func _amulets() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Amulets"
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for gem in WorldHud.AMULETS:
		if art.texture("world_amulets") != null:
			var cut := AtlasTexture.new()
			cut.atlas = art.texture("world_amulets")
			cut.region = art.frame_rect("world_amulets", int(gem[1]))
			var icon := _icon(cut, Vector2(12, 17) * 1.3)
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			row.add_child(icon)
		else:
			row.add_child(_label(String(gem[0]).capitalize(), 13, GOLD))
		row.add_child(_number(String(gem[0]), 16))
	return row


# ------------------------------------------------------------ the numbers --

## The Hero page's numbers as the hero now stands, by what they count.
func _number_values() -> Dictionary:
	var deck := 0
	for card in player.cards:
		if ((card as Dictionary).get("decks", []) as Array).has(player.current_deck):
			deck += 1
	var values := {"gold": str(player.gold), "food": str(player.food),
		"ankh": str(player.mana_links()), "book": "%d/%d" % [deck, player.cards.size()],
		"road": "Days on the road %d · lairs explored %d · World seed %s" % [
			WorldStatus.days_on_road(player), player.lairs_explored, player.world_seed_text]}
	for gem in WorldHud.AMULETS:
		values[String(gem[0])] = str(int(player.amulets.get(gem[0], 0)))
	return values


## A number of the Hero page, [param key] of [method _number_values]: a
## label kept to be written in place ([method _fill_numbers]).
func _number(key: String, size: int, color := INK) -> Label:
	var number := _label("", size, color)
	number.name = "Number_" + key
	_numbers[key] = number
	return number


## THE NUMBERS WRITTEN AGAIN where they stand: the purse, the food, the
## links, the deck, the amulets, the road — nothing else on the page is
## touched.
func _fill_numbers() -> void:
	var values := _number_values()
	for key in _numbers:
		var number := _numbers[key] as Label
		if is_instance_valid(number) and number.text != String(values[key]):
			number.text = String(values[key])


## How often each wizard's castle was entered, black to white (1997's
## "Attempts at Each Castle", [method DungeonDoors.entered]).
func _castle_tries() -> Array[int]:
	var tries: Array[int] = []
	for i in 5:
		tries.append(DungeonDoors.entered(player.world, i))
	return tries


## The twelve World Magics: the five cast with an amulet on the top row,
## the seven that simply hold under it, as the 1997 screen set them; the
## ones not owned dark.
func _magics() -> VBoxContainer:
	var rows := VBoxContainer.new()
	rows.name = "Magics"
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for active in [true, false]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in AdventurePlayer.WORLD_MAGICS.size():
			if (i >= 2 and i % 2 == 0) != active:
				continue
			var magic: String = AdventurePlayer.WORLD_MAGICS[i]
			var owned := player.owns(magic)
			var cell := HBoxContainer.new()
			cell.add_theme_constant_override("separation", 3)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if art.texture("world_magics") != null:
				var cut := AtlasTexture.new()
				cut.atlas = art.texture("world_magics")
				cut.region = art.frame_rect("world_magics", i)
				var icon := _icon(cut, Vector2(ICON, ICON))
				icon.modulate = Color.WHITE if owned else Color(0.45, 0.42, 0.4, 0.6)
				cell.add_child(icon)
			if owned:
				cell.add_child(_label(magic, 13, INK))
			cell.name = "Magic_%d" % i
			row.add_child(cell)
		rows.add_child(row)
	return rows


## The five wizards' castles, black to white: a beaten wizard's castle
## lit, the others dark, and the attempts at each under it.
func _castles() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Castles"
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 5:
		var color: String = AdventurePlayer.COLORS[i]
		var beaten := color in player.defeated_wizards
		var cell := VBoxContainer.new()
		cell.name = "Castle_" + color
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if beaten:
			# 1997's castle button, live for a beaten wizard: his room.
			cell.mouse_filter = Control.MOUSE_FILTER_STOP
			cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			cell.tooltip_text = "%s, beaten: %s room" % [WorldNames.WIZARDS[i],
				"her" if CreatureMeeting.wizard_feminine(i + 1) else "his"]
			cell.gui_input.connect(_castle_clicked.bind(color))
		var ref := WorldView._castle_ref(int(WorldView.CASTLE_FRAMES[i][2 if beaten else 0]))
		if art.texture(ref[0]) != null:
			var icon := _icon(_painted(String(ref[0]), int(ref[1])), Vector2(64, 50))
			icon.modulate = Color.WHITE if beaten else Color(0.55, 0.5, 0.48, 0.85)
			cell.add_child(icon)
		else:
			cell.add_child(_label(WorldNames.CASTLES[i], 12, GOLD if beaten else DIM))
		var count := _label(str(_castle_tries()[i]), 13, INK)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(count)
		row.add_child(cell)
	var note := _label("Attempts at Each Castle under each", 12, DIM)
	note.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(note)
	return row


## A beaten wizard's castle clicked: the Wizards tab on him.
func _castle_clicked(event: InputEvent, color: String) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		show_wizards(color)


# ------------------------------------------------------------ the wizards --

## THE WIZARDS' PAGE: the rule of Dominion, the hall ([WizardsPicture]) in
## the room the Hero page leaves it, and the record under it — a wizard a
## row: his name in his colours, his life in his stronghold, the mana domes
## he controls (of the Dominion count) and the wins against his colour; a
## beaten one "Beaten". The ringed wizard's row lit.
func _wizards_page() -> void:
	var rows := WorldStatus.wizard_rows(player)
	var rule := _label("A wizard who taps %d cities casts the Spell of Dominion%s." % [
		WorldStatus.dominion(player), " (Ring of the Guardian)" if player.owns("Ring of the Guardian") else ""], 14)
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page.add_child(rule)
	if WizardsPicture.available():
		var hall := WizardsPicture.new()
		hall.rows = rows
		hall.highlight = highlighted
		hall.room = room_shown if room_shown != "" and WizardsPicture.has_room(room_shown) else ""
		# The room the Hero page leaves, the picture fitted in it.
		hall.size_flags_vertical = Control.SIZE_EXPAND_FILL
		hall.custom_minimum_size = Vector2(0, 120)
		hall.room_closed.connect(func() -> void:
			room_shown = ""
			refresh())
		_page.add_child(hall)
	var grid := GridContainer.new()
	grid.name = "Wizards"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 2)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for heading in ["", "Life in stronghold", "Mana domes", "Won against"]:
		grid.add_child(_label(heading, 13, GOLD))
	for row in rows:
		var color := String(row["color"])
		var lit := color == highlighted
		var inks: Array = WorldHud.NAME_INKS[color]
		var wizard := _label(String(row["name"]), 16, inks[0])
		wizard.name = "Wizard_" + color
		wizard.add_theme_color_override("font_outline_color", inks[1])
		wizard.add_theme_constant_override("outline_size", 3)
		wizard.mouse_filter = Control.MOUSE_FILTER_PASS
		wizard.tooltip_text = wizard_words(row)
		var beaten := bool(row["beaten"])
		var cells := [wizard,
			_label("Beaten" if beaten else str(row["life"]), 14, DIM if beaten else INK),
			_label("—" if beaten else "%d of %d" % [row["taps"], WorldStatus.dominion(player)], 14,
				DIM if beaten else INK),
			_label(str(row["wins"]), 14)]
		var names := ["Wizard_", "Life_", "Domes_", "Won_"]
		for i in cells.size():
			var cell := cells[i] as Label
			cell.name = names[i] + color
			if lit:
				# One band along the row: each cell's glow reaches half the
				# gap to the next.
				var glow := StyleBoxFlat.new()
				glow.bg_color = Color(GOLD, 0.2)
				glow.set_content_margin_all(1)
				glow.expand_margin_left = 7
				glow.expand_margin_right = 7
				cell.add_theme_stylebox_override("normal", glow)
			grid.add_child(cell)
	_page.add_child(grid)


## What the wise man would say of wizard [param row] ([method
## WorldStatus.wizard_rows]) — `_qQuote` 0 and 1 (`Advblocks.txt`): "He has
## 37 life in his stronghold and controls 2 mana domes."; a beaten one's
## [ours].
static func wizard_words(row: Dictionary) -> String:
	var she := bool(row.get("feminine", false))
	if bool(row.get("beaten", false)):
		return "%s was defeated in %s Castle." % [row["name"], "her" if she else "his"]
	return "%s has %d life in %s stronghold and controls %d mana domes." % [
		"She" if she else "He", row["life"], "her" if she else "his", row["taps"]]


# ------------------------------------------------------------ the journal --

## The journal, newest first, in the 1997 words.
func journal_lines() -> Array[String]:
	var lines: Array[String] = []
	for i in range(player.journal.size() - 1, -1, -1):
		var line := journal_line(player.journal[i])
		if line != "":
			lines.append(line)
	return lines


## A journal entry as its line reads ("Day 3: …"); "" for one with no words.
static func journal_line(entry: Dictionary) -> String:
	var text := String(entry.get("text", ""))
	if text == "":
		return ""
	var day := int(entry.get("day", -1))
	return ("Day %d: " % day if day >= 0 else "") + text.replace("\n", " ")


## Whether the journal holds a line to show.
func _journal_written() -> bool:
	for i in range(player.journal.size() - 1, -1, -1):
		if String((player.journal[i] as Dictionary).get("text", "")) != "":
			return true
	return false


func _journal_page() -> void:
	_journal = null
	_journal_depth = 0
	_journal_newest = {}
	if not _journal_written():
		_page.add_child(_label("Nothing written yet: what you do in Shandalar is kept here.", 14, DIM))
		return
	# [Ours] 1997's journal was walked on the map, line by line: so it is —
	# where a map waits under the pane ([member journal_map]).
	var taken := 0.0
	if journal_map:
		var walk := Button.new()
		walk.name = "JournalOnMap"
		walk.text = "On the map"
		walk.focus_mode = Control.FOCUS_NONE
		_dress(walk)
		walk.pressed.connect(func() -> void: journal_map_pressed.emit())
		_page.add_child(walk)
		taken = walk.get_combined_minimum_size().y + float(_page.get_theme_constant("separation"))
	var scroll := _scroll("Journal")
	# The button above takes its height from the scroll: the pane keeps its
	# size from tab to tab.
	scroll.custom_minimum_size = Vector2(0, maxf(page_size.y - taken, 120.0))
	# A long journal scrolls: the wheel, a finger, or this bar in gold.
	var bar := scroll.get_v_scroll_bar()
	bar.name = "JournalBar"
	bar.custom_minimum_size.x = 12
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0.4)
	track.set_corner_radius_all(6)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(GOLD, 0.55)
	grab.set_corner_radius_all(6)
	var lit := grab.duplicate() as StyleBoxFlat
	lit.bg_color = Color(GOLD, 0.9)
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	bar.add_theme_stylebox_override("grabber", grab)
	bar.add_theme_stylebox_override("grabber_highlight", lit)
	bar.add_theme_stylebox_override("grabber_pressed", lit)
	if not bar.value_changed.is_connected(_journal_scrolled):
		bar.value_changed.connect(_journal_scrolled)
	_journal = VBoxContainer.new()
	_journal.name = "JournalLines"
	_journal.add_theme_constant_override("separation", 1)
	_journal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_journal)
	_page.add_child(scroll)
	_journal_width = maxf(page_size.x - bar.custom_minimum_size.x - 4.0, 200.0)
	_journal_newest = player.journal.back()
	_journal_more()


## A line of the journal, wrapped at the page's width — given its width at
## once, it is wrapped once, not first at every word.
func _journal_label(text: String) -> Label:
	var said := _label(text, 14)
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	said.custom_minimum_size = Vector2(_journal_width, 0)
	return said


## The next [constant JOURNAL_STEP] older lines, under those made.
func _journal_more() -> void:
	# New lines first, so the count from the newest still holds.
	if not _journal_news():
		return
	var journal := player.journal
	var made := 0
	while made < JOURNAL_STEP and _journal_depth < journal.size():
		_journal_depth += 1
		var line := journal_line(journal[journal.size() - _journal_depth])
		if line != "":
			_journal.add_child(_journal_label(line))
			made += 1


## THE LINES WRITTEN SINCE, on top, newest first; the reader's place is
## left as it is. False when the page is to be made anew: the newest line
## made is no longer in the journal (another journal), or a first line has
## been written.
func _journal_news() -> bool:
	if _journal == null or not is_instance_valid(_journal):
		# Nothing written when the page was made: still nothing, or a first
		# line to make the page for.
		return not _journal_written()
	var journal := player.journal
	var since := journal.size() - 1
	while since >= 0 and not is_same(journal[since], _journal_newest):
		since -= 1
	if since < 0:
		return false
	for i in range(since + 1, journal.size()):
		var line := journal_line(journal[i])
		if line != "":
			var said := _journal_label(line)
			_journal.add_child(said)
			_journal.move_child(said, 0)
	_journal_depth += journal.size() - 1 - since
	_journal_newest = journal.back()
	return true


## The reader near the end of the lines made: the next older ones.
func _journal_scrolled(value: float) -> void:
	if _journal == null or not is_instance_valid(_journal) or _journal.get_parent() == null:
		return
	var bar := (_journal.get_parent() as ScrollContainer).get_v_scroll_bar()
	if value + bar.page >= bar.max_value - JOURNAL_NEAR:
		_journal_more()


# --------------------------------------------------------------- the parts --

func _caption(text: String) -> Label:
	var caption := _label(text, 15, GOLD)
	caption.name = "Caption_" + text.replace(" ", "_").replace("'", "")
	return caption


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


## Frame [param frame] of sheet [param key], cut to its painted part.
func _painted(key: String, frame: int) -> AtlasTexture:
	var sheet := art.texture(key)
	var region := art.frame_rect(key, frame)
	var memo := trim_key(key, frame)
	if not _trims.has(memo):
		_trims[memo] = region
		# The sheet's pixels read back once for all its frames this build
		# (the smoothness pass, 0.50.66: five castles read the whole sheet
		# back five times, ~6 ms each), unless [PaneWarmer] trimmed it first.
		var id := sheet.get_instance_id()
		if not _read_back.has(id):
			_read_back[id] = sheet.get_image()
		var image: Image = _read_back[id]
		if image != null:
			_trims[memo] = trimmed(image, region, GameSkin.scale_of(sheet))
	var cut := AtlasTexture.new()
	cut.atlas = sheet
	cut.region = _trims[memo]
	return cut


## The sheets read back for [method _painted] while a page is built, by
## instance; let go as the build ends ([method _rebuild]).
static var _read_back := {}


## The memo of frame [param frame] of sheet [param key]'s painted part.
static func trim_key(key: String, frame: int) -> String:
	return "%s#%d" % [key, frame]


## FRAME [param region] (drawn pixels) OF A SHEET'S PIXELS [param image]
## ([param scale] image pixels to a drawn one) cut to its painted part — the
## whole region when nothing is painted. Touches nothing shared: a worker
## thread may trim a sheet it decoded ([PaneWarmer]).
static func trimmed(image: Image, region: Rect2, scale: int) -> Rect2:
	if image.is_compressed():
		image.decompress()
	# A 2x skin's sheet holds twice the pixels of the 1997 frame.
	var rect := Rect2i(Rect2i(region).position * scale, Rect2i(region).size * scale)
	var used := image.get_region(rect).get_used_rect()
	if used.size.x > 0:
		return Rect2(region.position + Vector2(used.position) / scale, Vector2(used.size) / scale)
	return region


## A painted part found ([method trimmed]) kept for [param memo] ([method
## trim_key]), unless one is kept already. Main thread.
static func keep_trim(memo: String, rect: Rect2) -> void:
	if not _trims.has(memo):
		_trims[memo] = rect


## Whether [param memo]'s painted part is kept.
static func trim_kept(memo: String) -> bool:
	return _trims.has(memo)


## THE CASTLES' FRAMES the hero's page trims ([method _castles]): `[key,
## frame]` for each wizard's castle, standing and beaten — for [PaneWarmer]
## to trim before the page opens.
static func castle_frames() -> Array[Array]:
	var out: Array[Array] = []
	for i in 5:
		for state in [0, 2]:
			out.append(WorldView._castle_ref(int(WorldView.CASTLE_FRAMES[i][state])))
	return out


func _icon(texture: Texture2D, at: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = at
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


## A tab, lettered like the panes: gold when chosen.
func _dress(button: Button) -> void:
	var face := GameSkin.font("font_title")
	if face != null:
		button.add_theme_font_override("font", face)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_pressed_color", Color8(255, 236, 170))
	button.add_theme_color_override("font_hover_color", Color8(255, 236, 170))
	var rest := StyleBoxFlat.new()
	rest.bg_color = Color(0, 0, 0, 0.25)
	rest.set_corner_radius_all(5)
	rest.content_margin_left = 10
	rest.content_margin_right = 10
	rest.content_margin_top = 2
	rest.content_margin_bottom = 2
	var lit := rest.duplicate() as StyleBoxFlat
	lit.bg_color = Color(GOLD, 0.22)
	lit.border_color = Color(GOLD, 0.6)
	lit.set_border_width_all(1)
	button.add_theme_stylebox_override("normal", rest)
	button.add_theme_stylebox_override("hover", lit)
	button.add_theme_stylebox_override("pressed", lit)
	button.add_theme_stylebox_override("hover_pressed", lit)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
