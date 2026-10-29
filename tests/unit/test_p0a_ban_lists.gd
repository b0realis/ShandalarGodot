extends GutTest
## P0a — THE BAN LIST, an Embark setting for the adventure's "Classic MTG
## rules" (the owner, 2026-10-28: "an Embark setting (Embark only) with
## three lists — '1998 (the original game's)', '1998 + modern', 'modern';
## default: the list as today (the nearest: 1998 + modern)") —
## [ClassicBans], read by [method DeckModel.classic_allowance] and through
## it by every place that offers a card ([method CardShop.classic_allows]),
## the deck builder's extra cards and the first deck. Magic Battle's
## formats keep [DeckFormat]'s lists as they are.

const SAVES := "user://adventure_tests_p0a_bans"

var player: AdventurePlayer


func before_each() -> void:
	CardRegistry.ensure_loaded()
	AdventurePlayer.saves_folder = SAVES
	player = _hero(ClassicBans.BOTH)


func after_each() -> void:
	AdventureSetup.forget()
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _hero(bans: String, rule := AdventurePlayer.RULE_CLASSIC) -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	setup.card_rule = rule
	setup.ban_list = bans
	var record := setup.resolve({})
	return AdventurePlayer.begin(record, AdventureSetup.make_world(record))


func _own(card_name: String, copies: int) -> void:
	for i in copies:
		player.cards.append({"card": card_name, "decks": []})


# ------------------------------------------------------------ the lists --

func test_the_three_lists_and_the_default() -> void:
	assert_eq(ClassicBans.LISTS, [ClassicBans.OLD, ClassicBans.BOTH, ClassicBans.MODERN] as Array[String])
	assert_eq(ClassicBans.DEFAULT, ClassicBans.BOTH, "the nearest to today's list")
	assert_eq(ClassicBans.key_of(null), ClassicBans.BOTH, "none named: the default")
	assert_eq(ClassicBans.key_of("Type 2"), ClassicBans.BOTH, "no list: the default")
	assert_eq(ClassicBans.key_of(ClassicBans.OLD), ClassicBans.OLD)


func test_1998_bans_the_three_and_restricts_none_of_the_modern_three() -> void:
	for card_name in ["Mind Twist", "Channel", "Divine Intervention"]:
		assert_true(CardRegistry.has_card(card_name), "%s is in our pool" % card_name)
		assert_true(ClassicBans.is_banned(card_name, ClassicBans.OLD), "%s banned in 1998" % card_name)
		assert_eq(DeckModel.classic_allowance(card_name, false, ClassicBans.OLD), 0, card_name)
	for card_name in ["Mana Crypt", "Mana Vault", "Time Vault"]:
		assert_true(CardRegistry.has_card(card_name), "%s is in our pool" % card_name)
		assert_false(ClassicBans.is_restricted(card_name, ClassicBans.OLD), "%s not restricted in 1998" % card_name)
		assert_eq(DeckModel.classic_allowance(card_name, false, ClassicBans.OLD), 4, card_name)
	# The Duelist #22's twenty-five, each in our pool, restricted.
	for card_name in ["Ancestral Recall", "Balance", "Berserk", "Black Lotus", "Black Vise",
			"Braingeyser", "Demonic Tutor", "Fastbond", "Fork", "Ivory Tower",
			"Library of Alexandria", "Maze of Ith", "Mirror Universe",
			"Mox Emerald", "Mox Jet", "Mox Pearl", "Mox Ruby", "Mox Sapphire",
			"Recall", "Regrowth", "Sol Ring", "Time Walk", "Timetwister",
			"Underworld Dreams", "Wheel of Fortune"]:
		assert_eq(DeckModel.classic_allowance(card_name, false, ClassicBans.OLD), 1, card_name)
	assert_eq(DeckModel.classic_allowance("Strip Mine", false, ClassicBans.OLD), 1,
		"restricted from 1 January 1998")
	for card_name in ["Crusade", "Jihad", "Mana Crypt"]:
		assert_eq(DeckModel.classic_allowance(card_name, false, ClassicBans.OLD), 4,
			"%s: four in 1998" % card_name)


