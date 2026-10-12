extends GutTest
## OPTIONS AND CARD PACKS ANSWER THE KEYBOARD AND THE BACK KEY, AND THE
## CARD PACKS PAGE TELLS PACK 6 WHOLE (bug campaign 2026-10-12, findings
## r2-5, r2-9 and b2-8).
##
##  * Card Packs opened with nothing focused and answered no Escape: from
##    Options by keyboard it was a dead end without a mouse.
##  * Escape (the Quest's back gesture, the R36's Start, pad B) did
##    nothing on Options and Card Packs.
##  * Pack 6 is Portal AND Portal Second Age; the page counted Portal
##    alone and named only its Extras switch.

var _was: Node = null


func before_each() -> void:
	_was = get_tree().current_scene


func after_each() -> void:
	get_viewport().gui_release_focus()
	await get_tree().process_frame
	await get_tree().process_frame
	var scene := get_tree().current_scene
	if scene != null and scene != _was:
		scene.queue_free()
	get_tree().current_scene = _was if is_instance_valid(_was) else null
	CardPacks.set_enabled(PortalPack.ID, false)
	await get_tree().process_frame


func _key(code: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	get_viewport().push_input(down)
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	get_viewport().push_input(up)


func _pad(button: JoyButton) -> void:
	var down := InputEventJoypadButton.new()
	down.device = 0
	down.button_index = button
	down.pressed = true
	get_viewport().push_input(down)
	var up := down.duplicate() as InputEventJoypadButton
	up.pressed = false
	get_viewport().push_input(up)


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


func _open_as_scene(path: String) -> Control:
	var screen: Control = load(path).instantiate()
	get_tree().root.add_child(screen)
	get_tree().current_scene = screen
	await get_tree().process_frame
	await get_tree().process_frame
	return screen


# ------------------------------------------------------------- r2-5 --

func test_card_packs_opens_with_the_ring_on_it_and_keeps_it() -> void:
	var screen: Control = load("res://game/card_packs_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(_focus() != null and screen.is_ancestor_of(_focus()),
		"Card Packs opens with a control under the ring (focus=%s)" % _focus())
	for code in [KEY_TAB, KEY_UP, KEY_UP, KEY_DOWN, KEY_RIGHT]:
		_key(code)
		await get_tree().process_frame
	_pad(JOY_BUTTON_DPAD_UP)
	await get_tree().process_frame
	assert_true(_focus() != null and screen.is_ancestor_of(_focus()),
		"after Tab, arrows and D-pad something on Card Packs holds the ring (focus=%s)" % _focus())
	var scroll := screen.find_child("PackListScroll", true, false) as ScrollContainer
	assert_true(scroll.follow_focus, "the list follows the ring below its fold")


# ------------------------------------------------------------- r2-9 --

func test_escape_on_card_packs_goes_back_to_options() -> void:
	var screen := await _open_as_scene("res://game/card_packs_screen.tscn")
	_key(KEY_ESCAPE)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(is_instance_valid(screen) and screen.is_inside_tree(), "Card Packs left")
	assert_eq(get_tree().current_scene.scene_file_path, "res://game/options_screen.tscn")


func test_pad_b_on_options_goes_back_to_the_title() -> void:
	var screen := await _open_as_scene("res://game/options_screen.tscn")
	_pad(JOY_BUTTON_B)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(is_instance_valid(screen) and screen.is_inside_tree(), "Options left")
	assert_eq(get_tree().current_scene.scene_file_path, "res://game/main.tscn")


func test_escape_with_a_popup_up_closes_the_popup_first() -> void:
	var screen := await _open_as_scene("res://game/options_screen.tscn")
	var veil := UiChrome.explain_popup(screen, "A rule", "Its words")
	await get_tree().process_frame
	_key(KEY_ESCAPE)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(is_instance_valid(veil), "the popup closed")
	assert_true(screen.is_inside_tree(), "and Options stayed")
	_key(KEY_ESCAPE)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(is_instance_valid(screen) and screen.is_inside_tree(), "the next Escape leaves")


# ------------------------------------------------------------- b2-8 --

func test_pack_6_is_counted_and_named_with_both_of_its_sets() -> void:
	assert_true(CardPacks.has_pack(PortalPack.ID), "the test Pack 6 is available")
	CardPacks.set_enabled(PortalPack.ID, true)
	var screen: Control = load("res://game/card_packs_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var status := screen.find_child("Pack6Status", true, false) as Label
	var counts: Dictionary = PortalPack.COUNTS
	assert_string_contains(status.text, "%d names · %d printings · %d new identities" % [
		int(counts["distinct_cards"]), int(counts["published_printings"]),
		int(counts["new_rules_identities"])], "the manifest's counts for the whole pack")
	assert_string_contains(status.text, "Portal %d · Second Age %d" % [
		int(PortalPack.SET_COUNTS["por"][1]), int(PortalPack.SET_COUNTS["p02"][1])])
	assert_string_contains(status.text, "Extras > Portal, Second Age", "both switches")
	var heading_found := false
	for label in screen.find_children("*", "Label", true, false):
		if (label as Label).text.begins_with("6-POR") and (label as Label).text.contains("Second Age"):
			heading_found = true
	assert_true(heading_found, "the heading names the second set too")
