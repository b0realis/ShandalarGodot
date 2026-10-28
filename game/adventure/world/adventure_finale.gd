class_name AdventureFinale
extends Control
## THE FINALE (part C, stage C2) — the screens from the fifth castle
## wizard's fall to the adventure's end, held over the world screen, which
## waits under them ([method WorldScreen.hold_for_duel]: the world, the
## panel and the arrows hidden, the clock still). 1997:
## `HandleDefeatedWizardCastle` from its test "are all five beaten" to the
## program's end (dungeonEncounter.c 1031–1105, the "dE" lines; retail
## database.c 1594–1758, step for step); the rules it drives are
## [FinalBattle]'s (the words, the score, the duel, the door, the result,
## the portal) and the [HallOfFame]'s. The owner's rulings of 2026-10-27
## (rounds P2, P3, P5, C1) shape it; every step's [ours] is marked below.
##
## THE STEPS, one at a time ([member step]):
##  - FIFTH — after a moment (1997's `DelayUiTicks(0x3C)`, about a second,
##    dE:1031), `5thwiz.pic` (`fifth_wizard`, Arzakon in his horned niche)
##    over the whole screen at the 1997 page's scale, @CASTLEWIN 6 centred
##    from page y 256 (dE:1032–1041), the fifth castle's tune going on (1997
##    stopped it only at the battle, dE:1060). Then ARZAKON'S QUESTION [ours,
##    the owner's Q-PORTAL "Choice at the moment"]: "Face me now" — or
##    "Return to Shandalar first": his portal opens near the map's middle
##    ([method FinalBattle.open_portal]; the guide arrows, the quest pane
##    and the journal point to it), the adventure is saved and the hero is
##    back on the world, to shop, trade, raid dungeons and tune the deck
##    first. Walked onto, the portal asks again ([method at_portal]). The
##    journal tells of the portal only then — never for "Face me now" (the
##    owner's ruling of 2026-10-28; [method FinalBattle.tell_portal]).
##  - DOOR — the same page taken up again at Arzakon's door after a lost
##    battle under "Reload allowed" (the owner's ruling of 2026-10-28,
##    "Fight or return"): "Arzakon awaits you at his door." — "Face him
##    again" (BANISH, the builder, the battle) or "Return to Shandalar
##    first": off the door, the portal open on the world for the hero to
##    buy cards, rebuild the deck and come back ([method
##    FinalBattle.leave_door]), the journal told where once. The battles
##    lost so far are said in the corner [ours].
##  - BANISH — @CASTLEWIN 7–8 under the first words from page y 350 (dE:
##    1042–1047): the years the battles so far banish Arzakon for, no lower
##    than 0 ([method FinalBattle.banish_lines]); a click, a key or Continue
##    goes on. Under "Reload allowed", back at the door after a loss, the
##    battles lost so far are said in the corner [ours].
##  - BUILDER — the adventure's deck builder as 1997 opened it here
##    (`DeckBuilderMain(…, 1, 1)`, dE:1049: the hero's own cards, cards may
##    move, nothing sold — [AdventureBuilder] as Conjurer's Will opens it);
##    Done, or its menu's "To the Final Battle" [ours], goes on; its Exit
##    game saves first as the world's does (the battle not begun).
##  - BATTLE — ARZAKON'S DOOR first ([method FinalBattle.door]: the hero
##    marked at the door, and the adventure SAVED, under both rules — 1997
##    saved nothing from the fifth castle on), then the duel over the world
##    ([WorldDuels], [method FinalBattle.duel_config]). Its questions are the
##    battle's own [ours]: under "One life" leaving for the main menu counts
##    as a loss (the owner's ruling of round C1: *"True ironman: closing
##    mid-battle ends the adventure as a lost final battle; no way to
##    retry."* — settled and saved at once as the duel is left); under
##    "Reload allowed" it leaves the adventure at the door, saved as the
##    battle began. Its result ([method FinalBattle.settle]) is SAVED at
##    once, and a win WRITTEN INTO THE HALL OF FAME ([method HallOfFame.add])
##    before anything is shown.
##  - A LOSS (a draw, a concession) — the quest has failed: 1997's
##    @QUESTFAILED end over `Uth-Arz.pic` ([method WorldScreen.show_end],
##    [method failed_parts]), then the title; under "Reload allowed" a line
##    under it says the adventure waits at the door [ours]. [ours: 1997
##    slip C3-1 — the result was never read: a loss played the win.]
##  - MOVIE — `Mtgend.avi`, converted by the importer to `win_movie.ogv`
##    (the owner's Q-MOVIE "Convert it"), centred on black at the page's
##    scale [ours: 1997 slip C3-5 — placed for a 560 × 420 box, dE:1068];
##    a click or a key ends it (as Statwin's player stopped on either);
##    absent, or a device that cannot play it, straight on (as 1997 without
##    `Statwin.dll`, dE:1847–1852).
##  - WIN — `Wingame.pic` (`win_game`) revealed in tiles of 3 page pixels
##    in a random order (1997's at 640 wide, dE:1079–1092; [TileReveal],
##    about a second and a half [ours: 1997's was the machine's speed]),
##    then @CASTLEWIN 9–10 from page y 129 with the final score (dE:1093)
##    — and `Wingame.wav` (`music_win_game`) ONCE [ours: the owner's "the
##    win tune plays once"; 1997 looped it to the program's end].
##  - STATS — 1997's stats menu at the end (`RunAdventureStatsMenu`,
##    dE:1100): the hero's record ([HeroStats]: Hero, Wizards, Journal) in
##    a rounded pane over the picture, the years told above it [ours], Done
##    (D, Escape).
##  - HALL — the [HallOfFamePane], the new line lit, and the last choice
##    (the owner: *"The win also gives you the choice to end or return to
##    roam Shandalar"*): "End" — the adventure saved as won, the title — or
##    "Return to Shandalar" ([method FinalBattle.roam]: the portal a
##    petrified monument, the journal's line, saved; the world at peace).
## A whole-screen step reads past on a click or a key only after a moment
## ([constant GUARD_MS], so the click that brought it does not also end
## it); the questions at FIFTH and DOOR and the last choice answer only to
## their buttons and first letters, never to Escape.
##
## A SAVE THAT COULD NOT BE WRITTEN IS SAID (part C stage C3, h3-3): the
## world's words after "Return to Shandalar first" and after the win's
## "Return to Shandalar" carry [constant WorldScreen.UNSAVED] with them
## (the world's own line under them was overwritten at once); the saves
## made while the world is hidden say it on what shows next — the
## battle's menu question when the door's save failed, the quest-failed
## end when the result's did (its "waits at the door" only when a save at
## the door or after it holds), the end taken up again when its save did.
## A WON BATTLE LEFT FOR THE MAIN MENU (its End of Duel window up: the
## result stands, and the world would leave once its panes are done) goes
## through the win's pages to the last choice all the same, and that
## choice decides: End, the title; Return to Shandalar, the hero walks on
## (h3-1 — the world's pending leave taken back, [method
## WorldScreen.stay_after_panes]).
##
## TAKEN UP AGAIN ([method after_load], the world's load calls it): "One
## life" and the battle begun or lost — the quest-failed end, saved
## ([method FinalBattle.on_load]); a failed adventure — its end, never the
## world; at the door under "Reload allowed" — DOOR, fight or return; all
## five beaten with no portal yet (the game left at the question) — the
## question again; a WON adventure — the Hall of Fame with its last choice
## again, End or Return to Shandalar (the owner's ruling of 2026-10-28,
## "Ask End or Return again"; the roaming line still written once).
##
## THE PORTAL ON THE WORLD ([method at_portal]) [ours]: walked onto while
## open, its pane over the world — Arzakon's niche, "Beyond the portal,
## Arzakon waits." — "Not yet." / "Enter the portal." (BANISH, the builder,
## the battle); petrified after the win, the monument's own pane tells the
## years he is banished for. [method place_at] names it under the pointer.

