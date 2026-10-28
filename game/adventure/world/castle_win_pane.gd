class_name CastleWinPane
extends StagePane
## A WIZARD BEATEN IN HIS CASTLE (part C, stage C2) — what the hero sees
## after [method CastleWin.beat], the owner's ruling B-5 of 2026-10-27,
## "With his room": 1.3's `HandleDefeatedWizardCastle` (dungeonEncounter.c
## 936–1030) in one of the world's rounded panes ([StagePane]), over the
## world, in pages:
##  1. HIS ROOM: the beaten wizard's room still (`Room-Blk.bmp` … of
##     statwin, `wizards_room_<colour>`, the quick package's import) coming
##     in as a castle's picture does ([TileReveal]'s staggered tiles), "The
##     Black Wizard is beaten!" [ours] — 1997 opened the wizards' window
##     here (`ShowStatsWindow(1, colour)`, dE:937); the owner's B-3 keeps
##     it shut, the Wizards tab holds it.
##  2. THE WORDS over the trade backdrop (`Tradscrn.pic`, `card_browser`),
##     in its black panel, centred where 1997 centred them (x 320, y 114
##     and 200), white, as large as they stand there with 1997's own line
##     breaks ([method StagePane.fit_points]): `@CASTLEWIN` 0/1 — "You have
##     defeated the dreaded / Red Wizardess.  No longer shall / her evil
##     creatures oppress / the good people of Shandalar." — each freed
##     town's "<town> freed!", and 3, "You may take any three / different
##     Red cards." Under the page
##     [ours] A NEWS LINE: the towns freed and his creatures gone from the
##     land ([method news_line]).
##  3. THE THREE PICKS (dE:983–1017): "Pick a card - 3 left" (`@CASTLEWIN`
##     4) over every card of his colour a trade may give ([method
##     CastleWin.offered]: the cards taken left out — "different" within the
##     three —, the Classic MTG rules' limit), by name in two columns with
##     the type chips and a name to look for [ours, the trader's]; the card
##     under the pointer large beside them; a card chosen asks "Will you
##     take this card..." — Yes ([method CastleWin.take]: it joins the
##     hero's cards in no deck) or No (the same pick again). No Done and no
##     way to skip, as 1997's browser; Escape puts the card chosen back.
##     [Ours: a full bag said — 1997 lost the card silently: a pick the bag
##     has no room for is not offered, "Your magic bag holds no more
##     spells." and the picks left are lost (the meeting's P4-6 rule).]
##  4. [Ours] THE CARDS TAKEN, fanned on the cards-won ground
##     (`win_back_cards`), what came of each said; Continue.
## His castle's tune (`music_castle_<colour>`, `PlayCastleMusic`, dE:942)
## loops through all of it, the world's bed stopped under it.
##
## [signal finished] once, with the cards picked; the tune then stops and
## the pane takes itself away. Not all five beaten, the world's bed comes
## back (1997: the tune stops, the screen fades, the board returns); all
## five (`all_five` in the record), the caller hands over to the finale
## ([AdventureFinale]) and the bed stays quiet for it.
## A record of a wizard beaten before (`already`) shows his room and the
## words, no picks: they were taken then. An empty record finishes at once.
## Escape or Enter reads a page on, as 1997's key did; a choice's first
## letter lights it. Without the 1997 pictures each page is a plain dark
## field under the same words, the room's still his face.

## The pane is done: [param picked] the cards picked (each kept, or lost to
## a full bag as said).
signal finished(picked: Array[String])

