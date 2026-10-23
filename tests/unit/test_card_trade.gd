extends GutTest
## TRADES, LAIRS AND THE SELLER'S HINTS (2026-10-23, the owner: *"Build all
## trade features"*): [CardTrade] (a town's trade for amulets, the Nomad's
## Bazaar, the Diamond Mine), [CardHints], [WorldLairs], [LairEvent] and
## [CardRiddle], each by the 1.3 rules they port.

var player: AdventurePlayer


func before_each() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	var record := setup.resolve({})
	player = AdventurePlayer.begin(record, AdventureSetup.make_world(record))


func after_each() -> void:
	CardHints.forget()


func _site(kind: int) -> int:
	for slot in player.world.sites.size():
		if int(player.world.sites[slot]["type"]) == kind:
			return slot
	return -1


func _facts(rarity: int, extra := 0, kind := CardValue.CREATURE, color := 16) -> Dictionary:
	return {"type": kind, "color": color, "rarity": rarity, "extra": extra, "exp": 1}


# ------------------------------------------------------------ the trade --

func test_what_a_town_trades_and_the_price_in_amulets() -> void:
	assert_eq(CardTrade.wares(1 << 4), "Red cards", "@CITYCARDTEXT, a colour's")
	assert_eq(CardTrade.wares(1), "Colorless cards")
	assert_eq(CardTrade.wares(2 << 8), "Any creatures", "a type's")
	assert_eq(CardTrade.wares(5 << 8), "Any fast effects")
	assert_true(CardTrade.wanted(1 << 4, _facts(1)), "a red card in a red town")
	assert_false(CardTrade.wanted(1 << 4, _facts(1, 0, CardValue.CREATURE, 8)), "not a green one")
	assert_true(CardTrade.wanted(5 << 8, _facts(1, 0, CardValue.INTERRUPT)), "fast effects take interrupts")
	assert_false(CardTrade.wanted(2 << 8, _facts(1, 0, CardValue.SORCERY)))
	assert_eq([CardTrade.amulets_for(_facts(1)), CardTrade.amulets_for(_facts(2)),
		CardTrade.amulets_for(_facts(3)), CardTrade.amulets_for(_facts(1, 0x80))], [1, 2, 3, 4],
		"its rarity in amulets, special four")
	assert_eq(CardTrade.amulets_for(_facts(1, CardValue.FAVOURED)), 2, "a favoured common two")
	assert_eq([CardTrade.copies("Plains"), CardTrade.copies("Serra Angel")], [4, 1], "basic lands four at a time")


func test_the_cards_traded() -> void:
	var names: Array[String] = []
	for row in CardTrade.catalogue():
		names.append(String(row["name"]))
	assert_true("Serra Angel" in names and "Plains" in names and "Juggernaut" in names)
	assert_false("Black Lotus" in names, "a dungeon's treasure is never traded")
	assert_false("Balance" in names, "nor a restricted card")
	var sorted := names.duplicate()
	sorted.sort()
	assert_eq(names, sorted, "by name")


func test_a_town_trades_for_amulets_of_its_colour() -> void:
	var village := _site(ShandalarWorld.VILLAGE)
	var town := _site(ShandalarWorld.TOWN)
	CardTrade.arrive(player, town)
	var want := String(player.shops[str(town)]["want"])
	var mask := CardShop.town_colors(player.world, town)
	assert_true(mask & CardShop.COLOR_BITS[AdventurePlayer.COLORS.find(want)] != 0, "a colour of its land")
	for hue in AdventurePlayer.COLORS:
		player.amulets[hue] = 0
	assert_eq(CardTrade.town_offer(player, town), {}, "no such amulet, no trade")
	player.amulets[want] = 5
	var offer := CardTrade.town_offer(player, town)
	var trade := int(player.world.sites[town]["trade"])
	assert_eq(offer["words"], "Trade %s amulet for %s" % [want, CardTrade.wares(trade)], "@CITYSCREEN_BUTTONS")
	CardTrade.arrive(player, village)
	player.amulets[String(player.shops[str(village)].get("want", want))] = 5
	assert_eq(CardTrade.town_offer(player, village), {}, "a village never trades")
	CardTrade.traded(player, town)
	assert_eq(CardTrade.town_offer(player, town), {}, "the screen closed: a wait")
	player.quest_timer += (player.difficulty + 3) * CardTrade.TRADE_WAIT + 1
	assert_false(CardTrade.town_offer(player, town).is_empty(), "(difficulty + 3) · 18 steps later, again")