## The finale is over: [param outcome] [constant RETURNED] (the hero back on
## the world, the portal open), [constant ROAMING] (walking on after the
## win), [constant ENDED] (the win's End: to the title), [constant FAILED]
## (the quest failed: the end screen is the world's), [constant LEFT] (the
## battle left for the main menu).
signal finished(outcome: String)
## The step shown changed to [param now].
signal step_changed(now: String)

# --------------------------------------------------------------- the steps --
const FIFTH := "fifth"
const DOOR := "door"
const BANISH := "banish"
const BUILDER := "builder"
const BATTLE := "battle"
const MOVIE := "movie"
const WIN := "win"
const STATS := "stats"
const HALL := "hall"
const DONE := "done"

# ------------------------------------------------------------- the outcomes --
const RETURNED := "returned"
const ROAMING := "roam"
const ENDED := "end"
const FAILED := "failed"
const LEFT := "left"

# --------------------------------------------------------------- the page --
## The 1997 page the pictures and the words were laid out on.
const PAGE := Vector2(640, 480)
## The 1997 font, 16 px on the 640 × 480 page (as [AdventureEndScreen]).
const FONT_SIZE := 16
## Where the words stand on the page (dE:1037, 1045, 1095).
const FIFTH_AT := 256.0
const BANISH_AT := 350.0
const WIN_AT := 129.0
## The moment before the fifth wizard's picture (1997's `DelayUiTicks(0x3C)`,
## 30 ticks of 33 ms).
const PAUSE := 1.0
## How long a whole-screen step ignores a click or a key, in milliseconds.
const GUARD_MS := AdventureEndScreen.GUARD_MS
## The movie's frame (Mtgend.avi, 576 × 340), on the page's scale; its file
## in the skin; how long a device may take to show its first frame before
## the win goes on without it, and the longest it may run.
const MOVIE_FRAME := Vector2(576, 340)
const MOVIE_KEY := "win_movie"
const MOVIE_START := 1.5
const MOVIE_MOST := 25.0
## The win's reveal: tiles of 3 page pixels (1997 at 640 wide) over this
## long [ours].
const REVEAL_TILE := 3.0
const REVEAL_SECONDS := 1.5
## The words' ink and their shadow (as [AdventureEndScreen]'s).
const INK := AdventureEndScreen.INK
const SHADOW := AdventureEndScreen.SHADOW
## The free room round the corner's button.
const CORNER := 24.0

