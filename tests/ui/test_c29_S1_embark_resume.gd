extends GutTest
## EMBARK AND RESUME WITHOUT A FROZEN WINDOW (0.60.15, the owner's ruling of
## 2026-11-03, c29 S1): setting out — or resuming a campaign — with its
## packs switched off in Options rebuilt the card pool once a pack on the
## thread that draws, before the hourglass showed: 3.3–5.3 s frozen with
## Packs 2–9. Now the hourglass shows first, the packs go on in one rebuild
## compiled on a thread, and the world comes when the pool is ready. A
## refusal that comes after the hourglass gives the screen back.

const FOLDER := "user://c29_s1_load"

var screen: EmbarkScreen
var _enabled_before: Array[String] = []
var _locker := RefCounted.new()


func before_each() -> void:
	_enabled_before = Settings.enabled_card_packs().duplicate()
	AdventureSetup.forget()
	AdventurePlayer.saves_folder = FOLDER
	_clear()
	screen = load("res://game/adventure/embark_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	CardPacks.unlock_catalogue(_locker)
	CardRegistry.ensure_loaded()
	for node in get_tree().root.get_children():
		if node is WorldScreen:
			node.free()
	_clear()
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER
	AdventureSetup.forget()
	for id in CardPacks.available_ids():
		if CardPacks.is_enabled(id) != (id in _enabled_before):
			CardPacks.set_enabled(id, id in _enabled_before)


func _clear() -> void:
	var dir := DirAccess.open(FOLDER)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
	AdventurePlayer.forget_saves()


func _offered() -> Array[String]:
	return AdventureSetup.offered_packs(CardPacks.available_ids())


func _switch(on: Array) -> void:
	for id in CardPacks.available_ids():
		if CardPacks.is_enabled(id) != (id in on):
			CardPacks.set_enabled(id, id in on)


func _ready_to_set_out(ids: Array[String]) -> void:
	screen.packs_aside = true
	for id in ids:
		(screen._pack_checks[id] as CheckBox).button_pressed = true
	(screen.find_child("HeroName", true, false) as LineEdit).text = "Quick Hands"


## The hourglass first, the click's frame switching nothing; then the
## packs on in one rebuild built on a thread, and the hero sets out.
func test_the_hourglass_shows_before_the_packs_go_on() -> void:
	var ids := _offered()
	if ids.is_empty():
		pass_test("no pack installed here")
		return
	_switch([])
	_ready_to_set_out(ids)
	watch_signals(screen)
	var before := CardRegistry.revision
	screen.embark()
	assert_not_null(screen.find_child("Conjuration", true, false), "the hourglass shows")
	assert_true(screen.adventure_button.disabled, "the choices held still")
	assert_eq(CardRegistry.revision, before, "nothing rebuilt in the click's frame")
	for id in ids:
		assert_false(CardPacks.is_enabled(id), id + " not yet switched")
	await wait_for_signal(screen.embarked, 20, "the hero sets out")
	assert_signal_emitted(screen, "embarked")
	assert_eq(CardRegistry.revision - before, 1, "one rebuild")
	assert_true(CardRegistry.is_loading() or CardRegistry.poll(), "built on its thread (or done already)")
	for id in ids:
		assert_true(CardPacks.is_enabled(id), id + " on")
	var record: Dictionary = get_signal_parameters(screen, "embarked")[0]
	assert_eq((record["packs"] as Array).size(), ids.size(), "the record keeps them")
	CardRegistry.ensure_loaded()


## A refusal that comes after the hourglass (a session took the catalogue
## meanwhile) gives the choices back and says why; nothing is switched.
func test_a_late_refusal_gives_the_screen_back() -> void:
	var ids := _offered()
	if ids.is_empty():
		pass_test("no pack installed here")
		return
	_switch([])
	_ready_to_set_out(ids)
	watch_signals(screen)
	screen.embark()
	CardPacks.lock_catalogue(_locker)
	await wait_frames(4)
	assert_signal_not_emitted(screen, "embarked")
	assert_null(screen._wait, "the hourglass put away")
	assert_false(screen.adventure_button.disabled, "Adventure can be pressed again")
	assert_true(screen.adventure_button.visible)
	var note := screen.find_child("Note", true, false) as Label
	assert_true(note.visible and note.text.contains("SGManalink"), "the refusal said: " + note.text)
	for id in ids:
		assert_false(CardPacks.is_enabled(id), id + " still off")


## Packs already on: nothing to switch, the screen sets out at once, as it
## always did.
func test_packs_already_on_set_out_at_once() -> void:
	var ids := _offered()
	if ids.is_empty():
		pass_test("no pack installed here")
		return
	_switch(ids)
	_ready_to_set_out(ids)
	watch_signals(screen)
	var before := CardRegistry.revision
	screen.embark()
	assert_signal_emitted(screen, "embarked", "in the click itself")
	assert_eq(CardRegistry.revision, before, "nothing rebuilt")


## RESUME: a save whose pack is off is taken up with the hourglass in the
## buttons' place while its pack goes on, built on a thread; the world is
## put up when the pool is ready, its arrival naming the pack.
func test_resume_waits_under_the_hourglass() -> void:
	var ids := _offered()
	if ids.is_empty():
		pass_test("no pack installed here")
		return
	var one: Array[String] = [ids[0]]
	_switch(one)
	var setup := AdventureSetup.new()
	setup.player_name = "Mira Thorn"
	setup.seed_text = "48271"
	setup.packs = one
	var record := setup.resolve({ids[0]: "1.0.0"})
	AdventurePlayer.begin(record, AdventureSetup.make_world(record)).autosave()
	_switch([])
	var list: LoadAdventureScreen = load("res://game/adventure/load_adventure_screen.tscn").instantiate()
	add_child_autofree(list)
	await get_tree().process_frame
	list.packs_aside = true
	var row := list.initial_selection()
	assert_gt(row, 0, "control: the autosave is listed")
	var before := CardRegistry.revision
	assert_true(list.continue_adventure(row), "taken up")
	assert_true(CardRegistry.is_loading(), "its pack builds on a thread")
	assert_true(CardPacks.is_enabled(ids[0]), "switched on")
	assert_not_null(list.find_child("Waiting", true, false), "the hourglass shows")
	assert_false(list.resume_button.visible, "in the buttons' place")
	assert_null(_world(), "no world yet")
	await wait_until(func() -> bool: return _world() != null, 20, "the world comes")
	var world := _world()
	assert_not_null(world, "the world put up once the pool is ready")
	assert_eq(CardRegistry.revision - before, 1, "one rebuild")
	if world != null:
		assert_string_contains(world.arrival, "enabled for this adventure", "the arrival names the pack")


func _world() -> WorldScreen:
	for node in get_tree().root.get_children():
		if node is WorldScreen:
			return node
	return null
