class_name DuelPause
extends VersusPanel
## THE PAUSE WINDOW — `Q` or `Esc` during a duel.
##
## The owner's playtest, 2026-09-03: *"When a player types Q or ESC keys
## during a duel, a menu should pop up with buttons: concede the duel (you
## lost), exit duel (return to duel config), return to main menu, exit
## game"*, then *"And another button: return to game. Pressing Q or ESC
## again would close the menu. The menu should be named Pause on top!"* —
## and *"This Q or ESC button menu should reuse the brown portraits window
## with buttons on the bottom."*
##
## So it is [VersusPanel]'s marble board with a title in the band above the
## wells and five buttons in the band below them. It shows the two seats
## because that is the window the owner pointed at, and because a menu that
## can end the duel should say whose duel it is ending.
##
## `[QoL]`, and squarely so. The 1997 duel has no pause and no menu on any
## key: `Duel.hlp`'s topic **Territory** puts leaving behind **Concede**
## (*"You must confirm this decision"*) and **Minimize**, and `Esc` in the
## original is *"just like Cancel"* — which is why Esc keeps that job here
## whenever there is anything to cancel and only opens this window when
## there is not. Recorded in `docs/ROADMAP.md`.
##
## **PAUSE IS A PROMISE ABOUT TIME, not a label.** While this is up the
## duel behind it stands still: [DuelScreen] counts it as a modal, so the
## automatic pass cannot fire and no card, phase icon or territory answers
## a click, and [method DuelScreen._maybe_schedule_ai] neither arms the AI's
## pacing timer nor lets an already-armed one act. Unlike [DuelIntro], this
## window carries NO timer of its own — a menu that dismisses itself while
## you are reading it is worse than no menu.

## What the window was answered with. `RESUME` first, because it is the
## harmless one and it is what the focused button does.
enum Action { RESUME, CONCEDE, EXIT_DUEL, MAIN_MENU, QUIT }

## The title, in the owner's own word, in the 59px band above the wells.
const TITLE := "Pause"

## The five entries, in [enum Action] order.
const ENTRIES: Array[String] = [
	"Return to game",
	"Concede duel",
	"Exit duel",
	"Return to main menu",
	"Exit game",
]

## Where each entry sits on the 500x400 board, in the art's own
## coordinates. The wells end at y=251 and the seat names run to y=285, so
## the buttons have the band 290..394 to live in — WHICH A COLUMN OF FIVE
## DOES NOT FIT: five 30px rows plus gaps is 166px and there are 104.
## Measured on the screenshot, not on arithmetic alone. So: the safe entry
## alone on its own row, then two rows of two, widest label first.
const BUTTON_RECTS: Array[Rect2] = [
	Rect2(150, 291, 200, 30),
	Rect2(60, 325, 180, 30),
	Rect2(260, 325, 180, 30),
	Rect2(60, 359, 180, 30),
	Rect2(260, 359, 180, 30),
]

## An entry was pressed; the payload is an [enum Action]. The window does
## none of it itself — conceding, leaving and quitting are the screen's to
## do, which is also what lets a test read the choice without changing
## scene or killing the process.
signal chosen(action: int)


func build(config: DuelConfig) -> void:
	# No deck lines: the *"playing with <deck>"* band is where the buttons
	# go, and five of them need all of it.
	var board := build_panel(config, TITLE, false)
	var first: Button = null
	for i in ENTRIES.size():
		var rect: Rect2 = BUTTON_RECTS[i]
		var button := UiChrome.menu_button(ENTRIES[i], rect.size, 14)
		button.position = rect.position
		button.size = rect.size
		button.pressed.connect(_press.bind(i))
		board.add_child(button)
		if i == Action.RESUME:
			first = button
	# THE REFLEX PRESS IS THE HARMLESS ONE. `Return to game` holds focus,
	# so a player who opens this and hits Return goes back to the duel
	# rather than out of it. Focus is tree-wide, so this only works with
	# the window already added — the caller adds first, exactly as
	# [DuelIntro]'s `Go!` needs.
	if first != null and is_inside_tree():
		first.grab_focus()


func _press(action: int) -> void:
	chosen.emit(action)


## For tests and the screenshot tour: the button labels, in order.
func button_labels() -> PackedStringArray:
	var out := PackedStringArray()
	for entry in ENTRIES:
		out.append(entry)
	return out


## Press one entry by its label. Returns false when this window has no such
## button, so a caller can tell a miss from a no-op.
func press(label: String) -> bool:
	var index := ENTRIES.find(label)
	if index < 0:
		return false
	_press(index)
	return true
