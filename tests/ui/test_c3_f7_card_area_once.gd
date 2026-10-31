extends GutTest
## Adventure campaign fix pass 2026-10-23, h5-10 round 2: A NEW PAGE'S
## CARDS ARE DRAWN ONCE. [method CardArea._make_cell] builds each cell's
## [MiniCard] for its card — and [method CardArea._bind_cell], straight
## after, gave the same card a second [CardInstance] and drew the face over
## again. A deck builder opening draws two pages that way (24 deck cards,
## nine in the Inventory). A fresh face is now bound as it was built; a
## face that showed another card, or that must wear a chosen printing, is
## rebound and redrawn as before.

## A surface that remembers the [CardInstance] each face was BUILT with.
class Watched extends CardArea:
	var built := {}

	func _make_cell(first: CardData) -> CardArea.Cell:
		var cell := super(first)
		built[cell] = cell.face.instance if cell.face != null else null
		return cell


var _packs_before: Array = []


func before_each() -> void:
	CardRegistry.ensure_loaded()
	_packs_before = Settings.enabled_card_packs().duplicate()


func after_each() -> void:
	for id in CardPacks.available_ids():
		if CardPacks.is_enabled(id) != _packs_before.has(id):
			CardPacks.set_enabled(id, _packs_before.has(id))


func _area() -> Watched:
	var area := Watched.new(true)
	area.size = Vector2(640, 480)
	add_child_autofree(area)
	return area


func _entries(names: Array) -> Array:
	var out: Array = []
	for card_name in names:
		out.append([CardRegistry.get_card(String(card_name)), 1])
	return out


func _shown(area: CardArea) -> Array[CardArea.Cell]:
	var out: Array[CardArea.Cell] = []
	for cell in area.cell_nodes():
		if cell.visible:
			out.append(cell)
	return out


func test_a_new_page_keeps_the_face_each_card_was_built_with() -> void:
	var area := _area()
	var names := ["Grizzly Bears", "Shivan Dragon", "Forest", "Lightning Bolt"]
	area.set_entries(_entries(names))
	var shown := _shown(area)
	assert_eq(shown.size(), names.size(), "a page of four")
	for cell in shown:
		assert_same(cell.face.instance, area.built[cell],
			"%s: the instance it was built with, not a second one" % cell.card_name)
		assert_eq(cell.face.instance.data, cell.data, "and it is the card's")
		assert_eq(cell.tooltip_text, "%s\n%s" % [cell.data.card_name, cell.data.oracle_text])
		assert_false(cell.face.hovered)


func test_a_new_page_keeps_card_frames_when_the_holder_handles_clicks() -> void:
	var area := _area()
	area.set_entries(_entries(["Amulet of Kroog", "Firebreathing", "Hill Giant"]))
	for cell in _shown(area):
		assert_true(cell.face.disabled, "the holder takes clicks on a fresh face")
		assert_true(cell.face.has_theme_stylebox_override("disabled"),
			"a disabled face must not fall through to the surrounding UI theme")
		assert_same(cell.face.get_theme_stylebox("disabled"),
			cell.face.get_theme_stylebox("normal"),
			"the whole frame stays visible behind the name and artwork")


func test_a_cell_moved_to_another_card_is_redrawn_as_that_card() -> void:
	var area := _area()
	area.set_entries(_entries(["Grizzly Bears", "Shivan Dragon"]))
	var first := _shown(area)[0]
	first.face.hovered = true
	area.set_entries(_entries(["Llanowar Elves", "Giant Growth"]))
	var cell := _shown(area)[0]
	assert_same(cell, first, "the page's widget is reused")
	assert_eq(cell.data.card_name, "Llanowar Elves")
	assert_eq(cell.face.instance.data.card_name, "Llanowar Elves", "its face shows the new card")
	assert_false(cell.face.hovered, "and is not lit")
	assert_eq(cell.tooltip_text, "%s\n%s" % [cell.data.card_name, cell.data.oracle_text])


func test_a_proxy_and_back_still_change_the_face() -> void:
	var area := _area()
	area.set_entries([[ProxyCard.data_for("No Such Card"), 1]])
	var cell := _shown(area)[0]
	assert_not_null(cell.proxy, "a proxy is paper")
	assert_null(cell.face)
	area.set_entries(_entries(["Forest"]))
	assert_null(cell.proxy)
	assert_not_null(cell.face, "and a card a card again")
	assert_eq(cell.face.instance.data.card_name, "Forest")
	# The paper face goes at the end of the frame.
	await get_tree().process_frame


func test_a_chosen_printing_is_worn_on_a_new_page() -> void:
	# Portal's numbered lands, where the pack is on this machine.
	if not CardPacks.has_pack("pack-6"):
		assert_true(true, "no Portal pack here: nothing to choose between")
		return
	CardPacks.set_enabled("pack-6", true)
	var area := _area()
	area.art_set_for = func(_d: CardData) -> String: return "por:215"
	area.set_entries(_entries(["Forest"]))
	var cell := _shown(area)[0]
	# Portal's picture where the pack carries it (the suite's packs carry
	# metadata only, and then there is no picture to wear either way).
	assert_same(cell.face.art_override, CardPrintings.texture("Forest", "por:215"),
		"the chosen printing's picture on the face")
	assert_eq(cell.printing_set, "por:215")
