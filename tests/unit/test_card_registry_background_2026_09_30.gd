extends GutTest
## THE POOL BUILDS OFF THE MAIN THREAD (2026-09-30, the Meta Quest start).
##
## The 0.40.52 start report put 4.6 of the headset's 9.1 seconds in the
## one call `main.gd` made before it drew the title: compiling every card
## script. The title reads no card, so the `CardPacks` autoload now starts
## the build on a [Thread] ([method CardRegistry.load_in_background]) and
## the first ask for a card — any public reader, on any thread — WAITS
## for it instead of building. This pins the contract:
##
##   1. A background build is idempotent, reports itself as in flight,
##      and the first ask joins it: the pool is complete, the thread is
##      gone, and the loader's line says "(background)".
##   2. [method CardRegistry.unload] during a build waits for it first —
##      a thread must never write into a pool being cleared, and a
##      [Thread] must be joined before it goes.
##   3. Reconfiguring the packs during a build settles it first, and the
##      next ask rebuilds in the foreground, as a toggle always did.
##   4. The main thread may `load()` the very scripts the worker is
##      compiling meanwhile — the loader's own contention case — and
##      both come out whole, with no duplicate registration.
##   5. The title's version corner says "loading cards…" while the
##      thread runs and fills in the count the frame it is done, without
##      ever waiting for it.
##   6. The title also hands the engine's loader threads the screens its
##      buttons open ([ScreenWarmup]), beside the pool thread; every
##      request is taken once, and a settled warm-up leaves nothing
##      pending — the process-end hook relies on that.
##   7. A press on a screen that reads a card, made while the thread
##      runs, holds the button ("Loading cards…") instead of freezing
##      the title in that screen's `_ready`, and opens it the frame the
##      pool is in; a second such press takes the wait over; a screen
##      that reads no card opens at once.

var _expected := 0


func before_all() -> void:
	CardRegistry.ensure_loaded()
	_expected = CardRegistry.size()


func after_each() -> void:
	CardRegistry.ensure_loaded()
	ShellMusic.stop()


## Wait for the build to finish WITHOUT asking the registry for a card
## (which would join it): the wall clock, not the runner's timer.
func _await_pool(limit_ms := 30000) -> bool:
	var started := Time.get_ticks_msec()
	while not CardRegistry.poll():
		if Time.get_ticks_msec() - started > limit_ms:
			return false
		await get_tree().process_frame
	return true


func test_a_background_build_is_joined_by_the_first_ask() -> void:
	CardRegistry.unload()
	assert_false(CardRegistry.is_loading())
	assert_eq(CardRegistry.pool_report(), "", "nothing built, nothing to say")
	assert_true(CardRegistry.load_in_background(), "started")
	assert_false(CardRegistry.load_in_background(), "one build at a time")
	assert_true(CardRegistry.is_loading() or CardRegistry.poll(),
		"in flight, or already done on a very fast machine")
	# The first ask: waits for the thread, returns the whole pool.
	assert_eq(CardRegistry.size(), _expected, "the pool the foreground build gives")
	assert_false(CardRegistry.is_loading())
	assert_true(CardRegistry.poll())
	assert_null(CardRegistry._thread, "joined by the ask")
	assert_eq(CardRegistry._loader_id, -1)
	assert_true(CardRegistry.pool_report().begins_with("card pool: %d cards in " % _expected),
		CardRegistry.pool_report())
	assert_true(CardRegistry.pool_report().ends_with(" ms (background)"), CardRegistry.pool_report())
	assert_not_null(CardRegistry.get_card("Grizzly Bears"))
	assert_false(CardRegistry.load_in_background(), "a built pool is left alone")


func test_without_threads_the_pool_loads_in_the_foreground() -> void:
	CardRegistry.unload()
	assert_false(CardRegistry.load_in_background(false), "no background worker")
	assert_true(CardRegistry.poll(), "the pool is already complete")
	assert_false(CardRegistry.is_loading(), "never wait for a stub Thread")
	assert_null(CardRegistry._thread)
	assert_eq(CardRegistry._loader_id, -1)
	assert_eq(CardRegistry.size(), _expected)
	assert_not_null(CardRegistry.get_card("Grizzly Bears"))
	assert_false(CardRegistry.pool_report().contains("background"))
	var revision_before := CardRegistry.revision
	assert_false(CardRegistry.load_in_background(false), "idempotent")
	assert_eq(CardRegistry.revision, revision_before)


func test_without_threads_screen_warmup_leaves_nothing_to_join() -> void:
	ScreenWarmup.settle()
	ScreenWarmup.request(MainScreen.WARM_SCREENS, false)
	assert_true(ScreenWarmup.pending().is_empty())
	ScreenWarmup.settle()
	assert_not_null(load("res://game/deck_builder/deck_builder_screen.tscn"),
		"ordinary foreground screen loads remain available")


func test_a_poller_sees_the_build_finish_without_waiting() -> void:
	CardRegistry.unload()
	assert_true(CardRegistry.load_in_background())
	assert_true(await _await_pool(), "the thread finished within the limit")
	assert_null(CardRegistry._thread, "poll joined it")
	assert_eq(CardRegistry.size(), _expected)


