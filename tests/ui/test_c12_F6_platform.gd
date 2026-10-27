extends GutTest
## THE BROWSER'S CHOOSERS AND THE HEADSET'S FOLDERS (the bug campaign c12,
## h6-5 and h6-6).
##
## h6-5. The web build's Skin and Card back `Choose...` open the page's own
## file box, and a second press while the first box was still waiting was
## ignored. A box that never answers — a browser that fires no `cancel`
## for a box closed with nothing chosen, or one that never opened it
## because it did not count the press as the player's (a pad's A) — kept
## the wait going for good: the Skin button was dead for the session, the
## card back's until Options was opened again. Now such a press opens the
## box afresh. No browser runs here, so the page is stood in for
## ([method SkinPack._page], [member CardBack.page]): what is tested is the
## GDScript's guard, which decides when the page's script runs again.
##
## h6-6. "Open Folder" (Options > Card Packs) and the Booster Draft
## result's "Open save folder" open nothing on Android (the Meta Quest),
## whose folders no file manager there can open. There they are disabled
## and say why — the card-pack one pointing to Add pack.... The platform
## is stood in for through `on_android` on each screen.

const SKIN_PACK := preload("res://game/skin_pack.gd")
const FOLDER := "user://test_c12_f6_platform"

var _files: Array[String] = []
var _page_state := "open"
var _scripts: Array[String] = []


## The skin's chooser with the page stood in for: every script it runs is
## kept, and the box's state is whatever the test says.
class PagedSkinPack extends "res://game/skin_pack.gd":
	var scripts: Array[String] = []
	var state := "open"
	func _page(script: String) -> Variant:
		scripts.append(script)
		if script.begins_with("window.shandalarPick ?"):
			return state
		return null


func before_each() -> void:
	_scripts.clear()
	_page_state = "open"
	CardBack.page = func(script: String) -> Variant:
		_scripts.append(script)
		if script.begins_with("window.shandalarBack ?"):
			return _page_state
		return null


func after_each() -> void:
	CardBack.page = Callable()
	CardPacksScreen.on_android = OS.has_feature("android")
	DraftSession.on_android = OS.has_feature("android")
	await get_tree().process_frame
	for path in _files:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	_files.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FOLDER))


func _count(scripts: Array[String], wanted: String) -> int:
	return scripts.filter(func(s: String) -> bool: return s == wanted).size()


# ------------------------------------------------------------- h6-5 --

func test_a_second_skin_press_opens_a_box_that_never_answered() -> void:
	var pack: PagedSkinPack = autofree(PagedSkinPack.new())
	pack._pick_on_page()
	assert_true(pack.picking)
	assert_eq(_count(pack.scripts, SKIN_PACK.PICK_JS), 1, "the box opened")
	# The box never said a word: still "open", nothing read.
	pack._pick_on_page()
	assert_eq(_count(pack.scripts, SKIN_PACK.PICK_JS), 2,
		"a second press opens it afresh instead of being ignored for the session")
	assert_true(pack.picking)


func test_a_skin_press_never_drops_a_file_on_its_way() -> void:
	var pack: PagedSkinPack = autofree(PagedSkinPack.new())
	pack._pick_on_page()
	# Chosen and in the page; the next frame takes it.
	pack.state = "ready"
	pack._pick_on_page()
	assert_eq(_count(pack.scripts, SKIN_PACK.PICK_JS), 1, "the chosen file is not thrown away")
	# Being read in.
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var arriving := FOLDER + "/arriving.zip"
	_files.append(arriving)
	pack._pick_file = FileAccess.open(arriving, FileAccess.WRITE)
	pack.state = "open"
	pack._pick_on_page()
	assert_eq(_count(pack.scripts, SKIN_PACK.PICK_JS), 1, "nor one being read in")
	pack._pick_file.close()
	pack._pick_file = null


func test_the_page_hears_only_the_newest_box() -> void:
	for js: String in [SKIN_PACK.PICK_JS, CardBack.CHOOSE_JS]:
		var input := "shandalarPickInput" if js == SKIN_PACK.PICK_JS else "shandalarBackInput"
		assert_string_contains(js, "var stale = window.%s;" % input, "the stale input is taken off the page")
		assert_string_contains(js, "if (window.%s !== input) { return; }" % input,
			"and a late word from it is not heard")


func test_a_second_card_back_press_opens_a_box_that_never_answered() -> void:
	var screen: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen._choose_card_back_on_page()
	var poll: Timer = screen._card_back_poll
	assert_not_null(poll, "the box is watched")
	assert_eq(_count(_scripts, CardBack.CHOOSE_JS), 1)
	screen._choose_card_back_on_page()
	assert_eq(_count(_scripts, CardBack.CHOOSE_JS), 2,
		"a second press opens it afresh instead of waiting until Options is opened again")
	assert_eq(screen._card_back_poll, poll, "one watch, still going")
	_page_state = "ready"
	screen._choose_card_back_on_page()
	assert_eq(_count(_scripts, CardBack.CHOOSE_JS), 2, "a chosen picture is not thrown away")
	screen._card_back_poll.stop()


# ------------------------------------------------------------- h6-6 --

func _card_packs_open_folder() -> Button:
	var page: Control = load("res://game/card_packs_screen.tscn").instantiate()
	add_child_autofree(page)
	await get_tree().process_frame
	return page.find_child("OpenFolder", true, false) as Button


func test_open_folder_is_off_on_a_headset_and_points_to_add_pack() -> void:
	CardPacksScreen.on_android = true
	var open := await _card_packs_open_folder()
	assert_not_null(open)
	if open == null: return
	assert_true(open.disabled, "no app on the headset opens the card folder")
	assert_string_contains(open.tooltip_text, CardPacksScreen.ADD_PACK, "and the way that works is named")


func test_open_folder_stays_on_a_desk() -> void:
	CardPacksScreen.on_android = false
	var open := await _card_packs_open_folder()
	assert_not_null(open)
	if open == null: return
	assert_eq(open.disabled, OS.has_feature("web"))


func _finished_draft() -> DraftSession:
	var pool := SealedPool.new()
	pool.counts = {"Lightning Bolt": 2, "Mountain": 20}
	var cards: Array[String] = []
	for card_name in pool.counts:
		for _i in pool.counts[card_name]: cards.append(card_name)
	pool.packs = [{"title": "Test pack", "cards": cards}]
	var store := DraftStore.new()
	assert_eq(store.prepare(FOLDER, pool, DraftPoolConfig.defaults()), "")
	_files.append_array([store.deck_path, store.pool_path,
		store.deck_path + ".pending", store.pool_path + ".pending"])
	var session := DraftSession.new()
	session.pool = pool
	session.store = store
	session.seconds = 600
	add_child_autofree(session)
	session.start_building()
	await get_tree().process_frame
	session.finish("done")
	return session


func _button_named(root: Node, text: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node
	return null


func test_open_save_folder_is_off_on_a_headset() -> void:
	DraftSession.on_android = true
	var session := await _finished_draft()
	var open := _button_named(session._result, "Open save folder")
	if OS.has_feature("web"):
		pass_test("the web build offers downloads instead")
		return
	assert_not_null(open)
	if open == null: return
	assert_true(open.disabled, "no file manager on the headset opens the save folder")
	assert_eq(open.tooltip_text, DraftSession.OPEN_FOLDER_ANDROID)


func test_open_save_folder_stays_on_a_desk() -> void:
	DraftSession.on_android = false
	var session := await _finished_draft()
	var open := _button_named(session._result, "Open save folder")
	assert_not_null(open)
	if open == null: return
	assert_false(open.disabled)