# -------------------------------------------------------- the words [ours] --
## Over Arzakon's question (the owner's "Arzakon appears and asks").
const ARZAKON_APPEARS := "Arzakon appears before you."
## Back at his door after a lost battle (the owner's "Fight or return").
const ARZAKON_AWAITS := "Arzakon awaits you at his door."
const FACE_AGAIN := "Face him again"
const CONTINUE := "Continue"
## Back at the door under "Reload allowed": the battles lost.
const LOST_BEFORE := "Final Battles lost: %d"
## The deck builder before the battle: its menu's way on, and its line.
const TO_BATTLE := "To the Final Battle"
const BUILDER_SAYS := "Done takes this deck to the Final Battle."
## The battle's two doors (the duel's Concede and Return to main menu).
const LEAVE_ONE_LIFE := "Concede the Final Battle to Arzakon? It counts as a loss: your quest fails and, with One life, the adventure ends for good."
const LEAVE_RELOAD := "Concede the Final Battle to Arzakon? It counts as a loss: your quest fails, and your adventure waits at his door."
const MENU_ONE_LIFE := "Return to the main menu? With One life, leaving the Final Battle counts as a loss: your quest fails and the adventure ends for good."
const MENU_RELOAD := "Return to the main menu? The Final Battle is left unfinished: your adventure waits at Arzakon's door, saved as the battle began."
## The same when the save at the door could not be written (h3-3).
const MENU_RELOAD_UNSAVED := "Return to the main menu? The Final Battle is left unfinished, and the adventure could not be saved at Arzakon's door: it goes back to where it was last saved."
## The menu's question once the battle is over (its result stands, saved
## at once): what it brought comes first — the win's pages and their last
## choice, or the end (h3-1).
const MENU_OVER_FINAL := "Return to the main menu? The Final Battle is over and its result stands: what it brought comes first."
## The record after the win: its title and the years told.
const RECORD_TITLE := "The record of %s"
const YEARS_LINE := "Arzakon is banished for %d years: %d for your battles, %d for the %d lives he lost."
const RECORD_DONE := "Done"
## The portal walked onto, open.
const PORTAL_LINES: Array[String] = ["Beyond the portal, Arzakon waits.", "Are you ready to face him?"]
const NOT_YET := "Not yet."
const ENTER := "Enter the portal."
## The monument walked onto, after the win.
const MONUMENT_LINES: Array[String] = ["Here Arzakon's portal turned to stone.",
	"%s banished him from Shandalar for %d years."]
const LEAVE := "Leave"
## The pointer's words over the portal ([method place_at]).
const PORTAL_KIND := "Enter when ready"
const MONUMENT_KIND := "Monument"

## Tests: 1 plays the movie headless too, 0 never, -1 by the rule (a screen
## to play it on).
static var movie_forced := -1

## The world held, and its adventure.
var world: WorldScreen
var player: AdventurePlayer
## The step shown ([constant FIFTH] … [constant DONE]).
var step := ""
## The size factor of the choices: 1, or [constant WorldHud.BIG].
var k := 1.0
## What the battle left ([method FinalBattle.settle]); `{}` before it.
var settled := {}
## The won adventure's place in the Hall of Fame (1 the best; 0 not written).
var hall_place := 0
## Whether the last save could not be written ([method _save], h3-3); and
## whether the save at Arzakon's door was.
var unsaved := false
var door_saved := false
## The battle's duel while it is up; the builder while it is open.
var duel: WorldDuels
var builder: AdventureBuilder
## The first step ([method _begin]).
var _start := FIFTH
var _shown_at := 0
var _guard_ms := GUARD_MS
var _over := false
var _scale := 1.0
var _ground: ColorRect
var _page: Control
var _art: TextureRect
var _words: Label
var _below: Label
var _ask: VBoxContainer
var _asks: Label
var _choices: HBoxContainer
var _note: Label
var _corner: Button
var _movie: VideoStreamPlayer
var _movie_seen := false
var _reveal: TileReveal
var _pane: Control
var _hall: HallOfFamePane
var _tune: AudioStreamPlayer
var _castle_tune: MusicPlayer


## THE PORTAL'S PANE, a place's pane ([VisitPane]) whose "Enter the portal."
## goes in ([method VisitPane.choose] knows only a castle's and a
## dungeon's doors).
class PortalPane extends VisitPane:
	func choose(action: String) -> void:
		if action == "enter":
			left.emit("enter")
			return
		super.choose(action)


## THE DECK BUILDER BEFORE THE BATTLE: the adventure's, cards moving and
## nothing sold, its menu's way back to the world made the way on to the
## battle, its line saying so.
class FinalBuilder extends AdventureBuilder:
	func _ready() -> void:
		super._ready()
		_say(BUILDER_SAYS)

	func _menu_entries() -> Array[String]:
		return [MENU_BACK, TO_BATTLE, "Exit game"]

	func _run_menu_entry(label: String) -> void:
		if label == TO_BATTLE:
			_close_deck_menu()
			_exit()
			return
		super._run_menu_entry(label)


# ------------------------------------------------------- the entry points --

## THE FIFTH WIZARD HAS FALLEN (the castle win's pane closed with all five
## beaten — [method CastleWin.beat]'s record `all_five` — and the board
## gone): the finale over [param world] from its first step, Arzakon's
## question.
static func after_fifth_wizard(world: WorldScreen, player: AdventurePlayer) -> void:
	_begin(world, player, FIFTH)


