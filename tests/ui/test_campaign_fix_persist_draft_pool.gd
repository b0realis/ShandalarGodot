extends GutTest
## THE BOOSTER DRAFT SETUP ANSWERS AT ONCE (whole-game campaign 2026-10,
## w7 LOW: draft setup pool recompute).
##
## [DraftSetup] re-reads the eligible pool and re-validates it on every
## spin-box step and every keystroke in the save-folder field. With every
## card pack on the pool is 3,093 cards, and both halves de-duplicated
## with `Array.has` — [method DraftPoolConfig.selected] over the whole
## remembered list, [method SealedPool.sheets] over each rarity sheet —
## so one click cost ~178 ms and one keystroke ~97 ms. Both are linear
## now; their answers are pinned against the quadratic originals.
##
## WAVE 2: a keystroke in the save-folder field changes only the folder
## note under the pool line, so it refreshes only that
## ([method DraftSetup._refresh_folder_note]); the spin boxes and the
## card-pool chooser still re-read the pool.


## A setup that counts its whole-pool refreshes.
class RefreshCountingSetup extends DraftSetup:
	var pool_refreshes := 0

	func _refresh() -> void:
		pool_refreshes += 1
		super._refresh()

var _had := false
var _saved: Variant = null
var _was: Array[String] = []


func before_each() -> void:
	_had = Settings.has_value(DraftPoolConfig.SETTING)
	_saved = Settings.get_value(DraftPoolConfig.SETTING, [])
	_was = Settings.enabled_card_packs()


func after_each() -> void:
	if _had:
		Settings.set_value(DraftPoolConfig.SETTING, _saved, false)
	else:
		Settings.clear_value(DraftPoolConfig.SETTING)
	if Settings.enabled_card_packs() != _was:
		Settings.set_enabled_card_packs(_was)
		CardPacks._configure_registry()
	CardRegistry.ensure_loaded()


func _every_pack_on() -> void:
	Settings.set_enabled_card_packs(CardPacks.available_ids())
	CardPacks._configure_registry()
	CardRegistry.ensure_loaded()


## The pre-2026-10 [method DraftPoolConfig.selected], word for word.
func _selected_reference(saved: Variant) -> Array[String]:
	var out: Array[String] = []
	if saved is Array or saved is PackedStringArray:
		for entry in saved:
			if entry is String and CardRegistry.has_card(entry) and not out.has(entry) \
					and SealedPool.SLOT_ORDER.has(SealedPool.slot_of(entry)):
				out.append(entry)
	out.sort()
	return out


## The pre-2026-10 [method SealedPool.sheets], word for word.
func _sheets_reference(library: Array) -> Dictionary:
	var out := {"rare": [], "uncommon": [], "common": [], "land": []}
	for data in library:
		if data == null:
			continue
		var tier := "land" if SealedPool.LAND_NAMES.has(data.card_name) else DeckStats.rarity_of(data.card_name)
		if out.has(tier):
			if not out[tier].has(data.card_name): out[tier].append(data.card_name)
	for slot in out:
		out[slot].sort()
	return out


func _messy_list() -> Array:
	var names: Array = CardRegistry.all_names()
	var messy: Array = []
	messy.append_array(names)
	var backwards := names.duplicate()
	backwards.reverse()
	messy.append_array(backwards)
	messy.append_array(["No Such Card", 42, null, "", "Forest", "Forest"])
	return messy


func test_selected_answers_as_before() -> void:
	var messy := _messy_list()
	Settings.set_value(DraftPoolConfig.SETTING, messy, false)
	assert_eq(DraftPoolConfig.selected(), _selected_reference(messy), "deduplicated, filtered, sorted")
	var packed := PackedStringArray(["Island", "Forest", "Island", "Nonexistent"])
	Settings.set_value(DraftPoolConfig.SETTING, packed, false)
	assert_eq(DraftPoolConfig.selected(), ["Forest", "Island"] as Array[String])
	Settings.set_value(DraftPoolConfig.SETTING, "not a list", false)
	assert_eq(DraftPoolConfig.selected(), [] as Array[String])
	Settings.clear_value(DraftPoolConfig.SETTING)
	assert_eq(DraftPoolConfig.selected(), _selected_reference(CardRegistry.all_names()),
		"nothing remembered: every eligible card")


func test_sheets_answer_as_before() -> void:
	var library := DraftPoolConfig.library(DraftPoolConfig.selected())
	var twice := library.duplicate()
	twice.append_array(library)
	twice.append(null)
	assert_eq(SealedPool.sheets(twice), _sheets_reference(twice), "one name once per sheet")


