class_name WorldDuels
extends Control
## AN ADVENTURE DUEL OVER THE WORLD — the duel screen held over the world
## screen ([method DuelScreen.held], part B's hosting contract), for every
## duel the adventure starts: a creature met on the map ([EncounterPane]),
## and — the same host — a lair's duel, a ruled town's, the besieger's.
## 1997 ran `RunDuelEngine` (visitLocation.c 2132–2245) from the encounter
## and came back to it with the result; this is that hand-off:
##
##  - [method host] puts the duel up as a child of the world screen and
##    asks the world to hold ([method WorldScreen.hold_for_duel]: the world,
##    the panel and the arrows hidden, the clock waiting); the duel deals at
##    once ([DuelConfig], made by [method CreatureMeeting.duel_config]).
##  - THE DUEL PLAYED OUT: [signal ended] with its [DuelReport] (the End of
##    Duel window closed — or at once headless, [signal
##    DuelScreen.duel_closed]); the duel taken away, the world shown again.
##  - "EXIT DUEL" (Pause, and the splash's left button, here "Concede")
##    ASKS FIRST and then CONCEDES: the duel is a LOSS — [signal ended] with
##    the report made a loss ([member conceded] true). 1997's adventure duel
##    had no way out but its menu's Concede; ours asks [QoL].
##  - "RETURN TO MAIN MENU" (Pause) ASKS FIRST and then LEAVES THE ADVENTURE
##    with the duel unfinished and NOTHING SAVED ([signal abandoned]): the
##    save made as the meeting began stands — the owner's ruling 4, as 1997:
##    reloading meets the creature again, nothing lost or won (a lair's duel:
##    the lair was spent as it was entered, the lead's ruling C).
##  - THE DUEL ALREADY OVER (its End of Duel window up, the pause key still
##    offering both doors): its result stands whichever door is taken —
##    Exit duel goes on to what it brought, and Return to main menu too, the
##    world then saved and left for the title once its panes are done
##    ([method WorldScreen.leave_after_panes]); the questions say so.
##  - THE QUESTIONS FIT THE DUEL [ours] (the playtest of part B, H1-4,
##    H2-6): "your ante is lost" only when the hero stakes a card (a lair's
##    duel stakes none of theirs), and the menu's words the holder's own
##    when it has them (a lair's, [constant MENU_LAIR]) — over, too (a
##    board's room, [constant DungeonPane.MENU_OVER]: the visit ends; part C
##    stage C3, h1-2).
##  - A DUEL OVER AS IT IS DEALT (headless, the hero at life 0) is heard
##    after the frame, once the holder has connected [signal ended].
##  - Pause → Quit ends the program, as from every duel; the world screen
##    does not save then either (its window-close guard).
##
## The world's own music (`ShellMusic`, the soundscape) is the holder's to
## bring back when its panes are done ([method world_music]): after a
## creature's duel the spoils' tunes play first, as 1997's did.

## The duel is over: played out, or conceded ([member conceded]; the report
## then a loss).
signal ended(report: DuelReport)
## The player left the duel for the main menu: unfinished, nothing saved.
signal abandoned

## The questions of the duel's two doors (`DuelScreen.leave_question`,
## `menu_question`), naming the foe.
const LEAVE_TITLE := "Concede"
const LEAVE_LABEL := "Concede"
const LEAVE := "Concede the duel to the %s? It counts as a loss: your ante is lost."
const MENU := "Return to the main menu? The duel is left unfinished and nothing is saved: the adventure goes back to where it was saved as you met the %s."
## [Ours] The Concede question when the hero stakes nothing (a lair's duel:
## the hoard is the creature's stake alone, `global_ante_cards[0][0] = −1`).
const LEAVE_UNSTAKED := "Concede the duel to the %s? It counts as a loss: you stake nothing, and win nothing."
## [Ours] A lair's menu question (the lead's ruling C: saved and spent as it
## was entered, [method WorldScreen.enter_lair]).
const MENU_LAIR := "Return to the main menu? The duel is left unfinished and nothing is saved: the adventure goes back to where it was saved as you entered the lair, and the lair is spent."
## [Ours] The doors' title and questions once the duel is over (its result
## stands, [method concede], [method _to_menu]).
const OVER_TITLE := "The duel is over"
const LEAVE_OVER := "Leave the duel? It is over: its result stands."
const MENU_OVER := "Return to the main menu? The duel is over and its result stands: what it brought comes first, then the adventure is saved and left."