## [Ours] The words.
const BEATEN := "The %s is beaten!"
const CONTINUE := "Continue"
const NEWS_TOWNS := "News from Shandalar: %s %s free again, and the %s's creatures have left the land."
const NEWS_NONE := "News from Shandalar: the %s's creatures have left the land."
const CHOOSE := "%d cards. Choose one."
const PICKS_LOST := "The last pick is lost."
const PICKS_LOST_MANY := "The %d picks left are lost."
## The words' places on `Tradscrn.pic`: its black panel runs x 220–416,
## y 84–345; 1997 centred the words at (320, 114) and the picks' line at
## (320, 200).
const WORDS_AT := Rect2(224, 88, 192, 156)
const TAKE_AT := Rect2(224, 250, 192, 64)
const WORDS_INK := Color8(254, 254, 254)
## The cards taken on `win_back_cards`.
const TAKEN_WIDTH := 150.0
const TAKEN_GAP := 24.0
const TAKEN_TOP := 70.0
## The large card beside the picks' list, at most and at least.
const LARGE_MOST := 0.78
const LARGE_LEAST := 0.5

## [method CastleWin.beat]'s record.
var record := {}
## Where the pane stands: `room`, `words`, `pick`, `bag_full`, `taken`,
## `done`.
var step := ""
## The picks left, the cards picked, what each came to.
var left := 0
var picked: Array[String] = []
var said: Array[String] = []
## The card chosen in the list, "" none; the type chip on (0 all).
var chosen := ""
var type_filter := 0
var _done := false
var _shown: Array[String] = []
var _pick_body: HBoxContainer
var _large: CardPreview
var _list: ItemList
var _search: LineEdit
var _take_line: Label
var _chips := {}
var _hovered := -1


## THE PANE for [param player] after [param record] ([method
## CastleWin.beat]'s return): not yet in the tree (the caller adds it,
## centres it — [method PaneStyle.centre] — and sets [member k]).
static func make(player: AdventurePlayer, record: Dictionary) -> CastleWinPane:
	var pane := CastleWinPane.new()
	pane.player = player
	pane.record = record
	return pane


func _ready() -> void:
	super._ready()
	name = "CastleWinPane"
	if record.is_empty() or player == null:
		_finish.call_deferred()
		return
	left = 0 if bool(record.get("already", false)) else CastleWin.PICKS
	var index := clampi(int(record.get("index", 0)), 0, 4)
	set_title(WorldNames.dungeon_name(index), WorldNames.CASTLES[index])
	play_music(String(record.get("music", "")))
	_room()


## The wizard's colour, 1 black … 5 white.
func color() -> int:
	return clampi(int(record.get("color", 1)), 1, 5)


## The wizard's name, "Black Wizard".
func wizard() -> String:
	return String(record.get("wizard", WorldNames.WIZARDS[color() - 1]))


# --------------------------------------------------------------- the pages --

## 1. HIS ROOM (the class doc).
func _room() -> void:
	step = "room"
	stage.clear()
	stage.hue = color()
	stage.ground("wizards_room_" + AdventurePlayer.COLORS[color() - 1])
	if not stage.has_ground():
		stage.creature_face(int(record.get("row", CreatureBook.castle_row(color()))))
	else:
		_reveal_page()
	say([BEATEN % wizard()])
	offer([["continue", CONTINUE, true]])


## The page comes in as a castle's picture does ([TileReveal]): nothing
## with the transitions off, never headless.
func _reveal_page() -> void:
	var cover := TileReveal.make(TileReveal.CASTLE_GRID, TileReveal.CASTLE_SECONDS, TileReveal.Order.STAGGERED)
	if cover == null:
		return
	cover.name = "PageReveal"
	stage.add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## 2. THE WORDS over the trade backdrop, the news line under it.
func _words_page() -> void:
	step = "words"
	stage.clear()
	stage.ground("card_browser")
	var said := "\n".join(PackedStringArray(record.get("lines", [])))
	var take := String(record.get("take_words", "")).strip_edges()
	# One size for both, so both wear one face (the title face from 15
	# points up, [method PaneStyle.label]).
	var points := StagePane.fit_points(said, WORDS_AT.size)
	if left > 0:
		points = mini(points, StagePane.fit_points(take, TAKE_AT.size))
		stage.words(take, TAKE_AT, points, WORDS_INK, "TakeWords", true)
	stage.words(said, WORDS_AT, points, WORDS_INK, "CastleWords", true)
	say([news_line()])
	offer([["continue", CONTINUE, true]])


