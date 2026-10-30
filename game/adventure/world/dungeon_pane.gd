class_name DungeonPane
extends PanelContainer
## INSIDE A CASTLE OR A DUNGEON (part C, stage C2) — 1.3's
## `RunCastleDungeonBoard` (dungeonEncounter.c 187–741, "dE" below) as the
## player meets it: the board ([DungeonView]: the maze, its rooms, the hero)
## in one of the world's movable rounded panes ([PaneStyle]), over the world,
## which waits under it ([method WorldScreen.on_board]) — the owner's ruling
## of round P3: *"A pane over the world"*, at most 1.25 × the 1997 page, as
## a meeting's. The rules are [DungeonBoard]'s, the duels [DungeonDuels]',
## a wizard beaten [CastleWin]'s; this pane asks the player and shows what
## each answers. The world's doors open it ([method WorldScreen._open_board],
## [DungeonDoors]) and close it with [signal finished].
##
## THE PANE: what the place is ("Dungeon", "Red Castle") — its name is on
## the page's plaque, not twice (the owner, 2026-10-30: "Top title should
## just say Dungeon"); the 1997 page; under it one row of choices — "Leave"
## always there while the hero stands free [QoL]. The page never changes
## size from step to step: 1997's text boxes stand OVER the board, in a
## box of the panes' glass ([method box]), so nothing under the page swells
## as the hero walks (part B's lesson). On the page's foot [ours, the
## owner's board extras]: the life the next duel starts with and the rooms
## left — every room still holding a creature, a treasure, the dice or a
## scroll, seen or not (the owner's ruling of round C1).
##
## THE FIRST VIEW (dE:1373–1382, 409): a dungeon with a card in effect shows
## it on the page — "Hypnotic Specter in effect." — until a key, a click or
## Continue [1997]. [ours: 1997 waited for a key on the first view with no
## card too, which swallowed the hero's first step unseen; here the board
## is walked at once.]
##
## MOVING [the owner's P4 "Modern"]: 1997's Home, PgUp, PgDn and End, the
## keypad's 7, 9, 3 and 1, the arrows and W A S D turned to the board's
## diagonals ([method DungeonBoard.direction_of_key]); a key held walks on,
## and of two held the newer, after the step under way (part C stage C3,
## h1-3). A click on a room next to the hero steps there; further along a straight
## corridor the hero has seen, the hero walks there, stopping at the first
## event ([method DungeonBoard.walk_toward]); anywhere else, 1997's quadrant
## round the hero ([method DungeonBoard.direction_toward]). A click on a
## figure is a click on its room. Touch is a click; a double click's second
## press is none, and a click puts a box or a page away only once it has
## been up a moment (h1-1). A creature's name shows over it while the
## pointer rests there [ours, the owner's pick].
## LEAVING ASKS FIRST [ours, the owner's board extras: "Leave?"]: the exit
## stepped onto or clicked, Escape, or Leave — "Leave Azar's Crypt? The
## dungeon will move elsewhere, and where it lies will be forgotten." (a
## dungeon with no card left: it will be gone, h1-4; a castle on Wizard:
## its wizard may send a siege) — Stay or Leave.
##
## THE EVENTS, each as 1997 played it (c4 §8) — the hero first walks half
## way into the cell ([method DungeonView.walk]):
##  - THE DICE (`sfx_dice`): "You get +2 (14) Lives / in the next duel!" or
##    the card's name, in a box; Continue — the hero walks in.
##  - THE SCROLL (`sfx_scroll`): the riddle in a box, its answers under it
##    (each also its first letter); Escape waits for an answer [ours, as the
##    meeting's riddle]; the verdict and the riddle's card; a wrong answer
##    (`sfx_dsummon`) summons the castle's or the dungeon's strongest
##    creature into the cell and the hero steps back.
##  - A TREASURE: a card (`sfx_find_card`) — `dungeon_treasure` (Staceybk)
##    coming in over the board in 8 × 8 tiles in a random order
##    ([TileReveal]; 1997's `BlitRectByRandomTileOrderInPlace`), the card at
##    (68, 166) and "Found This Card" over it; WITH THE BAG FULL [ours, the
##    owner's D12] "Swap a card for it" — the adventure's deck builder
##    ([TreasureSwapBuilder]) to leave one of the hero's cards in its place
##    (the card left STAYS IN THE DUNGEON as its treasure, the owner's
##    ruling of round C1) — or "Leave it here" (the card stays in the
##    dungeon). Gold (`sfx_treasure`): "Found 230 Gold / and a bag with
##    Jewels: …" in a box.
##  - A ROOM, OR THE CASTLE'S WIZARD: the duel's set-up and the stake
##    ([method DungeonDuels.setup_room], [method DungeonDuels.draw_stake];
##    nothing to stake at all — the game is over), "Exploring the Dungeon…"
##    (`sfx_dungeon_duel`) and what is at stake in [RoomDuelPane] — no
##    flight —, the duel held over the world ([WorldDuels]: the board's bed
##    paused, the pane hidden), its end settled ONCE ([method
##    DungeonDuels.settle], the one writer of the life pool) and told to the
##    board ([method DungeonBoard.room_done]): WON — "Defeated a Wolf." said
##    on the page, the hero walks in; DRAWN — no result (the owner's g3): the
##    hero steps back, the creature waits; LOST — "Lost this card" on
##    `lose_card` with the `card_banner` caption, silent as 1997's, and the
##    visit is over (a castle's booted words after); the castle's WIZARD
##    BEATEN — [method CastleWin.beat] once, at once (before any save), then
##    [CastleWinPane] (his room, the words, the three picks), then out —
##    with `all_five` in the result when he was the fifth.
##  - THE BOOTED WORDS ("You are unceremoniously booted from / the
##    stronghold of the Mighty Red Wizardess!", `sfx_dsummon`) are shown
##    ONCE, from [method DungeonBoard.close]'s `words`.
## THE SOUNDS: [DungeonSound] — the bed, the ambience on its own dice, the
## events' one-shots; the title's tune (`ShellMusic`) off while inside, back
## as the pane closes ([method WorldDuels.world_music]).
## NOTHING IS SAVED INSIDE (the owner's D2: the world saved the adventure at
## the door, [method WorldScreen._enter_board]); a room duel's "Return to
## the main menu" says so in its question. Taken once the duel is over
## ([method WorldScreen.leaving_after_panes]), the result stands: it is
## shown, the visit ends as by the exit and the world, saved on the way
## out, leaves for the title (part C stage C3, h1-2; [constant MENU_OVER]).
##
## [signal finished] once with [method DungeonBoard.close]'s result —
## `{index, beaten, booted, game_over, words}` — and, after a castle's
## wizard, `castle_win` (the [method CastleWin.beat] record) and `all_five`.