## THE HERO STEPS ONTO ARZAKON'S PORTAL ([method FinalBattle.portal_at]):
## its pane over [param world] — open, the question whose "Enter the
## portal." begins the battle's way in (BANISH); petrified after the win,
## the monument's words. The pane (a [VisitPane], in the world), or null
## when no portal of either kind stands for [param player].
static func at_portal(world: WorldScreen, player: AdventurePlayer) -> VisitPane:
	if world == null or player == null or showing(world) != null:
		return null
	var place := portal_place(player)
	if place.is_empty():
		return null
	var pane := PortalPane.new()
	pane.player = player
	pane.place = place
	pane.k = _k_of(world)
	world.add_child(pane)
	PaneStyle.centre(pane)
	pane.left.connect(func(then: String) -> void:
		if is_instance_valid(pane):
			pane.queue_free()
		if then == "enter" and is_instance_valid(world) and FinalBattle.portal_open(player):
			_begin(world, player, BANISH), CONNECT_DEFERRED | CONNECT_ONE_SHOT)
	return pane


## AN ADVENTURE TAKEN UP AGAIN, its world made (the class's notes): true when
## the finale or the end took the screen — the world does not run; false
## for an adventure that walks on as it is.
static func after_load(world: WorldScreen, player: AdventurePlayer) -> bool:
	if world == null or player == null:
		return false
	var saved := true
	if FinalBattle.on_load(player):
		# "One life", the battle begun or lost: the quest failed, saved so.
		saved = world.autosave() != ""
	match player.ended:
		AdventurePlayer.ENDED_FAILED:
			# A save that could not be written said on the end (h3-3): the
			# world's line beside the panel lies under it.
			world.show_end(failed_parts(false) + ([] if saved else [WorldScreen.UNSAVED]))
			return true
		AdventurePlayer.ENDED_WON:
			# Taken up again, a won adventure asks End or Return again (the
			# owner's ruling of 2026-10-28): the Hall and its last choice.
			_begin(world, player, HALL)
			return true
	if not FinalBattle.all_beaten(player):
		return false
	if player.at_door:
		_begin(world, player, DOOR)
		return true
	if player.portal.is_empty():
		_begin(world, player, FIFTH)
		return true
	return false


## The finale over [param world], or null.
static func showing(world: Node) -> AdventureFinale:
	if world == null:
		return null
	for child in world.get_children():
		if child is AdventureFinale and not (child as Node).is_queued_for_deletion():
			return child
	return null


## THE PORTAL'S PANE for [param player] as [VisitPane] describes a place:
## open, the question; petrified with the adventure won, the monument;
## `{}` for none.
static func portal_place(player: AdventurePlayer) -> Dictionary:
	if player == null or player.portal.is_empty():
		return {}
	var where := FinalBattle.portal_where(player)
	var subtitle := where.left(1).to_upper() + where.substr(1)
	if FinalBattle.portal_open(player):
		return {"kind": "portal", "slot": -1, "name": FinalBattle.PORTAL_NAME, "subtitle": subtitle,
			"picture": "fifth_wizard", "lines": PORTAL_LINES.duplicate(),
			"actions": [["leave", NOT_YET, true], ["enter", ENTER, true]]}
	if String(player.portal.get("state", "")) == FinalBattle.PORTAL_PETRIFIED \
			and player.ended == AdventurePlayer.ENDED_WON:
		return {"kind": "portal", "slot": -1, "name": FinalBattle.MONUMENT_NAME, "subtitle": subtitle,
			"picture": "win_game",
			"lines": [MONUMENT_LINES[0], MONUMENT_LINES[1] % [player.name, int(player.final.get("score", 0))]],
			"actions": [["leave", LEAVE, true]]}
	return {}


## The portal under the pointer at [param tile] ([method WorldScreen.place_at]):
## `{kind, name, subtitle}` — kind "portal" while open, "monument" once
## petrified (each its own pointer, [constant WorldCursors.FOR_PLACE]) — or
## `{}`.
static func place_at(player: AdventurePlayer, tile: Vector2i) -> Dictionary:
	if not FinalBattle.portal_at(player, tile):
		return {}
	var name := FinalBattle.portal_name(player)
	if name == "":
		return {}
	var open := FinalBattle.portal_open(player)
	return {"kind": "portal" if open else "monument", "name": name,
		"subtitle": PORTAL_KIND if open else MONUMENT_KIND}


## @QUESTFAILED 1, 4 and 5 as the end screen's parts ([method
## WorldScreen.show_end]); with [param reload] the line that the adventure
## waits at the door ([constant FinalBattle.RELOAD_HINT]).
static func failed_parts(reload: bool) -> Array:
	var out: Array = [FinalBattle.FAILED.strip_edges(), FinalBattle.WORN_DOWN.strip_edges(),
		FinalBattle.SUFFER.strip_edges()]
	if reload:
		out.append(FinalBattle.RELOAD_HINT)
	return out


## Whether the movie plays: a screen to play it on ([member movie_forced]
## for tests).
static func movie_wanted() -> bool:
	if movie_forced >= 0:
		return movie_forced == 1
	return DisplayServer.get_name() != "headless"


## The win's movie in the skin worn (`win_movie.ogv`, [method
## GameSkin.movie]), null for none.
static func movie() -> VideoStream:
	return GameSkin.movie(MOVIE_KEY)


static func _k_of(world: WorldScreen) -> float:
	return WorldHud.BIG if world != null and world.hud != null and world.hud.big else 1.0


## The finale over [param world] from step [param first] — the one already
## there when one is.
static func _begin(world: WorldScreen, player: AdventurePlayer, first: String) -> AdventureFinale:
	var there := showing(world)
	if there != null:
		return there
	var finale := AdventureFinale.new()
	finale.world = world
	finale.player = player
	finale._start = first
	world.add_child(finale)
	return finale


# ------------------------------------------------------------- the screen --

