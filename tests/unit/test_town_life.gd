extends GutTest
## THE TOWNS' LIFE (2026-10-23, part A of the world's missing pieces): the
## site status word ([TownStatus]) and the mana links, the quests
## ([Quests]), the wise men ([WiseMan]), buying a World Magic
## ([WorldMagicShop]), the save slots ([SaveSlots]) and the creatures'
## table ([CreatureBook]), each by the 1.3 rules it ports.

var player: AdventurePlayer
const SAVES := "user://adventure_tests_town_life"


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	var record := setup.resolve({})
	player = AdventurePlayer.begin(record, AdventureSetup.make_world(record))


func after_each() -> void:
	WiseMan.forget()
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _sites(kind: int) -> Array[int]:
	var out: Array[int] = []
	for slot in player.world.sites.size():
		if int(player.world.sites[slot]["type"]) == kind:
			out.append(slot)
	return out


# ------------------------------------------------------- the status word --

func test_the_status_bits_and_the_ten_first_links() -> void:
	var world := player.world
	assert_eq(TownStatus.mana_links(world), 10, "the first ten towns and cities placed: the hero's ten lives")
	var town: int = TownStatus.linked_towns(world)[0]
	TownStatus.take(world, town, 4)
	assert_eq(TownStatus.ruler(world, town), 4, "the Red Wizardess holds it")
	assert_false(TownStatus.linked(world, town), "its link lost")
	assert_eq(TownStatus.mana_links(world), 9)
	TownStatus.release(world, town)
	assert_eq(TownStatus.ruler(world, town), 0, "freed")
	assert_eq(TownStatus.mana_links(world), 9, "the link stays lost")
	var village := _sites(ShandalarWorld.VILLAGE)[0]
	TownStatus.put(world, village, TownStatus.LINKED)
	assert_eq(TownStatus.mana_links(world), 9, "a village's link counts for nothing")
	assert_eq(player.mana_links(), 9)


# ------------------------------------------------------------ the quests --

func test_a_village_gives_letters_and_cards() -> void:
	var offers := 0
	for village in _sites(ShandalarWorld.VILLAGE):
		player.amulets = {"black": 3, "blue": 3, "green": 3, "red": 3, "white": 3}
		CardTrade.arrive(player, village)
		Quests.arrive(player, village)
		# A third of the unlinked villages ask for a creature (part B).
		if player.quest_offer.is_empty() or int(player.quest_offer["type"]) < 0:
			continue
		offers += 1
		var offer := player.quest_offer
		assert_true(int(offer["type"]) in [Quests.LETTER_LINK, Quests.CARD, Quests.LETTER_AMULET])
		var destination := int(offer["destination"])
		assert_true(TownStatus.is_town(player.world, destination), "a town or a city")
		assert_false(TownStatus.linked(player.world, destination), "not linked yet")
		var here: Dictionary = player.world.sites[village]
		var there: Dictionary = player.world.sites[destination]
		assert_gte(WorldGenerator.distance(int(there["x"]) - int(here["x"]), int(there["y"]) - int(here["y"])),
			Quests.NEAREST, "at least eight tiles away")
		assert_eq(int(offer["at"]), village)
	assert_gt(offers, 0, "two villages in three give one")
	for town in _sites(ShandalarWorld.TOWN):
		Quests.arrive(player, town)
		assert_lt(int(player.quest_offer.get("type", 0)), 0, "a town's quests are the creatures' (part B)")


func test_a_letter_quest_from_offer_to_link() -> void:
	var village := _sites(ShandalarWorld.VILLAGE)[0]
	var destination := -1
	for slot in _sites(ShandalarWorld.TOWN):
		if not TownStatus.linked(player.world, slot):
			destination = slot
			break
	player.quest_offer = {"type": Quests.LETTER_LINK, "destination": destination, "color": 4, "at": village}
	assert_true(Quests.offered(player, village), "Begin a Quest")
	assert_false(Quests.offered(player, destination), "only where it was drawn")
	var words := Quests.offer_words(player)
	assert_string_contains(words[0], "Take this message")
	assert_string_contains(words[0], WorldNames.site_name(player.world, destination))
	assert_eq(words[1], "He will reward you with a mana link.")
	assert_eq(Quests.accept(player, village), "You have 4 days to complete the quest.")
	assert_eq(int(player.quest["deadline"]), player.quest_timer + 63, "32 units: 63 steps")
	assert_eq(int(player.town_quests[str(village)]), player.quest_timer, "the town remembers")
	assert_false(Quests.offered(player, village), "one quest at a time")
	var links := player.mana_links()
	var done := Quests.complete_at(player, destination)
	assert_eq(done["lines"][1], "You create a mana link here.", "@VISIT 17")
	assert_eq(done["sound"], "sfx_mana_link")
	assert_eq(player.mana_links(), links + 1)
	assert_false(Quests.has_quest(player))