## [Ours] THE NEWS LINE: the towns freed — or none — and his creatures gone
## from the land ([method Sieges.free_all]).
func news_line() -> String:
	var towns: Array = record.get("towns", [])
	var names: Array[String] = []
	for town in towns:
		names.append(WorldNames.site_name(player.world, int(town)) if player != null else str(town))
	if names.is_empty():
		return NEWS_NONE % wizard()
	return NEWS_TOWNS % [joined(names), "is" if names.size() == 1 else "are", wizard()]


## "A", "A and B", "A, B and C".
static func joined(names: Array[String]) -> String:
	if names.size() <= 1:
		return "".join(PackedStringArray(names))
	return ", ".join(PackedStringArray(names.slice(0, names.size() - 1))) + " and " + names[-1]


## 3. A PICK, or the picks' end: the bag full, the cards taken, the end.
func _next_pick() -> void:
	if left <= 0:
		if picked.is_empty():
			_finish()
		else:
			_taken_page()
		return
	if player.bag_room() < 1:
		_bag_full()
		return
	step = "pick"
	chosen = ""
	set_title(CastleWin.pick_title(left), WorldNames.CASTLES[color() - 1])
	if _pick_body == null:
		_pick_body = _make_picks()
	show_body(_pick_body)
	_refresh()
	_ask()


## [Ours] The bag full: the picks left not offered, said.
func _bag_full() -> void:
	step = "bag_full"
	show_body(null)
	stage.clear()
	stage.ground("card_browser")
	var lost := PICKS_LOST if left == 1 else PICKS_LOST_MANY % left
	said.append(AdventurePlayer.BAG_FULL)
	left = 0
	# Our words, not 1997's: wrapped to the panel as they come.
	stage.words("%s\n\n%s" % [AdventurePlayer.BAG_FULL, lost], WORDS_AT, 16, WORDS_INK, "BagFull", true)
	say([])
	offer([["continue", CONTINUE, true]])


## 4. [Ours] THE CARDS TAKEN, fanned, what each came to said.
func _taken_page() -> void:
	step = "taken"
	set_title(WorldNames.dungeon_name(clampi(int(record.get("index", 0)), 0, 4)), WorldNames.CASTLES[color() - 1])
	show_body(null)
	stage.clear()
	stage.ground("win_back_cards")
	var count := picked.size()
	var room := EncounterStage.PAGE.x - 40.0
	var step_x := minf(TAKEN_WIDTH + TAKEN_GAP, (room - TAKEN_WIDTH) / maxf(count - 1, 1))
	var from := (EncounterStage.PAGE.x - (step_x * (count - 1) + TAKEN_WIDTH)) / 2.0
	for i in count:
		stage.card(picked[i], Vector2(from + step_x * i, TAKEN_TOP), TAKEN_WIDTH, "Taken%d" % i)
	say(said)
	offer([["continue", CONTINUE, true]])


## THE PANE IS DONE: [signal finished], once, the tune stopped (the world's
## bed again unless the finale follows), the pane taken away.
func _finish() -> void:
	if _done:
		return
	_done = true
	step = "done"
	stop_music()
	if not bool(record.get("all_five", false)):
		WorldDuels.world_music(self)
	finished.emit(picked.duplicate())
	if get_parent() != null:
		PaneStyle.drop(self)
	else:
		queue_free()


## Whether the pane is done.
func done() -> bool:
	return _done


## WHAT A CHOICE DOES, at the page the pane stands at.
func choose(action: String) -> void:
	if _done:
		return
	match step:
		"room":
			_words_page()
		"words":
			if left > 0:
				_next_pick()
			else:
				_finish()
		"pick":
			if action == "yes":
				take_chosen()
			elif action == "no":
				choose_card("")
		"bag_full":
			if picked.is_empty():
				_finish()
			else:
				_taken_page()
		"taken":
			_finish()


## Escape: a page read on; at a pick, the card chosen put back.
func escape() -> void:
	match step:
		"pick":
			choose_card("")
		"room", "words", "bag_full", "taken":
			choose("continue")