## The board is left: [param result] (see the class's notes).
signal finished(result: Dictionary)
## A card right-clicked, to be read full screen ([method WorldScreen.read_card]).
signal card_read(card_name: String)

## The page's size against 1997's, at most and at least; the room kept free
## above and below the pane.
const MOST := 1.25
const LEAST := 0.55
const ROOM_MARGIN := 32.0
## [Ours] The choices' words.
const GO_ON := "Continue"
const LEAVE := "Leave"
const STAY := "Stay"
const SWAP := "Swap a card for it"
const KEEP := "Leave it here"
## [Ours] The question before leaving, and its reasons.
const LEAVE_ASK := "Leave %s?"
const LEAVE_MOVES := "The dungeon will move elsewhere, and where it lies will be forgotten."
## [Ours] A dungeon with no card left in it is drawn and entered no more
## ([method WorldClues.holds_cards]): it does not move, it is gone (part C
## stage C3, h1-4).
const LEAVE_GONE := "No card is left here: the dungeon will be gone."
const LEAVE_SIEGE := "The %s may send a siege against you."
## [Ours] The page's foot: the next duel's life, the rooms left.
const LIFE := "Life in the next duel: %d"
const ROOMS := "Rooms left: %s"
const ALL_CLEARED := "Every room cleared"
## [Ours] A full bag's question and its answers' words.
const BAG_FULL := "Your magic bag holds no more spells. Leave one of yours here in its place?"
const SWAPPED := "%s stays here in its place. %s joins your cards."
const STAYS := "%s stays in the dungeon."
## [Ours] A room's duel drawn.
const DRAWN := "A draw: %s still waits."
## [Ours] A room duel's "Return to main menu" question: nothing saved inside.
const MENU := "Return to the main menu? The duel is left unfinished and nothing is saved: the adventure goes back to where it was saved, at the door of %s."
## [Ours] The same question once the duel is over (part C stage C3, h1-2):
## its result is shown, the visit ends as by the exit — saved on the way
## out, as every way out is ([method WorldScreen._board_done]) — and the
## title.
const MENU_OVER := "Return to the main menu? The duel is over and its result stands: it is shown, then you leave %s as by its exit, and the adventure is saved and left."
## [Ours] How long after a box or a page comes a click on the page may put
## it away (part C stage C3, h1-1): a quick second click the desktop did not
## call a double click never puts away, unread, what the first brought —
## the card found's page not before it has come in ([constant
## TREASURE_SECONDS]).
const READ_GUARD_MS := 300
## The page's points where a box stands (1997's text boxes at (200, 192),
## the booted words at (320, 288)); beside the card found.
const BOX_AT := Vector2(320, 236)
const BOOTED_AT := Vector2(320, 288)
const BESIDE_CARD := Vector2(430, 250)
## The card found (dE:1513–1527) and its words; the card lost (dE:884–890).
const FOUND_CARD_AT := Vector2(68, 166)
const FOUND_WORDS_AT := Vector2(144, 147)
const CARD_WIDE := 150.0
const LOST_CARD_AT := Vector2(75, 166)
const LOST_CARD_WIDE := 160.0
const BANNER := Rect2(0, 0, 149, 19)
## The treasure's tiles: 8 × 8 page pixels over the 640 × 480 page, and how
## long they take [ours: 1997's speed was the machine's].
const TREASURE_TILES := Vector2i(80, 60)
const TREASURE_SECONDS := 0.6

var player: AdventurePlayer
## The world screen: it holds the duels and the panes over the world.
var screen: Node
## The board ([method DungeonBoard.enter]).
var board: DungeonBoard
## The size factor of the choices: 1, or [constant WorldHud.BIG].
var k := 1.0
var view: DungeonView
var sound: DungeonSound
## Where the pane stands: `first`, `idle`, `walking`, `box`, `riddle`,
## `leave`, `swap_ask`, `swapping`, `room`, `duel`, `lost`, `won`, `booted`,
## `done`.
var step := ""
## What [signal finished] carries, once it is known.
var result := {}