func test_unload_during_the_build_waits_for_it_then_clears() -> void:
	CardRegistry.unload()
	assert_true(CardRegistry.load_in_background())
	CardRegistry.unload()
	assert_null(CardRegistry._thread, "joined, never abandoned")
	assert_eq(CardRegistry._loader_id, -1)
	assert_false(CardRegistry._loaded)
	assert_false(CardRegistry.is_loading())
	assert_eq(CardRegistry.pool_report(), "")
	assert_eq(CardRegistry.size(), _expected, "rebuilt in the foreground on the next ask")
	assert_false(CardRegistry.pool_report().contains("background"), CardRegistry.pool_report())


func test_reconfiguring_the_packs_during_the_build_settles_it_first() -> void:
	CardRegistry.unload()
	assert_true(CardRegistry.load_in_background())
	CardRegistry.configure_expansion_packs(CardRegistry._expansion_sets,
		CardRegistry._expansion_scripts, CardRegistry._expansion_records)
	assert_false(CardRegistry.is_loading(), "settled, and cleared: a toggle rebuilds on the next ask")
	assert_false(CardRegistry._loaded)
	assert_null(CardRegistry._thread)
	CardRegistry.unload()
	assert_true(CardRegistry.load_in_background())
	CardRegistry.configure_optional_pack(CardRegistry._optional_enabled,
		CardRegistry._optional_sets, CardRegistry._optional_scripts,
		CardRegistry._optional_records, CardRegistry._optional_counts)
	assert_false(CardRegistry.is_loading())
	assert_null(CardRegistry._thread)
	assert_eq(CardRegistry.size(), _expected)


func test_the_main_thread_loads_the_same_scripts_meanwhile() -> void:
	CardRegistry.unload()
	assert_true(CardRegistry.load_in_background())
	# The scripts the worker is compiling right now, and a screen whose
	# scripts sit beside them.
	for path in ["res://cards/sets/2ed/terror.gd", "res://cards/sets/2ed/grizzly_bears.gd",
			"res://cards/sets/leg/the_abyss.gd", "res://cards/sets/4ed/millstone.gd",
			"res://game/deck_builder/deck_builder_screen.tscn"]:
		assert_not_null(load(path), path)
	# The printing index the worker builds first: a main-thread ask waits
	# for it rather than writing the same tables from two threads.
	assert_eq(CardRegistry.artist_of("Terror", "2ed"), "Ron Spencer")
	assert_eq(CardRegistry.size(), _expected, "one registration per card")
	assert_eq(CardRegistry.get_card("Terror").set_code, "2ed")
	assert_true(CardRegistry.originally_printed_in("Erg Raiders", "arn"))


func test_the_title_says_loading_then_fills_in_the_count() -> void:
	CardRegistry.unload()
	assert_true(CardRegistry.load_in_background())
	var title: Control = load("res://game/main.tscn").instantiate()
	add_child_autofree(title)
	var version := title.find_child("Version", true, false) as Label
	assert_not_null(version)
	# Ready ran on this frame: the corner says what the thread is doing,
	# unless the machine finished it before the screen came up.
	if CardRegistry.is_loading():
		assert_string_contains(version.text, "loading cards…")
		assert_true(title.is_processing(), "asking each frame")
	assert_true(await _await_pool())
	await get_tree().process_frame
	assert_false(title.is_processing(), "done asking")
	assert_false(version.text.contains("loading"), version.text)
	assert_true(version.text.contains("cards"), version.text)
	assert_eq(CardRegistry.size(), _expected)


func test_the_title_warms_the_screens_its_buttons_open() -> void:
	ScreenWarmup.settle()
	var was_cached := {}
	for path in MainScreen.WARM_SCREENS:
		was_cached[path] = ResourceLoader.has_cached(path)
	var title: Control = load("res://game/main.tscn").instantiate()
	add_child_autofree(title)
	for path in MainScreen.WARM_SCREENS:
		if was_cached[path]:
			assert_false(ScreenWarmup.pending().has(path), path + ": cached, not asked for")
			continue
		assert_true(ScreenWarmup.pending().has(path), path + ": asked for")
		var status := ResourceLoader.load_threaded_get_status(path)
		assert_true(status in [ResourceLoader.THREAD_LOAD_IN_PROGRESS,
			ResourceLoader.THREAD_LOAD_LOADED], "%s: in flight or done, not %d" % [path, status])
	# A second title asks for nothing twice.
	var pending_before := ScreenWarmup.pending()
	var again: Control = load("res://game/main.tscn").instantiate()
	add_child_autofree(again)
	assert_eq(ScreenWarmup.pending(), pending_before, "asked once")
	ScreenWarmup.settle()
	assert_true(ScreenWarmup.pending().is_empty(), "taken")
	ScreenWarmup.settle()
	for path in MainScreen.WARM_SCREENS:
		var started := Time.get_ticks_msec()
		assert_not_null(load(path), path)
		assert_lt(Time.get_ticks_msec() - started, 200, path + " is warm (cold: 276-1,032 ms)")


