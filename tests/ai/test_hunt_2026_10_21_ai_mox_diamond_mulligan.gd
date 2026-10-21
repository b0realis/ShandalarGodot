extends GameTest
## THE MOX THAT NEEDS A LAND (bug hunt 2026-10-21, ai).
##
## The mulligan counts a free mana source — a {0} permanent with a mana
## ability — as a land drop that does not use the land drop up ([method
## AiMulligan.is_free_source]). Mox Diamond is {0} with a mana ability, and
## "if Mox Diamond would enter the battlefield, you may discard a land card
## instead; if you do not, put it into its owner's graveyard"
## ([member CardData.entry_payment]): without a land it is no source at
## all, and with one it costs that land. Two Mox Diamonds and five spells
## with no land read as two sources and a castable hand; the pilot kept a
## seven that can never make mana. A card whose arrival costs a price is
## counted as no free source now — the Lion's Eye Diamond's rule — and a
## Mox still is one (the control).


func before_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, id == "pack-9")


func after_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func after_each() -> void:
	g = null


func _hand(names: Array) -> void:
	for inst in g.players[0].hand:
		inst.zone = Mtg.Zone.LIBRARY
	g.players[0].hand.clear()
	for card_name in names:
		give_hand(0, card_name)


func test_two_diamonds_and_no_land_go_back() -> void:
	_hand(["Mox Diamond", "Mox Diamond", "Dark Ritual", "Dark Ritual",
		"Lightning Bolt", "Lightning Bolt", "Giant Growth"])
	assert_false(AiMulligan.is_free_source(g.players[0].hand[0]), "its arrival costs a land")
	assert_ne(AiMulligan.reason(g, 0), "", "no land, no mana: a mulligan")


## THE CONTROL: Mox Pearl and Mox Ruby are still free sources.
func test_a_mox_is_still_a_source() -> void:
	_hand(["Mox Pearl", "Mox Ruby", "Plains", "Lightning Bolt", "Swords to Plowshares",
		"Serra Angel", "Mountain"])
	assert_true(AiMulligan.is_free_source(g.players[0].hand[0]))
	assert_eq(AiMulligan.mana_sources(g.players[0].hand), 4)