# ---------------------------------------------------------------- the picks --

## The picks' body: the large card, and the line, the chips, the name box
## and the list beside it — sized to the window.
func _make_picks() -> HBoxContainer:
	var room := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 800)
	var large := clampf((room.y - 330.0 - 40.0 * (k - 1.0)) / CardPreview.SIZE.y, LARGE_LEAST, LARGE_MOST)
	var across := HBoxContainer.new()
	across.name = "Picks"
	across.add_theme_constant_override("separation", 14)
	across.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder := Control.new()
	holder.name = "LargeHolder"
	holder.custom_minimum_size = CardPreview.SIZE * large
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_large = CardPreview.new()
	_large.name = "Large"
	_large.docked = true
	_large.scale = Vector2(large, large)
	_large.mouse_filter = Control.MOUSE_FILTER_STOP
	_large.gui_input.connect(func(input: InputEvent) -> void:
		if PaneStyle.right_click(input) and _large._shown != null:
			card_read.emit(_large._shown.data.card_name))
	_large.visible = false
	holder.add_child(_large)
	across.add_child(holder)
	var width := clampf(room.x - SIDE_MARGIN - holder.custom_minimum_size.x - 40.0, 360.0, 600.0)
	var column := VBoxContainer.new()
	column.name = "PickColumn"
	column.add_theme_constant_override("separation", 6)
	column.custom_minimum_size = Vector2(width, 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	across.add_child(column)
	_take_line = PaneStyle.label(String(record.get("take_words", "")).strip_edges().replace("\n", " "), 15,
		PaneStyle.DIM)
	_take_line.name = "TakeLine"
	column.add_child(_take_line)
	var chips := HFlowContainer.new()
	chips.name = "Types"
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 4)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for chip in [["All", 0]] + CardTradePane.TYPE_CHIPS:
		var button := PaneStyle.button(String(chip[0]), "Chip_" + String(chip[0]), k, 13)
		button.toggle_mode = true
		var bit := int(chip[1])
		button.button_pressed = bit == type_filter
		button.toggled.connect(func(_on: bool) -> void:
			type_filter = bit
			_sync_chips()
			_refresh())
		_chips[button.name] = [button, bit]
		chips.add_child(button)
	column.add_child(chips)
	_search = LineEdit.new()
	_search.name = "PickSearch"
	_search.placeholder_text = "type a name"
	_search.custom_minimum_size = Vector2(220, 0)
	_search.text_changed.connect(func(_text: String) -> void: _refresh())
	column.add_child(_search)
	_list = ItemList.new()
	_list.name = "PickCards"
	_list.max_columns = 2
	_list.same_column_width = true
	_list.fixed_column_width = int((width - 24.0) / 2.0)
	var high := holder.custom_minimum_size.y - 6.0 * 3 - 24.0 * k - 30.0 - 22.0
	_list.custom_minimum_size = Vector2(width, maxf(high, 140.0))
	_list.focus_mode = Control.FOCUS_NONE
	var face_font := GameSkin.font("font_title")
	if face_font != null:
		_list.add_theme_font_override("font", face_font)
	_list.add_theme_font_size_override("font_size", 15)
	_list.add_theme_color_override("font_color", PaneStyle.INK)
	_list.add_theme_color_override("font_hovered_color", PaneStyle.LIT)
	_list.add_theme_color_override("font_selected_color", PaneStyle.LIT)
	_list.add_theme_stylebox_override("panel", PaneStyle.well())
	var lit := StyleBoxFlat.new()
	lit.bg_color = Color(PaneStyle.GOLD, 0.22)
	lit.set_corner_radius_all(4)
	_list.add_theme_stylebox_override("selected", lit)
	_list.add_theme_stylebox_override("selected_focus", lit)
	_list.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_list.item_selected.connect(func(at: int) -> void:
		if at >= 0 and at < _shown.size():
			choose_card(_shown[at]))
	_list.gui_input.connect(_hover_list)
	_list.mouse_exited.connect(func() -> void: _hovered = -1)
	column.add_child(_list)
	return across


