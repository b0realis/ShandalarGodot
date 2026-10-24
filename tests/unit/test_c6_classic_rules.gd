extends GutTest
## THE CLASSIC MTG RULES, the third card rule of the Embark (the owner,
## 2026-10-24: "also classic MTG rules (max 4 same cards in deck, limited
## cards as per rules only one per deck). Traders stop offering the cards if
## you have 4 copies all-ready in your possession"; the banned cards banned
## too; "Restricted to 4 copies!" with Tome of Enlightenment): each card's
## allowance ([method DeckModel.classic_allowance]), the deck builder's
## extra cards, every source that offers a card ([method
## CardShop.classic_allows]), the first deck, and the rule kept by the saves.

var player: AdventurePlayer
const SAVES := "user://adventure_tests_c6_classic"
const BOLT := "Lightning Bolt"
const LOTUS := "Black Lotus"
const BANNED := "Contract from Below"


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	setup.card_rule = AdventurePlayer.RULE_CLASSIC
	var record := setup.resolve({})
	player = AdventurePlayer.begin(record, AdventureSetup.make_world(record))


func after_each() -> void:
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _own(card_name: String, copies: int) -> void:
	for i in copies:
		player.cards.append({"card": card_name, "decks": []})


func _owned(card_name: String) -> int:
	return player.cards.filter(func(c: Dictionary) -> bool: return String(c["card"]) == card_name).size()


# ------------------------------------------------------------ the rules --

func test_each_card_s_allowance() -> void:
	assert_true(DeckFormat.RESTRICTED.has(LOTUS), "control: restricted")
	assert_true(DeckFormat.BANNED.has(BANNED), "control: banned")
	assert_eq(DeckModel.classic_allowance(BOLT), 4, "four of a card")
	assert_eq(DeckModel.classic_allowance(LOTUS), 1, "one of a restricted card")
	assert_eq(DeckModel.classic_allowance(LOTUS, true), 4, "four with Tome of Enlightenment")
	assert_eq(DeckModel.classic_allowance(BANNED), 0, "none of a banned one")
	assert_eq(DeckModel.classic_allowance(BANNED, true), 0, "the Tome or not")
	assert_eq(DeckModel.classic_allowance("Mountain"), -1, "a basic land without end")


func test_the_deck_builder_s_extra_cards() -> void:
	var deck := DeckModel.new()
	deck.counts = {BOLT: 5, LOTUS: 2, BANNED: 1, "Mountain": 20, "Shivan Dragon": 4}
	assert_eq(deck.extra_copies(false, DeckModel.CLASSIC), {BOLT: 1, LOTUS: 1, BANNED: 1})
	assert_eq(deck.extra_copies(true, DeckModel.CLASSIC), {BOLT: 1, BANNED: 1}, "the Tome: two Lotuses are fine")
	var said := "\n".join(deck.over_duplicate_limit(false, DeckModel.CLASSIC))
	assert_string_contains(said, "5 Lightning Bolt (the Classic MTG rules allow 4)")
	assert_string_contains(said, "1 Contract from Below (banned by the Classic MTG rules)")
	assert_eq(deck.trim_duplicates(false, DeckModel.CLASSIC), 3, "Remove Extra Cards")
	assert_eq([deck.count_of(BOLT), deck.count_of(LOTUS), deck.count_of(BANNED)], [4, 1, 0])
	# The 1997 rule is not the classic one: four Shivan Dragons in a deck
	# under 59 cards are one too many there.
	deck.counts = {"Shivan Dragon": 4, "Mountain": 20}
	assert_eq(deck.extra_copies(false, DeckModel.DECK_BUILDER_1997), {"Shivan Dragon": 1})
	assert_eq(deck.extra_copies(false, DeckModel.CLASSIC), {})


func test_the_adventure_builder_judges_by_the_hero_s_rule() -> void:
	var builder := AdventureBuilder.new()
	builder.player = player
	assert_eq(builder._copy_rule(), DeckModel.CLASSIC)
	player.card_rule = AdventurePlayer.RULE_MEANT
	assert_eq(builder._copy_rule(), DeckModel.DECK_BUILDER_1997)
	builder.free()


# ------------------------------------------------- what is offered --

func test_nothing_is_offered_past_what_a_deck_may_hold() -> void:
	_own(BOLT, 3)
	assert_true(CardShop.may_offer(player, BOLT), "three owned: a fourth may come")
	_own(BOLT, 1)
	assert_false(CardShop.may_offer(player, BOLT), "four owned, in any deck or none: no more")
	assert_true(CardShop.may_offer(player, LOTUS), "a restricted card while none is owned")
	_own(LOTUS, 1)
	assert_false(CardShop.may_offer(player, LOTUS), "one owned: no more")
	player.world_magics.append("Tome of Enlightenment")
	assert_true(CardShop.may_offer(player, LOTUS), "the Tome: up to four")
	assert_false(CardShop.may_offer(player, BANNED), "a banned card never")
	_own("Mountain", 40)
	assert_true(CardShop.may_offer(player, "Mountain"), "a basic land always")
	player.card_rule = AdventurePlayer.RULE_MEANT
	assert_true(CardShop.classic_rule(player).is_empty(), "the 1997 rules: each place its own count")
	assert_true(CardShop.may_offer(player, BOLT))