func _ready() -> void:
	name = "AdventureFinale"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	k = _k_of(world)
	_hold(true)
	if world != null and world.walk != null:
		world.walk.stop()
	_ground = ColorRect.new()
	_ground.name = "Ground"
	_ground.color = Color.BLACK
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ground)
	_ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page = Control.new()
	_page.name = "Page"
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_page)
	_art = TextureRect.new()
	_art.name = "Art"
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(_art)
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_words = _lettering("Words")
	_page.add_child(_words)
	_below = _lettering("Below")
	_page.add_child(_below)
	_ask = VBoxContainer.new()
	_ask.name = "Ask"
	_ask.add_theme_constant_override("separation", int(10 * k))
	_ask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(_ask)
	_asks = PaneStyle.label(ARZAKON_APPEARS, 18, PaneStyle.GOLD)
	_asks.name = "Appears"
	_asks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_asks.add_theme_color_override("font_outline_color", SHADOW)
	_asks.add_theme_constant_override("outline_size", 4)
	_ask.add_child(_asks)
	_choices = HBoxContainer.new()
	_choices.name = "Choices"
	_choices.alignment = BoxContainer.ALIGNMENT_CENTER
	_choices.add_theme_constant_override("separation", int(14 * k))
	_choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ask.add_child(_choices)
	_note = PaneStyle.label("", 16, PaneStyle.DIM)
	_note.name = "Note"
	add_child(_note)
	_corner = PaneStyle.button(CONTINUE, "Continue", k, 18)
	_corner.pressed.connect(_on_continue)
	add_child(_corner)
	resized.connect(_layout)
	_show(_start)
	_layout()


## THE PAGE AT THE SCREEN'S SCALE: the 1997 page as large as the screen
## holds it, centred (the pictures stretched to it as 1997 stretched them,
## dE:1034, 1083); the words at their page lines, in the 1997 size scaled
## up to twice (as [AdventureEndScreen]'s); the corner's button and note
## in the screen's corners; the movie centred.
func _layout() -> void:
	if _page == null or size.x <= 0.0 or size.y <= 0.0:
		return
	_scale = minf(size.x / PAGE.x, size.y / PAGE.y)
	_page.size = PAGE * _scale
	_page.position = ((size - _page.size) / 2.0).round()
	var font := maxi(int(FONT_SIZE * clampf(_scale, 1.0, 2.0)), FONT_SIZE)
	for label: Label in [_words, _below]:
		label.add_theme_font_size_override("font_size", font)
		label.size = Vector2(_page.size.x, 0)
	match step:
		WIN:
			_words.position = Vector2(0, WIN_AT * _scale)
		_:
			_words.position = Vector2(0, FIFTH_AT * _scale)
	_below.position = Vector2(0, BANISH_AT * _scale)
	_ask.position = Vector2(0, BANISH_AT * _scale)
	_ask.size = Vector2(_page.size.x, 0)
	_corner.reset_size()
	_corner.position = (size - _corner.size - Vector2(CORNER, CORNER)).round()
	_note.reset_size()
	_note.position = Vector2(CORNER, size.y - _note.size.y - CORNER).round()
	if _movie != null:
		_movie.size = MOVIE_FRAME * _scale
		_movie.position = ((size - _movie.size) / 2.0).round()


## A line of the page's words: 1997's title face, the end's ink, a shadow
## and an outline, centred across the page.
func _lettering(label_name: String) -> Label:
	var label := Label.new()
	label.name = label_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", INK)
	label.add_theme_color_override("font_shadow_color", SHADOW)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_color_override("font_outline_color", SHADOW)
	label.add_theme_constant_override("outline_size", 4)
	var face := GameSkin.font("font_title")
	if face != null:
		label.add_theme_font_override("font", face)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## The page's picture, by skin key ("" none): without the skin a plain black
## page, the words on it.
func _picture(key: String) -> void:
	_art.texture = GameSkin.texture(key) if key != "" else null


# --------------------------------------------------------------- the steps --

## Step [param now] shown.
func _show(now: String) -> void:
	if _over:
		return
	step = now
	_shown_at = Time.get_ticks_msec()
	_guard_ms = GUARD_MS
	_page.visible = true
	_ask.visible = false
	_corner.visible = false
	_note.text = ""
	_below.text = ""
	match now:
		FIFTH:
			_show_fifth()
		DOOR:
			_show_door()
		BANISH:
			_show_banish()
		BUILDER:
			_open_builder()
		BATTLE:
			_begin_battle()
		MOVIE:
			_play_movie()
		WIN:
			_show_win()
		STATS:
			_show_stats()
		HALL:
			_show_hall()
	_layout()
	step_changed.emit(now)


## FIFTH: the fifth wizard's picture and words after a moment, the castle's
## tune on, then Arzakon's question.
func _show_fifth() -> void:
	_ask_question(ARZAKON_APPEARS, [["face", FinalBattle.FACE_NOW], ["return", FinalBattle.RETURN_FIRST]])
	# The moment before it (dE:1031): the page comes up out of the dark, and
	# nothing is taken from it until it has.
	_guard_ms = int(PAUSE * 1000.0)
	if TileReveal.wanted():
		_page.modulate.a = 0.0
		var fade := create_tween()
		fade.tween_interval(PAUSE * 0.4)
		fade.tween_property(_page, "modulate:a", 1.0, PAUSE * 0.6)


