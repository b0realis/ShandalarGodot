extends GutTest
## THE SECOND BUG HUNT (2026-10-21), the screens: Escape on Booster Draft.
##
## WAS: `DraftSetup.open_on` hides the screen it covers (Options or the
## Deck Builder) and disables it, so that screen's own Escape never ran —
## and the setup, its `Card pool…` chooser and its verifier had none of
## their own. Escape, a pad's B and the Quest's back gesture did nothing;
## only a click on `Back` left. NOW Escape peels one window: the verifier,
## then the chooser, then the setup itself, as `Back`.

var saved: Dictionary = {}
var previous: Control


func before_each() -> void:
	CardRegistry.ensure_loaded()
	for key in [DraftPoolConfig.SETTING, DraftPoolConfig.OPTIONS, GamePaths.KEY_DRAFTS]:
		saved[key] = Settings.get_value(key, 0) if Settings.has_value(key) else null
		Settings.clear_value(key)
	previous = Control.new()
	add_child_autofree(previous)


func after_each() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	for key in saved:
		if saved[key] == null: Settings.clear_value(key)
		else: Settings.set_value(key, saved[key], false)


func _escape() -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = "ui_cancel"
		ev.pressed = pressed
		Input.parse_input_event(ev)
	for i in 3:
		await get_tree().process_frame


func _open() -> DraftSetup:
	var setup := DraftSetup.open_on(previous)
	await get_tree().process_frame
	assert_false(previous.visible, "control: the setup covers the screen it came from")
	return setup


func _live(setup: DraftSetup, kind: Variant) -> Array:
	var out: Array = []
	for child in setup.get_children():
		if is_instance_of(child, kind) and not child.is_queued_for_deletion():
			out.append(child)
	return out


func _gone(setup: Variant) -> bool:   # untyped: it may be freed already
	return not is_instance_valid(setup) or (setup as Node).is_queued_for_deletion()


func test_escape_is_back() -> void:
	var setup := await _open()
	await _escape()
	assert_true(_gone(setup), "Escape left the setup")
	assert_true(previous.visible, "and the screen under it is back")


func test_escape_closes_the_verifier_first() -> void:
	var setup := await _open()
	(setup.find_child("VerifyDraftDeck", true, false) as Button).pressed.emit()
	assert_eq(_live(setup, DraftVerifier).size(), 1, "control: the verifier is up")
	await _escape()
	assert_eq(_live(setup, DraftVerifier).size(), 0, "the verifier went")
	assert_false(_gone(setup), "and only the verifier")
	await _escape()
	assert_true(_gone(setup))


func test_escape_closes_the_card_pool_first() -> void:
	var setup := await _open()
	(setup.find_child("DraftCardPool", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	assert_eq(_live(setup, DraftPoolDialog).size(), 1, "control: the chooser is up")
	await _escape()
	assert_eq(_live(setup, DraftPoolDialog).size(), 0, "the chooser went, unsaved")
	assert_false(_gone(setup))
	setup.close_setup()