## Every pack on, and the remembered list eight times over (24,000-odd
## entries, the duplicates a quadratic de-duplication pays for in full —
## ~450 ms before the fix, ~35 ms after, measured 2026-10-07):
## the whole of one setup refresh's pool work stays far inside a frame
## budget a click can wait for.
func test_the_pool_work_of_one_refresh_is_linear() -> void:
	_every_pack_on()
	var messy: Array = []
	for _i in 4:
		messy.append_array(_messy_list())
	Settings.set_value(DraftPoolConfig.SETTING, messy, false)
	var started := Time.get_ticks_msec()
	var names := DraftPoolConfig.selected()
	var refusal := DraftPoolConfig.validate(DraftPoolConfig.defaults(), names)
	var ms := Time.get_ticks_msec() - started
	gut.p("selected() + validate() over %d entries: %d ms" % [messy.size(), ms])
	assert_gt(names.size(), 2000, "every pack's cards are eligible")
	assert_eq(refusal, "")
	assert_lt(ms, 250, "selected() + validate() over %d remembered entries, ms" % messy.size())


func test_a_spin_step_and_a_keystroke_in_the_draft_setup_are_quick() -> void:
	_every_pack_on()
	Settings.clear_value(DraftPoolConfig.SETTING)
	var setup := DraftSetup.new()
	var holder := Control.new()
	add_child_autofree(holder)
	holder.add_child(Control.new())
	holder.add_child(setup)
	await get_tree().process_frame
	var started := Time.get_ticks_msec()
	setup.fields.boosters.value = 4
	var step_ms := Time.get_ticks_msec() - started
	started = Time.get_ticks_msec()
	for character in "/tmp/drafts":
		setup.folder.text += character
		setup.folder.text_changed.emit(setup.folder.text)
	var typing_ms := (Time.get_ticks_msec() - started) / 11.0
	assert_lt(step_ms, 150, "one click on a draft spin box, ms")
	assert_lt(typing_ms, 75.0, "one keystroke in the save-folder field, ms")


func _type(setup: DraftSetup, text: String) -> void:
	for character in text:
		setup.folder.text += character
		setup.folder.text_changed.emit(setup.folder.text)


func test_typing_in_the_save_folder_refreshes_only_the_folder_note() -> void:
	var setup := RefreshCountingSetup.new()
	add_child_autofree(setup)
	await get_tree().process_frame
	var before := setup.pool_refreshes
	assert_gt(before, 0, "the setup read the pool when it opened")
	setup.folder.text = ""
	_type(setup, DeckStore.USER_DIR)
	assert_eq(setup.pool_refreshes, before, "no keystroke re-reads the pool")
	assert_string_contains(setup.status.text, "cards to build with", "the pool half of the line stays")
	assert_false(setup.status.text.contains("Load deck lists only"),
		"the folder Load deck reads: no note")
	_type(setup, "/elsewhere")
	assert_eq(setup.pool_refreshes, before)
	assert_string_contains(setup.status.text, "Load deck lists only", "another folder: the note")
	assert_string_contains(setup.status.text, "cards to build with")
	setup.fields.boosters.value = 4
	assert_eq(setup.fields.boosters.value, 4.0, "the step stays")
	assert_eq(setup.pool_refreshes, before + 1, "a spin step still re-reads the pool")
	assert_string_contains(setup.status.text, "120 cards to build with")
	assert_string_contains(setup.status.text, "Load deck lists only", "and keeps the folder note")
	var reset: Button = null
	for node in setup.find_children("*", "Button", true, false):
		if (node as Button).text == "Default":
			reset = node
	assert_not_null(reset, "the Default button")
	if reset == null: return
	setup.folder.text = DeckStore.USER_DIR
	reset.pressed.emit()
	assert_eq(setup.folder.text, GamePaths.DEFAULT_DRAFTS)
	assert_eq(setup.status.text.contains("Load deck lists only"),
		not setup._folder_the_deck_pickers_read(), "Default refreshes the note for the folder it puts in")
	assert_eq(setup.pool_refreshes, before + 1)


## A STEP ON A SPIN BOX STAYS (found with the test above, 2026-10): every
## refresh asked [method DraftSetup.options], which `apply()`s each box's
## line edit — and inside `value_changed` that line edit still read the
## OLD number, so the step was undone at once and Boosters stayed at 3.
## An arrow click is the same step (`Range.value` plus `step`; a click
## pushed through the headless viewport does not reach the box, so the
## step is taken here directly). The refresh now reads the values;
## `Launch draft` still commits a number typed without Enter.
func test_a_step_on_a_spin_box_stays() -> void:
	var setup := DraftSetup.new()
	add_child_autofree(setup)
	await get_tree().process_frame
	var spin: SpinBox = setup.fields.boosters
	assert_eq(spin.value, 3.0, "the default")
	spin.value += spin.step
	assert_eq(spin.value, 4.0, "the step stays")
	assert_string_contains(setup.status.text, "120 cards to build with")
	var extras: SpinBox = setup.fields.extras
	extras.value += extras.step
	assert_eq(extras.value, 1.0)
	assert_eq(spin.value, 4.0, "and a step on another box leaves this one alone")
	assert_string_contains(setup.status.text, "121 cards to build with")
	spin.get_line_edit().text = "6"
	assert_eq(setup.options().boosters, 6, "a number typed without Enter still counts at Launch")