func test_a_card_quest_takes_a_card_of_its_colour_and_class() -> void:
	var destination := _sites(ShandalarWorld.TOWN)[0]
	var wanted_class := Quests.card_class(destination)
	player.quest = {"type": Quests.CARD, "destination": destination, "giver": 0, "color": 4, "data": -1,
		"deadline": player.quest_timer + 79}
	player.cards.clear()
	assert_eq(Quests.card_for_quest(player), -1)
	assert_eq(Quests.complete_at(player, destination), {}, "nothing to hand over yet")
	var fitting := ""
	for card_name in CardRegistry.all_names():
		if not CardTrade.in_adventure(String(card_name)):
			continue
		var f := CardValue.facts(CardRegistry.get_card(card_name))
		if int(f.get("color", 0)) & 16 != 0 and int(f.get("type", 0)) & wanted_class != 0:
			fitting = String(card_name)
			break
	player.cards = [{"card": fitting, "decks": [0]}, {"card": fitting, "decks": []}]
	assert_eq(Quests.card_for_quest(player), 1, "one no deck holds, first [ours]")
	var red := int(player.amulets["red"])
	var done := Quests.complete_at(player, destination)
	assert_eq(done["lines"][0], "The people are pleased to receive the %s spell." % fitting)
	assert_eq(player.cards, [{"card": fitting, "decks": [0]}], "the deck's copy kept")
	assert_eq(int(player.amulets["red"]), red + 1)
	assert_true(TownStatus.linked(player.world, destination))


func test_a_quest_lost_turns_the_wise_man_away() -> void:
	var giver := _sites(ShandalarWorld.VILLAGE)[0]
	player.quest = {"type": 0, "destination": _sites(ShandalarWorld.TOWN)[0], "giver": giver, "color": 1,
		"data": 0, "deadline": player.quest_timer}
	assert_string_contains(Quests.check_deadline(player), "are sorry their quest was not completed")
	assert_true(TownStatus.refuses_quests(player.world, giver), "0x04")
	assert_eq(WiseMan.speak(player, giver)["pages"][0], WiseMan.REFUSAL, "for good")


# ------------------------------------------------------------ the wise man --

func test_the_six_gifts_by_the_town_s_place() -> void:
	assert_eq(WiseMan.GIFTS, [[WiseMan.TALE, WiseMan.CLUE, WiseMan.LIVES],
		[WiseMan.COMPANION, WiseMan.COPY, WiseMan.DECK]], "1997's four where it gave them, the two more [ours]")
	player.next_duel_life = 0
	var talk := WiseMan.give(player, WiseMan.LIVES, 4)
	assert_eq(player.next_duel_life, 2, "two extra lives")
	assert_string_contains(talk["pages"][0], "two extra lives")
	var food := player.food
	WiseMan.give(player, WiseMan.LIVES, 4)
	assert_eq(player.food, food + 25, "a gift already waits: food instead")
	player.next_duel_life = 0
	talk = WiseMan.give(player, WiseMan.COMPANION, 4)
	assert_true(player.next_duel_card in ["Keldon Warlord", "Atog"], "a red companion")
	talk = WiseMan.give(player, WiseMan.DECK, 2)
	assert_eq(talk["then"], "deck")
	assert_string_contains(talk["pages"][0], "blue creature")
	player.amulets["red"] = 1
	talk = WiseMan.give(player, WiseMan.COPY, 4)
	assert_eq(talk["then"], "", "too few amulets: the lives instead [ours]")
	player.amulets["red"] = 3
	talk = WiseMan.give(player, WiseMan.COPY, 4)
	assert_eq(talk["then"], "copy")
	var cards := player.cards.size()
	assert_true(WiseMan.copy(player, String(player.cards[0]["card"]), 4))
	assert_eq([player.cards.size(), int(player.amulets["red"])], [cards + 1, 0], "three amulets for the copy")
	talk = WiseMan.give(player, WiseMan.CLUE, 4)
	assert_string_contains(talk["pages"][0], "dungeons which hold valuable spells")