var _title: Label
var _choices: HFlowContainer
var _box: PanelContainer
var _box_words: Label
var _box_answers: HFlowContainer
## What Continue does at a box (none: no Continue).
var _then := Callable()
## A corridor walk's ways still to go.
var _queue: Array[int] = []
## The step under way: where it began and its way.
var _from := DungeonBoard.START
var _way := 0
## The duel's set-up, its host, the panes over the world.
var _duel_setup := {}
var _duel: WorldDuels
var _over_pane: Control
var _builder: Control
var _found := ""
var _lost: Array = []
var _lost_shown := 0
var _record := {}
var _done := false
var _most := 1.0
var _factor := 1.0
var _drag := {}
## The direction keys pressed on the board, the newest last (part C stage
## C3, h1-3): the newest still held walks on after the step under way.
var _held: Array[int] = []
## Until when a click on the page puts nothing away ([constant
## READ_GUARD_MS]), in [method Time.get_ticks_msec].
var _guard_until := 0


func _ready() -> void:
	name = "DungeonPane"
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", PaneStyle.glass())
	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	# What the place is, alone: its name is on the page's plaque (the
	# owner, 2026-10-30: "Top title should just say Dungeon").
	_title = PaneStyle.title(_kind())
	_title.name = "BoardTitle"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	var frame := PanelContainer.new()
	frame.name = "Picture"
	var rim := StyleBoxFlat.new()
	rim.bg_color = Color(0.02, 0.015, 0.015, 1.0)
	rim.border_color = Color(PaneStyle.GOLD, 0.7)
	rim.set_border_width_all(2)
	rim.set_corner_radius_all(4)
	rim.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", rim)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	view = DungeonView.new()
	view.board = board
	view.title_text = board.title() if board != null else ""
	if player != null:
		view.walker = player.walker
		view.hero_sheet = _hero_sheet()
	view.clicked.connect(_clicked)
	view.pointed.connect(_pointed)
	view.mouse_exited.connect(func() -> void: _pointed(Vector2(-1000, -1000)))
	view.card_read.connect(func(card_name: String) -> void: card_read.emit(card_name))
	frame.add_child(view)
	column.add_child(frame)
	_choices = HFlowContainer.new()
	_choices.name = "BoardChoices"
	_choices.alignment = FlowContainer.ALIGNMENT_CENTER
	_choices.add_theme_constant_override("h_separation", int(8 * k))
	_choices.add_theme_constant_override("v_separation", int(6 * k))
	_choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# One row of choices, always its height: the pane never swells.
	var probe := PaneStyle.button(GO_ON, "", k)
	_choices.custom_minimum_size.y = probe.get_combined_minimum_size().y
	probe.free()
	column.add_child(_choices)
	sound = DungeonSound.new()
	add_child(sound)
	var room := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 800)
	_most = clampf((room.x - 120.0) / DungeonView.PAGE.x, LEAST, MOST)
	_set_factor(_most)
	if is_inside_tree():
		get_viewport().size_changed.connect(_fit)
	_fit.call_deferred()
	_begin()


## The pane's title: "Dungeon", or the castle's colour ("Red Castle").
func _kind() -> String:
	if board == null:
		return ""
	return WorldNames.CASTLES[clampi(board.index, 0, 4)] if board.castle else "Dungeon"


## The hero's figure in their colours, as the world shows it.
func _hero_sheet() -> Texture2D:
	var world_view: Variant = screen.get("view") if screen != null else null
	if world_view is WorldView and (world_view as WorldView).hero_sheet != null:
		return (world_view as WorldView).hero_sheet
	return HeroColors.dressed(view.art, player.walker, player.figure_colors)


## IN: the bed, the title's tune off, the first view.
func _begin() -> void:
	if board == null or player == null:
		_finish()
		return
	sound.start()
	WorldDuels.world_music_off(self)
	_refresh()
	var effect := board.effect_name()
	if effect != "":
		step = "first"
		view.show_effect(effect)
		_then = _first_seen
		offer([["go", GO_ON, true]])
		return
	_idle()


func _first_seen() -> void:
	view.show_effect("")
	_idle()


# ---------------------------------------------------------------- size --

func _set_factor(value: float) -> void:
	_factor = value
	view.set_factor(value)
	_choices.custom_minimum_size.x = DungeonView.PAGE.x * value


## THE PAGE AS LARGE AS THE ROOM ALLOWS: as wide as the screen gives
## ([member _most]), as tall as the screen less the pane's own parts — the
## title, the choices' one row — measured once laid out; again when the
## window changes, never from step to step.
func _fit() -> void:
	if not is_inside_tree() or view == null:
		return
	var room := get_viewport_rect().size
	_most = clampf((room.x - 120.0) / DungeonView.PAGE.x, LEAST, MOST)
	var rest := get_combined_minimum_size().y - view.custom_minimum_size.y
	var grow := clampf((room.y - ROOM_MARGIN - rest) / DungeonView.PAGE.y, LEAST, _most)
	if absf(grow - _factor) * DungeonView.PAGE.y >= 1.0:
		_set_factor(grow)
	_relayout.call_deferred()


func _relayout() -> void:
	if not is_inside_tree():
		return
	var middle := position + size / 2.0
	size = get_combined_minimum_size()
	position = middle - size / 2.0
	var room := get_viewport_rect().size
	if size.y <= room.y:
		position.y = minf(position.y, room.y - size.y)
	position.x = clampf(position.x, 40.0 - size.x, room.x - 40.0)
	position.y = clampf(position.y, 0.0, maxf(room.y - 40.0, 0.0))
	_place_box()


## The page's size now, times 1997's.
func page_factor() -> float:
	return _factor


# ------------------------------------------------------------- the words --

