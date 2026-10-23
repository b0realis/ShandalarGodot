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

const TABS: Array[String] = ["Hero", "Wizards", "Journal"]
const GOLD := Color8(232, 190, 110)
const INK := Color8(236, 222, 196)
const DIM := Color8(160, 146, 128)
## 1997's colours for a creature's record: losing badly, losing, even,
## winning, winning big.
const RECORD_INKS := [Color8(232, 70, 50), Color8(236, 150, 90), INK, Color8(150, 220, 120), Color8(110, 236, 140)]
const PORTRAIT := Vector2(96, 118)
const ICON := 26.0

var player: AdventurePlayer
var art := WorldArt.new()
## Each sprite's painted part, found once: `"key#frame"` → its region.
static var _trims := {}
var tab := "Hero"
## The Hero page's size, which every tab keeps.
var page_size := Vector2.ZERO
var _tabs := {}
var _page: VBoxContainer


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


## Build the page shown, as the hero now stands.
func refresh() -> void:
	if _page == null:
		return
	for key in _tabs:
		(_tabs[key] as Button).set_pressed_no_signal(key == tab)
	_clear_page()
	if player == null:
		return
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


func _clear_page() -> void:
	for child in _page.get_children():
		child.free()


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
	who.add_child(_label("Days on the road %d · lairs explored %d · World seed %s" % [
		WorldStatus.days_on_road(player), player.lairs_explored, player.world_seed_text], 13, DIM))
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
		for creature in creatures:
			var tally: Array = creatures[creature]
			list.add_child(_label("%d/%d %s" % [tally[0], tally[1], creature], 14,
				record_ink(int(tally[0]), int(tally[1]))))
		# Many creatures fought: four rows show, the rest scroll, so the
		# pane stays on the screen.
		var rows := ceili(creatures.size() / 3.0)
		if rows > 4:
			var scroll := ScrollContainer.new()
			scroll.name = "CreatureScroll"
			scroll.custom_minimum_size = Vector2(0, 4 * 21)
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll.add_child(list)
			_page.add_child(scroll)
		else:
			_page.add_child(list)


## Gold, food, mana links and the deck, on the frame's own painted tiles.
func _carried() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Carried"
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var deck := 0
	for card in player.cards:
		if ((card as Dictionary).get("decks", []) as Array).has(player.current_deck):
			deck += 1
	var values := {"gold": str(player.gold), "food": str(player.food),
		"ankh": str(player.mana_links.size()), "book": "%d/%d" % [deck, player.cards.size()]}
	for key in WorldHud.STRIP:
		var frame := GameSkin.texture("world_frame")
		if frame != null:
			var cut := AtlasTexture.new()
			cut.atlas = frame
			cut.region = Rect2(WorldHud.FRAME_ICONS[key])
			row.add_child(_icon(cut, Vector2(WorldHud.FRAME_ICONS[key].size) * (ICON / WorldHud.FRAME_ICONS[key].size.y)))
		else:
			row.add_child(_label(WorldHud.STRIP_NAMES[key], 13, GOLD))
		row.add_child(_label(values[key], 16))
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
		row.add_child(_label(str(int(player.amulets.get(gem[0], 0))), 16))
	return row


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
		var tries := 0
		if player.world != null and i < player.world.encounters.size():
			tries = int(player.world.encounters[i].get("times_entered", 0))
		var count := _label(str(tries), 13, INK)
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
		var entry := player.journal[i] as Dictionary
		var text := String(entry.get("text", ""))
		if text == "":
			continue
		var day := int(entry.get("day", -1))
		lines.append(("Day %d: " % day if day >= 0 else "") + text.replace("\n", " "))
	return lines


func _journal_page() -> void:
	var lines := journal_lines()
	if lines.is_empty():
		_page.add_child(_label("Nothing written yet: what you do in Shandalar is kept here.", 14, DIM))
		return
	var scroll := ScrollContainer.new()
	scroll.name = "Journal"
	scroll.custom_minimum_size = Vector2(0, maxf(page_size.y, 120.0))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
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
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for line in lines:
		var said := _label(line, 14)
		said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(said)
	scroll.add_child(column)
	_page.add_child(scroll)


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
