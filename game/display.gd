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
##
## THE LAUNCHER'S WORD (2026-09-27). A handheld launcher starts the
## engine with `--fullscreen` (`packaging/handhelds/arkos.sh`), and
## until this date the boot pass here put the window straight back —
## the key was unwritten, unwritten read `false`, and `false` is a
## window. Now an unwritten key defers to the flag: the window the
## engine was asked to open is the window it keeps. A WRITTEN key is
## the player's and still wins, either way. The Steam Deck launcher does
## not need the flag at all — it names the device ([constant
## Settings.HANDHELD_ENV]) and the unwritten key reads `true` there.
##
## THE POWER SAVER lives here too (2026-09-27), because it is the other
## thing the display does with a setting: [member OS.low_processor_usage_mode]
## makes the engine redraw only when something changed and rest between
## frames, which on a handheld is the difference between a duel that
## drains the battery like a shooter and one that sips it like a book.
## Off on a desk unless asked; on under a handheld launcher unless the
## player says otherwise ([method Settings.power_saver]). Applied at boot
## with the window mode, and at once from the Options row.
##
## THE FRAME CAP WHERE V-SYNC IS REFUSED (2026-10-12). V-Sync is what
## paces the frames on a desk. Where the graphics driver will not set it —
## Xvfb, a virtual machine, some remote desktops; the engine logs "Could
## not set V-Sync mode" and the window's mode reads DISABLED — nothing
## did, and the title screen idled at ~700 frames a second on eight cores.
## The boot then caps the frame rate at the screen's refresh rate (60
## where that is unknown) ([method apply_frame_cap]). A cap a launcher set
## (ArkOS's `--max-fps 30`) is kept.

## The [Settings] key. `false` is the shipped window — 1280x800, resizable
## — which is what the game has always opened into.
const KEY := "fullscreen"
## The [Settings] key of the power saver.
const POWER_KEY := "power_saver"
## The frame cap where V-Sync is refused and the screen's rate is unknown.
const FALLBACK_FPS := 60


## What the stored setting asks the window to be.
static func wanted_mode() -> int:
	return DisplayServer.WINDOW_MODE_FULLSCREEN if Settings.fullscreen() \
		else DisplayServer.WINDOW_MODE_WINDOWED


## Put the stored setting onto the window. Idempotent — asking for the
## mode the window is already in is a no-op, so this is safe to call from
## every screen that wants to be sure — and silent headless, where there
## is no window to set (the test suite, the soak, the Deck Lab).
static func apply_settings() -> void:
	apply_power_saver()
	if DisplayServer.get_name() == "headless":
		return
	apply_frame_cap()
	if not Settings.has_value(KEY) and launcher_asked_fullscreen():
		return          # the launcher's word, until the player has one
	var wanted := wanted_mode()
	if DisplayServer.window_get_mode() == wanted:
		return
	DisplayServer.window_set_mode(wanted)


## Whether the engine was started with `--fullscreen` (or its short
## `-f`) — a launcher's request for the window, honoured while the
## player has not written one of their own (class doc).
##
## THE ENGINE EATS THE FLAG (bug pass 2026-10-03). Godot consumes
## `--fullscreen`/`-f` itself and opens the window full screen; neither
## [method OS.get_cmdline_args] nor the user args carry it (measured
## under Xvfb: the args read `["-s", …]` while the window was already
## full screen at the first script line), so the args test alone never
## fired and the boot put the window straight back. What the flag leaves
## behind is its effect — a full-screen window in a project that opens
## windowed — and that is read here, at boot, before anything else has
## touched the window ([Lifecycle] runs [method apply_settings] first).
static func launcher_asked_fullscreen() -> bool:
	var mode := DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.get_name() != "headless":
		mode = DisplayServer.window_get_mode()
	var args := OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	return launcher_fullscreen_from(args, mode,
		int(ProjectSettings.get_setting("display/window/size/mode",
			DisplayServer.WINDOW_MODE_WINDOWED)))


## The rule, pure, so a headless test can pin it: the flag in the args
## (should a build ever pass it through), or a full-screen window the
## project itself did not ask for.
static func launcher_fullscreen_from(args: PackedStringArray, mode: int,
		project_mode: int) -> bool:
	if args.has("--fullscreen") or args.has("-f"):
		return true
	var full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	return full and project_mode != DisplayServer.WINDOW_MODE_FULLSCREEN \
		and project_mode != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


## The switch's own setter: store, then apply. The Options screen calls
## this and nothing else, so the file and the window cannot disagree.
static func set_fullscreen(on: bool) -> void:
	Settings.set_value(KEY, on)
	apply_settings()


## Put the stored power saver onto the engine's main loop. Idempotent,
## and harmless headless: the flag only lengthens the rest between
## frames of a loop that has nothing to draw anyway.
static func apply_power_saver() -> void:
	var wanted := Settings.power_saver()
	if OS.low_processor_usage_mode != wanted:
		OS.low_processor_usage_mode = wanted


## The switch's own setter: store, then apply.
static func set_power_saver(on: bool) -> void:
	Settings.set_value(POWER_KEY, on)
	apply_power_saver()


## Cap the frame rate when V-Sync does not pace it (class doc). Silent
## headless, where there is nothing to draw, and on the web, where the
## browser paces every frame. Idempotent: once capped, the cap stands.
static func apply_frame_cap() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("web"):
		return
	var cap := frame_cap_from(Engine.max_fps, DisplayServer.window_get_vsync_mode(),
		DisplayServer.screen_get_refresh_rate())
	if cap != Engine.max_fps:
		Engine.max_fps = cap


## The rule, pure, so a headless test can pin it: the frame cap for a
## window whose cap is [param max_fps] (0: none), whose V-Sync is
## [param vsync_mode] and whose screen refreshes [param refresh_rate]
## times a second (NaN or -1 when unknown).
static func frame_cap_from(max_fps: int, vsync_mode: int, refresh_rate: float) -> int:
	if max_fps != 0 or vsync_mode != DisplayServer.VSYNC_DISABLED:
		return max_fps
	if is_finite(refresh_rate) and refresh_rate >= 30.0 and refresh_rate <= 500.0:
		return roundi(refresh_rate)
	return FALLBACK_FPS
