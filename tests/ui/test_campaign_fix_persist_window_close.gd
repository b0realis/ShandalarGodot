extends GutTest
## THE WINDOW'S CLOSE BUTTON ASKS BEFORE IT DROPS UNSAVED DECKS
## (whole-game campaign 2026-10, w7-7).
##
## `Exit game` and `Return to main menu` walk every slot with unsaved work
## through `@SAVE` ([method DeckBuilderScreen._confirm_discard_all]), and
## the Booster Draft session turns `auto_accept_quit` off so a close saves
## first. The ordinary builder left `auto_accept_quit` on and never
## handled NOTIFICATION_WM_CLOSE_REQUEST, so the title-bar X, Alt+F4 or
## Cmd+Q ended the process with three slots of unsaved decks and no
## question. The builder now takes the close request while it is open —
## unless someone else (the draft session) already holds it — and walks
## the same `@SAVE` questions `Exit game` asks.
##
## WAVE 2: `Booster Draft` hides the builder under [DraftSetup], and the
## X there — or during the draft session started there — quit at once over
## the builder's unsaved slots. The setup now holds the close for the
## builder it covers: it brings the builder back to ask, and a session it
## started saves the draft first and then hands the quit to the setup.

const DECK_NAME := "Campaign Close Saves"
const DRAFTS := "user://campaign_fix_persist_drafts"


## A builder whose process end is COUNTED rather than obeyed: the real
## [method DeckBuilderScreen._end_process] quits the test runner with it.
class QuitSpyBuilder extends DeckBuilderScreen:
	var quits := 0

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		super._ready()

	func _end_process() -> void:
		quits += 1


## A draft setup whose process end is counted the same way.
class QuitSpySetup extends DraftSetup:
	var quits := 0

	func _end_process() -> void:
		quits += 1


var _policy_before := true
var _saved_settings: Dictionary = {}
var _holder: Control = null


func before_each() -> void:
	_policy_before = get_tree().auto_accept_quit
	# The game's own policy outside the builder and the draft.
	get_tree().auto_accept_quit = true
	CardRegistry.ensure_loaded()
	# A launched draft remembers its folder and options; put them back.
	for key in [DraftPoolConfig.SETTING, DraftPoolConfig.OPTIONS, GamePaths.KEY_DRAFTS]:
		_saved_settings[key] = Settings.get_value(key, 0) if Settings.has_value(key) else null


func after_each() -> void:
	var path := DeckStore.path_for(DECK_NAME)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if _holder != null and is_instance_valid(_holder):
		_holder.free()
	_holder = null
	await get_tree().process_frame
	var drafts := DirAccess.open(DRAFTS)
	if drafts != null:
		for f in drafts.get_files():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(DRAFTS.path_join(f)))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DRAFTS))
	for key in _saved_settings:
		if _saved_settings[key] == null: Settings.clear_value(key)
		else: Settings.set_value(key, _saved_settings[key], false)
	get_tree().auto_accept_quit = _policy_before


func _builder(autofree := true) -> QuitSpyBuilder:
	var builder := QuitSpyBuilder.new()
	if autofree:
		add_child_autofree(builder)
	else:
		add_child(builder)
	await get_tree().process_frame
	return builder


func _walk(node: Node) -> Array:
	var out := [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out


func _answer(builder: DeckBuilderScreen, label: String) -> void:
	var dialogs := builder.open_dialogs()
	assert_gt(dialogs.size(), 0, "a dialog is asking")
	if dialogs.is_empty(): return
	for node in _walk(dialogs[-1]):
		if node is Button and node.text == label:
			node.pressed.emit()
			return
	fail_test("no '%s' button in the dialog" % label)


func _close(builder: DeckBuilderScreen) -> void:
	builder._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)


func test_the_builder_holds_the_close_request_while_it_is_open() -> void:
	var builder := await _builder(false)
	assert_false(get_tree().auto_accept_quit, "a close request now reaches the builder first")
	remove_child(builder)
	assert_true(get_tree().auto_accept_quit, "and the game's own policy is back once it goes")
	add_child(builder)
	assert_false(get_tree().auto_accept_quit, "back in the tree, it holds it again")
	remove_child(builder)
	builder.free()
	assert_true(get_tree().auto_accept_quit)


func test_a_close_with_nothing_unsaved_closes_at_once() -> void:
	var builder := await _builder()
	_close(builder)
	assert_eq(builder.quits, 1, "no question to ask")
	assert_eq(builder.open_dialogs().size(), 0)


func test_a_close_with_unsaved_work_asks_and_cancel_keeps_the_window() -> void:
	var builder := await _builder()
	assert_true(builder._add_one("Mountain"))
	_close(builder)
	assert_eq(builder.quits, 0, "not before the question is answered")
	assert_eq(builder.open_dialogs().size(), 1, "@SAVE asks about the deck")
	_answer(builder, "Cancel")
	assert_eq(builder.quits, 0, "Cancel keeps the window")
	assert_eq(builder.deck.count_of("Mountain"), 1, "and the deck")
	_close(builder)
	_answer(builder, "No")
	assert_eq(builder.quits, 1, "No lets it go")