func test_the_wise_man_s_talk_and_his_reminder() -> void:
	var town := _sites(ShandalarWorld.TOWN)[0]
	var talk := WiseMan.speak(player, town)
	assert_false((talk["pages"] as PackedStringArray).is_empty(), "he says something")
	assert_eq(player.last_town, town)
	var again := WiseMan.speak(player, town)
	assert_false((again["pages"] as PackedStringArray).is_empty(), "the same again in the same town")
	var destination := _sites(ShandalarWorld.CITY)[0]
	player.quest = {"type": 0, "destination": destination, "giver": town, "color": 1, "data": -1,
		"deadline": player.quest_timer + 50}
	var line := WiseMan.reminder(player)
	assert_string_contains(line, "If you seek the mana link, travel")
	assert_string_contains(line, WorldNames.site_name(player.world, destination))
	assert_ne(int(player.quest["data"]), -1, "the way shown again")
	assert_eq(WiseMan.fill("He has %2!d! life and %3!d! domes, %1.", ["Lich", 30, 2]),
		"He has 30 life and 2 domes, Lich.")
	assert_eq(WiseMan.fill("%s and %s.", ["A", "B"]), "A and B.")
	assert_eq(WiseMan.castle_life(player, 1), 35, "20 + 5 + 10 for a Magician, no wins, no towns")


# ---------------------------------------------------- the World Magic shop --

func test_the_nearest_world_magic_is_offered_as_a_town_is_left() -> void:
	var town := _sites(ShandalarWorld.TOWN)[0]
	var offer := WorldMagicShop.offer(player, town)
	assert_false(offer.is_empty(), "eleven not yet owned")
	assert_false(player.owns(String(offer["name"])))
	assert_eq(int(offer["price"]), WorldMagicShop.PRICES[int(offer["index"])], "half the 1997 table")
	assert_eq(WorldMagicShop.offer(player, _sites(ShandalarWorld.VILLAGE)[0]), {}, "never on leaving a village")
	var seller := int(offer["seller"])
	var at_seller := WorldMagicShop.offer(player, seller)
	assert_true(at_seller["here"], "its own town")
	player.gold = 10
	at_seller = WorldMagicShop.offer(player, seller)
	assert_eq(WorldMagicShop.words(at_seller)[0], WorldMagicShop.INSUFFICIENT)
	player.gold = 2000
	at_seller = WorldMagicShop.offer(player, seller)
	assert_string_contains(WorldMagicShop.words(at_seller)[0], "To release the WORLDMAGIC spell")
	assert_eq(WorldMagicShop.buy(player, at_seller), "%s is yours." % String(at_seller["name"]))
	assert_true(player.owns(String(at_seller["name"])))
	assert_eq(WorldMagicShop.seller(player.world, int(at_seller["index"])), 0, "its seller cleared")
	assert_eq(String(player.journal[-1]["text"]), "Bought WM: %s" % String(at_seller["name"]))


# ------------------------------------------------------------- the saves --

func test_ten_named_slots() -> void:
	player.autosave()
	var slots := SaveSlots.slots_of(player.adventure_id)
	assert_eq(slots.size(), 10)
	assert_true(slots.all(func(s: Dictionary) -> bool: return s["empty"]), "all empty at first")
	var path := SaveSlots.save_into(player, 3, "  Before the castle ")
	assert_true(path.ends_with(".slot03.json"))
	slots = SaveSlots.slots_of(player.adventure_id)
	assert_eq([slots[2]["name"], slots[2]["empty"]], ["Before the castle", false], "by its name")
	SaveSlots.save_into(player, 4, "")
	assert_string_contains(String(SaveSlots.slots_of(player.adventure_id)[3]["name"]), "Day 0 near",
		"a blank name: the day and the place")
	# An older save becomes slot 1.
	var older := player.save(player.save_path("save"))
	SaveSlots.migrate(SAVES)
	assert_false(FileAccess.file_exists(older), "the old file gone")
	assert_eq(String(SaveSlots.slots_of(player.adventure_id)[0]["name"]), SaveSlots.LEGACY_NAME)


# --------------------------------------------------------- the creatures --

func test_the_creatures_and_their_decks() -> void:
	assert_eq(CreatureBook.size(), 57)
	assert_eq(CreatureBook.called(1), "a Witch")
	assert_eq(CreatureBook.called(2), "an Undead Knight")
	var black := CreatureBook.of_color(1)
	assert_true(black.has(1) and black.has(7), "the Witch and the Greater Lich are black")
	assert_false(black.has(0) or black.has(55), "never the lair or Arzakon")
	for index in range(1, 55):
		assert_ne(CreatureBook.deck_path(index), "", "%s has its deck" % CreatureBook.name_of(index))
	var deck := CreatureBook.deck(1)
	assert_not_null(deck)
	assert_true(deck.cards.has("Swamp"), "the Witch's deck")