## DOOR: the same page at Arzakon's door after a lost battle — fight or
## return — the battles lost said in the corner.
func _show_door() -> void:
	_ask_question(ARZAKON_AWAITS, [["face", FACE_AGAIN], ["return", FinalBattle.RETURN_FIRST]])
	if player.final_attempts > 0:
		_note.text = LOST_BEFORE % player.final_attempts


## A QUESTION ON THE FIFTH WIZARD'S PAGE: its picture and @CASTLEWIN 6,
## [param asking] over [param choices] (`[id, words]`, answered by [method
## choose]), the castle's tune on.
func _ask_question(asking: String, choices: Array) -> void:
	_picture("fifth_wizard")
	_words.text = "\n".join(FinalBattle.fifth_lines())
	_asks.text = asking
	PaneStyle.drop_children(_choices)
	for choice in choices:
		var button := PaneStyle.button(String(choice[1]), "Choice_" + String(choice[0]), k, 18)
		button.pressed.connect(choose.bind(String(choice[0])))
		_choices.add_child(button)
	_ask.visible = true
	_play_castle_tune()


## BANISH: the first words, and the years the battles so far banish Arzakon
## for under them; the battles lost before, back at the door.
func _show_banish() -> void:
	_page.modulate.a = 1.0
	_picture("fifth_wizard")
	_words.text = "\n".join(FinalBattle.fifth_lines())
	_below.text = "\n".join(FinalBattle.banish_lines(FinalBattle.score(player)))
	if player.final_attempts > 0:
		_note.text = LOST_BEFORE % player.final_attempts
	_corner.visible = true
	_play_castle_tune()


## ARZAKON'S QUESTION ANSWERED ([param what]: "face" or "return"), at the
## fifth wizard's fall or at his door, after its moment.
func choose(what: String) -> void:
	if not step in [FIFTH, DOOR] or not ready_for_input():
		return
	match what:
		"face":
			_show(BANISH)
		"return":
			return_first()


## RETURN TO SHANDALAR FIRST: the portal opens near the map's middle — or,
## back from the door, stays open and the hero leaves the door ([method
## FinalBattle.leave_door]) —, the journal told where (once), the adventure
## saved, the hero back on the world, told where it stands.
func return_first() -> void:
	if step == DOOR:
		FinalBattle.leave_door(player)
	else:
		FinalBattle.open_portal(player)
	_save()
	var said := saying(FinalBattle.OPENED_LOG % FinalBattle.portal_where(player))
	_finish(RETURNED)
	if world.hud != null:
		world.hud.say(said)


## THE ADVENTURE SAVED ([method WorldScreen.autosave]): whether it was, kept
## in [member unsaved] for the words that follow (h3-3).
func _save() -> bool:
	unsaved = world.autosave() == ""
	return not unsaved


## [param line] as the world says it after a save: with [constant
## WorldScreen.UNSAVED] after it when the save could not be written (h3-3:
## the world's own line said it, and this one took its place at once).
func saying(line: String) -> String:
	if not unsaved:
		return line
	return WorldScreen.UNSAVED if line == "" else "%s. %s" % [line.trim_suffix("."), WorldScreen.UNSAVED]


## A click, a key or Continue on a step that reads past (after its moment).
func go_on() -> void:
	if not ready_for_input():
		return
	match step:
		BANISH:
			_show(BUILDER)
		MOVIE:
			_movie_done()
		WIN:
			_show(STATS)


func _on_continue() -> void:
	go_on()


## Whether the step may be read past yet (a moment after it came).
func ready_for_input() -> bool:
	return Time.get_ticks_msec() - _shown_at >= _guard_ms


## BUILDER: the adventure's deck builder, the hero's own cards moving,
## nothing sold ([FinalBuilder]); no cards at all — straight on.
func _open_builder() -> void:
	_stop_castle_tune()
	_page.visible = false
	if player.cards.is_empty():
		_after_builder.call_deferred()
		return
	builder = FinalBuilder.new()
	builder.name = "DeckBuilder"
	builder.player = player
	builder.closed.connect(_after_builder, CONNECT_DEFERRED | CONNECT_ONE_SHOT)
	builder.exit_requested.connect(_exit_game)
	add_child(builder)


## The builder's Exit game (or the window's close): the decks written back
## by the builder, the adventure saved and the game ended as the world's
## Exit game does — the battle not begun.
func _exit_game() -> void:
	if is_instance_valid(world):
		world._save_and_end()


## The builder left: the battle.
func _after_builder() -> void:
	if is_instance_valid(builder):
		builder.queue_free()
	builder = null
	_show(BATTLE)


## BATTLE: at Arzakon's door — marked there and saved, under both rules —
## then the duel over the world, its doors' words the battle's own.
func _begin_battle() -> void:
	_page.visible = false
	if FinalBattle.door(player):
		door_saved = _save()
	var config := FinalBattle.duel_config(player)
	var one_life := player.life_rule == AdventurePlayer.LIFE_ONE
	var menu := MENU_ONE_LIFE if one_life else (MENU_RELOAD if door_saved else MENU_RELOAD_UNSAVED)
	duel = WorldDuels.host(world, config, FinalBattle.ARZAKON_NAME, menu, MENU_OVER_FINAL)
	if is_instance_valid(duel.duel):
		duel.duel.leave_question = LEAVE_ONE_LIFE if one_life else LEAVE_RELOAD
	duel.ended.connect(battle_over)
	duel.abandoned.connect(_battle_left)