## The page's lines: the next duel's (1997's), the life it starts with and
## the rooms left (ours).
func _refresh() -> void:
	if board == null:
		return
	view.gift_line = board.next_duel_line(player)
	view.status_left = LIFE % DungeonDuels.hero_life(player, board.run)
	view.status_right = rooms_words(board.rooms_left())
	view.redraw()


## "Rooms left: 4 creatures · 2 treasures · 1 dice · 1 scroll" for
## [param left] ([method DungeonBoard.rooms_left]).
static func rooms_words(left: Dictionary) -> String:
	var parts: Array[String] = []
	for kind in [["creatures", "creature"], ["treasures", "treasure"], ["dice", "dice"], ["scrolls", "scroll"]]:
		var count := int(left.get(kind[0], 0))
		if count > 0:
			parts.append("%d %s" % [count, kind[0] if count > 1 else kind[1]])
	return ROOMS % " · ".join(parts) if not parts.is_empty() else ALL_CLEARED


# ------------------------------------------------------------ the moves --

## Standing free on the board: Leave offered, the keys and the mouse move.
func _idle() -> void:
	step = "idle"
	_then = Callable()
	_hide_box()
	offer([["leave", LEAVE, true]])


## A STEP the way [param way] (1, 3, 5, 7), if the hero stands free.
func move(way: int) -> void:
	if step != "idle":
		return
	_queue.clear()
	_step(way)


func _step(way: int) -> void:
	var before := board.cells.duplicate()
	var from := board.hero
	var went := board.step(way)
	match String(went.get("kind", "")):
		"moved":
			step = "walking"
			view.hold_cells(before)
			view.walk(from, way, 0, DungeonView.STEPS, _walked)
		"event":
			step = "walking"
			_from = from
			_way = way
			view.walk(from, way, 0, DungeonView.HALF, _event.bind(int(went["event"])))
		"out":
			_queue.clear()
			view.redraw()
			_idle()
			ask_leave()
		_:
			# A wall: the hero only turns (1997: silently).
			_queue.clear()
			view.redraw()
			_idle()


## A step walked: the next of a corridor's, the newest key still held, or
## free.
func _walked() -> void:
	_refresh()
	step = "idle"
	if not _queue.is_empty():
		_step(_queue.pop_front())
		return
	var way := _held_way()
	if way != 0:
		_step(way)
		return
	_idle()


## Direction key [param code] pressed on the board: the newest held.
func _press_held(code: int) -> void:
	_held.erase(code)
	_held.append(code)


## THE WAY OF THE NEWEST DIRECTION KEY STILL HELD [modern] (part C stage C3,
## h1-3): a second key pressed while the hero walks turns them after the
## step under way — a tap let go before the step ends is dropped, as
## 1997's —, and the one still held under it walks on once it is let go;
## 0 for none. The keys let go are forgotten.
func _held_way() -> int:
	while not _held.is_empty():
		var code: int = _held[-1]
		if Input.is_key_pressed(code):
			var way := DungeonBoard.direction_of_key(code)
			if way != 0:
				return way
		_held.pop_back()
	return 0


## The hero walks on from half way into the event's cell (it was passed).
func _go_on() -> void:
	view.hide_page()
	_hide_box()
	step = "walking"
	offer([])
	view.walk(_from, _way, DungeonView.HALF, DungeonView.STEPS, _walked)


## The hero steps back from the event's cell (pushed back).
func _back() -> void:
	view.hide_page()
	_hide_box()
	step = "walking"
	offer([])
	view.walk(_from, _way, DungeonView.HALF, 0, _walked)


## A CLICK on the page at [param page_point].
func _clicked(page_point: Vector2, button: int) -> void:
	if _done or button != MOUSE_BUTTON_LEFT:
		return
	if step == "first" or (step in ["box", "lost", "booted"] and _then.is_valid()):
		# Not in the moment the box or the page came (h1-1, [constant
		# READ_GUARD_MS]).
		if Time.get_ticks_msec() >= _guard_until:
			choose("go")
		return
	if step != "idle":
		return
	var at := view.cell_at(page_point)
	if at == DungeonBoard.ENTRANCE:
		# 1997: a click on the exit leaves from anywhere — asked first [ours].
		ask_leave()
		return
	var ways := board.walk_toward(at)
	if not ways.is_empty():
		_queue = ways
		_step(_queue.pop_front())
		return
	var anchor := Vector2(DungeonBoard.cell_to_page(board.hero))
	_queue.clear()
	_step(DungeonBoard.direction_toward(page_point - anchor))


## THE POINTER over the page: a creature's name over it [ours].
func _pointed(page_point: Vector2) -> void:
	var at := DungeonView.NOWHERE
	var text := ""
	if step == "idle" or step == "first":
		var under := view.cell_at(page_point)
		var look := view.cell_look(under)
		if String(look.get("stands", "")) in ["creature", "wizard"]:
			at = under
			text = CreatureBook.name_of(int(look.get("row", -1)))
	if at != view.hover or text != view.hover_text:
		view.hover = at
		view.hover_text = text
		view.redraw()


# ----------------------------------------------------------- the events --

## THE HERO HALF WAY INTO an event's cell: its page.
func _event(event: int) -> void:
	match event:
		DungeonBoard.DICE:
			_dice()
		DungeonBoard.SCROLL:
			_scroll()
		DungeonBoard.TREASURE:
			_treasure()
		_:
			if DungeonBoard.is_room(event) or event == DungeonBoard.WIZARD:
				_room()
			else:
				_go_on()


