extends GutTest
## THE CREATURE QUESTS (part B, W7, 2026-10-23): a town's, a city's and
## some villages' quest to defeat a creature ([Quests]) — drawn on the dice
## as 1997's `RunTownServicesMenu` drew it (a roaming slot's creature, or
## one of the town's colour and roaming slot 0 emptied), offered in the
## wise man's words (`@CITYWISEMAN` 6–11), accepted for three days, beaten
## on the map ("Return to %s"), rewarded back at the giver (a village's
## amulets and its quiet link; a town's card picked free — [CardTrade]'s
## reward), or failed; the quest pane's reward line and the guides (no way
## to the creature until it is beaten, then the giver); the wise man's
## reminder of it.

var player: AdventurePlayer
const SAVES := "user://adventure_tests_b_w7_quests"
const WITCH := 1
const WARLOCK := 3
const MANDURANG := 50


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Keleena"
	setup.color = "black"
	setup.difficulty = 1
	setup.walker = "female"
	setup.seed_text = "12345"
	var record := setup.resolve({})
	player = AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	player.monsters = [] as Array


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


## The quest's colour as 1997 drew it: a colour of the town's own land.
func _land_color(slot: int, dice: MsvcRandom) -> int:
	var mask := CardShop.town_colors(player.world, slot)
	while true:
		var color := dice.below(5) + 1
		if mask & (1 << color) != 0:
			return color
	return 0


## The six roaming slots each holding a creature (rows 1–6), slot 0 too.
func _six_creatures() -> void:
	player.monsters = [] as Array
	for slot in WorldLairs.SLOTS:
		player.monsters.append({"slot": slot, "kind": "creature", "creature": slot + 1,
			"x": player.position.x + 64, "y": player.position.y, "color": 1, "heading": 0, "frame": 0})


# ------------------------------------------------------------ the offer --

func test_a_town_draws_a_creature_of_its_colour_and_empties_slot_0() -> void:
	var town := _sites(ShandalarWorld.TOWN)[0]
	player.monsters = [{"slot": 0, "kind": "lair", "x": player.position.x, "y": player.position.y, "color": 1},
		{"slot": 3, "kind": "lair", "x": player.position.x, "y": player.position.y, "color": 2}]
	CardTrade.arrive(player, town)
	var dice := MsvcRandom.new(player.dice)
	dice.below(3)
	dice.below(6)
	dice.below(4)
	var tier := (dice.below(8) + 2) * 2
	var row := CreatureBook.pick(dice, CardTrade.favoured(player, town), tier)
	var color := _land_color(town, dice)
	Quests.arrive(player, town)
	assert_eq(player.quest_offer, {"type": -row, "destination": town, "color": color, "at": town},
		"no creature in the slot drawn: the town's own, of its favoured colour and a tier 4–18")
	assert_eq(player.dice, dice.state, "the dice drawn as 1997 drew them")
	assert_true(WorldLairs.held_in(player, 0).is_empty(), "slot 0 emptied at the offer — a lair too")
	assert_false(WorldLairs.held_in(player, 3).is_empty(), "the other slots kept")
	assert_true(CreatureBook.tier(row) in [4, 6, 8, 10, 12, 14, 16, 18])
	var favoured := CardTrade.favoured(player, town)
	if favoured > 0:
		assert_ne(WorldCreatures.colors_of(row) & (1 << favoured), 0, "of the town's favoured colour")