func test_modern_is_today_s_vintage_list_for_our_pool() -> void:
	for card_name in ["Mana Crypt", "Mana Vault", "Time Vault", "Channel", "Strip Mine", "Black Lotus",
			"Library of Alexandria", "Sol Ring", "Demonic Tutor"]:
		assert_true(CardRegistry.has_card(card_name), "%s is in the base cards" % card_name)
		assert_eq(DeckModel.classic_allowance(card_name, false, ClassicBans.MODERN), 1,
			"%s restricted today" % card_name)
	# The packs' cards on today's list, by name: restricted the day their
	# pack joins (Ice Age, Homelands, Mirage, Visions, Tempest).
	for card_name in ["Brainstorm", "Necropotence", "Demonic Consultation", "Lion's Eye Diamond",
			"Lotus Petal", "Merchant Scroll", "Mystical Tutor", "Vampiric Tutor", "Flash"]:
		assert_true(ClassicBans.is_restricted(card_name, ClassicBans.MODERN), "%s restricted today" % card_name)
		assert_false(ClassicBans.is_restricted(card_name, ClassicBans.OLD), "%s not in 1998" % card_name)
	for card_name in ["Mind Twist", "Black Vise", "Berserk", "Fastbond", "Regrowth", "Divine Intervention"]:
		assert_eq(DeckModel.classic_allowance(card_name, false, ClassicBans.MODERN), 4,
			"%s: four today" % card_name)
	for card_name in ["Crusade", "Cleanse", "Imprison", "Invoke Prejudice", "Jihad", "Pradesh Gypsies",
			"Stone-Throwing Devils", "Contract from Below"]:
		assert_true(CardRegistry.has_card(card_name), "%s is in the base cards" % card_name)
		assert_eq(DeckModel.classic_allowance(card_name, false, ClassicBans.MODERN), 0,
			"%s banned today" % card_name)


func test_1998_plus_modern_is_never_looser_than_either() -> void:
	var names := {}
	for key in [ClassicBans.OLD, ClassicBans.MODERN]:
		for card_name in ClassicBans.banned(key) + ClassicBans.restricted(key):
			names[card_name] = true
	for card_name in names:
		var both := DeckModel.classic_allowance(card_name, false, ClassicBans.BOTH)
		for key in [ClassicBans.OLD, ClassicBans.MODERN]:
			assert_lte(both, DeckModel.classic_allowance(card_name, false, key), "%s against %s" % [card_name, key])
	assert_eq(DeckModel.classic_allowance("Mind Twist", false, ClassicBans.BOTH), 0, "banned in 1998")
	assert_eq(DeckModel.classic_allowance("Channel", false, ClassicBans.BOTH), 0, "banned beats restricted")
	assert_eq(DeckModel.classic_allowance("Crusade", false, ClassicBans.BOTH), 0, "banned today")
	assert_eq(DeckModel.classic_allowance("Mana Crypt", false, ClassicBans.BOTH), 1, "restricted today")
	assert_eq(DeckModel.classic_allowance("Black Vise", false, ClassicBans.BOTH), 1, "restricted in 1998")
	assert_eq(DeckModel.classic_allowance("Mana Crypt", true, ClassicBans.BOTH), 4, "the Tome as ever")
	assert_eq(DeckModel.classic_allowance("Lightning Bolt", false, ClassicBans.BOTH), 4)
	assert_eq(DeckModel.classic_allowance("Mountain", false, ClassicBans.OLD), -1, "a basic land without end")


func test_1998_plus_modern_is_today_s_list_in_our_pool_and_stricter() -> void:
	for card_name in DeckFormat.BANNED:
		assert_true(ClassicBans.is_banned(card_name, ClassicBans.BOTH), card_name)
	for card_name in DeckFormat.RESTRICTED:
		if CardRegistry.has_card(card_name):
			assert_true(ClassicBans.is_restricted(card_name, ClassicBans.BOTH)
				or ClassicBans.is_banned(card_name, ClassicBans.BOTH), "%s, in our pool" % card_name)
	assert_eq(DeckModel.classic_allowance("Mind Twist"), DeckModel.classic_allowance("Mind Twist", false, ClassicBans.BOTH),
		"no list named: the default")


func test_magic_battle_s_lists_are_untouched() -> void:
	assert_eq(DeckFormat.BANNED.size(), 12, "the ante cards, the dexterity cards and the sub-game")
	assert_false(DeckFormat.BANNED.has("Channel"))
	assert_false(DeckFormat.BANNED.has("Crusade"))
	for card_name in ["Mind Twist", "Channel", "Mana Crypt", "Mana Vault", "Time Vault"]:
		assert_true(DeckFormat.RESTRICTED.has(card_name), card_name)
	assert_eq(DeckFormat.legal(["Crusade", "Crusade", "Crusade", "Crusade"], DeckFormat.RESTRICTED_T1), "",
		"Magic Battle's Type 1 reads its own list")


# ---------------------------------------------------- where it is read --