## The world screen holding the duel (any Node: a test's host too).
var screen: Node
## The duel's set-up.
var config: DuelConfig
## Who the duel is against, for the questions ("Witch").
var foe := "creature"
## The duel screen while it is up.
var duel: DuelScreen
## The menu question's words when the holder has its own ("" the
## meeting's, [constant MENU]); and once the duel is over ("" [constant
## MENU_OVER]).
var menu_words := ""
var menu_over_words := ""
## Whether the duel was conceded.
var conceded := false
var _over := false
## The duel being dealt (its `_ready`, inside [method _ready]'s add_child).
var _dealing := false


## THE DUEL OF [param config] OVER [param screen] against [param foe_name]:
## the host, in the tree, the duel dealt; [param menu_text] the menu
## question's words when the holder has its own (a lair's, [constant
## MENU_LAIR]), [param menu_over_text] its words once the duel is over (a
## board's room, [constant DungeonPane.MENU_OVER]). Connect [signal ended]
## (and [signal abandoned]) right after: a duel over as it is dealt is heard
## after the frame ([method _closed]).
static func host(on: Node, duel_config: DuelConfig, foe_name := "creature", menu_text := "",
		menu_over_text := "") -> WorldDuels:
	var out := WorldDuels.new()
	out.name = "WorldDuel"
	out.screen = on
	out.config = duel_config
	out.foe = foe_name
	out.menu_words = menu_text
	out.menu_over_words = menu_over_text
	on.add_child(out)
	return out


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var leave_text := (LEAVE if hero_stakes() else LEAVE_UNSTAKED) % foe
	duel = DuelScreen.held(config, LEAVE_TITLE, leave_text, menu_words if menu_words != "" else MENU % foe,
		LEAVE_LABEL)
	duel.duel_closed.connect(_closed)
	duel.duel_finished.connect(_questions_over)
	duel.leave_confirmed.connect(concede)
	duel.menu_confirmed.connect(_to_menu)
	_hold(true)
	_dealing = true
	add_child(duel)
	_dealing = false


## THE DUEL MADE READY BEFORE IT OPENS (the smoothness pass, 0.50.66;
## [DuelWarmup]): its pictures, sounds and stones made off the thread that
## draws while the player reads what comes before it, under [param on]
## (the meeting's pane; the world screen) — the seats' colours the hero's
## deck's and, when [param color] names one (1 black … 5 white, a
## meeting's `color`), the creature's, and the coin's sheets with it. The
## first duel of a session then opens in about the time the later ones do.
## Null where no warm-up runs (headless, the web).
static func warm_for(on: Node, player: AdventurePlayer, color := 0) -> DuelWarmup:
	if on == null or player == null or not DuelWarmup.runs_here():
		return null
	var colors: Array[String] = [DuelConfig.dominant_color(player.deck_cards()), ""]
	if color >= 1 and color <= AdventurePlayer.COLORS.size():
		colors[1] = AdventurePlayer.COLORS[color - 1]
	# A special meeting's sound plays as its Duel is clicked
	# ([method EncounterPane._to_duel]); the coin's sheets (39 MB) only for
	# a meeting, a duel at hand — not on arrival in the world.
	return DuelWarmup.warm(on, colors, player.playmat, ["sfx_dsummon"] as Array[String], color > 0)


## Whether the hero stakes a card in this duel ([member DuelConfig.ante_cards]
## or [member DuelConfig.ante_extras] of seat 0): a meeting's, a ruled
## town's; a lair's none.
func hero_stakes() -> bool:
	if config == null:
		return true
	for stakes in [config.ante_cards, config.ante_extras]:
		if (stakes as Array).size() > 0 and not ((stakes as Array)[0] as Array).is_empty():
			return true
	return false