func test_a_trade_paid_in_the_town_s_amulets() -> void:
	player.amulets = {"black": 0, "blue": 0, "green": 0, "red": 2, "white": 0}
	var cards := player.cards.size()
	var asked := CardTrade.offer(player, "Serra Angel", CardTrade.TOWN, "red")
	assert_eq(asked["words"], "I'll trade you 1 Serra Angel for 2 red amulets.", "@BUYANYCARD")
	assert_true(asked["afford"])
	var done := CardTrade.pay(player, asked, CardTrade.TOWN, "red")
	assert_true(done["traded"])
	assert_eq(player.amulets["red"], 0, "the town's colour taken")
	assert_eq(player.cards[-1], {"card": "Serra Angel", "decks": []}, "the hero's, in no deck")
	assert_eq(player.cards.size(), cards + 1)
	asked = CardTrade.offer(player, "Plains", CardTrade.TOWN, "red")
	assert_eq(asked["words"], "I'll trade you 4 Plains for 1 red amulet.")
	assert_false(asked["afford"])
	assert_eq(CardTrade.pay(player, asked, CardTrade.TOWN, "red")["said"], CardTrade.AFFORD)


func test_the_diamond_mine_takes_amulets_of_any_colour() -> void:
	player.amulets = {"black": 1, "blue": 1, "green": 0, "red": 0, "white": 1}
	var asked := CardTrade.offer(player, "Serra Angel", CardTrade.MINE)
	assert_eq(asked["words"], "I'll trade you 1 Serra Angel for 2 amulets.")
	CardTrade.pay(player, asked, CardTrade.MINE)
	assert_eq(player.amulet_count(), 1, "two taken")
	assert_eq(player.amulets["green"] + player.amulets["red"], 0, "only from colours held")


func test_the_nomad_s_price() -> void:
	CardRegistry.ensure_loaded()
	player.gold = 10000
	for card_name in ["Serra Angel", "Plains", "Grizzly Bears", "Shivan Dragon"]:
		var data := CardRegistry.get_card(card_name)
		for draw in [0, 96]:
			var price := CardTrade.bazaar_price(player, data, draw)
			var f := CardValue.facts(data)
			assert_true(price % 5 == 0, "by fives")
			assert_true(price >= CardTrade.amulets_for(f) * 50, "never under 50 an amulet")
			assert_true(price <= 1000 * CardTrade.copies(card_name), "at most 1000 a copy")
	var bears := CardRegistry.get_card("Grizzly Bears")
	assert_true(CardTrade.bazaar_price(player, bears, 0) >= CardTrade.bazaar_price(player, bears, 96),
		"the Nomad's dice only lower it")
	var asked := CardTrade.offer(player, "Grizzly Bears", CardTrade.BAZAAR, "", 135)
	assert_eq(asked["words"], "I'll trade you 1 Grizzly Bears for 135 gold pieces.")
	CardTrade.pay(player, asked, CardTrade.BAZAAR)
	assert_eq(player.gold, 10000 - 135)


# ------------------------------------------------------------ the hints --

func test_the_seller_suggests_a_card_that_works_with_one_owned() -> void:
	var town := _site(ShandalarWorld.TOWN)
	var offers := CardShop.offers(player, town)
	var offered := ""
	for card_name in offers:
		if card_name != "" and not card_name in CardShop.LANDS:
			offered = card_name
			break
	var owned := String(player.cards[0]["card"])
	CardHints._read = true
	CardHints._hints = [{"first": offered, "second": owned, "levels": 0xF, "text": "do great things!"},
		{"first": offered, "second": "Black Lotus", "levels": 0xF, "text": "never shown"}]
	CardHints.arrive(player, town)
	var hint := CardHints.current(player, town)
	assert_eq(hint["card"], offered)
	assert_eq(hint["text"], CardHints.SUGGESTS % [offered, owned, "do great things!"], "@HINTTEXT")
	CardHints._hints[0]["levels"] = 1 << 3
	CardHints.arrive(player, town)
	assert_eq(CardHints.current(player, town), {}, "a Wizard's hint is not an Apprentice's")
	CardHints._hints[0]["levels"] = 0xF
	CardHints.arrive(player, town)
	player.gold = 5000
	CardShop.buy(player, town, offers.find(offered))
	assert_eq(CardHints.current(player, town), {}, "bought, the hint is told [ours]")


# ------------------------------------------------------------ the lairs --

