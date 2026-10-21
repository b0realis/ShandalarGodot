extends GutTest
## THE SECOND BUG HUNT (2026-10-21), the screens: the Deck Builder's
## rarity is the first printing's.
##
## WAS: `DeckStats._load_rarity` promises "first printing wins" but read
## `cards/data/` in the order the folder lists it — `2ed`, `4ed`, `arn`,
## `atq`, `drk`, `leg` — so for the 47 cards Fourth Edition reprinted at
## another rarity, Fourth Edition's won: Hurr Jackal (an Arabian Nights
## common) was a rare, Apprentice Wizard (a Dark rare) a common, Sylvan
## Library and the Mana Batteries rares. The Rarity filter, the rarity
## letter on the cards, the Stats bars, AutoDeck's rarity wish and the
## Sealed and Booster Draft sheets all read it; the Showcase
## (`CardRegistry.rarity_of`, printing order) said otherwise. NOW the files
## are read in `CardRegistry.SET_ORDER`, and the two agree on every card.


func before_all() -> void:
	CardRegistry.ensure_loaded()


func test_the_first_printing_names_the_rarity() -> void:
	assert_eq(DeckStats.rarity_of("Hurr Jackal"), "common", "Arabian Nights, before Fourth Edition")
	assert_eq(DeckStats.rarity_of("Apprentice Wizard"), "rare", "The Dark")
	assert_eq(DeckStats.rarity_of("Sylvan Library"), "uncommon", "Legends")
	assert_eq(DeckStats.rarity_of("Dragon Engine"), "common", "Antiquities")


func test_the_builder_and_the_showcase_agree_on_every_card() -> void:
	var differ := PackedStringArray()
	for card_name in CardRegistry.all_names():
		var printed := CardRegistry.rarity_of(card_name)
		if printed != "" and DeckStats.rarity_of(card_name) != printed:
			differ.append(card_name)
	assert_eq(differ.size(), 0, "these disagree: %s" % ", ".join(differ.slice(0, 12)))


func test_the_draft_sheets_follow() -> void:
	assert_eq(SealedPool.slot_of("Apprentice Wizard"), "rare", "a Dark rare is dealt as a rare")
	assert_eq(SealedPool.slot_of("Hurr Jackal"), "common", "and an Arabian Nights common as a common")