func _dice() -> void:
	sound.play("sfx_dice")
	var got := board.roll_dice(player)
	_refresh()
	box(CreatureMeeting.lines_of(String(got.get("words", ""))), _go_on)


func _scroll() -> void:
	sound.play("sfx_scroll")
	var asked := board.riddle(player)
	if asked.is_empty():
		_go_on()
		return
	step = "riddle"
	_then = Callable()
	var answers: Array = []
	var given: Array = asked["answers"]
	for i in given.size():
		answers.append(["answer_%d" % i, String(given[i]), true])
	_show_box([String(asked["question"])], BOX_AT, answers)
	offer([])


## THE RIDDLE ANSWERED with answer [param index]: the verdict and its card;
## a wrong answer summons the creature, the hero steps back.
func answer(index: int) -> void:
	if step != "riddle":
		return
	var got := board.riddle_answered(player, index)
	if got.is_empty():
		return
	var right := bool(got["right"])
	if not right:
		sound.play("sfx_dsummon")
	box([String(got["words"])], _go_on if right else _back, BOX_AT, String(got.get("card", "")))


func _treasure() -> void:
	var got := board.open_treasure(player)
	if got.is_empty():
		_go_on()
		return
	if got.has("gold"):
		sound.play("sfx_treasure")
		_refresh()
		box(CreatureMeeting.lines_of(String(got["words"])), _go_on)
		return
	_found = String(got["card"])
	sound.play("sfx_find_card")
	_treasure_page(_found)
	if bool(got.get("bag_full", false)):
		_ask_swap()
		return
	step = "box"
	_then = _go_on
	offer([["go", GO_ON, true]])


## THE CARD FOUND on `dungeon_treasure`, coming in over the board in 8 × 8
## tiles (1997's random order; ours in [constant TREASURE_SECONDS]).
func _treasure_page(card_name: String) -> void:
	var was := TileReveal.picture_of(self) if TileReveal.wanted() else null
	var stage := view.show_page("dungeon_treasure")
	stage.card(card_name, FOUND_CARD_AT, CARD_WIDE, "FoundCard")
	stage.words(DungeonBoard.FOUND_CARD, EncounterStage.centred(FOUND_WORDS_AT, Vector2(240, 24)), 17,
		DungeonView.BROWN if stage.has_ground() else PaneStyle.GOLD, "FoundWords")
	if was != null:
		var cover := TileReveal.cover(stage, Rect2(Vector2.ZERO, DungeonView.PAGE * _factor), TREASURE_TILES,
			TREASURE_SECONDS)
		if cover != null:
			cover.take_screen(was)
			# A click puts the page away only once the card has come in (h1-1).
			_guard_until = maxi(_guard_until, Time.get_ticks_msec() + int(TREASURE_SECONDS * 1000.0))


func _ask_swap() -> void:
	step = "swap_ask"
	_then = Callable()
	_show_box([BAG_FULL], BESIDE_CARD)
	offer([["swap", SWAP, true], ["keep", KEEP, true]])


## THE SWAP [ours, the owner's D12]: the deck builder over the world, the
## pane hidden; a card left gives the found one ([method
## DungeonBoard.treasure_swap]), closed with none the question again.
func _open_swap() -> void:
	step = "swapping"
	var builder := TreasureSwapBuilder.new()
	builder.name = "TreasureSwap"
	builder.player = player
	builder.found_card = _found
	_builder = builder
	sound.pause_for_duel()
	visible = false
	_host().add_child(builder)
	builder.swapped.connect(_swapped, CONNECT_DEFERRED | CONNECT_ONE_SHOT)
	builder.closed.connect(_swap_closed, CONNECT_DEFERRED | CONNECT_ONE_SHOT)
	builder.exit_requested.connect(_quit_inside, CONNECT_DEFERRED | CONNECT_ONE_SHOT)


func _swapped(give_up: int) -> void:
	_drop_builder()
	var got := board.treasure_swap(player, give_up)
	if got.is_empty():
		_ask_swap()
		return
	_refresh()
	box([SWAPPED % [String(got["left"]), String(got["card"])]], _go_on, BESIDE_CARD)


func _swap_closed() -> void:
	_drop_builder()
	if step == "swapping":
		_ask_swap()


func _drop_builder() -> void:
	if is_instance_valid(_builder):
		_builder.queue_free()
	_builder = null
	visible = true
	sound.resume()


## The game closed from the swap's builder: nothing saved inside (the save
## at the door stands, as the window's own close).
func _quit_inside() -> void:
	if screen != null and screen.has_method("_end_process"):
		screen.call("_end_process")
	elif is_inside_tree():
		get_tree().quit()


func _keep_found() -> void:
	var got := board.treasure_declined(player)
	box([STAYS % String(got.get("card", _found))], _go_on, BESIDE_CARD)


# ------------------------------------------------------------ the rooms --

## A ROOM'S CREATURE OR THE CASTLE'S WIZARD: the set-up and the stake, then
## what is at stake ([RoomDuelPane]) over the world.
func _room() -> void:
	var duel := DungeonDuels.setup_room(player, board.run)
	if duel.is_empty():
		board.room_done(player, DungeonBoard.CLEARED)
		_go_on()
		return
	if not DungeonDuels.draw_stake(player, duel):
		# Nothing in the deck in use to stake at all: the game is over.
		board.room_done(player, DungeonBoard.GAME_OVER)
		view.stand()
		_end_visit()
		return
	_duel_setup = duel
	step = "room"
	_then = Callable()
	offer([])
	sound.play(DungeonDuels.SOUND)
	var pane := RoomDuelPane.make(player, board.run, duel)
	pane.k = k
	_show_over(pane)
	pane.card_read.connect(func(card_name: String) -> void: card_read.emit(card_name))
	pane.chosen.connect(_room_chosen, CONNECT_DEFERRED | CONNECT_ONE_SHOT)