## THE DUEL OVER, its End of Duel window to come: both doors' words say its
## result stands ([constant LEAVE_OVER], [constant MENU_OVER] or the
## holder's [member menu_over_words]) — read as each question is asked.
func _questions_over(_winner: int) -> void:
	if not is_instance_valid(duel):
		return
	duel.leave_title = OVER_TITLE
	duel.leave_question = LEAVE_OVER
	duel.menu_question = menu_over_words if menu_over_words != "" else MENU_OVER


## Whether the duel is still up.
func playing() -> bool:
	return not _over


## CONCEDE (the leave question's Yes; a test may call it): the duel ends as
## a loss — unless it is already over: a duel won or drawn, its End of Duel
## window up, keeps its result (the bug pass of part B, q2-1: the pause key
## still offers Exit duel there, and its Yes turned a won duel into a loss,
## the stake lost and no spoils).
func concede() -> void:
	if _over:
		return
	if duel != null and duel.game != null and duel.game.game_over:
		_finish(duel.report())
		return
	conceded = true
	var report := duel.report() if duel != null else DuelReport.new()
	report.finished = true
	report.winner = 1
	report.result = DuelReport.LOSS
	_finish(report)


func _closed(report: DuelReport) -> void:
	if _over:
		return
	if _dealing:
		# OVER AS IT IS DEALT (the playtest of part B, H1-3): headless, a hero
		# at life 0 has lost by the duel's start, inside [method host] — so
		# [signal ended] came before the holder had connected it, the pane
		# hidden and the world held for good. Heard after the frame instead.
		_finish.call_deferred(report)
		return
	_finish(report)


## The duel taken away (hidden at once, freed after the frame: never from
## inside its own signal), the world shown again, [signal ended] — once.
func _finish(report: DuelReport) -> void:
	if _over:
		return
	_over = true
	_drop_duel()
	_hold(false)
	ended.emit(report)
	queue_free()


## RETURN TO MAIN MENU: the duel left unfinished, nothing saved, the title
## — unless it is already over (the playtest of part B, H1-2: its End of
## Duel window up, this door's Yes went to the title and threw the result
## away — a win's cards gone, a loss undone by the reload, past ruling 4,
## which is about quitting mid-duel). Its result stands, as Exit duel's does
## ([method concede], q2-1): the duel finished with its report, and the
## world leaves for the title — saved — once what it brought is shown.
func _to_menu() -> void:
	if _over:
		return
	if duel != null and duel.game != null and duel.game.game_over:
		if screen != null and screen.has_method("leave_after_panes"):
			screen.call("leave_after_panes")
		_finish(duel.report())
		return
	_over = true
	abandoned.emit()
	if screen != null and screen.has_method("leave_unsaved"):
		# The world screen's own way out, without its save (ruling 4).
		screen.call("leave_unsaved")


func _drop_duel() -> void:
	if is_instance_valid(duel):
		duel.visible = false
		duel.process_mode = Node.PROCESS_MODE_DISABLED
		duel.queue_free()


## The world held under the duel, or let go ([method
## WorldScreen.hold_for_duel], when the holder has it).
func _hold(on: bool) -> void:
	if screen != null and screen.has_method("hold_for_duel"):
		screen.call("hold_for_duel", on)


func _exit_tree() -> void:
	# Freed with the duel still up (the world screen left): the world is not
	# held by a duel that is gone.
	if not _over:
		_over = true
		if is_instance_valid(screen) and not screen.is_queued_for_deletion() and screen.is_inside_tree():
			_hold(false)


## THE WORLD'S BED AGAIN after an adventure duel's panes (the duel stopped
## it, `DuelScreen._play_music`): `ShellMusic` played, found through the tree
## (a tool compiled before the autoloads may load this file).
static func world_music(node: Node) -> void:
	if node == null or not node.is_inside_tree():
		return
	var music := node.get_node_or_null(^"/root/ShellMusic")
	if music != null:
		music.call(&"play")


## The world's bed stopped for a pane's own tune (the meeting's
## `music_duel`, the spoils' `music_win_duel` / `music_lose_duel`).
static func world_music_off(node: Node) -> void:
	if node == null or not node.is_inside_tree():
		return
	var music := node.get_node_or_null(^"/root/ShellMusic")
	if music != null:
		music.call(&"stop")