func test_every_unsaved_slot_is_asked_about() -> void:
	var builder := await _builder()
	assert_true(builder._add_one("Mountain"))
	builder._switch_slot(1)
	assert_true(builder._add_one("Island"))
	assert_eq(builder._unsaved_slots(), [0, 1] as Array[int])
	_close(builder)
	_answer(builder, "No")
	assert_eq(builder.quits, 0, "one slot answered, one to go")
	_answer(builder, "No")
	assert_eq(builder.quits, 1)


func test_yes_saves_the_deck_before_the_window_goes() -> void:
	var builder := await _builder()
	builder.deck.deck_name = DECK_NAME
	for _i in 3:
		assert_true(builder._add_one("Mountain"))
	_close(builder)
	_answer(builder, "Yes")
	assert_eq(builder.quits, 1)
	var path := DeckStore.path_for(DECK_NAME)
	assert_true(FileAccess.file_exists(path), "saved first")
	assert_string_contains(DeckStore.read_text(path), "3 Mountain")


func test_a_close_under_an_open_window_is_not_lost_silently() -> void:
	var builder := await _builder()
	assert_true(builder._add_one("Mountain"))
	builder._run_command("Stats")
	var open := builder.open_dialogs().size()
	assert_gt(open, 0, "a window is up")
	_close(builder)
	assert_eq(builder.quits, 0, "unsaved work under a window: not closed")
	assert_eq(builder.open_dialogs().size(), open, "no second dialog stacked on the first")
	assert_string_contains(builder._status_label.text, "not saved", "the status line says why")


## The draft session turns `auto_accept_quit` off BEFORE it builds its
## [DraftBuilder] and saves on a close itself; the builder inside it must
## neither take the request nor hand the policy back on its way out.
func test_a_builder_whose_close_someone_else_holds_leaves_it_alone() -> void:
	get_tree().auto_accept_quit = false
	var builder := await _builder(false)
	assert_true(builder._add_one("Mountain"))
	_close(builder)
	assert_eq(builder.quits, 0)
	assert_eq(builder.open_dialogs().size(), 0, "the owner of the close asks, not this builder")
	remove_child(builder)
	assert_false(get_tree().auto_accept_quit, "left as its owner set it")
	builder.free()


## `Booster Draft` hides the builder under [DraftSetup], and the draft
## session that starts there saves on a close itself. A question asked on
## a hidden builder would hold the window shut with nothing to answer, so
## a hidden builder lets the close go, and takes it back once it is shown.
func test_a_builder_hidden_behind_another_screen_lets_the_close_go() -> void:
	var builder := await _builder()
	assert_true(builder._add_one("Mountain"))
	builder.hide()
	assert_true(get_tree().auto_accept_quit, "the screen on top keeps the close it always had")
	_close(builder)
	assert_eq(builder.open_dialogs().size(), 0, "no question on a screen nobody can see")
	assert_eq(builder.quits, 0)
	builder.show()
	assert_false(get_tree().auto_accept_quit, "shown again, the builder holds it")
	var setup := DraftSetup.open_on(builder)
	assert_false(builder.visible, "sanity: the draft setup covers the builder")
	assert_false(builder._holds_window_close, "under the draft setup the close is not the builder's")
	assert_true(setup._holds_window_close, "the setup holds it for the builder")
	assert_false(get_tree().auto_accept_quit)
	setup.close_setup()
	await get_tree().process_frame
	assert_true(builder.visible)
	assert_true(builder._holds_window_close, "back from the draft setup, the builder holds it again")
	assert_false(get_tree().auto_accept_quit)
	_close(builder)
	assert_eq(builder.open_dialogs().size(), 1, "and it asks")


func test_exit_game_still_asks_and_ends_by_the_same_door() -> void:
	var builder := await _builder()
	assert_true(builder._add_one("Mountain"))
	builder._quit_game()
	assert_eq(builder.open_dialogs().size(), 1)
	_answer(builder, "No")
	assert_eq(builder.quits, 1)


# ------------------------------------------- wave 2: the draft setup --

## The builder and the screens `Booster Draft` puts beside it share a
## parent, as they do under the scene root; a close request reaches them
## in tree order, the builder first.
func _builder_under_a_holder() -> QuitSpyBuilder:
	_holder = Control.new()
	add_child(_holder)
	var builder := QuitSpyBuilder.new()
	_holder.add_child(builder)
	await get_tree().process_frame
	return builder


## The window hands its close request down the tree parent first, a node's
## children after it — and, unlike [method Node.propagate_notification],
## without locking each parent while its children hear it (the draft
## session adds its result window from inside the request).
func _close_window() -> void:
	_notify_down(_holder, Node.NOTIFICATION_WM_CLOSE_REQUEST)


func _notify_down(node: Node, what: int) -> void:
	node.notification(what)
	for child in node.get_children():
		_notify_down(child, what)


func _session_of(setup: DraftSetup) -> DraftSession:
	for child in setup.get_children():
		if child is DraftSession and not child.is_queued_for_deletion():
			return child
	return null


