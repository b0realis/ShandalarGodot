extends GutTest
## THE ADVENTURE'S RULES, THE BUG CAMPAIGN c12 (fixer F1, 2026-10-27):
##  - h2-1: a lair's "rare of any kind" — the waiting rare, the Thieves
##    Hideout's and the Lost City's bad luck, the Pyramids' riddle answered
##    — keeps to the Classic MTG rules ([method CardShop.classic_allows]); a
##    lair duel's hoard, a creature's stake, is never limited.
##  - the playmat chosen on the Embark screen worn on the hero's half of
##    every adventure duel ([member DuelConfig.territories]): a meeting's, a
##    ruled town's and a lair's.
##  - the Help promises nothing the adventure cannot do yet, and tells the
##    Save and Load of "Ready to Quit?" and the place names' switch.

var player: AdventurePlayer
var town := -1


func before_each() -> void:
	player = _hero(AdventurePlayer.RULE_CLASSIC)


func _hero(rule: String) -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.player_name = "Classic Delver"
	setup.color = "green"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	setup.card_rule = rule
	var record := setup.resolve({})
	var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	hero.monsters = []
	hero.monster_timer = 0
	hero.siege_timer = LairEvent.SAFE_SIEGE
	hero.cards = []
	for card_name in ["Forest", "Forest", "Forest", "Forest", "Forest", "Forest", "Forest", "Forest",
			"Llanowar Elves", "Grizzly Bears", "Giant Growth", "Craw Wurm", "War Mammoth"]:
		hero.cards.append({"card": card_name, "decks": [0]})
	hero.current_deck = 0
	return hero


## Every rare and special card of the adventure owned as often as the
## Classic MTG rules allow (none of a banned one): no such card may come.
func _own_every_rare(hero: AdventurePlayer) -> void:
	for row in LairEvent._cards():
		if CardShop.shop_rarity(row["facts"]) >= 3:
			for i in maxi(DeckModel.classic_allowance(String(row["name"])), 0):
				hero.cards.append({"card": String(row["name"]), "decks": []})


func _event(kind: int) -> Dictionary:
	return {"slot": 1, "color": 3, "event": kind, "name": LairEvent.NAMES[kind], "reward": "",
		"lair_rare": "", "oasis": -1}


# ------------------------------------------------- h2-1: the lair's rares --

func test_a_rare_of_any_kind_keeps_to_the_classic_rules() -> void:
	var rule := CardShop.classic_rule(player)
	for seed_value in range(1, 400):
		var card_name := LairEvent.rare_of_any_kind(MsvcRandom.new(seed_value), rule)
		assert_true(CardShop.classic_allows(rule, card_name), "%s, seed %d" % [card_name, seed_value])
		assert_false(DeckFormat.BANNED.has(card_name), "never a banned card: %s" % card_name)
	_own_every_rare(player)
	assert_eq(LairEvent.rare_of_any_kind(MsvcRandom.new(7), CardShop.classic_rule(player)), "",
		"every rare held as often as allowed: none")
	assert_ne(LairEvent.rare_of_any_kind(MsvcRandom.new(7)), "", "control: without the rules, one")


## The four places a lair gives a rare of any kind, under the Classic MTG
## rules with every rare already held: none comes — and, as control, the
## same draws under 1997's rule give one.
func test_the_four_lair_sources_obey_the_classic_rules() -> void:
	var meant := _hero(AdventurePlayer.RULE_MEANT)
	_own_every_rare(player)
	_own_every_rare(meant)
	var given := {"waiting": 0, "thieves": 0, "lost city": 0, "pyramids": 0}
	for seed_value in range(1, 60):
		for hero in [player, meant]:
			var classic: bool = hero == player
			# The waiting rare, a quarter of the time as the fourteen begin.
			hero.dice = seed_value
			var begun := LairEvent.begin(hero, {"slot": 1, "color": 3})
			if not LairEvent.is_treasure(begun):
				_given(given, "waiting", String(begun["reward"]), classic)
			# The thieves' and the Lost City's bad luck.
			hero.dice = seed_value
			var event := _event(LairEvent.THIEVES)
			hero.gold = 100
			LairEvent.thieves(hero, event)
			_given(given, "thieves", String(event["reward"]), classic)
			hero.dice = seed_value
			event = _event(LairEvent.LOST_CITY)
			LairEvent.lost_city(hero, event)
			_given(given, "lost city", String(event["reward"]), classic)
			# The Pyramids' riddle answered right.
			hero.dice = seed_value
			event = _event(LairEvent.PYRAMIDS)
			LairEvent.riddle_answered(hero, event, true)
			_given(given, "pyramids", String(event["reward"]), classic)
	for source in given:
		assert_gt(int(given[source]), 0, "control: %s gives a rare under 1997's rule" % source)


