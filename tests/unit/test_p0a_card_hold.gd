extends GutTest
## P0a — THE CARD HOLD, an Embark setting (the owner, 2026-10-28: "A new
## Embark setting: card hold — '1997 card hold limit' / 'unlimited card
## hold'"): under the 1997 limit the magic bag holds 500 cards
## ([constant AdventurePlayer.BAG_MOST]) as before — the shops, trades,
## rewards, lairs, dungeon treasures (with the full bag's swap), the castle
## picks and the wise man refuse or lose a card past it; under "Unlimited
## card hold" there is no limit anywhere, and no full-bag word, warning or
## swap ever comes. The record, the save and the next visit carry it; an
## adventure saved before the choice plays by the 1997 limit.

var player: AdventurePlayer


func before_each() -> void:
	CardRegistry.ensure_loaded()
	player = _hero(AdventurePlayer.HOLD_UNLIMITED)


func after_each() -> void:
	AdventureSetup.forget()
	CardValue.forget()
	CardShop.forget()


func _hero(hold: String) -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	setup.card_hold = hold
	var record := setup.resolve({})
	return AdventurePlayer.begin(record, AdventureSetup.make_world(record))


## The bag filled to [param count] cards.
func _fill(count: int, card_name := "Mountain") -> void:
	while player.cards.size() < count:
		player.cards.append({"card": card_name, "decks": []})


func _town() -> int:
	for slot in player.world.sites.size():
		if int(player.world.sites[slot]["type"]) == ShandalarWorld.TOWN:
			return slot
	return -1


# ------------------------------------------------------------ the choice --

func test_the_1997_limit_by_default_and_for_an_older_save() -> void:
	assert_eq(AdventurePlayer.CARD_HOLDS, [AdventurePlayer.HOLD_1997, AdventurePlayer.HOLD_UNLIMITED] as Array[String])
	assert_eq(AdventureSetup.new().card_hold, AdventurePlayer.HOLD_1997, "the Embark's default")
	assert_eq(AdventurePlayer.new().card_hold, AdventurePlayer.HOLD_1997)
	var plain := _hero(AdventurePlayer.HOLD_1997)
	assert_true(plain.bag_limited())
	var data := JSON.parse_string(JSON.stringify(player.to_dict())) as Dictionary
	assert_eq(String((data["hero"] as Dictionary)["card_hold"]), AdventurePlayer.HOLD_UNLIMITED, "saved")
	assert_eq(AdventurePlayer.from_dict(data).card_hold, AdventurePlayer.HOLD_UNLIMITED, "and read back")
	(data["hero"] as Dictionary).erase("card_hold")
	assert_eq(AdventurePlayer.from_dict(data).card_hold, AdventurePlayer.HOLD_1997, "a save from before: 1997")
	(data["hero"] as Dictionary)["card_hold"] = 7
	assert_eq(AdventurePlayer.from_dict(data).card_hold, AdventurePlayer.HOLD_1997, "a wrong value: 1997")


func test_the_record_and_the_next_visit_carry_it() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.card_hold = AdventurePlayer.HOLD_UNLIMITED
	var record := setup.resolve({})
	assert_eq(String(record["card_hold"]), AdventurePlayer.HOLD_UNLIMITED)
	setup.remember()
	assert_eq(AdventureSetup.restore([] as Array[String]).card_hold, AdventurePlayer.HOLD_UNLIMITED)
	AdventureSetup.forget()
	assert_eq(AdventureSetup.restore([] as Array[String]).card_hold, AdventurePlayer.HOLD_1997, "forgotten: 1997")
	assert_true("card_hold" in AdventureSetup.REMEMBERED)


# ------------------------------------------------------ the bag unlimited --

func test_the_bag_takes_a_card_past_five_hundred() -> void:
	_fill(AdventurePlayer.BAG_MOST)
	assert_false(player.bag_limited())
	assert_gt(player.bag_room(), 0, "room in the bag")
	assert_true(player.add_card("Shivan Dragon"), "the 501st card kept")
	assert_eq(player.cards.size(), AdventurePlayer.BAG_MOST + 1)
	_fill(2000)
	assert_true(player.add_card("Lightning Bolt"), "and the 2001st")
	var limited := _hero(AdventurePlayer.HOLD_1997)
	while limited.cards.size() < AdventurePlayer.BAG_MOST:
		limited.cards.append({"card": "Mountain", "decks": []})
	assert_eq(limited.bag_room(), 0, "control: the 1997 bag is full at 500")
	assert_false(limited.add_card("Shivan Dragon"), "control: and loses the card")