func _room_chosen(_what: String) -> void:
	_drop_over()
	_start_duel()


## THE DUEL OVER THE WORLD ([WorldDuels]): the bed paused, the pane hidden.
func _start_duel() -> void:
	step = "duel"
	visible = false
	sound.pause_for_duel()
	var row := int(_duel_setup.get("row", 0))
	var config := DungeonDuels.duel_config(player, board.run, _duel_setup)
	_duel = WorldDuels.host(_host(), config, CreatureBook.name_of(row), MENU % board.title(),
		MENU_OVER % board.title())
	_duel.ended.connect(_after_duel, CONNECT_ONE_SHOT)
	_duel.abandoned.connect(_abandoned, CONNECT_ONE_SHOT)


## The duel host while the duel is up (a test plays it through).
func duel_host() -> WorldDuels:
	return _duel if is_instance_valid(_duel) else null


## THE DUEL OVER ([param report]): settled once, told to the board, shown.
func _after_duel(report: DuelReport) -> void:
	var conceded := _duel != null and _duel.conceded
	_duel = null
	var out := DungeonDuels.settle(player, board.run, _duel_setup, report, conceded)
	var outcome := String(out["outcome"])
	board.room_done(player, outcome)
	visible = true
	_refresh()
	# "Return to main menu" taken once the duel was over (part C stage C3,
	# h1-2): its result shown, then the visit ends — saved on the way out —
	# and the world leaves for the title; the hero walked on before.
	var leaving := _leaving()
	match outcome:
		DungeonBoard.CLEARED:
			sound.resume()
			var won := String(out.get("journal", "")) + "."
			if leaving:
				box([won], _end_visit)
			else:
				view.say(won)
				_go_on()
		DungeonBoard.AGAIN:
			sound.resume()
			var drawn := DRAWN % CreatureBook.called(int(out.get("row", 0)))
			if leaving:
				box([drawn], _end_visit)
			else:
				view.say(drawn)
				_back()
		DungeonBoard.BEATEN:
			view.stand()
			_castle_won()
		_:
			# A room lost, or the wizard's duel: the cards lost, then out.
			view.stand()
			_lost = out.get("lost", [])
			_lost_shown = 0
			_next_lost()


## Whether the world screen leaves for the title once its panes are done
## ([method WorldScreen.leaving_after_panes]: a room duel's "Return to main
## menu" taken after it was over).
func _leaving() -> bool:
	return screen != null and screen.has_method("leaving_after_panes") and bool(screen.call("leaving_after_panes"))


## The player left the duel for the main menu: nothing settled, nothing
## saved; the world screen goes ([WorldDuels]).
func _abandoned() -> void:
	_done = true
	step = "done"
	sound.stop()


