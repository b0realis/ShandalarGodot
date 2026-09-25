extends GutTest
## Fifth Edition: 449 printings of cards the game already knows, no new identity.

func after_each() -> void:
	CardPacks.set_current_deck_names([])
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

func test_fifth_edition_alone_reuses_the_expansion_scripts() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	assert_false(CardRegistry.has_card("Abyssal Specter"))
	assert_eq(CardRegistry.size(), 897)
	assert_true(CardPacks.set_enabled("pack-7", true))
	assert_eq(CardRegistry.names_in_set("5ed").size(), 434)
	assert_eq(CardRegistry.size(), 1044)
	assert_eq(FifthEditionPack.new_names(), [])
	assert_eq(FifthEditionPack.records().size(), 434)
	assert_eq(FifthEditionPack.printings().size(), 449)
	assert_eq(FifthEditionPack.shared().size(), 147)
	for name in FifthEditionPack.shared():
		assert_true(CardRegistry.has_card(name), name)
		if not CardRegistry.has_card(name): continue
		var c := CardRegistry.get_card(name)
		assert_eq(c.set_code, "5ed", name)
		assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending", name)
		var one: Array[String] = [name]
		assert_eq(CardPacks.packs_required_by(one), ["pack-7"])
	for row in FifthEditionPack.records():
		assert_true(CardRegistry.card_in_set(row.name, "5ed"), row.name)
	assert_eq(CardRegistry.get_card("Shivan Dragon").set_code, "2ed")
	assert_true(CardRegistry.card_in_set("Shivan Dragon", "5ed"))
	assert_false(CardRegistry.card_in_set("Serra Angel", "5ed"))   # dropped from Fifth Edition
	assert_false(CardRegistry.card_in_set("Black Lotus", "5ed"))
	assert_eq(CardPacks.packs_required_by(["Shivan Dragon", "Counterspell"]), [])
	assert_eq(CardRegistry.extra_set_order(), ["5ed"])

func test_original_expansions_keep_their_scripts_when_both_packs_are_on() -> void:
	CardPacks.set_enabled("pack-7", true)
	CardPacks.set_enabled("pack-3", true)
	assert_eq(CardRegistry.get_card("Abyssal Specter").set_code, "ice")
	assert_true(CardRegistry.card_in_set("Abyssal Specter", "5ed"))
	assert_true(CardRegistry.card_in_set("Abyssal Specter", "ice"))
	assert_eq(CardRegistry.extra_set_order(), ["ice", "5ed"])
	assert_eq(CardPacks.packs_required_by(["Abyssal Specter"]), ["pack-3"])
	CardPacks.set_current_deck_names(["Abyssal Specter", "Shivan Dragon"])
	assert_eq(CardPacks.disable_warning("pack-7"), "")
	assert_eq(CardPacks.disable_warning("pack-3"), "")
	CardPacks.set_enabled("pack-3", false)
	assert_string_contains(CardPacks.disable_warning("pack-7"), "Abyssal Specter")
	assert_false(CardPacks.disable_warning("pack-7").contains("Shivan Dragon"))
	CardPacks.set_enabled("pack-7", false)
	assert_eq(CardPacks.packs_required_by(["Abyssal Specter"]), ["pack-3"])
	assert_eq(CardPacks.missing_requirements(["pack-3"]), ["pack-3"])
	assert_true(CardRegistry.has_card("Shivan Dragon"))
	assert_false(CardRegistry.card_in_set("Shivan Dragon", "5ed"))

func test_portal_and_fifth_edition_share_two_ice_age_names() -> void:
	CardPacks.set_enabled("pack-6", true)
	CardPacks.set_enabled("pack-7", true)
	for name in ["Mountain Goat", "Nature's Lore"]:
		assert_true(FifthEditionPack.shared().has(name), name)
		assert_true(PortalPack.SHARED.has(name), name)
		assert_eq(CardPacks.packs_required_by([name]), ["pack-6"], name)
	CardPacks.set_enabled("pack-6", false)
	assert_eq(CardPacks.packs_required_by(["Mountain Goat"]), ["pack-7"])
	assert_true(CardRegistry.has_card("Mountain Goat"))

func test_every_pack_together_adds_no_identity() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, true)
	assert_eq(CardRegistry.size(), 1898)
	assert_eq(CardRegistry.names_in_set("5ed").size(), 434)
	for name in FifthEditionPack.shared():
		assert_ne(CardRegistry.get_card(name).set_code, "5ed", name)
	CardPacks.set_enabled("pack-7", false)
	assert_eq(CardRegistry.size(), 1898)

func test_numbered_basic_lands_offer_four_fifth_edition_pictures() -> void:
	CardPacks.set_enabled("pack-7", true)
	for land in ["Plains", "Island", "Swamp", "Mountain", "Forest"]:
		var ids: Array = []
		for choice in CardPacks.printing_choices(land):
			if String(choice.set) == "5ed": ids.append(String(choice.id))
		assert_eq(ids.size(), 4, land)
		for id in ids:
			assert_true(id.begins_with("5ed:"), id)
			assert_true(DeckPrintings.valid_id(id), id)
	var dragon: Array = CardPacks.printing_choices("Shivan Dragon")
	assert_eq(dragon[0].set, "2ed")
	var fifth: Array = dragon.filter(func(c): return c.set == "5ed")
	assert_eq(fifth.size(), 1)
	if fifth.size() == 1:
		assert_eq(fifth[0].id, "5ed:267")
		assert_eq(fifth[0].rarity, "rare")
	assert_true(CardPacks.printing_choices("Serra Angel").filter(func(c): return c.set == "5ed").is_empty())
