class_name GameDisplay
extends RefCounted
## THE WINDOW — one stored value, `fullscreen`, and the one place it is
## put onto the OS window.
##
## **`[QoL]`. The 1997 game had no such switch.** Its shell and its duel
## ran in a window of their own making at 640x480, and the nearest
## thing to a display option anywhere in its string tables is
## `M&inimize` — `@DECKSURFACE_STANDALONE` entry 7
## (`s30/assets/text/Menus.txt:169-179`) and `@MENU_TERRITORY` entry 21,
## which [method DuelScreen._minimize_window] keeps — plus one config key
## with no menu entry at all: `NoFrame`, read by the deck builder
## (`shandalar-src/src/deck/deckdll.cpp:1269`) and spent on
## `WS_POPUP | WS_VISIBLE | (global_cfg_no_frame ? 0 : WS_THICKFRAME)`
## (`:1772`) — a frameless window, which is as close as 1997 came to
## "full screen". So this is ours, marked as ours, and it exists because
## the owner asked for it on 2026-09-07: *"options menu in the main menu
## lacks full screen / windowed option."*
##
## **ONE VALUE, ONE STORAGE, MANY VIEWS** — the contract [GameAudio]
## states for the sound switches. The Options screen's `Full screen`
## switch writes the [Settings] key; [Lifecycle] applies it once at boot,
## before the title screen is drawn, so the choice is the window the
## player opens into and not a thing to redo each run (*"all selections
## you make should keep as default on your next run"*, the same message).
##
## BORDERLESS, NOT EXCLUSIVE. `WINDOW_MODE_FULLSCREEN` keeps the desktop's
## own resolution and lets the compositor keep running, so alt-tab and
## a second monitor behave; `EXCLUSIVE_FULLSCREEN` buys nothing for a 2D
## card game drawn through the compatibility renderer and costs a mode
## switch on the way in and out.

## The [Settings] key. `false` is the shipped window — 1280x800, resizable
## — which is what the game has always opened into.
const KEY := "fullscreen"


## What the stored setting asks the window to be.
static func wanted_mode() -> int:
	return DisplayServer.WINDOW_MODE_FULLSCREEN if Settings.fullscreen() \
		else DisplayServer.WINDOW_MODE_WINDOWED


## Put the stored setting onto the window. Idempotent — asking for the
## mode the window is already in is a no-op, so this is safe to call from
## every screen that wants to be sure — and silent headless, where there
## is no window to set (the test suite, the soak, the Deck Lab).
static func apply_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var wanted := wanted_mode()
	if DisplayServer.window_get_mode() == wanted:
		return
	DisplayServer.window_set_mode(wanted)


## The switch's own setter: store, then apply. The Options screen calls
## this and nothing else, so the file and the window cannot disagree.
static func set_fullscreen(on: bool) -> void:
	Settings.set_value(KEY, on)
	apply_settings()
