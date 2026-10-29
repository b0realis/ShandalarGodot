extends GutTest
## THE SPELL CHAIN MINIMIZES, AND A CHAIN TOO LONG FOR THE SCREEN STAYS ON
## IT (the polish pass, 2026-10-28; P3 item 3 — the owner, round "open
## items": *"Spell Chain minimize"*).
##
## Manual p.122: *"you can minimize the Spell Chain window by clicking in
## its upper right corner. To restore the minimized window, click on the
## window icon in the center area of the Phase Bar."* `@MENU_SPELLCHAIN`
## (`UIStrings.txt:851`) is `Minimize` / `Help...` and
## `@MENU_MINIMIZEDSPELLCHAIN` (`:856`) `Restore` / `Help...`; both were
## tabled, `Minimize` grey, because our chain had no window to shrink. It
## has a title band now ([member DuelScreen._chain_head], `Spell Chain` —
## `@WINDOWTITLES[2]`) with the gadget at its right: minimized, the band is
## all that stands — the 1997 tab's job, at the chain's own place, since
## the Phase Bar's one centre band already holds the Combat window's icon
## [ours]. A fresh chain opens again, as a fresh attack opens its window.
##
## And the overflow (c12 h4-2 left it): the column slides its entries under
## one another down to [constant DuelScreen.ChainColumn.MIN_SHOWN] each; a
## chain longer than even that ran off the foot of the screen, the object
## that resolves NEXT — the last — first. Now the oldest go under the band
## instead, and the band counts them.

var screen: DuelScreen
var _next_id := 94300
const SCREEN := Vector2(1280, 800)


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen.size = SCREEN
	await get_tree().process_frame
	await get_tree().process_frame


func after_each() -> void:
	await get_tree().process_frame


func _push(card_name: String, controller := 0, x := 0) -> StackItem:
	var data := CardRegistry.get_card(card_name)
	var inst := CardInstance.new(data, _next_id, controller)
	_next_id += 1
	screen.game._instances[inst.id] = inst
	var item := StackItem.new()
	item.kind = Mtg.StackKind.SPELL
	item.controller = controller
	item.card = inst
	item.x_value = x
	item.description = "%s (test)" % card_name
	screen.game.stack.append(item)
	return item


func _chain(count: int) -> void:
	for i in count:
		if i % 2 == 0:
			_push("Fireball", 0, 3)
		else:
			_push("Lightning Bolt", 1)
	screen._refresh()
	await get_tree().process_frame
	await get_tree().process_frame


func _entries() -> Array[Control]:
	var out: Array[Control] = []
	for child in screen._chain_box.get_children():
		if (child as Control).is_visible_in_tree():
			out.append(child as Control)
	return out


func _labels(menu: PopupMenu) -> Array:
	var out: Array = []
	for i in menu.item_count:
		out.append([menu.get_item_text(i), menu.is_item_disabled(i)])
	return out


# =============================================================== minimize --

func test_the_chain_menus_minimize_and_restore_are_live() -> void:
	assert_true(bool(CardMenu.SPELL_CHAIN[0]["live"]), "Minimize is live")
	assert_true(bool(CardMenu.MINIMIZED_SPELL_CHAIN[0]["live"]), "Restore is live")
	await _chain(2)
	screen._open_chain_menu(Vector2.ZERO)
	assert_eq(_labels(screen._chain_menu), [["Minimize", false], ["Help...", false]])
	screen._chain_menu.hide()


func test_the_title_band_names_the_chain_and_counts_it() -> void:
	await _chain(3)
	assert_not_null(screen._chain_head, "the chain has a title band")
	assert_true(screen._chain_head.is_visible_in_tree(), "up while the chain is")
	assert_string_contains(screen._chain_head_text(), "Spell Chain")
	assert_string_contains(screen._chain_head_text(), "3")
	var band: Rect2 = screen._chain_head.get_global_rect()
	assert_lte(band.end.y, 150.0 + 0.5, "the band stands over the column, not in it")
	assert_almost_eq(band.position.x, screen._chain_box.get_global_rect().position.x, 0.5,
		"one column")


