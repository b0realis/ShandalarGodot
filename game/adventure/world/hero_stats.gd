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
##    Shandalar" (wins / losses, coloured by how it goes, as 1997 coloured
##    it); ours beside them: the days on the road, the lairs explored.
##  - THE WIZARDS: each wizard's cities tapped toward Dominion ([WorldStatus])
##    and whether their castle has fallen — 1997's `Statwin` window drew
##    them as skulls.
##  - THE JOURNAL: what has happened, newest first, in the 1997 words
##    (`@LOGSTRINGS`); 1997 walked it on the map.
## The counts are read from the journal as 1997 rebuilt them
## (`RebuildStatsJournalCounts`, [method record]).
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
## 1997's colours for a creature's record: losing badly, losing, even,
## winning, winning big.
const RECORD_INKS := [Color8(232, 70, 50), Color8(236, 150, 90), INK, Color8(150, 220, 120), Color8(110, 236, 140)]
const PORTRAIT := Vector2(96, 118)
const ICON := 26.0
## The creature record's rows shown before it scrolls.
const CREATURE_ROWS := 4
## The journal's lines made at a time, and how near the end of those made,
## in pixels, the reader comes before the next older ones are made.
const JOURNAL_STEP := 100
const JOURNAL_NEAR := 400.0

## The journal is to be walked on the map ([method WorldMap.walk_journal]).
signal journal_map_pressed

var player: AdventurePlayer
var art := WorldArt.new()
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
		button.pressed.connect(show_tab.bind(key))
		bar.add_child(button)
		_tabs[key] = button
	add_child(bar)
	_page = VBoxContainer.new()
	_page.name = "Page"
	_page.add_theme_constant_override("separation", 8)
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_page)
	refresh()


## Show [param key]'s tab.
func show_tab(key: String) -> void:
	tab = key
	refresh()


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
				player.difficulty, _castle_tries()])
		"Wizards":
			parts.append_array([WorldStatus.taps(player), WorldStatus.dominion(player), player.defeated_wizards,
				player.owns("Ring of the Guardian")])
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
## [won, lost]}}`.
static func record(hero: AdventurePlayer) -> Dictionary:
	var out := {"saved": 0, "recovered": 0, "quests_done": 0, "quests_failed": 0,
		"treasures": 0, "creatures": {}}
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
				if creature != "":
					var tally: Array = (out["creatures"] as Dictionary).get(creature, [0, 0])
					tally[0 if bool(line.get("won", false)) else 1] += 1
					out["creatures"][creature] = tally
	return out


## The ink of a creature's record, as 1997 chose it: badly losing, losing,
## few games or even, winning, winning big.
static func record_ink(won: int, lost: int) -> Color:
	var games := won + lost
	var share := float(won) / float(games) if games > 0 else 0.5
	if lost - won > 5 and share <= 0.25:
		return RECORD_INKS[0]
	if won - lost > 5 and share >= 0.75:
		return RECORD_INKS[4]
	if games < 5 or (share >= 0.4 and share <= 0.6):
		return RECORD_INKS[2]
	return RECORD_INKS[3] if share > 0.6 else RECORD_INKS[1]


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
	for pair in [["Cities Saved", str(kept["saved"])], ["Cities Recovered", str(kept["recovered"])],
			["Quest Record", "%d/%d" % [kept["quests_done"], kept["quests_failed"]]],
			["Overall Won/Loss", "%d/%d" % [kept["won"], kept["lost"]]],
			["Dungeon Treasures", str(kept["treasures"])]]:
		grid.add_child(_label(pair[0], 14, GOLD))
		var value := _label(pair[1], 14)
		value.name = "Value_" + String(pair[0]).replace(" ", "_").replace("/", "_")
		grid.add_child(value)
	_page.add_child(grid)
	_page.add_child(_caption("Record vs the Creatures of Shandalar"))
	var creatures: Dictionary = kept["creatures"]
	if creatures.is_empty():
		_page.add_child(_label("No creature fought yet.", 14, DIM))
	else:
		var list := GridContainer.new()
		list.name = "Creatures"
		list.columns = 3
		list.add_theme_constant_override("h_separation", 16)
		list.add_theme_constant_override("v_separation", 4)
		for creature in creatures:
			var tally: Array = creatures[creature]
			list.add_child(_label("%d/%d %s" % [tally[0], tally[1], creature], 14,
				record_ink(int(tally[0]), int(tally[1]))))
		# Many creatures fought: four rows show, the rest scroll, so the
		# pane stays on the screen.
		if ceili(creatures.size() / 3.0) > CREATURE_ROWS:
			var scroll := _scroll("CreatureScroll")
			scroll.add_child(list)
			_page.add_child(scroll)
			# Measured once on the page, where the rows have their letters.
			scroll.custom_minimum_size = Vector2(0, _rows_height(list, CREATURE_ROWS))
		else:
			_page.add_child(list)


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


## How often each wizard's castle was entered, black to white.
func _castle_tries() -> Array[int]:
	var tries: Array[int] = []
	for i in 5:
		var entered := 0
		if player.world != null and i < player.world.encounters.size():
			entered = int(player.world.encounters[i].get("times_entered", 0))
		tries.append(entered)
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


# ------------------------------------------------------------ the wizards --

func _wizards_page() -> void:
	var taps := WorldStatus.taps(player)
	var rule := _label("A wizard who taps %d cities casts the Spell of Dominion%s." % [
		WorldStatus.dominion(player), " (Ring of the Guardian)" if player.owns("Ring of the Guardian") else ""], 14)
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page.add_child(rule)
	var grid := GridContainer.new()
	grid.name = "Wizards"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 5:
		var color: String = AdventurePlayer.COLORS[i]
		var inks: Array = WorldHud.NAME_INKS[color]
		var wizard := _label(WorldNames.WIZARDS[i], 16, inks[0])
		wizard.add_theme_color_override("font_outline_color", inks[1])
		wizard.add_theme_constant_override("outline_size", 3)
		grid.add_child(wizard)
		var pips := ""
		for t in WorldStatus.dominion(player):
			pips += "●" if t < taps[i] else "○"
		grid.add_child(_label(pips, 14, GOLD))
		grid.add_child(_label("beaten" if color in player.defeated_wizards
			else "%d of %d taps" % [taps[i], WorldStatus.dominion(player)], 14))
	_page.add_child(grid)


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
	# [Ours] 1997's journal was walked on the map, line by line: so it is.
	var walk := Button.new()
	walk.name = "JournalOnMap"
	walk.text = "On the map"
	walk.focus_mode = Control.FOCUS_NONE
	_dress(walk)
	walk.pressed.connect(func() -> void: journal_map_pressed.emit())
	_page.add_child(walk)
	var scroll := _scroll("Journal")
	# The button above takes its height from the scroll: the pane keeps its
	# size from tab to tab.
	var taken := walk.get_combined_minimum_size().y + float(_page.get_theme_constant("separation"))
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
	var memo := "%s#%d" % [key, frame]
	if not _trims.has(memo):
		_trims[memo] = region
		var image := sheet.get_image()
		if image != null:
			if image.is_compressed():
				image.decompress()
			# A 2x skin's sheet holds twice the pixels of the 1997 frame.
			var scale := GameSkin.scale_of(sheet)
			var used := image.get_region(GameSkin.image_rect(sheet, Rect2i(region))).get_used_rect()
			if used.size.x > 0:
				_trims[memo] = Rect2(region.position + Vector2(used.position) / scale, Vector2(used.size) / scale)
	var cut := AtlasTexture.new()
	cut.atlas = sheet
	cut.region = _trims[memo]
	return cut


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
