extends GutTest
## THE SHELL'S POPUPS HOLD THE RING, AND GIVE IT BACK (bug campaign
## 2026-10-12, finding r2-2).
##
## A [method UiChrome.action_popup] grabbed the focus for its first button
## and did nothing else: the arrows walked the ring OFF the popup onto the
## buttons under the veil (Enter then pressed a covered button), and when
## the popup closed the ring went to nothing — the title after the
## Shandalar placeholder or a set badge, Options after rebinding a key —
## so the keyboard and a D-pad with the pad pointer off had nothing left
## to move from.

var _saved_controls: Variant = null


func before_each() -> void:
	_saved_controls = Settings.get_value(Controls.SETTINGS_KEY, null) \
		if Settings.has_value(Controls.SETTINGS_KEY) else null
	Controls.reset()


func after_each() -> void:
	get_viewport().gui_release_focus()
	Controls.reset()
	if _saved_controls != null:
		Settings.set_value(Controls.SETTINGS_KEY, _saved_controls)
		Controls.apply()


func _key(code: Key, shift := false) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	down.shift_pressed = shift
	get_viewport().push_input(down)
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	get_viewport().push_input(up)


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


## A host with three buttons under where the popup will open.
func _host() -> Control:
	var host := Control.new()
	host.size = Vector2(1280, 800)
	add_child_autofree(host)
	for i in 3:
		var b := Button.new()
		b.name = "Under%d" % i
		b.text = "under %d" % i
		b.position = Vector2(500 + 120 * i, 300 + 60 * i)
		b.size = Vector2(110, 40)
		host.add_child(b)
	return host


func test_the_arrows_and_tab_stay_on_a_one_button_popup() -> void:
	var host := _host()
	(host.get_node("Under0") as Button).grab_focus()
	var veil := UiChrome.explain_popup(host, "Title", "Body")
	await get_tree().process_frame
	var ok := veil.find_child("OK", true, false) as Button
	assert_eq(_focus(), ok, "OK holds the ring")
	var escaped := []
	for step in [[KEY_DOWN, false], [KEY_UP, false], [KEY_LEFT, false], [KEY_RIGHT, false],
			[KEY_TAB, false], [KEY_TAB, true]]:
		_key(step[0], step[1])
		await get_tree().process_frame
		if _focus() != ok:
			escaped.append("%s -> %s" % [OS.get_keycode_string(step[0]), _focus()])
			ok.grab_focus()
	assert_eq(escaped, [], "the ring stays on the popup")


func test_the_ring_walks_the_row_of_a_popup_with_several_actions() -> void:
	var host := _host()
	var veil := UiChrome.action_popup(host, "Title", "Body", [
		{"label": "One", "name": "One"},
		{"label": "Off", "name": "Off", "disabled": true},
		{"label": "Two", "name": "Two"},
	])
	await get_tree().process_frame
	var one := veil.find_child("One", true, false) as Button
	var two := veil.find_child("Two", true, false) as Button
	assert_eq(_focus(), one)
	_key(KEY_RIGHT)
	await get_tree().process_frame
	assert_eq(_focus(), two, "Right skips the greyed one")
	_key(KEY_RIGHT)
	await get_tree().process_frame
	assert_eq(_focus(), one, "and wraps")
	_key(KEY_DOWN)
	await get_tree().process_frame
	assert_eq(_focus(), one, "Down leaves nothing to go to")
	_key(KEY_TAB)
	await get_tree().process_frame
	assert_eq(_focus(), two, "Tab walks the row")


func test_the_ring_comes_back_to_where_it_was_when_the_popup_closes() -> void:
	var host := _host()
	var opener := host.get_node("Under1") as Button
	opener.grab_focus()
	var veil := UiChrome.explain_popup(host, "Title", "Body")
	await get_tree().process_frame
	(veil.find_child("OK", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(_focus(), opener, "the button that opened it holds the ring again")


func test_a_popup_opened_by_a_popup_keeps_the_ring() -> void:
	var host := _host()
	(host.get_node("Under0") as Button).grab_focus()
	var second := [null]
	var first := UiChrome.action_popup(host, "First", "Body", [
		{"label": "Next", "name": "Next", "callable": func() -> void:
			second[0] = UiChrome.explain_popup(host, "Second", "Body")},
	])
	await get_tree().process_frame
	(first.find_child("Next", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var ok := (second[0] as Control).find_child("OK", true, false) as Button
	assert_eq(_focus(), ok, "the closing popup does not take the ring off the new one")


func test_the_title_gets_the_ring_back_after_the_placeholder() -> void:
	var menu: Control = load("res://game/main.tscn").instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame
	var shandalar: Button = null
	for n in menu.find_children("*", "Button", true, false):
		if (n as Button).text == "Shandalar":
			shandalar = n
	assert_not_null(shandalar)
	shandalar.grab_focus()
	_key(KEY_ENTER)
	await get_tree().process_frame
	assert_true(_focus() is Button and (_focus() as Button).name == "OK", "the popup's OK holds the ring")
	_key(KEY_DOWN)
	await get_tree().process_frame
	assert_true(_focus() is Button and (_focus() as Button).name == "OK", "Down cannot reach the menu under the veil")
	_key(KEY_ENTER)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(_focus(), shandalar, "after the popup closes the ring is back on the button")


func test_rebinding_a_key_leaves_the_ring_on_its_slot() -> void:
	var screen: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var slot := screen.find_child("Key_duel_log", true, false) as Button
	slot.grab_focus()
	_key(KEY_ENTER)
	await get_tree().process_frame
	assert_not_null(screen.find_child("ControlsListener", true, false), "the popup listens")
	_key(KEY_K)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(Controls.key_text("duel_log"), "K")
	assert_eq(_focus(), slot, "the ring is back on the slot that was rebound")
	_key(KEY_DOWN)
	await get_tree().process_frame
	assert_true(_focus() != null and screen.is_ancestor_of(_focus()),
		"and the arrows walk on from there (focus=%s)" % _focus())