## THE BATTLE OVER with [param report] ([signal WorldDuels.ended]; [param
## conceded] read off the host): settled, saved; a win written into the Hall
## of Fame, then the movie — the world's pending leave taken back, should
## the won battle have been left for the main menu (h3-1: the last choice
## decides); anything else the quest-failed end, saying so when the save
## could not be written (h3-3) — and that the adventure waits at the door
## only when a save at the door or after it holds.
func battle_over(report: DuelReport, conceded := false) -> void:
	if step != BATTLE or _over:
		return
	_hold(true)
	var gave_up := conceded or (is_instance_valid(duel) and duel.conceded)
	duel = null
	settled = FinalBattle.settle(player, report, gave_up)
	_save()
	if bool(settled["won"]):
		world.stay_after_panes()
		hall_place = HallOfFame.add(player)
		_show(MOVIE)
		return
	var parts := failed_parts(bool(settled["reload"]) and (door_saved or not unsaved))
	if unsaved:
		parts.append(WorldScreen.UNSAVED)
	_finish(FAILED, false)
	world.show_end(parts)


## THE BATTLE LEFT FOR THE MAIN MENU ([signal WorldDuels.abandoned]; the
## host leaves the world for the title after): under "One life" a lost
## final battle, settled and saved now; under "Reload allowed" the door's
## save stands.
func _battle_left() -> void:
	if _over:
		return
	if player.life_rule == AdventurePlayer.LIFE_ONE and player.ended == "":
		FinalBattle.settle(player, null, true)
		player.final["left"] = true
		world.autosave()
	duel = null
	_finish(LEFT, false)


# ------------------------------------------------------------- the win --

## MOVIE: the win's movie centred on black at the page's scale; none (no
## skin, not converted, no screen) — straight to the picture.
func _play_movie() -> void:
	_page.visible = false
	var stream := movie() if movie_wanted() else null
	if stream == null:
		_show.call_deferred(WIN)
		return
	_movie = VideoStreamPlayer.new()
	_movie.name = "Movie"
	_movie.stream = stream
	_movie.expand = true
	_movie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_movie.bus = GameAudio.MUSIC_BUS
	if not Settings.music_enabled():
		_movie.volume = 0.0
	_movie.finished.connect(_movie_done)
	add_child(_movie)
	move_child(_movie, _page.get_index() + 1)
	_movie.play()
	get_tree().create_timer(MOVIE_START).timeout.connect(_check_movie)
	get_tree().create_timer(MOVIE_MOST).timeout.connect(_movie_done)


## A moment in: a movie the device has not begun to show is skipped.
func _check_movie() -> void:
	if step != MOVIE or not is_instance_valid(_movie):
		return
	_movie_seen = _movie.is_playing() and _movie.get_video_texture() != null
	if not _movie_seen:
		_movie_done()


## The movie over (its end, a click or a key, its time run out): the picture.
func _movie_done() -> void:
	if step != MOVIE or _over:
		return
	if is_instance_valid(_movie):
		_movie.stop()
		_movie.queue_free()
	_movie = null
	_show(WIN)


## WIN: Wingame revealed tile by tile, its tune once, then the years.
func _show_win() -> void:
	_picture("win_game")
	_words.text = ""
	_play_win_tune()
	var lines := "\n".join(FinalBattle.win_lines(int(settled.get("score", 0))))
	_reveal = null
	if _art.texture != null and TileReveal.wanted():
		var tiles := Vector2i(int(ceil(PAGE.x / REVEAL_TILE)), int(ceil(PAGE.y / REVEAL_TILE)))
		_reveal = TileReveal.make(tiles, REVEAL_SECONDS, TileReveal.Order.RANDOM)
	if _reveal != null:
		_reveal.name = "WinReveal"
		_reveal.ground = Color.BLACK
		_page.add_child(_reveal)
		_page.move_child(_reveal, _art.get_index() + 1)
		_reveal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# The words after the picture, as 1997 drew them (dE:1093) — and the
		# page's moment begun again: the click or key that cut the reveal
		# short shows the words, it does not also read past them.
		_reveal.done.connect(func() -> void:
			if step == WIN:
				_words.text = lines
				_shown_at = Time.get_ticks_msec())
	else:
		_words.text = lines
	_corner.visible = true