func test_the_shop_trade_wise_man_lair_and_castle_take_cards_past_five_hundred() -> void:
	_fill(AdventurePlayer.BAG_MOST)
	var town := _town()
	var cards := CardShop.offers(player, town)
	var index := -1
	for i in cards.size():
		if cards[i] != "":
			index = i
			break
	assert_gte(index, 0, "control: a card for sale")
	player.gold = 50000
	var bought := CardShop.buy(player, town, index)
	assert_true(bool(bought["bought"]), "the shop sells: %s" % [bought])
	var held := player.cards.size()
	var asked := CardTrade.offer(player, "Shivan Dragon", CardTrade.BAZAAR)
	var paid := CardTrade.pay(player, asked, CardTrade.BAZAAR)
	assert_true(bool(paid["traded"]), "the trader trades: %s" % [paid])
	assert_eq(player.cards.size(), held + int(asked["copies"]))
	player.amulets["red"] = 3
	assert_true(WiseMan.copy(player, "Mountain", 4), "the wise man copies")
	assert_eq(LairEvent.finish(player, {"reward": "Shivan Dragon"}), "Shivan Dragon", "a lair's card kept")
	var taken := CastleWin.take(player, "Hypnotic Specter")
	assert_true(bool(taken["kept"]), "a castle's pick kept: %s" % [taken])
	assert_gt(player.cards.size(), AdventurePlayer.BAG_MOST + 4)


func test_a_dungeon_treasure_never_asks_for_the_swap() -> void:
	var world := player.world
	world.encounters[7]["cards"] = [11] as Array[int]
	player.cards = []
	for n in AdventurePlayer.BAG_MOST:
		player.cards.append({"card": "Forest", "decks": [0]})
	var board := DungeonBoard.new()
	board.cells.resize(DungeonBoard.CELLS)
	board.cells.fill(0)
	board.depth.resize(DungeonBoard.CELLS)
	board.depth.fill(0)
	for at in [DungeonBoard.ENTRANCE, DungeonBoard.START]:
		board.cells[at.x * DungeonBoard.HEIGHT + at.y] = DungeonBoard.OPEN
	board.index = 7
	board.color = int(world.encounters[7]["color"])
	board.rules = int(world.encounters[7]["rules"])
	board.difficulty = player.difficulty
	board.monsters = [1, 2, 3, 4, 5] as Array[int]
	board.dice = MsvcRandom.new(1)
	var cell := Vector2i(8, 11)
	board.cells[cell.x * DungeonBoard.HEIGHT + cell.y] = DungeonBoard.OPEN | (DungeonBoard.TREASURE << DungeonBoard.EVENT_SHIFT)
	board.hero = DungeonBoard.START
	board.pending = DungeonBoard.NOWHERE
	board.reveal(board.hero)
	assert_eq(board.step(DungeonBoard.UP_RIGHT).get("kind"), "event", "control: the treasure waits")
	var got := board.open_treasure(player)
	assert_eq(got, {"card": "Black Lotus", "words": "Found This Card", "bag_full": false}, "no swap asked")
	assert_eq(player.cards.size(), AdventurePlayer.BAG_MOST + 1, "the find taken")
	assert_eq(String(player.cards[-1]["card"]), "Black Lotus")


func test_the_duel_spoils_neither_warn_nor_lose() -> void:
	_fill(AdventurePlayer.BAG_MOST)
	var spoils := {"cards": ["Shivan Dragon", "Lightning Bolt"]}
	DuelSpoils._keep_cards(player, spoils)
	assert_eq(spoils["bag_lost"], [] as Array[String], "nothing lost")
	assert_eq(spoils["kept"], ["Shivan Dragon", "Lightning Bolt"] as Array[String])
	var after := {"cards": []}
	DuelSpoils._after_cards(player, {"row": 22, "color": 4, "strength": 40}, after)
	assert_false(after.has("bag"), "no \"only holds 500 spells\" note")
	var limited := _hero(AdventurePlayer.HOLD_1997)
	while limited.cards.size() < AdventurePlayer.BAG_WARN:
		limited.cards.append({"card": "Mountain", "decks": []})
	var warned := {"cards": []}
	DuelSpoils._after_cards(limited, {"row": 22, "color": 4, "strength": 40}, warned)
	assert_eq(int(warned.get("bag", 0)), AdventurePlayer.BAG_WARN, "control: the 1997 note from 450")