func _sync_chips() -> void:
	for key in _chips:
		var entry: Array = _chips[key]
		(entry[0] as Button).set_pressed_no_signal(int(entry[1]) == type_filter)


## THE CARDS OFFERED NOW ([method CastleWin.offered]), by the type chip and
## the name looked for.
func cards() -> Array[String]:
	var out: Array[String] = []
	var look := _search.text.strip_edges().to_lower() if _search != null else ""
	var facts := {}
	if type_filter != 0:
		for row in CardTrade.catalogue():
			facts[String(row["name"])] = row["facts"]
	for card_name in CastleWin.offered(player, picked, color()):
		if type_filter != 0 and int((facts.get(card_name, {}) as Dictionary).get("type", 0)) & type_filter == 0:
			continue
		if look != "" and not card_name.to_lower().contains(look):
			continue
		out.append(card_name)
	return out


## The list as it now stands, the card chosen kept lit.
func _refresh() -> void:
	if _list == null:
		return
	_shown = cards()
	_list.clear()
	_hovered = -1
	var owned := AdventureBuilder.owned_counts(player)
	for card_name in _shown:
		var count := int(owned.get(card_name, 0))
		var at := _list.add_item("%s-%d" % [card_name, count] if count > 0 else card_name)
		if card_name == chosen:
			_list.select(at)
	if chosen != "" and not chosen in _shown:
		chosen = ""
	_ask()


## CARD [param card_name] CHOSEN ("" none): shown large, "Will you take
## this card..." asked.
func choose_card(card_name: String) -> void:
	if step != "pick":
		return
	chosen = card_name
	if card_name != "":
		show_large(card_name)
		var at := _shown.find(card_name)
		if at >= 0 and not _list.is_selected(at):
			_list.select(at)
			_list.ensure_current_is_visible()
	elif _list != null:
		_list.deselect_all()
	_ask()


## The question and its two answers, live once a card is chosen.
func _ask() -> void:
	if chosen == "":
		say([CHOOSE % _shown.size()])
	else:
		say([CastleWin.TAKE_THIS])
	offer([["yes", CastleWin.YES, chosen != ""], ["no", CastleWin.NO, chosen != ""]], note())


## YES: the card chosen taken ([method CastleWin.take]); the next pick, or
## the picks' end.
func take_chosen() -> void:
	if step != "pick" or chosen == "":
		return
	var taken := CastleWin.take(player, chosen)
	picked.append(chosen)
	said.append(String(taken.get("said", "")))
	left -= 1
	set_note(String(taken.get("said", "")))
	chosen = ""
	if _search != null:
		_search.text = ""
	_next_pick()


## Card [param card_name] large beside the list.
func show_large(card_name: String) -> void:
	if _large != null and PaneStyle.show_card(_large, card_name):
		_large.visible = true


## The pointer over the list: the row under it large; a right click reads it.
func _hover_list(input: InputEvent) -> void:
	if PaneStyle.right_click(input):
		var at := _list.get_item_at_position((input as InputEventMouseButton).position, true)
		if at >= 0 and at < _shown.size():
			show_large(_shown[at])
			card_read.emit(_shown[at])
			_list.accept_event()
		return
	var motion := input as InputEventMouseMotion
	if motion == null:
		return
	var at := _list.get_item_at_position(motion.position, true)
	if at == _hovered:
		return
	_hovered = at
	if at >= 0 and at < _shown.size():
		show_large(_shown[at])


## The cards in the list now.
func shown() -> Array[String]:
	return _shown.duplicate()


## ESCAPE IN THE NAME BOX, met before the box keeps it: a name typed is
## cleared and the box left (the trader's way, [CardTradePane]).
func _input(input: InputEvent) -> void:
	super._input(input)
	if _search == null or not _search.has_focus() or not input.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	_search.text = ""
	_search.release_focus()
	_refresh()