## A card from [param source]: under the Classic MTG rules none may come
## (every rare is held); under 1997's, counted for the control.
func _given(given: Dictionary, source: String, card_name: String, classic: bool) -> void:
	if classic:
		assert_eq(card_name, "", "%s under the Classic MTG rules" % source)
	elif card_name != "":
		given[source] = int(given[source]) + 1


func test_a_lair_duel_s_hoard_is_never_limited() -> void:
	_own_every_rare(player)
	var setup := LairDuels.begin(player, _event(LairEvent.DRAGON))
	var rares: Array = setup["rares"]
	assert_eq(rares.size(), int(LairDuels.SETUPS[LairEvent.DRAGON][1]),
		"the creature's stake, whatever the hero holds")


# ------------------------------------------------------- the playmat --

func test_a_meeting_s_duel_wears_the_hero_s_playmat() -> void:
	player.playmat = {"color": "blue", "type": "Mana symbols"}
	var met := CreatureMeeting.meet(player, 22, 3)
	var config := CreatureMeeting.duel_config(player, met)
	assert_eq(config.territories[0], {"color": "blue", "type": "Mana symbols"}, "the hero's half")
	assert_eq(config.territories[1], {}, "the creature's: the Duel Options' own answer")


func test_a_ruled_town_s_duel_wears_the_hero_s_playmat() -> void:
	player.playmat = {"color": "white", "type": "Line drawing"}
	for slot in player.world.sites.size():
		if int(player.world.sites[slot]["type"]) == ShandalarWorld.TOWN:
			town = slot
			break
	TownStatus.take(player.world, town, 4)
	var entry := RuledTowns.enter(player, town)
	var config := RuledTowns.duel_config(player, RuledTowns.meeting(player, entry))
	assert_eq(config.territories[0], {"color": "white", "type": "Line drawing"})
	assert_eq(config.territories[1], {})
	RuledTowns.forget()


func test_a_lair_duel_wears_the_hero_s_playmat() -> void:
	player.playmat = {"color": "red", "type": "Pattern"}
	var setup := LairDuels.begin(player, _event(LairEvent.SHRINE))
	var config := LairDuels.duel_config(player, setup)
	assert_eq(config.territories[0], {"color": "red", "type": "Pattern"})
	assert_eq(config.territories[1], {})


func test_an_adventure_without_a_playmat_leaves_the_duel_options_answer() -> void:
	player.playmat = {}
	var config := CreatureMeeting.duel_config(player, CreatureMeeting.meet(player, 22, 3))
	assert_eq(config.territories, [{}, {}])
	player.playmat = {"color": 3, "type": ["Pattern"]}
	config = CreatureMeeting.duel_config(player, CreatureMeeting.meet(player, 22, 3))
	assert_eq(config.territories, [{}, {}], "a misshapen playmat is none")


func test_the_embark_s_playmat_reaches_the_duel() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Mat Bearer"
	setup.color = "black"
	setup.seed_text = "4242"
	setup.playmat_color = "green"
	setup.playmat_type = "Pattern"
	var record := setup.resolve({})
	var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	var config := CreatureMeeting.duel_config(hero, CreatureMeeting.meet(hero, 22, 3))
	assert_eq(config.territories[0], {"color": "green", "type": "Pattern"})


# ---------------------------------------------------------- the Help --

func test_the_help_tells_what_the_adventure_does_now() -> void:
	var text := HelpPages.all_text()
	assert_true(text.contains("Save and Load are there too (S, L)"), "Ready to Quit? holds Save and Load")
	assert_true(text.contains("the path arrows (on to begin with) and the place names"), "the place names' switch")
	assert_false(text.contains("your attempts at each (click a beaten wizard's castle"),
		"no castle room promised before the castles open")
	assert_false(text.contains("your duels won and lost, the dungeon treasures"),
		"no dungeon treasures promised before the dungeons open")
	assert_false(text.contains("Your hero's stats count your attempts at each castle"))
	# Part C stage C2 (2026-10-28): the castles and dungeons open, and the
	# Help says what is there instead of what comes next.
	assert_false(text.contains("come with the insides of the castles and the dungeons"))
	assert_false(text.contains("come next"), "nothing left to come in the castles and dungeons")
	assert_true(text.contains("a beaten wizard's room (click the castle), the dungeon treasures you have found"))