## "LOST THIS CARD" (dE:879–893): `lose_card`, the card staked and its
## caption on `card_banner`, silent; a card at a time, then out.
func _next_lost() -> void:
	if _lost_shown >= _lost.size():
		view.hide_page()
		_end_visit()
		return
	step = "lost"
	var card_name := String(_lost[_lost_shown])
	_lost_shown += 1
	var stage := view.show_page("lose_card")
	stage.card(card_name, LOST_CARD_AT, LOST_CARD_WIDE, "LostCard")
	var font := GameSkin.font("font_title")
	var width := 120.0
	if font != null:
		width = font.get_string_size(DungeonDuels.LOST_CARD, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 20.0
	var banner := Rect2(LOST_CARD_AT.x + LOST_CARD_WIDE / 2.0 - width / 2.0, LOST_CARD_AT.y - 24.0, width, 20.0)
	stage.piece("card_banner", BANNER, banner, "LostBanner")
	stage.words(DungeonDuels.LOST_CARD, banner, 15, Color.WHITE, "LostWords")
	_then = _next_lost
	offer([["go", GO_ON, true]])


## THE CASTLE'S WIZARD BEATEN: [method CastleWin.beat] once — before any
## save —, then his pane ([CastleWinPane]) over the world; done, out.
func _castle_won() -> void:
	step = "won"
	sound.stop()
	_record = CastleWin.beat(player, board.index)
	var pane := CastleWinPane.make(player, _record)
	pane.k = k
	_show_over(pane)
	pane.card_read.connect(func(card_name: String) -> void: card_read.emit(card_name))
	pane.finished.connect(_castle_done, CONNECT_DEFERRED | CONNECT_ONE_SHOT)


func _castle_done(picked: Array[String]) -> void:
	_drop_over()
	_end_visit({"castle_win": _record, "all_five": bool(_record.get("all_five", false)), "picked": picked})


## [param pane] over the world, this one hidden under it.
func _show_over(pane: Control) -> void:
	_drop_over()
	_over_pane = pane
	visible = false
	_host().add_child(pane)
	PaneStyle.centre(pane)


func _drop_over() -> void:
	if is_instance_valid(_over_pane):
		_over_pane.queue_free()
	_over_pane = null


## The pane over the world now (the room's, the castle's), or null.
func over_pane() -> Control:
	return _over_pane if is_instance_valid(_over_pane) and not _over_pane.is_queued_for_deletion() else null


func _host() -> Node:
	return screen if screen != null else get_parent()


# -------------------------------------------------------------- leaving --

## "LEAVE?" [ours, the owner's board extras] — the exit stepped onto or
## clicked, Escape, Leave: Stay or Leave.
func ask_leave() -> void:
	if step != "idle" or _done:
		return
	step = "leave"
	_then = Callable()
	_queue.clear()
	var lines: Array[String] = [LEAVE_ASK % board.title()]
	if not board.castle:
		lines.append(LEAVE_MOVES if _holds_cards() else LEAVE_GONE)
	elif player.difficulty == DungeonDoors.RETALIATING \
			and not AdventurePlayer.COLORS[clampi(board.index, 0, 4)] in player.defeated_wizards \
			and not Sieges.calm(player):
		# No warning where no siege can begin ([method Sieges.start]): the
		# Embark's Sieges "None", a world at peace (the 0.50.66 bug campaign,
		# h3-1).
		lines.append(LEAVE_SIEGE % WorldNames.WIZARDS[clampi(board.index, 0, 4)])
	_show_box(lines, BOX_AT)
	offer([["stay", STAY, true], ["leave", LEAVE, true]])


## Whether the dungeon still holds a card ([method WorldClues.holds_cards]):
## left, it moves; with none, it is gone ([constant LEAVE_GONE]).
func _holds_cards() -> bool:
	var world := player.world if player != null else null
	if world == null or board == null or board.index < 0 or board.index >= world.encounters.size():
		return true
	return WorldClues.holds_cards(world.encounters[board.index])


## THE VISIT OVER, whatever the way out ([method DungeonBoard.close]): a
## castle's booted words once, then [signal finished].
func _end_visit(extra := {}) -> void:
	if _done:
		return
	_queue.clear()
	result = board.close(player)
	result.merge(extra, true)
	visible = true
	var words: Array = result.get("words", [])
	if not words.is_empty() and not bool(result.get("game_over", false)):
		sound.play(DungeonDuels.BOOTED_SOUND)
		var lines: Array[String] = []
		for line in words:
			lines.append_array(CreatureMeeting.lines_of(String(line)))
		box(lines, _finish, BOOTED_AT)
		step = "booted"
		return
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	step = "done"
	_hide_box()
	sound.stop()
	_drop_over()
	WorldDuels.world_music(self)
	if result.is_empty() and board != null:
		result = board.close(player)
	finished.emit(result)


## Whether the visit is over.
func done() -> bool:
	return _done


# ------------------------------------------------------------- the boxes --

## A BOX OF WORDS over the page ([param lines]), at page point [param at],
## a card under them ([param card_name]) — and Continue, which does
## [param then].
func box(lines: Array, then: Callable, at := BOX_AT, card_name := "") -> void:
	step = "box"
	_then = then
	_show_box(lines, at, [], card_name)
	offer([["go", GO_ON, true]])


func _show_box(lines: Array, at: Vector2, answers: Array = [], card_name := "") -> void:
	_hide_box()
	var face := PaneStyle.glass(12.0)
	_box = PanelContainer.new()
	_box.name = "Box"
	_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_box.add_theme_stylebox_override("panel", face)
	_box.set_meta("at", at)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(8 * k))
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(column)
	var width := minf(view.size.x - 40.0, maxf(260.0, view.size.x * (0.5 if at == BESIDE_CARD else 0.66)))
	_box_words = PaneStyle.wrapped("\n".join(PackedStringArray(lines)), int(17 * k), width - 28.0)
	_box_words.name = "BoxWords"
	_box_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_box_words)
	if card_name != "" and CardRegistry.has_card(card_name):
		var holder := CenterContainer.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shown := CardPreview.new()
		shown.name = "BoxCard"
		shown.docked = true
		shown.mouse_filter = Control.MOUSE_FILTER_STOP
		shown.show_card(CardInstance.new(CardRegistry.get_card(card_name), -1, 0))
		var wide := 96.0 * clampf(_factor, 0.8, 1.25)
		var fit := wide / CardPreview.SIZE.x
		shown.scale = Vector2(fit, fit)
		shown.gui_input.connect(func(input: InputEvent) -> void:
			if PaneStyle.right_click(input):
				card_read.emit(card_name))
		var spot := Control.new()
		spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spot.custom_minimum_size = CardPreview.SIZE * fit
		spot.add_child(shown)
		holder.add_child(spot)
		column.add_child(holder)
	_box_answers = HFlowContainer.new()
	_box_answers.name = "BoxAnswers"
	_box_answers.alignment = FlowContainer.ALIGNMENT_CENTER
	_box_answers.add_theme_constant_override("h_separation", int(8 * k))
	_box_answers.add_theme_constant_override("v_separation", int(6 * k))
	_box_answers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box_answers.custom_minimum_size.x = width - 28.0
	_box_answers.visible = not answers.is_empty()
	for action in answers:
		_box_answers.add_child(_button(String(action[1]), String(action[0]), bool(action[2])))
	column.add_child(_box_answers)
	view.add_child(_box)
	_place_box.call_deferred()


## The box kept centred on its page point and inside the page.
func _place_box() -> void:
	if not is_instance_valid(_box):
		return
	_box.size = _box.get_combined_minimum_size()
	var at: Vector2 = _box.get_meta("at", BOX_AT)
	var where := at * _factor - _box.size / 2.0
	where.x = clampf(where.x, 8.0, maxf(8.0, view.size.x - _box.size.x - 8.0))
	where.y = clampf(where.y, 8.0, maxf(8.0, view.size.y - _box.size.y - 8.0))
	_box.position = where


