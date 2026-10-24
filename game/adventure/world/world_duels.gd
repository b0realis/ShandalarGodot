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

## The world screen holding the duel (any Node: a test's host too).
var screen: Node
## The duel's set-up.
var config: DuelConfig
## Who the duel is against, for the questions ("Witch").
var foe := "creature"
## The duel screen while it is up.
var duel: DuelScreen
## Whether the duel was conceded.
var conceded := false
var _over := false


## THE DUEL OF [param config] OVER [param screen] against [param foe_name]:
## the host, in the tree, the duel dealt. Connect [signal ended] (and
## [signal abandoned]) right after.
static func host(on: Node, duel_config: DuelConfig, foe_name := "creature") -> WorldDuels:
	var out := WorldDuels.new()
	out.name = "WorldDuel"
	out.screen = on
	out.config = duel_config
	out.foe = foe_name
	on.add_child(out)
	return out


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	duel = DuelScreen.held(config, LEAVE_TITLE, LEAVE % foe, MENU % foe, LEAVE_LABEL)
	duel.duel_closed.connect(_closed)
	duel.leave_confirmed.connect(concede)
	duel.menu_confirmed.connect(_to_menu)
	_hold(true)
	add_child(duel)


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
	_finish(report)


## The duel taken away (hidden at once, freed after the frame: never from
## inside its own signal), the world shown again, [signal ended].
func _finish(report: DuelReport) -> void:
	_over = true
	_drop_duel()
	_hold(false)
	ended.emit(report)
	queue_free()


## RETURN TO MAIN MENU: the duel left unfinished, nothing saved, the title.
func _to_menu() -> void:
	if _over:
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
