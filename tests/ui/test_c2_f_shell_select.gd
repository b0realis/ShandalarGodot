extends GutTest
## ARKOS'S SELECT OPENS THE MENU EVEN AFTER A SEARCH (bug campaign
## 2026-10-12, finding b1-8). Select typed `q` — the pause key, and the
## Deck Builder's menu key — and a focused text field took it as a
## letter: after the R36 player used the search box (the on-screen
## keyboard's field), Select typed a `q` into the search and the menu that
## holds Exit game did not open. Select now types F10, which no text field
## types ([constant Controls.MENU_KEY]).

var screen: DeckBuilderScreen


func before_each() -> void:
	CardRegistry.ensure_loaded()
	screen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)
	screen.size = Vector2(1280, 800)
	await get_tree().process_frame


func after_each() -> void:
	var owner := get_viewport().gui_get_focus_owner()
	if owner != null:
		owner.release_focus()
	if screen != null and is_instance_valid(screen) and screen.is_menu_open():
		screen._toggle_deck_menu()


func _press(code: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	get_viewport().push_input(down)
	var up := down.duplicate()
	up.pressed = false
	get_viewport().push_input(up)


func test_select_opens_the_menu_with_the_search_box_focused() -> void:
	var search: LineEdit = screen._filter_bar.search_field
	search.grab_focus()
	await get_tree().process_frame
	_press(Controls.MENU_KEY)
	await get_tree().process_frame
	assert_true(screen.is_menu_open(), "Select (F10) opens the menu that holds Exit game")
	assert_eq(search.text, "", "and types nothing into the search")
	_press(Controls.MENU_KEY)
	await get_tree().process_frame
	assert_false(screen.is_menu_open(), "and closes it again, as Q does")


func test_q_still_types_into_the_search() -> void:
	var search: LineEdit = screen._filter_bar.search_field
	search.grab_focus()
	await get_tree().process_frame
	var q := InputEventKey.new()
	q.keycode = KEY_Q
	q.unicode = "q".unicode_at(0)
	q.pressed = true
	get_viewport().push_input(q)
	await get_tree().process_frame
	assert_eq(search.text, "q", "a desk player still searches for Quicksand")
	assert_false(screen.is_menu_open())
