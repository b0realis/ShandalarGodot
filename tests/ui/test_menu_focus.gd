extends GutTest
## THE MENUS WALK WITH THE D-PAD — the shell (`game/main.gd`), the
## Options screen (`game/options_screen.gd`), the battle setup
## (`game/setup_screen.gd`) and the gauntlet's startup window
## (`game/duel/original_dialog.gd`, `gauntlet_screen.gd`) each give one
## button the focus as they open.
##
## `[QoL]`, 2026-09-27, the Steam Deck release. The engine's focus ring
## walks on the arrows, the D-pad and the left stick (`ui_up`...), and
## presses on Enter, Space and — since the same day, `project.godot` —
## the pad's A; but a ring has to START somewhere, and until now no
## screen gave it anywhere, so the first press of a D-pad did nothing.
## The pad pointer (`PadControls`) is what the pad drives while it is
## on; the ring is what the keyboard drives always and the pad drives
## with the pointer off. The duel keeps its hands off the ring on
## purpose (a focused card would eat the Spacebar rule); the Deck
## Builder's own test pins that it opens with no focus.

func after_each() -> void:
	get_viewport().gui_release_focus()
	SetupScreen.forget_choices()


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


func test_the_shell_opens_with_magic_battle_under_the_ring() -> void:
	var menu: Control = load("res://game/main.tscn").instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame
	var owner := _focus()
	assert_not_null(owner, "something holds the focus")
	assert_true(owner is Button and (owner as Button).text == "Magic Battle",
		"the first entry of the menu, where the 1997 cursor rested: %s" % owner)
	assert_eq(owner.focus_mode, Control.FOCUS_ALL)


func test_the_options_screen_opens_with_its_first_switch_under_the_ring() -> void:
	var screen: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var owner := _focus()
	assert_not_null(owner)
	assert_true(owner is CheckButton and (owner as CheckButton).text == "Full screen",
		"the first row of Display, the first section: %s" % owner)
	var scroll: ScrollContainer = null
	for node in _walk(screen):
		if node is ScrollContainer:
			scroll = node
	assert_not_null(scroll, "the rows sit in a scroller")
	assert_true(scroll.follow_focus, "that follows the ring down the list")


func test_the_battle_setup_opens_with_its_chosen_mode_under_the_ring() -> void:
	var screen: Control = load("res://game/setup_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var owner := _focus()
	assert_not_null(owner)
	assert_true(owner is BaseButton and screen._mode_buttons.has(owner),
		"one of the mode buttons: %s" % owner)
	assert_true((owner as BaseButton).button_pressed, "the chosen one")


func test_the_gauntlets_startup_window_puts_run_under_the_ring() -> void:
	var options := GauntletOptions.new()
	var dialog := options.window(["res://decks/big_green.deck"] as Array[String],
		func() -> void: pass, func() -> void: pass)
	add_child_autofree(dialog)
	await get_tree().process_frame
	assert_null(_focus(), "the window alone asks for nothing")
	dialog.focus_first_button()
	var owner := _focus()
	assert_not_null(owner, "the screen's `_show_options` asks after adding it")
	assert_true(owner is Button and (owner as Button).text == GauntletOptions.RUN,
		"the first of its foot row: %s" % owner)
	assert_true(dialog.is_ancestor_of(owner))


func test_the_dialog_asks_for_nothing_outside_the_tree() -> void:
	var dialog := OriginalDialog.create("Nothing", Vector2(200, 100), "panel_dark_stone")
	dialog.add_button("OK")
	dialog.focus_first_button()
	assert_null(_focus(), "no tree, no viewport, no error above this line")
	dialog.free()


func _walk(node: Node) -> Array:
	var out := [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out