func _launch_draft(setup: DraftSetup) -> DraftSession:
	setup.folder.text = DRAFTS
	setup._launch()
	var session := _session_of(setup)
	assert_not_null(session, "a draft session started")
	if session != null:
		session.start_building()
	return session


func test_a_close_under_the_draft_setup_brings_the_builder_back_to_ask() -> void:
	var builder := await _builder_under_a_holder()
	assert_true(builder._add_one("Mountain"))
	var setup := DraftSetup.open_on(builder, QuitSpySetup.new()) as QuitSpySetup
	await get_tree().process_frame
	assert_false(get_tree().auto_accept_quit, "the setup holds the close over unsaved work")
	_close_window()
	assert_eq(setup.quits, 0, "not before the builder's question is answered")
	assert_true(builder.visible, "the builder is back on show")
	assert_ne(builder.process_mode, Node.PROCESS_MODE_DISABLED, "and answers input again")
	assert_eq(builder.open_dialogs().size(), 1, "@SAVE asks about its deck")
	assert_true(setup.is_queued_for_deletion(), "the draft setup is closed")
	await get_tree().process_frame
	assert_false(get_tree().auto_accept_quit, "the builder holds the close again")
	_answer(builder, "No")
	assert_eq(builder.quits, 1, "No lets the window go")


func test_a_close_under_the_draft_setup_with_nothing_unsaved_closes() -> void:
	var builder := await _builder_under_a_holder()
	var setup := DraftSetup.open_on(builder, QuitSpySetup.new()) as QuitSpySetup
	await get_tree().process_frame
	_close_window()
	assert_eq(setup.quits, 1, "nothing to ask")
	assert_eq(builder.quits, 0)
	assert_eq(builder.open_dialogs().size(), 0)


func test_a_close_during_a_draft_from_the_builder_saves_the_draft_then_asks() -> void:
	var builder := await _builder_under_a_holder()
	assert_true(builder._add_one("Mountain"))
	var setup := DraftSetup.open_on(builder, QuitSpySetup.new()) as QuitSpySetup
	await get_tree().process_frame
	var session := _launch_draft(setup)
	if session == null: return
	assert_false(get_tree().auto_accept_quit, "the session holds the close while it runs")
	_close_window()
	assert_true(session.finished, "the session finished the draft")
	assert_eq(session._save_warning, "")
	assert_true(FileAccess.file_exists(session.store.deck_path), "and saved it first")
	assert_eq(setup.quits, 0)
	assert_eq(builder.quits, 0, "the builder's own deck is asked about")
	assert_true(builder.visible)
	assert_eq(builder.open_dialogs().size(), 1)
	_answer(builder, "No")
	assert_eq(builder.quits, 1)
	await get_tree().process_frame
	assert_false(is_instance_valid(session), "the finished draft went with its setup")
	assert_false(get_tree().auto_accept_quit, "and the builder holds the close")


func test_a_close_during_a_draft_with_nothing_unsaved_quits_after_the_save() -> void:
	var builder := await _builder_under_a_holder()
	var setup := DraftSetup.open_on(builder, QuitSpySetup.new()) as QuitSpySetup
	await get_tree().process_frame
	var session := _launch_draft(setup)
	if session == null: return
	_close_window()
	assert_true(FileAccess.file_exists(session.store.deck_path), "the draft is saved")
	assert_eq(setup.quits, 1, "and the window goes")
	assert_eq(builder.open_dialogs().size(), 0)


## The draft session's own holding is unchanged: it holds the close while it
## runs and puts back what it found — the setup's hold — when it goes; the
## setup hands it to the builder on Back; a setup over any other screen
## (Options) leaves the policy alone, and the session restores that.
func test_who_holds_the_close_through_a_draft_and_back() -> void:
	var builder := await _builder_under_a_holder()
	var setup := DraftSetup.open_on(builder, QuitSpySetup.new()) as QuitSpySetup
	await get_tree().process_frame
	var session := _launch_draft(setup)
	if session == null: return
	session.finish("done")
	session.return_to_setup()
	await get_tree().process_frame
	assert_true(setup._holds_window_close, "back at the setup, it still holds the close")
	assert_false(get_tree().auto_accept_quit)
	setup.close_setup()
	await get_tree().process_frame
	assert_true(builder._holds_window_close, "Back hands it to the builder")
	assert_false(get_tree().auto_accept_quit)
	_holder.free()
	_holder = null
	assert_true(get_tree().auto_accept_quit, "and the builder hands it back when it goes")
	var screen := Control.new()
	add_child_autofree(screen)
	var other := DraftSetup.open_on(screen, QuitSpySetup.new()) as QuitSpySetup
	await get_tree().process_frame
	assert_false(other._holds_window_close, "a setup over Options leaves the policy alone")
	assert_true(get_tree().auto_accept_quit)
	var drafted := _launch_draft(other)
	if drafted == null: return
	assert_false(get_tree().auto_accept_quit, "its session holds the close")
	drafted.finish("done")
	drafted.return_to_setup()
	await get_tree().process_frame
	assert_true(get_tree().auto_accept_quit, "and puts back what it found")
	other.queue_free()