func _hide_box() -> void:
	if is_instance_valid(_box):
		PaneStyle.drop(_box)
	_box = null
	_box_words = null
	_box_answers = null


## The words in the box now ("" none).
func box_words() -> String:
	return _box_words.text if is_instance_valid(_box_words) else ""


## The answers offered in the box (their ids).
func answer_ids() -> Array[String]:
	var out: Array[String] = []
	if is_instance_valid(_box_answers):
		for child in _box_answers.get_children():
			if not child.is_queued_for_deletion():
				out.append(String(child.name).trim_prefix("Choice_"))
	return out


# ------------------------------------------------------------- choices --

## The choices now: [param actions], each `[id, words, ready]`.
func offer(actions: Array) -> void:
	_guard_until = maxi(_guard_until, Time.get_ticks_msec() + READ_GUARD_MS)
	PaneStyle.drop_children(_choices)
	for action in actions:
		_choices.add_child(_button(String(action[1]), String(action[0]), bool(action[2])))


func _button(words: String, action: String, ready := true) -> Button:
	var choice := PaneStyle.button(words, "Choice_" + action, k)
	choice.disabled = not ready
	choice.pressed.connect(func() -> void: WorldSoundscape.play_from(self, "sfx_button"))
	choice.pressed.connect(choose.bind(action))
	# A double click's second press is no choice (part B's guard, q2-2).
	choice.gui_input.connect(func(input: InputEvent) -> void:
		var press := input as InputEventMouseButton
		if press != null and press.double_click:
			choice.accept_event())
	return choice


func choice_ids() -> Array[String]:
	var out: Array[String] = []
	for child in _choices.get_children():
		if not child.is_queued_for_deletion():
			out.append(String(child.name).trim_prefix("Choice_"))
	return out


## WHAT A CHOICE DOES, at the step the pane stands at.
func choose(action: String) -> void:
	if _done:
		return
	if action.begins_with("answer_"):
		answer(int(action.trim_prefix("answer_")))
		return
	match action:
		"go":
			if _then.is_valid():
				var then := _then
				_then = Callable()
				then.call()
		"leave":
			if step == "idle":
				ask_leave()
			elif step == "leave":
				_hide_box()
				_end_visit()
		"stay":
			if step == "leave":
				_idle()
		"swap":
			if step == "swap_ask":
				_hide_box()
				_open_swap()
		"keep":
			if step == "swap_ask":
				_keep_found()


# ------------------------------------------------------- keys and mouse --

func _unhandled_input(input: InputEvent) -> void:
	if not visible or _done or not VisitPane.on_top(self):
		return
	var key := input as InputEventKey
	if step == "idle" and key != null and key.pressed and not key.ctrl_pressed and not key.alt_pressed \
			and not key.meta_pressed:
		var way := DungeonBoard.direction_of_key(key.keycode)
		if way != 0:
			get_viewport().set_input_as_handled()
			_press_held(key.keycode)
			move(way)
			return
	if key != null and key.pressed and not key.echo and _then.is_valid() \
			and key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and get_viewport().gui_get_focus_owner() == null:
		get_viewport().set_input_as_handled()
		choose("go")
		return
	var answers := _box_answers if step == "riddle" else null
	if answers != null and VisitPane.letter_choice(self, answers, input):
		get_viewport().set_input_as_handled()
		return
	if VisitPane.letter_choice(self, _choices, input):
		get_viewport().set_input_as_handled()
		return
	if input.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		escape()
	elif key != null and DungeonBoard.direction_of_key(key.keycode) != 0:
		# The board's keys never reach the world under it; on the first view
		# any of them goes on, as 1997's key did (dE:409).
		get_viewport().set_input_as_handled()
		if step == "first" and key.pressed and not key.echo:
			choose("go")
		elif step == "walking" and key.pressed and not key.echo and not key.ctrl_pressed \
				and not key.alt_pressed and not key.meta_pressed:
			# A second direction pressed while the hero walks: the newest held
			# wins after this step ([method _held_way], h1-3).
			_press_held(key.keycode)


## A press of the mouse puts out the choice a letter lit.
func _input(input: InputEvent) -> void:
	VisitPane.drop_letter(_choices, input)
	if is_instance_valid(_box_answers):
		VisitPane.drop_letter(_box_answers, input)


## ESCAPE, by the step: free on the board, "Leave?"; at "Leave?", Stay; at
## a box, on; at the riddle, the swap's question and before a duel, nothing.
func escape() -> void:
	match step:
		"idle":
			ask_leave()
		"leave":
			_idle()
		"first", "box", "lost", "booted":
			choose("go")
		_:
			pass


## A drag on the pane's glass moves it (the owner's movable panes), kept on
## the screen.
func _gui_input(input: InputEvent) -> void:
	var press := input as InputEventMouseButton
	if press != null and press.button_index == MOUSE_BUTTON_LEFT:
		if press.pressed:
			_drag = {"grip": press.global_position - global_position}
		else:
			_drag = {}
		accept_event()
		return
	var motion := input as InputEventMouseMotion
	if motion != null and not _drag.is_empty():
		var room := get_viewport_rect().size
		var to: Vector2 = motion.global_position - Vector2(_drag["grip"])
		to.x = clampf(to.x, 40.0 - size.x, room.x - 40.0)
		to.y = clampf(to.y, 0.0, room.y - 40.0)
		global_position = to
		accept_event()


func _exit_tree() -> void:
	if sound != null:
		sound.stop()
	_drop_over()
	if is_instance_valid(_builder):
		_builder.queue_free()