func test_a_roaming_creature_is_asked_for_three_times_in_four() -> void:
	var city := _sites(ShandalarWorld.CITY)[0]
	var kept_seed := -1
	var own_seed := -1
	for seed in range(1, 400):
		var dice := MsvcRandom.new(seed)
		dice.below(3)
		dice.below(6)
		if dice.below(4) != 0:
			kept_seed = seed if kept_seed < 0 else kept_seed
		elif own_seed < 0:
			own_seed = seed
		if kept_seed >= 0 and own_seed >= 0:
			break
	# rand(4) not 0: the creature in the slot drawn, slot 0 left as it was.
	_six_creatures()
	CardTrade.arrive(player, city)
	player.dice = kept_seed
	var dice := MsvcRandom.new(kept_seed)
	dice.below(3)
	var slot := dice.below(6)
	dice.below(4)
	var color := _land_color(city, dice)
	Quests.arrive(player, city)
	assert_eq(player.quest_offer, {"type": -(slot + 1), "destination": city, "color": color, "at": city},
		"the row of the creature in slot %d" % slot)
	assert_eq(player.monsters.size(), 6, "slot 0 kept: the slot's creature asked for")
	# rand(4) 0: the town's own creature all the same, slot 0 emptied.
	_six_creatures()
	player.dice = own_seed
	Quests.arrive(player, city)
	assert_lt(int(player.quest_offer["type"]), 0)
	assert_true(WorldLairs.held_in(player, 0).is_empty(), "slot 0 emptied")
	assert_eq(player.monsters.size(), 5)


func test_a_village_asks_for_a_creature_one_time_in_three_unlinked() -> void:
	var village := -1
	for slot in _sites(ShandalarWorld.VILLAGE):
		if not TownStatus.linked(player.world, slot):
			village = slot
			break
	assert_gte(village, 0)
	CardTrade.arrive(player, village)
	var creature_seed := -1
	for seed in range(1, 400):
		if MsvcRandom.new(seed).below(3) == 0:
			creature_seed = seed
			break
	player.dice = creature_seed
	Quests.arrive(player, village)
	assert_lt(int(player.quest_offer.get("type", 0)), 0, "rand(3) 0, unlinked: a creature")
	assert_eq(int(player.quest_offer["destination"]), village, "its giver its destination")
	TownStatus.put(player.world, village, TownStatus.LINKED)
	player.dice = creature_seed
	player.amulets = {"black": 3, "blue": 3, "green": 3, "red": 3, "white": 3}
	Quests.arrive(player, village)
	assert_true(player.quest_offer.is_empty() or int(player.quest_offer["type"]) >= 0,
		"a linked village always offers a letter, never a creature")


func test_a_letter_that_finds_no_town_becomes_a_creature_quest() -> void:
	var village := _sites(ShandalarWorld.VILLAGE)[0]
	# Every town linked: the letter's thousand tries find none.
	for slot in player.world.sites.size():
		if TownStatus.is_town(player.world, slot):
			TownStatus.put(player.world, slot, TownStatus.LINKED)
	CardTrade.arrive(player, village)
	var seed := -1
	for s in range(1, 400):
		if MsvcRandom.new(s).below(3) != 0:
			seed = s
			break
	player.dice = seed
	Quests.arrive(player, village)
	assert_lt(int(player.quest_offer.get("type", 0)), 0, "1997's goto: the village asks for a creature")
	assert_eq(int(player.quest_offer["destination"]), village)
	TownStatus.put(player.world, village, TownStatus.LINKED)
	player.dice = seed
	Quests.arrive(player, village)
	assert_true(player.quest_offer.is_empty(), "a linked village's letter that finds no town: nothing")


# ------------------------------------------------------------ the words --

func test_the_wise_man_offers_it_in_the_1997_words() -> void:
	var village := _sites(ShandalarWorld.VILLAGE)[0]
	var town := _sites(ShandalarWorld.TOWN)[0]
	player.quest_offer = {"type": -WITCH, "destination": village, "color": 1, "at": village}
	assert_eq(Quests.offer_words(player), PackedStringArray([
		"Defeat the Witch which has been menacing our village.",
		"Return here and I will reward you with 1 black amulet."]), "tier 4: one amulet")
	player.quest_offer = {"type": -WARLOCK, "destination": village, "color": 4, "at": village}
	assert_eq(Quests.offer_words(player)[1], "Return here and I will reward you with 2 red amulets.",
		"tier 8: tier / 7 + 1")
	player.quest_offer = {"type": -MANDURANG, "destination": village, "color": 1, "at": village}
	assert_eq(Quests.offer_words(player), PackedStringArray([
		"Defeat the Mandurang Dragon which has been menacing our village.",
		"Return here and I will reward you with 3 black amulets."]), "tier 18: a Dragon")
	player.quest_offer = {"type": -WITCH, "destination": town, "color": 1, "at": town}
	var wares := CardTrade.wares(int(player.world.sites[town]["trade"]))
	assert_eq(Quests.offer_words(player)[1], "Return here and I will reward you with: %s." % wares,
		"a town: a card of its wares")
	assert_eq(Quests.reward_amulets(MANDURANG), 3)
	assert_eq(Quests.reward_amulets(WITCH), 1)