func test_the_shop_sells_no_card_the_hero_holds_every_copy_of() -> void:
	var slot := -1
	for i in player.world.sites.size():
		if int(player.world.sites[i]["type"]) == ShandalarWorld.TOWN:
			slot = i
			break
	var shop := CardShop.town_record(player, slot)
	shop["cards"] = [BOLT]
	shop["restock"] = [0]
	player.gold = 5000
	_own(BOLT, 4)
	var sale := CardShop.buy(player, slot, 0)
	assert_false(bool(sale["bought"]))
	assert_eq(String(sale["said"]), CardShop.CLASSIC_HELD % BOLT)
	assert_eq(player.gold, 5000, "nothing paid")


func test_the_cards_won_stop_at_what_a_deck_may_hold() -> void:
	# Every card of the catalogue but the basic lands held four times (a
	# restricted card once): a creature has nothing left to give but lands
	# and its own stake.
	var stake := "Ironclaw Orcs"
	for row in CardTrade.catalogue():
		var card_name := String(row["name"])
		var most := DeckModel.classic_allowance(card_name)
		if most > 0:
			_own(card_name, most)
	var meeting := {"row": 22, "color": 4, "strength": 40, "creature_ante": [stake]}
	var won := DuelSpoils.reward_cards(player, meeting, MsvcRandom.new(7))
	assert_eq(won[0], stake, "the stake won is never limited")
	for card_name in won.slice(1):
		assert_true(DeckModel.classic_allowance(card_name) < 0, "only lands besides: %s" % card_name)


func test_a_reward_counts_the_copies_it_draws_itself() -> void:
	var meeting := {"row": 22, "color": 4, "strength": 200, "creature_ante": []}
	for seed_value in 12:
		var won := DuelSpoils.reward_cards(player, meeting, MsvcRandom.new(seed_value))
		for card_name in won:
			var most := DeckModel.classic_allowance(card_name)
			if most >= 0:
				assert_lte(_owned(card_name) + won.count(card_name), most, "%s, seed %d" % [card_name, seed_value])


func test_a_lair_s_rare_and_the_wise_man_s_copy_obey_it() -> void:
	for row in CardTrade.catalogue():
		var card_name := String(row["name"])
		if CardShop.shop_rarity(row["facts"]) == 3:
			_own(card_name, maxi(DeckModel.classic_allowance(card_name), 0))
	assert_eq(LairEvent._lair_rare(player, MsvcRandom.new(3), 4), "", "every rare held as often as allowed")
	player.amulets["red"] = 3
	_own(BOLT, 4 - _owned(BOLT))
	assert_false(WiseMan.copy(player, BOLT, 4), "no fifth Lightning Bolt")
	assert_eq(int(player.amulets["red"]), 3, "no amulets taken")


func test_the_first_deck_keeps_to_the_rules() -> void:
	for seed_value in 40:
		var dealt := StarterDeck.deal("red", 3, MsvcRandom.new(seed_value), true)
		for card_name in dealt:
			var most := DeckModel.classic_allowance(card_name)
			if most >= 0:
				assert_lte(dealt.count(card_name), most, "%s, seed %d" % [card_name, seed_value])


# ------------------------------------------------------------ the saves --

func test_the_rule_is_saved_and_old_saves_keep_their_limit() -> void:
	var data := JSON.parse_string(JSON.stringify(player.to_dict())) as Dictionary
	assert_eq(AdventurePlayer.from_dict(data).card_rule, AdventurePlayer.RULE_CLASSIC, "saved and read back")
	assert_true(bool((data["hero"] as Dictionary)["copy_limit"]), "an older game reads a limit on")
	(data["hero"] as Dictionary).erase("card_rule")
	(data["hero"] as Dictionary)["copy_limit"] = false
	assert_eq(AdventurePlayer.from_dict(data).card_rule, AdventurePlayer.RULE_SHIPPED,
		"a save from before the third rule, its limit off")
	(data["hero"] as Dictionary)["copy_limit"] = true
	assert_eq(AdventurePlayer.from_dict(data).card_rule, AdventurePlayer.RULE_MEANT, "its limit on")
	(data["hero"] as Dictionary)["card_rule"] = "nonsense"
	assert_eq(AdventurePlayer.from_dict(data).card_rule, AdventurePlayer.RULE_MEANT, "a rule not one: the limit kept")
