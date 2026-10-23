extends GutTest
## THE WORTH STRIP ([method AdventureBuilder._build_sideboard_area]; the
## owner, 2026-10-23: "leave the sideboard empty - maybe we can use it to
## display card under the mouse value for selling? (In adventure)"). The
## adventure builder's sideboard strip tells what the card under the mouse
## is worth: in a town what the town pays, out in the wilds what the places
## pay at least and at most, the best price the hero knows of, and the
## copies owned, in this deck and to sell.

var screen: WorldScreen
const SAVES := "user://adventure_tests_worth"


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	screen = WorldScreen.new()
	screen.record = setup.resolve({})
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _first(kind: int) -> int:
	for slot in screen.world.sites.size():
		if int(screen.world.sites[slot]["type"]) == kind:
			return slot
	return -1


## A card of the deck in use, and one more copy of it in no deck.
func _a_deck_card_with_a_spare() -> String:
	var card_name := ""
	for entry in screen.player.cards:
		if (entry["decks"] as Array).has(screen.player.current_deck) \
				and not CardRegistry.get_card(entry["card"]).is_land():
			card_name = entry["card"]
			break
	screen.player.cards.append({"card": card_name, "decks": []})
	return card_name


func _hover(builder: AdventureBuilder, card_name: String) -> void:
	builder._deck_area.card_hovered.emit(CardRegistry.get_card(card_name))


func _strip(builder: AdventureBuilder) -> Array[String]:
	var out: Array[String] = [builder._worth_title.text]
	for line in builder._worth_lines:
		if line.text != "":
			out.append(line.text)
	return out


func test_the_sideboard_gives_way_to_the_strip() -> void:
	var builder := screen.show_deck(-1, true)
	await get_tree().process_frame
	assert_false(builder._sideboard_area.visible, "no sideboard in the adventure")
	var strip := builder.find_child("WorthStrip", true, false) as Control
	assert_not_null(strip)
	assert_true(strip.visible)
	assert_true(builder._sideboard_rect().encloses(strip.get_rect()), "where the sideboard was")
	assert_eq(_strip(builder), [AdventureBuilder.WORTH_HEADING, AdventureBuilder.WORTH_PROMPT],
		"before a card is pointed at")


func test_out_in_the_wilds_it_tells_what_the_places_pay() -> void:
	var card_name := _a_deck_card_with_a_spare()
	var builder := screen.show_deck(-1, true)
	await get_tree().process_frame
	_hover(builder, card_name)
	var paid := CardShop.sell_range(card_name)
	var lines := _strip(builder)
	assert_eq(lines[0], card_name, "the card under the mouse")
	assert_eq(lines[1], "The places pay %d to %d gold for one." % [paid.x, paid.y] if paid.x != paid.y
		else "The places pay %d gold for one." % paid.x)
	var held := builder.deck.count_of(card_name)
	assert_eq(lines.back(), "You own %d · in this deck %d" % [held + 1, held], "no selling out here")
	assert_eq(lines.size(), 3, "no place visited: no best price")
	# A place visited: the best price known.
	var town := _first(ShandalarWorld.TOWN)
	TownStatus.put(screen.world, town, TownStatus.VISITED)
	_hover(builder, card_name)
	assert_eq(_strip(builder)[2], "The best you know of: %d gold at %s." % [
		CardShop.sell_price_at(screen.player, town, card_name), WorldNames.site_name(screen.world, town)])


func test_in_a_town_it_tells_what_the_town_pays_and_follows_a_sale() -> void:
	var card_name := _a_deck_card_with_a_spare()
	var town := _first(ShandalarWorld.TOWN)
	var builder := screen.show_deck(town)
	await get_tree().process_frame
	_hover(builder, card_name)
	var price := CardShop.sell_price_at(screen.player, town, card_name)
	var held := builder.deck.count_of(card_name)
	var lines := _strip(builder)
	assert_eq(lines[1], "%s pays %d gold for one." % [WorldNames.site_name(screen.world, town), price])
	assert_eq(lines.back(), "You own %d · in this deck %d · to sell 1" % [held + 1, held])
	assert_eq(builder.sell(card_name), price, "the spare sold")
	assert_eq(_strip(builder).back(), "You own %d · in this deck %d · to sell 0" % [held, held],
		"the strip follows the sale")
	# The town the hero stands in is never "the best you know of" again.
	TownStatus.put(screen.world, town, TownStatus.VISITED)
	_hover(builder, card_name)
	for line in _strip(builder):
		assert_false(line.begins_with("The best you know of"), "not this town again: %s" % line)


## The bug pass after the campaign (r2-3, r2-4): a sale reaches the deck
## Undo would put back, and the Sell button follows the deck's changes as
## the strip does.
func test_a_sale_reaches_the_undo_and_the_button_follows_the_deck() -> void:
	var card_name := _a_deck_card_with_a_spare()
	var town := _first(ShandalarWorld.TOWN)
	var builder := screen.show_deck(town)
	await get_tree().process_frame
	_hover(builder, card_name)
	var held := builder.deck.count_of(card_name)
	var sell_button := builder.find_child("SellButton", true, false) as Button
	assert_false(sell_button.disabled, "one spare: Sell is open")
	builder.sell(card_name)
	assert_true(sell_button.disabled, "every copy left is in the deck")
	builder._remove_one(card_name)
	assert_false(sell_button.disabled, "a copy taken out may be sold: the button follows at once")
	assert_eq(_strip(builder).back(), "You own %d · in this deck %d · to sell 1" % [held, held - 1])
	builder.sell(card_name)
	builder._undo_last()
	assert_eq(builder.deck.count_of(card_name), held - 1,
		"Undo puts back no card that was sold (the hero owns %d)" % (held - 1))