func test_the_warm_up_runs_beside_the_pool_thread() -> void:
	ScreenWarmup.settle()
	CardRegistry.unload()
	assert_true(CardRegistry.load_in_background())
	ScreenWarmup.request(MainScreen.WARM_SCREENS)
	ScreenWarmup.settle()
	assert_true(await _await_pool(), "the pool thread finished within the limit")
	assert_eq(CardRegistry.size(), _expected, "one registration per card")
	for path in MainScreen.WARM_SCREENS:
		assert_not_null(load(path), path)
	assert_not_null(CardRegistry.get_card("Grizzly Bears"))


func _menu_entry(title: Control, text: String) -> Button:
	for child in title.find_child("MenuColumn", true, false).get_children():
		if child is Button and child.text == text:
			return child
	return null


func test_a_press_before_the_pool_holds_the_button_then_opens() -> void:
	assert_null(get_tree().current_scene, "the runner has no current scene to replace")
	CardRegistry.unload()
	assert_true(CardRegistry.load_in_background())
	var title: Control = load("res://game/main.tscn").instantiate()
	add_child_autofree(title)
	var builder := _menu_entry(title, "Deck Builder")
	var battle := _menu_entry(title, "Magic Battle")
	assert_not_null(builder)
	assert_not_null(battle)
	if not CardRegistry.is_loading():
		# A machine that built the pool before the title stood has
		# nothing to hold: the press opens at once, as before.
		assert_eq(title._pending_open, "")
		return
	var pressed_at := Time.get_ticks_msec()
	builder.pressed.emit()
	assert_lt(Time.get_ticks_msec() - pressed_at, 100, "the press did not wait for the thread")
	assert_eq(title._pending_open, "res://game/deck_builder/deck_builder_screen.tscn")
	assert_eq(builder.text, MainScreen.WAITING_TEXT, "the button says why")
	assert_true(title.is_processing(), "asking each frame")
	await get_tree().process_frame
	assert_null(get_tree().current_scene, "not opened yet")
	# A second card screen pressed meanwhile takes the wait over.
	battle.pressed.emit()
	assert_eq(builder.text, "Deck Builder", "let go")
	assert_eq(battle.text, MainScreen.WAITING_TEXT)
	assert_eq(title._pending_open, "res://game/setup_screen.tscn")
	assert_true(await _await_pool(), "the thread finished within the limit")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(battle.text, "Magic Battle", "let go on the way out")
	assert_eq(title._pending_open, "")
	var opened := get_tree().current_scene
	assert_not_null(opened, "opened the frame the pool was in")
	if opened != null:
		assert_eq(opened.scene_file_path, "res://game/setup_screen.tscn")
		opened.free()
		get_tree().current_scene = null


## OPTIONS, NOT HELP, since the bug pass of 2026-10-03: this test used
## Help as the screen that reads no card, and Help does read them — its
## format pages list the restricted and banned cards the pool holds
## (`HelpPages._page_format_lists` joins the build), so the press froze
## the title for the rest of the build. Help is held now (below).
func test_a_screen_that_reads_no_card_opens_at_once_under_the_build() -> void:
	assert_null(get_tree().current_scene, "the runner has no current scene to replace")
	CardRegistry.unload()
	assert_true(CardRegistry.load_in_background())
	var title: Control = load("res://game/main.tscn").instantiate()
	add_child_autofree(title)
	var options := _menu_entry(title, "Options")
	assert_not_null(options)
	options.pressed.emit()
	assert_eq(title._pending_open, "", "nothing held")
	assert_eq(options.text, "Options")
	await get_tree().process_frame
	await get_tree().process_frame
	var opened := get_tree().current_scene
	assert_not_null(opened, "opened without the pool")
	if opened != null:
		assert_eq(opened.scene_file_path, "res://game/options_screen.tscn")
		opened.free()
		get_tree().current_scene = null
	assert_true(await _await_pool())


func test_help_reads_cards_so_a_press_under_the_build_is_held() -> void:
	assert_true(MainScreen.POOL_SCREENS.has("res://game/help/help_screen.tscn"),
		"Help's format pages read the pool")
	CardRegistry.unload()
	assert_true(CardRegistry.load_in_background())
	var title: Control = load("res://game/main.tscn").instantiate()
	add_child_autofree(title)
	var help := _menu_entry(title, "Help")
	assert_not_null(help)
	if not CardRegistry.is_loading():
		pass_test("the pool built before the title stood — nothing to hold")
		return
	var pressed_at := Time.get_ticks_msec()
	help.pressed.emit()
	assert_lt(Time.get_ticks_msec() - pressed_at, 100, "the press did not wait for the thread")
	assert_eq(title._pending_open, "res://game/help/help_screen.tscn")
	assert_eq(help.text, MainScreen.WAITING_TEXT, "the button says why")
	title._let_go()
	assert_true(await _await_pool())