func test_accepted_it_runs_three_days_and_guides_nowhere_until_beaten() -> void:
	var village := _sites(ShandalarWorld.VILLAGE)[0]
	player.quest_offer = {"type": -WITCH, "destination": village, "color": 2, "at": village}
	assert_true(Quests.offered(player, village))
	assert_eq(Quests.accept(player, village), "You have 3 days to complete the quest.")
	assert_eq(int(player.quest["deadline"]), player.quest_timer + 47, "24 units: 47 steps")
	assert_eq(int(player.quest["giver"]), village)
	assert_eq(WorldStatus.quest_target(player), -1, "no way shown to the creature (as 1997)")
	for target in WorldStatus.targets(player):
		assert_ne(String(target["kind"]), "quest", "no guide arrow, no mark on the small map")
	assert_eq(WorldStatus.quest_lines(player), ["Defeat a Witch", "Reward: Blue Amulet", "3 days left"] as Array[String],
		"the creature with its article, ours: the reward")
	assert_eq(WorldCreatures.quest_row(player), WITCH, "slot 0 held for it while it runs")
	assert_false(Quests.creature_beaten(player, WARLOCK), "another creature beaten: nothing")
	assert_true(Quests.creature_beaten(player, WITCH))
	var named := WorldNames.site_name(player.world, village)
	assert_eq(WorldStatus.quest_lines(player)[0], "Return to %s" % named)
	assert_eq(WorldStatus.quest_target(player), village, "beaten: the giver")
	assert_eq(String(WorldStatus.targets(player)[-1]["kind"]), "quest")


func test_the_wise_man_reminds_of_the_creature() -> void:
	var town := _sites(ShandalarWorld.TOWN)[0]
	player.quest = {"type": -WITCH, "destination": town, "giver": town, "color": 1, "data": -1, "deadline": 999}
	var named := WorldNames.site_name(player.world, town)
	assert_eq(WiseMan.reminder(player), "I see that the people of %s have asked you to defeat a Witch." % named)
	Quests.creature_beaten(player, WITCH)
	assert_string_starts_with(WiseMan.reminder(player), "You should travel ")
	assert_string_ends_with(WiseMan.reminder(player), " to %s to claim your reward!" % named)


# --------------------------------------------------------- the rewards --

func test_a_village_rewards_amulets_and_links_itself_quietly() -> void:
	var village := -1
	for slot in _sites(ShandalarWorld.VILLAGE):
		if not TownStatus.linked(player.world, slot):
			village = slot
			break
	player.quest = {"type": -WARLOCK, "destination": village, "giver": village, "color": 3, "data": -1,
		"deadline": player.quest_timer + 47}
	player.amulets["green"] = 0
	assert_eq(Quests.complete_at(player, village), {}, "the creature not beaten yet: nothing")
	assert_true(Quests.has_quest(player))
	Quests.creature_beaten(player, WARLOCK)
	assert_eq(Quests.complete_at(player, _sites(ShandalarWorld.TOWN)[0]), {}, "only at the giver")
	player.last_town = village
	var done := Quests.complete_at(player, village)
	assert_eq(done["lines"], PackedStringArray(["The village is glad to be rid of the pesky Warlock.",
		"You are rewarded with 2 fine green amulets."]))
	assert_false(done.has("pick"))
	assert_eq(int(player.amulets["green"]), 2, "tier 8: two amulets")
	assert_true(TownStatus.linked(player.world, village), "the village linked, unsaid")
	assert_false(Quests.has_quest(player))
	assert_eq(player.last_town, -1, "no longer the last town: a new quest is drawn there at once")
	# One amulet: "a fine".
	player.quest = {"type": -WITCH + Quests.DEFEATED, "destination": village, "giver": village, "color": 1,
		"deadline": 999}
	assert_eq(Quests.complete_at(player, village)["lines"][1], "You are rewarded with a fine black amulet.")


