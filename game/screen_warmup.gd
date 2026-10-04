class_name ScreenWarmup
extends RefCounted
## THE SCREENS THE TITLE OPENS COMPILE IN THE BACKGROUND (2026-09-30, the
## Meta Quest start, second half). With the card pool off the main thread
## the title comes up fast — and then the first button pays for its
## screen's scripts: the setup screen 734 ms cold on the desk (its script
## names the duel screen, and that one the whole duel), the deck builder
## 276 ms, the SGManalink lobby 1,032 ms (the protocol/tournament script
## cluster, a cycle the compiler resolves in one go). On a handheld two
## to three times that, felt as a dead click.
##
## The engine's own loader threads do the work ([method
## ResourceLoader.load_threaded_request]); this class only remembers what
## was asked for, so the process-end hook ([Lifecycle]) can take the
## results before static state tears down. A threaded load that is never
## taken leaves its token behind — three "leaked instance" lines at exit,
## which `run_tests.sh` reads as a red suite — and a loader thread still
## compiling while the engine tears down is worse than a leak.
##
## A click that comes before a load is done simply joins it:
## `change_scene_to_file` loads by path, and the loader hands a path
## already in flight to whoever asks for it next. Measured on the desk
## (2026-09-30): the setup screen 734 ms cold, 0 ms once warm. Nothing in
## the game waits for a warm-up; the pool thread runs beside it, and the
## two share no dependency cycle (cards and screens both lean on the
## engine layer, never on each other).

static var _pending: Array[String] = []


## Ask the loader for each path not already cached, once.
static func request(paths: Array[String], allow_threads := true) -> void:
	# Keep Web resource reads on the browser's main thread, including the
	# threaded template (see CardRegistry.load_in_background). Screens
	# use their ordinary foreground load when opened, with nothing to join.
	if not allow_threads or not OS.has_feature("threads") or OS.has_feature("web"):
		return
	for path in paths:
		if _pending.has(path) or ResourceLoader.has_cached(path):
			continue
		if ResourceLoader.load_threaded_request(path) == OK:
			_pending.append(path)


## What was asked for and not yet taken.
static func pending() -> Array[String]:
	return _pending.duplicate()


## Take every result, waiting for the ones still in flight. Idempotent;
## the process-end hook calls it, and so may a test.
static func settle() -> void:
	for path in _pending:
		ResourceLoader.load_threaded_get(path)
	_pending.clear()