func test_the_six_slots_are_filled_four_tiles_out() -> void:
	var hero := player.tile()
	WorldLairs.tick(player)
	assert_true(player.monsters.size() > 0, "the slots filled")
	for held in player.monsters:
		var at := Vector2i(int(held["x"]) / 32, int(held["y"]) / 32)
		assert_eq(maxi(absi(at.x - hero.x), absi(at.y - hero.y)), WorldLairs.RING, "on the square 4 out")
		assert_ne(ShandalarWorld.magic_mask(player.world.terrain(at.x, at.y)), 0, "not the sea")
		assert_eq(player.world.tile_flags(at.x, at.y) & ShandalarWorld.SITE, 0, "not a town")
		assert_eq(int(held["x"]) % 32, 16, "the tile's middle")


func test_lairs_come_as_often_as_in_1997() -> void:
	var lairs := 0
	var all := 0
	for i in 400:
		player.monsters = []
		player.monster_timer = 100000 + i * 7
		WorldLairs.tick(player)
		for held in player.monsters:
			all += 1
			if String(held["kind"]) == "lair":
				lairs += 1
	var share := float(lairs) / float(all)
	assert_between(share, 0.5, 0.72, "about 60 in 100 at first (12 draws of 20)")


func test_a_lair_is_seen_beside_it_and_entered_on_it() -> void:
	var hero := player.tile()
	player.monsters = [{"slot": 2, "kind": "lair", "color": 3,
		"x": (hero.x + 2) * 32 + 16, "y": hero.y * 32 + 16}]
	assert_eq(WorldLairs.seen(player), [] as Array[Dictionary], "two tiles off: unseen")
	player.position = (hero + Vector2i(1, 0)) * 32 + Vector2i(16, 16)
	assert_eq(WorldLairs.seen(player).size(), 1, "beside it: seen")
	player.dice = 1
	assert_eq(WorldLairs.tick(player), -1, "not yet in it")
	player.position = (hero + Vector2i(2, 0)) * 32 + Vector2i(10, 16)
	assert_eq(WorldLairs.tick(player), 2, "within 26 of its middle: entered")
	var timer := player.monster_timer
	WorldLairs.explored(player, 2)
	assert_eq(WorldLairs.held_in(player, 2), {}, "gone")
	assert_eq(player.world.lair_respawn[2], timer, "its slot's meeting now")
	assert_eq(player.monster_timer, timer | 0x1F)
	assert_eq(player.lairs_explored, 1)


# ----------------------------------------------------------- the events --

func test_a_lair_s_treasure() -> void:
	for t in [4, 8, 20]:
		player.monster_timer = t
		var event := LairEvent.begin(player, {"slot": 0, "color": 4})
		assert_true(LairEvent.is_treasure(event), "(T >> 2) % 3 not 0: a treasure")
		assert_eq(event["name"], "Active Volcano", "red's")
		var card := String(event["reward"])
		var bits := int(CardValue.facts(CardRegistry.get_card(card)).get("color", 1))
		assert_true(card == "Mountain" or bits == 1 or CardValue.first_color(bits) == 16,
			"%s: the land or a red or colourless card" % card)


func test_an_event_drawn_and_journaled() -> void:
	var seen := {}
	for i in 60:
		player.monster_timer = 12 * i
		player.next_duel_life = 5
		var event := LairEvent.begin(player, {"slot": 0, "color": 2})
		assert_false(LairEvent.is_treasure(event))
		seen[int(event["event"])] = true
		assert_eq(String(player.journal[-1]["text"]), "Discovered %s" % LairEvent.with_article(
			LairEvent.NAMES[int(event["event"])]), "@LOGSTRINGS")
	assert_false(seen.has(LairEvent.SULTAN) or seen.has(LairEvent.OASIS), "drawn again while a gift waits")
	assert_true(seen.size() >= 8, "the others alike")


func test_an_before_a_vowel() -> void:
	assert_eq(LairEvent.with_article("Abandoned Shrine"), "an Abandoned Shrine")
	assert_eq(LairEvent.with_article("Oasis of Muldoon"), "an Oasis of Muldoon")
	assert_eq(LairEvent.with_article("Diamond Mine"), "a Diamond Mine")