## STATS: the hero's record in a pane over the picture, the years told.
func _show_stats() -> void:
	_words.text = ""
	if _reveal != null and is_instance_valid(_reveal):
		_reveal.finish()
	var pane := PanelContainer.new()
	pane.name = "Record"
	pane.mouse_filter = Control.MOUSE_FILTER_STOP
	pane.add_theme_stylebox_override("panel", PaneStyle.glass(16.0))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pane.add_child(column)
	var title := PaneStyle.title(RECORD_TITLE % player.name, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var years := PaneStyle.label(years_line(), 16, PaneStyle.GOLD)
	years.name = "Years"
	years.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(years)
	var stats := HeroStats.new()
	stats.player = player
	# The journal's "On the map" is not offered: the world's map waits
	# under the finale.
	stats.journal_map = false
	stats.done_pressed.connect(_after_stats)
	column.add_child(stats)
	var done := PaneStyle.button(RECORD_DONE, "RecordDone", k)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(_after_stats)
	column.add_child(done)
	_pane = pane
	add_child(pane)
	PaneStyle.centre(pane)


## The years told over the record: the final score, the battles' share
## (shown), the battle's, and the lives Arzakon lost.
func years_line() -> String:
	var start: Array = settled.get("lives_start", [0, 0])
	var end: Array = settled.get("lives_end", [0, 0])
	var lost := maxi(int(start[1]) - int(end[1]), 0)
	return YEARS_LINE % [int(settled.get("score", 0)), int(settled.get("shown", 0)),
		int(settled.get("years", 0)), lost]


func _after_stats() -> void:
	if step != STATS:
		return
	if is_instance_valid(_pane):
		_pane.queue_free()
	_pane = null
	_show(HALL)


## HALL: the Hall of Fame, the new line lit, and the last choice.
func _show_hall() -> void:
	# Over the win's picture — also when a won adventure is taken up again.
	_picture("win_game")
	_words.text = ""
	_hall = HallOfFamePane.open(self, k, player.adventure_id,
		[[ENDED, FinalBattle.WIN_END], [ROAMING, FinalBattle.WIN_ROAM]])
	_hall.chosen.connect(last_choice, CONNECT_DEFERRED)


## THE LAST CHOICE ([param what]): [constant ENDED] — the title, the
## adventure saved as won; [constant ROAMING] — the hero walks on in the
## world at peace, the portal a monument.
func last_choice(what: String) -> void:
	if step != HALL or _over:
		return
	match what:
		ENDED:
			if world.autosave() != "":
				# Saved as won: the title, the world never shown again.
				_finish(ENDED, false)
				world.leave_unsaved()
			else:
				# Not saved: the world's own way out asks first (Stay, or
				# Leave without saving), over the world let go.
				_finish(ENDED)
				world.leave()
		ROAMING:
			var line := FinalBattle.roam(player)
			_save()
			line = saying(line)
			_finish(ROAMING)
			if line != "" and world.hud != null:
				world.hud.say(line)


# ------------------------------------------------------------- the music --

## The fifth castle's tune, as 1997 kept it playing up to the battle
## (dE:1060); the world's bed and the place's tune at rest under it.
func _play_castle_tune() -> void:
	if not Settings.music_enabled() or (_castle_tune != null and _castle_tune.playing):
		return
	var castle := FinalBattle.fifth_castle(player)
	if castle < 0:
		return
	WorldDuels.world_music_off(self)
	if _castle_tune == null:
		_castle_tune = MusicPlayer.new()
		_castle_tune.name = "CastleTune"
		add_child(_castle_tune)
	_castle_tune.play_one(CastleWin.MUSIC % AdventurePlayer.COLORS[castle])


func _stop_castle_tune() -> void:
	if _castle_tune != null:
		_castle_tune.stop_music()


## `Wingame.wav` ONCE (the owner's "the win tune plays once").
func _play_win_tune() -> void:
	_stop_castle_tune()
	if not Settings.music_enabled() or DisplayServer.get_name() == "headless":
		return
	var stream := GameSkin.sound("music_win_game")
	if stream == null:
		return
	var once: AudioStream = stream.duplicate()
	if once is AudioStreamWAV:
		(once as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
	WorldDuels.world_music_off(self)
	_tune = AudioStreamPlayer.new()
	_tune.name = "WinTune"
	GameAudio.ensure_buses()
	_tune.bus = GameAudio.MUSIC_BUS
	_tune.stream = once
	add_child(_tune)
	_tune.play()


# ---------------------------------------------------------- the world held --

## The world held under the finale, or let go ([method
## WorldScreen.hold_for_duel]: the world, the panel and the arrows hidden,
## the clock still, nothing saved by the window's close); the place's tune
## at rest while it is held.
func _hold(on: bool) -> void:
	if not is_instance_valid(world) or not world.is_inside_tree():
		return
	world.hold_for_duel(on)
	if world.soundscape != null:
		world.soundscape.rest(on)


## THE FINALE OVER with [param outcome]: its music stopped, the world let go
## when [param release] (else the next screen holds it — the end, the
## title), [signal finished], freed.
func _finish(outcome: String, release := true) -> void:
	if _over:
		return
	_over = true
	step = DONE
	_stop_castle_tune()
	if _tune != null:
		_tune.stop()
	if is_instance_valid(_movie):
		_movie.stop()
	if release:
		_hold(false)
		WorldDuels.world_music(world)
	finished.emit(outcome)
	queue_free()


func _exit_tree() -> void:
	# Freed with the world (the world left for the title): no step goes on —
	# a movie's timers find it over.
	if not _over:
		_over = true


# ---------------------------------------------------------- keys and mouse --

func _gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT \
			and step in [BANISH, MOVIE, WIN]:
		accept_event()
		go_on()


func _unhandled_input(event: InputEvent) -> void:
	if _over or not is_visible_in_tree():
		return
	match step:
		FIFTH, DOOR:
			# The question answers to its buttons and their first letters;
			# Escape is not an answer.
			if event.is_action_pressed("ui_cancel"):
				get_viewport().set_input_as_handled()
			elif VisitPane.letter_choice(self, _choices, event):
				get_viewport().set_input_as_handled()
		BANISH, MOVIE, WIN:
			var key := event as InputEventKey
			if key != null and key.pressed and not key.echo:
				get_viewport().set_input_as_handled()
				go_on()
		STATS:
			if event.is_action_pressed("ui_cancel"):
				get_viewport().set_input_as_handled()
				_after_stats()


func _input(event: InputEvent) -> void:
	if step in [FIFTH, DOOR]:
		VisitPane.drop_letter(_choices, event)
