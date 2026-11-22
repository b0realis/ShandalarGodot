extends GameTest
## A CARD THAT KEEPS A GAME CARD'S RULES WHOLE (`rules_of`): the game card
## itself under another name — its script — with a cost, a power and
## toughness and additions of the maker's own.


func _whole(card_name: String) -> Dictionary:
	var data := CardRegistry.get_card(card_name)
	var result := CardImport.whole(data)
	var spec: Dictionary = result["spec"]
	spec["name"] = "Kept " + CardImport._name(card_name)
	assert_eq(CommunityCard.problems(spec), [] as Array[String], card_name)
	assert_eq(CommunityCard.pool_problems(spec), [] as Array[String], card_name)
	return spec


func test_the_card_built_is_the_game_card_under_its_new_name() -> void:
	var spec := _whole("Shivan Dragon")
	spec["cost"] = "{3}{R}{R}"
	spec["power"] = 6
	var base := CardRegistry.get_card("Shivan Dragon")
	var built := CommunityCard.build(spec)
	assert_eq(built.card_name, "Kept Shivan Dragon")
	assert_eq([built.cost.text, built.power, built.toughness, built.types], ["{3}{R}{R}", 6, base.toughness, base.types])
	assert_eq(built.keywords, base.keywords)
	assert_eq(built.activated_abilities.size(), base.activated_abilities.size())
	assert_true(built.activated_abilities.size() > 0, "the firebreathing came over")
	assert_eq(built.oracle_text, base.oracle_text.replace("Shivan Dragon", "Kept Shivan Dragon"))
	# The game's own card is as it was.
	assert_eq([base.card_name, base.cost.text, base.power], ["Shivan Dragon", "{4}{R}{R}", 5])
	assert_false(is_same(built.activated_abilities, base.activated_abilities), "its lists are its own")


func test_additions_come_on_top() -> void:
	var spec := _whole("Dandân")
	spec["keywords"] = ["flying"]
	spec["abilities"] = [{"kind": "trigger", "when": "enters", "effects": [{"effect": "draw", "amount": 1}]}]
	assert_eq(CommunityCard.problems(spec), [] as Array[String])
	var base := CardRegistry.get_card("Dandân")
	var built := CommunityCard.build(spec)
	assert_true(built.keywords.has(Mtg.Keyword.FLYING))
	assert_eq(built.triggered_abilities.size(), base.triggered_abilities.size() + 1)
	assert_eq(built.attack_needs_defender_land, base.attack_needs_defender_land)
	assert_string_contains(built.oracle_text, "can't attack unless")
	assert_string_contains(built.oracle_text, "draw a card")
	assert_false(base.keywords.has(Mtg.Keyword.FLYING))


func test_what_the_rules_lean_on_stays() -> void:
	var spec := _whole("Fireball")
	spec["cost"] = "{R}"
	assert_string_contains(CommunityCard.pool_problems(spec)[0], "keeps {X}")
	spec = _whole("Shivan Dragon")
	spec["types"] = ["artifact", "creature"]
	assert_string_contains(CommunityCard.pool_problems(spec)[0], "keeps its card types")
	spec = _whole("Lightning Bolt")
	assert_eq(CommunityCard.problems(spec), [] as Array[String], "no spell effect of its own is asked for")
	spec["abilities"] = [{"kind": "modal", "modes": []}]
	assert_true(CommunityCard.problems(spec).any(func(p: String) -> bool: return p.contains("on top")))


func test_a_card_whose_base_is_not_in_the_pool_waits() -> void:
	var spec := _whole("Shivan Dragon")
	spec["rules_of"] = "No Such Card Anywhere"
	assert_eq(CommunityCard.problems(spec), [] as Array[String], "the card itself is whole")
	assert_string_contains(CommunityCard.pool_problems(spec)[0], "does not have now")
	var shown := CommunityCard.build(spec)
	assert_not_null(shown, "it can still be looked at")
	assert_string_contains(shown.oracle_text, "No Such Card Anywhere")
	# No card keeps the rules of a community card.
	assert_null(CardRegistry.game_card("No Such Card Anywhere"))


func test_it_plays_in_the_pool_and_at_a_table() -> void:
	var spec := _whole("Prodigal Sorcerer")
	spec["cost"] = "{1}{U}"
	CardRegistry.configure_community([spec], [{"name": spec["name"], "set": "comm", "rarity": "common", "artist": ""}])
	assert_true(CardRegistry.has_community("Kept Prodigal Sorcerer"))
	assert_eq(CardRegistry.community_waiting(), [] as Array[String])
	var data := CardRegistry.get_card("Kept Prodigal Sorcerer")
	assert_eq(data.activated_abilities.size(), 1)
	var gone := spec.duplicate(true)
	gone["name"] = "Kept Nothing"
	gone["rules_of"] = "No Such Card Anywhere"
	CardRegistry.configure_community([spec, gone], [])
	assert_eq(CardRegistry.community_waiting(), ["Kept Nothing"] as Array[String])
	assert_false(CardRegistry.has_card("Kept Nothing"))
	CardRegistry.configure_community([], [])


func test_every_card_that_can_start_can_keep_its_rules() -> void:
	var n := 0
	for card_name: String in CardRegistry.all_names():
		var data := CardRegistry.get_card(card_name)
		if CardRegistry.has_community(card_name) or not CardImport.can_start(data):
			continue
		var spec: Dictionary = CardImport.whole(data)["spec"]
		spec["name"] = "Kept card"
		var found := CommunityCard.problems(spec) + CommunityCard.pool_problems(spec)
		if not found.is_empty():
			assert_eq(found, [] as Array[String], card_name)
			continue
		var built := CommunityCard.build(spec)
		if built.types != data.types or built.subtypes != data.subtypes or built.keywords != data.keywords:
			assert_eq([built.types, built.subtypes, built.keywords], [data.types, data.subtypes, data.keywords], card_name)
		n += 1
	assert_true(n > 800, "%d cards keep their rules" % n)