func test_the_deck_builder_judges_by_the_adventure_s_list() -> void:
	var deck := DeckModel.new()
	deck.counts = {"Mind Twist": 1, "Mana Crypt": 2, "Black Vise": 2, "Mountain": 20}
	assert_eq(deck.extra_copies(false, DeckModel.classic_with(ClassicBans.OLD)), {"Mind Twist": 1, "Black Vise": 1})
	assert_eq(deck.extra_copies(false, DeckModel.classic_with(ClassicBans.MODERN)), {"Mana Crypt": 1})
	assert_eq(deck.extra_copies(false, DeckModel.classic_with(ClassicBans.BOTH)),
		{"Mind Twist": 1, "Mana Crypt": 1, "Black Vise": 1})
	assert_eq(DeckModel.classic_with(ClassicBans.BOTH), DeckModel.CLASSIC, "the default is the plain rule")
	var said := deck.over_duplicate_limit(false, DeckModel.classic_with(ClassicBans.OLD))
	assert_true(said.has("1 Mind Twist (banned by the Classic MTG rules)"), "%s" % [said])
	var builder := AdventureBuilder.new()
	builder.player = player
	for key in ClassicBans.LISTS:
		player.ban_list = key
		assert_eq(builder._copy_rule(), DeckModel.classic_with(key), key)
	player.card_rule = AdventurePlayer.RULE_MEANT
	assert_eq(builder._copy_rule(), DeckModel.DECK_BUILDER_1997, "the list is read only under Classic")
	builder.free()


func test_what_is_offered_follows_the_list() -> void:
	player.ban_list = ClassicBans.OLD
	assert_false(CardShop.may_offer(player, "Mind Twist"), "banned in 1998")
	assert_eq(CardShop.classic_refusal("Mind Twist", player.ban_list), CardShop.CLASSIC_BANNED % "Mind Twist")
	_own("Mana Crypt", 1)
	assert_true(CardShop.may_offer(player, "Mana Crypt"), "four of it in 1998")
	player.ban_list = ClassicBans.MODERN
	assert_true(CardShop.may_offer(player, "Mind Twist"), "four of it today")
	assert_false(CardShop.may_offer(player, "Mana Crypt"), "one owned, restricted today")
	assert_eq(CardShop.classic_refusal("Mana Crypt", player.ban_list), CardShop.CLASSIC_HELD % "Mana Crypt")
	assert_false(CardShop.may_offer(player, "Crusade"), "banned today")
	assert_eq(String(CardShop.classic_rule(player)["bans"]), ClassicBans.MODERN, "the rule carries its list")
	player.card_rule = AdventurePlayer.RULE_SHIPPED
	assert_true(CardShop.may_offer(player, "Crusade"), "not under the 1997 rules: the list is not read")


func test_the_first_deck_deals_no_card_its_list_bans() -> void:
	for key in ClassicBans.LISTS:
		for seed_value in 40:
			var dealt := StarterDeck.deal("white", 3, MsvcRandom.new(seed_value), true, key)
			for card_name in dealt:
				var most := DeckModel.classic_allowance(card_name, false, key)
				if most >= 0:
					assert_lte(dealt.count(card_name), most, "%s, %s, seed %d" % [card_name, key, seed_value])


# ------------------------------------------------- the choice, kept --

func test_the_list_is_chosen_kept_and_read_back() -> void:
	assert_eq(AdventureSetup.new().ban_list, ClassicBans.BOTH, "the Embark's default")
	assert_eq(AdventurePlayer.new().ban_list, ClassicBans.BOTH)
	var old := _hero(ClassicBans.OLD)
	assert_eq(old.ban_list, ClassicBans.OLD, "the adventure plays by it")
	var data := JSON.parse_string(JSON.stringify(old.to_dict())) as Dictionary
	assert_eq(String((data["hero"] as Dictionary)["ban_list"]), ClassicBans.OLD, "saved")
	assert_eq(AdventurePlayer.from_dict(data).ban_list, ClassicBans.OLD, "and read back")
	(data["hero"] as Dictionary).erase("ban_list")
	assert_eq(AdventurePlayer.from_dict(data).ban_list, ClassicBans.BOTH, "a save from before: the default")
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.ban_list = ClassicBans.MODERN
	assert_eq(String(setup.resolve({})["ban_list"]), ClassicBans.MODERN, "the record carries it")
	setup.remember()
	assert_eq(AdventureSetup.restore([] as Array[String]).ban_list, ClassicBans.MODERN, "and the next visit")
	assert_true("ban_list" in AdventureSetup.REMEMBERED)
	var kept := _hero(ClassicBans.OLD, AdventurePlayer.RULE_MEANT)
	assert_eq(kept.ban_list, ClassicBans.OLD, "kept under any card rule, read only under Classic")