func test_a_town_rewards_a_card_of_its_wares_picked_free() -> void:
	var town := _sites(ShandalarWorld.TOWN)[0]
	var trade := int(player.world.sites[town]["trade"])
	player.quest = {"type": -WITCH + Quests.DEFEATED, "destination": town, "giver": town, "color": 1,
		"deadline": 999}
	var links := player.mana_links()
	var amulets := player.amulet_count()
	player.last_town = 7
	var done := Quests.complete_at(player, town)
	assert_eq(done["lines"], PackedStringArray(["The people are glad to be rid of the pesky Witch.",
		"You are rewarded with %s of your choice." % CardTrade.wares(trade)]))
	assert_eq(int(done["pick"]), trade, "the card picked from the town's trade")
	assert_eq(player.mana_links(), links, "no link")
	assert_eq(player.amulet_count(), amulets, "no amulets")
	assert_eq(player.last_town, 7, "another town last: kept")
	assert_false(Quests.has_quest(player))


func test_the_reward_line_names_what_the_giver_gives() -> void:
	var village := _sites(ShandalarWorld.VILLAGE)[0]
	var town := _sites(ShandalarWorld.CITY)[0]
	player.quest = {"type": -MANDURANG, "destination": village, "giver": village, "color": 5, "deadline": 999}
	assert_eq(Quests.reward_line(player), "Reward: 3 White Amulets")
	player.quest = {"type": -WITCH + Quests.DEFEATED, "destination": town, "giver": town, "color": 5, "deadline": 999}
	assert_eq(Quests.reward_line(player), "Reward: %s of your choice" % CardTrade.wares(int(player.world.sites[town]["trade"])))
	player.quest = {"type": Quests.LETTER_LINK, "destination": town, "giver": village, "color": 5, "deadline": 999}
	assert_eq(Quests.reward_line(player), "", "a letter's reward is the panel's own")


func test_the_free_pick_gives_one_card_in_no_deck() -> void:
	var asked := CardTrade.offer(player, "Mountain", CardTrade.REWARD)
	assert_eq(int(asked["copies"]), 1, "one basic land, not four")
	assert_eq(int(asked["amulets"]), 0)
	assert_true(asked["afford"])
	assert_eq(String(asked["words"]), "Mountain. Will you take this card...")
	var amulets := player.amulet_count()
	var gold := player.gold
	var count := player.cards.size()
	var taken := CardTrade.pay(player, asked, CardTrade.REWARD)
	assert_true(taken["traded"])
	assert_eq(String(taken["said"]), "Mountain joins your cards.")
	assert_eq(player.cards.size(), count + 1)
	assert_eq(player.cards[-1], {"card": "Mountain", "decks": []}, "in no deck")
	assert_eq([player.amulet_count(), player.gold], [amulets, gold], "free")
	while player.cards.size() < AdventurePlayer.BAG_MOST:
		player.cards.append({"card": "Swamp", "decks": []})
	assert_eq(String(CardTrade.pay(player, asked, CardTrade.REWARD)["said"]),
		"Your cards are too many: Mountain is lost.", "the bag full: lost, as 1997 lost it")
	assert_eq(player.cards.size(), AdventurePlayer.BAG_MOST)


func test_a_creature_quest_not_reported_in_time_fails() -> void:
	var town := _sites(ShandalarWorld.TOWN)[0]
	player.quest = {"type": -WITCH + Quests.DEFEATED, "destination": town, "giver": town, "color": 1,
		"deadline": player.quest_timer + 47}
	player.quest_timer += 47
	var named := WorldNames.site_name(player.world, town)
	assert_eq(Quests.check_deadline(player), "The people of %s are sorry their quest was not completed." % named,
		"beaten but not reported: failed all the same")
	assert_true(TownStatus.refuses_quests(player.world, town), "its wise man turns the hero away")
	assert_eq(String(player.journal[-1]["event"]), "quest")
	assert_false(bool(player.journal[-1]["done"]))
	assert_eq(WorldCreatures.quest_row(player), 0, "slot 0 free again")