func test_minimize_leaves_the_tab_and_restore_brings_the_cards_back() -> void:
	await _chain(3)
	screen._open_chain_menu(Vector2.ZERO)
	screen._on_chain_menu_chosen(0)   # Minimize
	await get_tree().process_frame
	assert_true(screen.chain_minimized(), "minimized")
	assert_false(screen._chain_box.is_visible_in_tree(), "the cards are gone")
	assert_true(screen._chain_head.is_visible_in_tree(), "the tab stays")
	assert_string_contains(screen._chain_head_text(), "3", "and still counts the chain")
	# The minimized twin's menu.
	screen._open_chain_menu(Vector2.ZERO)
	assert_eq(_labels(screen._chain_menu), [["Restore", false], ["Help...", false]])
	screen._on_chain_menu_chosen(0)   # Restore
	await get_tree().process_frame
	assert_false(screen.chain_minimized())
	assert_true(screen._chain_box.is_visible_in_tree(), "the cards are back")


func test_the_gadget_and_a_click_on_the_tab() -> void:
	await _chain(2)
	screen._chain_gadget.pressed.emit()
	await get_tree().process_frame
	assert_true(screen.chain_minimized(), "the corner gadget minimizes")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	screen._on_chain_head_input(click)
	await get_tree().process_frame
	assert_false(screen.chain_minimized(), "a click on the tab restores — the window icon's job")


func test_a_fresh_chain_opens_again() -> void:
	await _chain(2)
	screen._set_chain_minimized(true)
	screen.game.stack.clear()
	screen._refresh()
	assert_false(screen.chain_minimized(), "the chain emptied: the next one opens")
	assert_false(screen._chain_head.is_visible_in_tree(), "no chain, no band")
	await _chain(1)
	assert_true(screen._chain_box.is_visible_in_tree())


func test_aiming_shows_a_minimized_chain() -> void:
	await _chain(2)
	screen._set_chain_minimized(true)
	screen.mode = DuelScreen.Mode.TARGETING
	screen._refresh()
	assert_true(screen._chain_box.is_visible_in_tree(),
		"a spell being aimed may want a card on the chain")
	screen.mode = DuelScreen.Mode.NORMAL
	screen._refresh()
	assert_false(screen._chain_box.is_visible_in_tree(), "and it goes again after")


# =============================================================== overflow --

func test_a_chain_longer_than_the_screen_keeps_its_top_whole_and_on_it() -> void:
	await _chain(40)
	var entries := _entries()
	assert_gt(entries.size(), 0)
	assert_lt(entries.size(), 40, "not all forty can show")
	for i in entries.size():
		var rect := entries[i].get_global_rect()
		assert_lte(rect.end.y, SCREEN.y + 0.5,
			"shown entry %d ends on the screen (%.0f)" % [i, rect.end.y])
	# The last child is the top of the chain — the object that resolves next.
	var last: Control = screen._chain_box.get_child(screen._chain_box.get_child_count() - 1)
	assert_true(last.is_visible_in_tree(), "the top of the chain is shown")
	assert_string_contains(screen._chain_head_text(), str(40 - entries.size()),
		"the band says how many went under it: %s" % screen._chain_head_text())


func test_a_chain_that_fits_hides_nothing() -> void:
	await _chain(6)
	assert_eq(_entries().size(), 6)
	assert_false(screen._chain_head_text().contains("not shown"))


# ================================================================ arrows --

func test_a_minimized_chains_arrows_spring_from_its_band() -> void:
	var g: MtgGame = screen.game
	var angel := CardInstance.new(CardRegistry.get_card("Serra Angel"), g._next_instance_id, 1)
	g._next_instance_id += 1
	g._instances[angel.id] = angel
	g._put_on_battlefield(angel, 1)
	var item := _push("Lightning Bolt", 0)
	item.targets.append(TargetRef.card(angel))
	screen._refresh()
	await get_tree().process_frame
	var from_card := false
	for link in screen._arrows.links():
		if link["from"] is int and int(link["from"]) == item.card.id:
			from_card = true
	assert_true(from_card, "control: open, the arrow springs from the chain's card")
	screen._set_chain_minimized(true)
	screen._update_arrows()
	var from_band := false
	for link in screen._arrows.links():
		if link["from"] == screen._chain_head:
			from_band = true
	assert_true(from_band, "minimized, it springs from the band — not from the hand window")