func test_thieves_and_the_lost_city() -> void:
	player.gold = 300
	player.siege_timer = 0
	var event := {"reward": "Serra Angel"}
	assert_eq(LairEvent.thieves(player, event), "You get 500 gold!", "before the siege clock's 128, always")
	assert_eq([player.gold, event["reward"]], [800, ""], "and the waiting card is gone")
	player.amulets = {"black": 0, "blue": 1, "green": 2, "red": 3, "white": 4}
	assert_eq(LairEvent.lost_city(player, event), "You find an amulet of each color!")
	assert_eq(player.amulets, {"black": 1, "blue": 2, "green": 3, "red": 4, "white": 5})
	player.siege_timer = 500
	var thieved := 0
	for i in 20:
		player.amulets = {"black": 0, "blue": 1, "green": 2, "red": 3, "white": 5}
		if LairEvent.lost_city(player, event) == "Thieves take half your amulets!":
			thieved += 1
			assert_eq(player.amulets, {"black": 0, "blue": 1, "green": 1, "red": 2, "white": 3},
				"half, rounded to the hero")
			assert_ne(event["reward"], "", "a rare left behind")
	assert_between(thieved, 3, 17, "half the time after the siege clock's 128")


func test_the_gemcutter_and_the_oasis() -> void:
	player.gold = 450
	player.amulets["blue"] = 1
	assert_eq(LairEvent.amulet_words(player, "blue"), "Buy a blue amulet. (you have 1)", "@LAIR")
	LairEvent.buy_amulet(player, "blue")
	LairEvent.buy_amulet(player, "blue")
	assert_eq([player.gold, player.amulets["blue"]], [50, 3])
	assert_eq(LairEvent.buy_amulet(player, "blue"), "Insufficient Funds")
	player.cards.append({"card": "Serra Angel", "decks": []})
	var held := player.cards.size()
	var event := {"oasis": player.cards.size() - 1}
	assert_eq(LairEvent.oasis_card(player, event), "Serra Angel")
	LairEvent.oasis_trade(player, event)
	assert_eq(player.next_duel_life, 5, "five extra life in the next duel")
	assert_eq(player.cards.size(), held - 1, "the card given")


func test_the_ruined_tower_tells_a_clue() -> void:
	var before := {}
	for i in player.world.encounters.size():
		before[i] = int(player.world.encounters[i].get("clues", 0))
	var told := LairEvent.ruined_tower(player)
	assert_true(told >= 0, "a castle or dungeon to tell of")
	var now := int(player.world.encounters[told]["clues"])
	assert_true(now != int(before[told]) and now & int(before[told]) == int(before[told]), "one clue more")
	for slot in player.world.encounters:
		slot["clues"] = 7
	assert_eq(LairEvent.ruined_tower(player), -1, "all told: a riddle instead")


func test_a_found_card_is_the_hero_s() -> void:
	var event := {"reward": "Shivan Dragon"}
	assert_eq(LairEvent.finish(player, event), "Shivan Dragon")
	assert_eq(player.cards[-1], {"card": "Shivan Dragon", "decks": []})
	assert_eq(LairEvent.finish(player, event), "", "once")


# ----------------------------------------------------------- the riddles --

func test_the_riddles() -> void:
	var dice := MsvcRandom.new(7)
	for i in 40:
		var riddle := CardRiddle.make(dice, 0)
		assert_false(riddle.is_empty())
		assert_false(bool(riddle["direct"]), "an Apprentice never gets a named card")
		var choices: Array = riddle["choices"]
		assert_eq(choices.size(), 5)
		assert_eq(choices[int(riddle["right"])], riddle["card"], "the subject at its place")
		assert_true(CardRiddle.correct(riddle, int(riddle["right"])))
		assert_eq(CardRiddle.verdict(riddle, (int(riddle["right"]) + 1) % 5), CardRiddle.WRONG_SHOWN)
	var direct := 0
	for i in 40:
		var riddle := CardRiddle.make(dice, 3)
		if not bool(riddle["direct"]):
			continue
		direct += 1
		if int(riddle["right"]) == -1:
			var bits := int(riddle["bits"])
			for answer in 10:
				assert_eq(CardRiddle.correct(riddle, answer), bits & (1 << answer) != 0,
					"any ability the card has is right")
		else:
			assert_eq((riddle["answers"] as Array).size(), 9, "0 to 8+")
			assert_eq(CardRiddle.verdict(riddle, int(riddle["right"])), CardRiddle.CORRECT)
	assert_true(direct >= 20, "a Wizard: three in four named")
	var serra := CardRiddle.abilities(CardRegistry.get_card("Serra Angel"))
	assert_true(serra & CardRiddle.BIT_FLYING != 0, "flying")
	assert_eq(CardRiddle.abilities(CardRegistry.get_card("Bog Wraith")) & 0x1F, 1, "swampwalk")
