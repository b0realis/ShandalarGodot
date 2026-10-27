extends GutTest
## `ORIGINAL TYPE` SHOWS WHAT IS PRINTED ON THE CARD (the bug campaign c12,
## h4-7).
##
## `Duel.hlp`, **Territory**: *"shows you what this card was when it was
## cast, before any spells and effects changed it."* The entry drew
## `inst.data`, which for a copy IS the copied card, so a Clone that had
## copied Serra Angel showed "Serra Angel / Creature — Angel". It now shows
## the card's own printed card ([member CardInstance.printed_data]) through
## [method CardPreview.show_card]'s `printed`, and it is offered only on a
## copy — anywhere else the card is what is printed on it, which the
## Showcase already shows.

var screen: DuelScreen

## `Original type` — entry 1 of `@MENU_SMALLCARD`, id 0 in the table
## ([constant DuelScreen.CARD_MENU_ORIGINAL_TYPE]).
const ORIGINAL_TYPE := 0


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _summon(pid: int, card_name: String) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name),
		g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	g._put_on_battlefield(inst, pid)
	inst.summoning_sick = false
	return inst


func _a_clone_of_serra_angel() -> CardInstance:
	var clone := _summon(0, "Clone")
	screen.game.become_copy(clone, CardRegistry.get_card("Serra Angel"))
	assert_eq(clone.data.card_name, "Serra Angel", "control: the Clone is a Serra Angel")
	return clone


func _entry_disabled(id: int) -> bool:
	return screen._card_menu.is_item_disabled(screen._card_menu.get_item_index(id))


func test_original_type_shows_the_clone_as_a_clone() -> void:
	var clone := _a_clone_of_serra_angel()
	screen._open_card_menu(clone, Vector2.ZERO)
	screen._card_menu.hide()
	assert_false(_entry_disabled(ORIGINAL_TYPE),
		"offered on a copy")
	screen._on_card_menu_chosen(ORIGINAL_TYPE)
	var preview: CardPreview = screen._card_preview
	assert_eq(preview._name_label.text, "Clone", "what the card was when it was cast")
	assert_false(preview._type_label.text.contains("Angel"),
		"not the copy's type line: %s" % preview._type_label.text)
	assert_ne(preview._pt_label.text, "4/4", "the printed card's own power and toughness, not the copy's")


func test_show_full_card_still_shows_the_copy() -> void:
	var clone := _a_clone_of_serra_angel()
	screen._open_card_menu(clone, Vector2.ZERO)
	screen._card_menu.hide()
	screen._on_card_menu_chosen(1)
	assert_eq(screen._card_preview._name_label.text, "Serra Angel",
		"`Show full card` is the Showcase: the card as it is in play")
	assert_eq(screen._card_preview._pt_label.text, "4/4")


func test_the_expand_toggle_keeps_the_printed_card() -> void:
	var clone := _a_clone_of_serra_angel()
	var preview: CardPreview = screen._card_preview
	preview.call("show_card", clone, "", true)   # three arguments since c12 h4-7
	preview.set_text_expanded(not preview.text_is_expanded())
	assert_eq(preview._name_label.text, "Clone", "a redraw keeps showing the printed card")
	preview.set_text_expanded(not preview.text_is_expanded())


func test_original_type_is_greyed_on_a_card_that_is_no_copy() -> void:
	var lion := _summon(0, "Savannah Lions")
	screen._open_card_menu(lion, Vector2.ZERO)
	screen._card_menu.hide()
	assert_true(_entry_disabled(ORIGINAL_TYPE),
		"nothing to show that the Showcase does not")
	assert_false(_entry_disabled(1), "control: Show full card stays live")
	var tip := screen._card_menu.get_item_tooltip(
		screen._card_menu.get_item_index(ORIGINAL_TYPE))
	assert_ne(tip, "", "the greyed entry says why")
