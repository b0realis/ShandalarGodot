extends GutTest
## A WIZARD BEATEN IN HIS CASTLE (part C, W2, 2026-10-27): [CastleWin] —
## 1997's words (her or his, two spaces after the full stop, each freed
## town), what the win changes (the towns freed with their links still lost,
## his creatures and his besieger gone, the colour beaten, the castle a
## beaten site), the journal, the victory logged as the owner's SC2 asks
## (kind 12: it counts in the wins and pays the end score's +25), the three
## picks (the colour's cards, a card taken not offered again, the Classic
## MTG rules, in no deck, a full bag said), and `all_five` only on the fifth.

var base: Dictionary
var player: AdventurePlayer


func before_all() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Liberator"
	setup.color = "white"
	setup.difficulty = 3
	setup.walker = "female"
	setup.seed_text = "90210"
	var record := setup.resolve({})
	var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	base = JSON.parse_string(JSON.stringify(hero.to_dict()))


func before_each() -> void:
	player = AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(base)))
	player.monsters = []
	player.siege_active = false
	for slot in player.world.sites.size():
		TownStatus.release(player.world, slot)


## The first [param count] towns and cities (slot order) ruled by wizard
## [param wizard], skipping [param skip] of them; their slots.
func _rule(wizard: int, count: int, skip := 0) -> Array[int]:
	var out: Array[int] = []
	var seen := 0
	for slot in player.world.sites.size():
		if not TownStatus.is_town(player.world, slot):
			continue
		seen += 1
		if seen <= skip:
			continue
		if out.size() < count:
			TownStatus.take(player.world, slot, wizard)
			out.append(slot)
	return out


# ------------------------------------------------------------- the words --

func test_her_and_his_words_with_the_towns_freed() -> void:
	assert_eq(CastleWin.defeated_lines(4, ["Kraag Temple", "Ardestan"] as Array[String]),
		["You have defeated the dreaded", "Red Wizardess.  No longer shall", "her evil creatures oppress",
			"the good people of Shandalar.", "Kraag Temple freed!", "Ardestan freed!"] as Array[String])
	assert_eq(CastleWin.defeated_lines(2, [] as Array[String])[2], "her evil creatures oppress",
		"the Blue Wizardess")
	for color in [1, 3, 5]:
		assert_eq(CastleWin.defeated_lines(color, [] as Array[String])[2], "his evil creatures oppress")
	assert_eq(CastleWin.defeated_lines(1, [] as Array[String])[1], "Black Wizard.  No longer shall",
		"two spaces after the full stop, as written")
	assert_eq(CastleWin.pick_title(3), "Pick a card - 3 left")
	assert_eq(CastleWin.TAKE_THREE % WorldClues.COLOR_CARDS[1], "You may take any three\ndifferent Black cards.\n")


# ---------------------------------------------------------- what it changes --

func test_the_win_frees_his_towns_and_sends_his_creatures_away() -> void:
	var his := _rule(4, 2)
	var other := _rule(1, 1, 2)
	player.monsters = [{"slot": 1, "kind": "lair", "x": 64, "y": 64, "color": 4},
		{"slot": 2, "kind": "creature", "creature": 33, "x": 96, "y": 96, "color": 4},
		{"slot": 3, "kind": "creature", "creature": 22, "x": 128, "y": 128, "color": 3},
		{"slot": 7, "kind": "creature", "creature": 34, "x": 200, "y": 200, "color": 4, "town": other[0]}]
	player.siege_active = true
	var won := CastleWin.beat(player, 3)
	assert_eq(won["towns"], his, "his towns, in slot order")
	var names: Array[String] = []
	for slot in his:
		assert_eq(TownStatus.ruler(player.world, slot), 0, "freed")
		names.append(WorldNames.site_name(player.world, slot))
	assert_eq(won["lines"], CastleWin.defeated_lines(4, names))
	assert_eq(TownStatus.ruler(player.world, other[0]), 1, "another wizard's kept")
	assert_eq(player.monsters.size(), 1, "his lair, his creature and his besieger gone")
	assert_eq(int(player.monsters[0]["color"]), 3)
	assert_false(player.siege_active, "the siege over")
	assert_true("red" in player.defeated_wizards)
	var site := CastleWin.castle_site(player.world, 3)
	assert_gte(site, 0)
	assert_eq(int(player.world.sites[site]["type"]), CastleWin.BEATEN_CASTLE, "a beaten site, type 5")
	assert_false(Sieges.castle_tiles(player).has(4), "no siege from his castle")
	var tile := Vector2i(int(player.world.sites[site]["x"]), int(player.world.sites[site]["y"]))
	assert_eq(String(VisitPane.describe(player, tile)["kind"]), "fallen")
	assert_eq(won["take_words"], "You may take any three\ndifferent Red cards.\n")
	assert_eq(won["music"], "music_castle_red")


func test_the_freed_town_s_link_stays_lost() -> void:
	var his := _rule(1, 1)
	assert_false(TownStatus.linked(player.world, his[0]), "taken: its link lost")
	var links := player.mana_links()
	CastleWin.beat(player, 0)
	assert_eq(TownStatus.ruler(player.world, his[0]), 0)
	assert_false(TownStatus.linked(player.world, his[0]), "still lost")
	assert_eq(player.mana_links(), links)


func test_the_journal_and_the_victory_logged() -> void:
	var journal := player.journal.size()
	var wins := player.total_wins()
	var won := CastleWin.beat(player, 0)
	assert_eq(won["journal"], "Defeated a Greater Lich")
	assert_eq(player.journal.size(), journal + 1)
	var line: Dictionary = player.journal[-1]
	assert_eq([line["event"], line["text"], line["won"], line["row"], line["castle"]],
		["duel", "Defeated a Greater Lich", true, 7, 0])
	# [ours: SC2] the castle wizard's win logged, kind 12, on his colour.
	assert_eq(player.total_wins(), wins + 1)
	assert_eq(player.duel_victories[-1], {"color": 1, "kind": CreatureBook.CASTLE_WIZARD,
		"creature": "Greater Lich"})
	assert_eq(HeroStats.record(player)["won"], 1)


func test_a_wizard_beaten_twice_changes_nothing_more() -> void:
	CastleWin.beat(player, 2)
	var journal := player.journal.size()
	var wins := player.total_wins()
	var again := CastleWin.beat(player, 2)
	assert_true(bool(again["already"]))
	assert_eq(player.journal.size(), journal)
	assert_eq(player.total_wins(), wins)
	assert_eq(player.defeated_wizards.count("green"), 1)
	assert_true(CastleWin.beat(player, 5).is_empty(), "no sixth castle")
	assert_true(CastleWin.beat(player, -1).is_empty())


func test_all_five_only_on_the_fifth() -> void:
	for index in [4, 0, 3, 1]:
		assert_false(bool(CastleWin.beat(player, index)["all_five"]), "castle %d" % index)
	assert_true(bool(CastleWin.beat(player, 2)["all_five"]), "the fifth")
	assert_eq(player.total_wins(), 5, "five castle wizards in the log: +25 each in the end score")


func test_no_retaliation_after_the_win() -> void:
	CastleWin.beat(player, 1)
	assert_eq(DungeonDoors.leave(player, 1, {"beaten": true}), [] as Array[Dictionary])
	assert_eq(DungeonDoors.leave(player, 1, {"beaten": false}), [] as Array[Dictionary],
		"a beaten wizard sends no siege")
	assert_false(player.siege_active)


# ------------------------------------------------------------- the picks --

func test_the_picks_offer_the_colour_s_cards_less_those_taken() -> void:
	player.card_rule = AdventurePlayer.RULE_MEANT
	var black := CastleWin.offered(player, [], 1)
	assert_gt(black.size(), 20)
	assert_true(black.has("Hypnotic Specter"))
	assert_false(black.has("Serra Angel"))
	for card_name in black:
		var f := CardValue.facts(CardRegistry.get_card(card_name))
		assert_true(int(f.get("color", 1)) & 2 != 0, "black: %s" % card_name)
	var less := CastleWin.offered(player, ["Hypnotic Specter"], 1)
	assert_false(less.has("Hypnotic Specter"), "taken: not offered again")
	assert_eq(less.size(), black.size() - 1)
	assert_true(CastleWin.offered(player, [], 5).has("Serra Angel"))


func test_the_classic_rules_offer_no_card_held_at_its_limit() -> void:
	player.card_rule = AdventurePlayer.RULE_CLASSIC
	for i in 4:
		player.cards.append({"card": "Hypnotic Specter", "decks": []})
	assert_false(CastleWin.offered(player, [], 1).has("Hypnotic Specter"))
	player.card_rule = AdventurePlayer.RULE_MEANT
	assert_true(CastleWin.offered(player, [], 1).has("Hypnotic Specter"), "the 1997 rules: offered")


func test_a_card_taken_joins_in_no_deck() -> void:
	var cards := player.cards.size()
	var taken := CastleWin.take(player, "Royal Assassin")
	assert_true(bool(taken["kept"]))
	assert_eq(player.cards.size(), cards + 1)
	assert_eq(player.cards[-1], {"card": "Royal Assassin", "decks": []}, "in no deck")
	assert_eq(String(player.journal[-1]["text"]), "Acquired spell: Royal Assassin", "a rare")
	while player.cards.size() < AdventurePlayer.BAG_MOST:
		player.cards.append({"card": "Swamp", "decks": []})
	var full := CastleWin.take(player, "Hypnotic Specter")
	assert_false(bool(full["kept"]))
	assert_eq(full["said"], AdventurePlayer.BAG_FULL, "[ours] a full bag is said")
	assert_eq(player.cards.size(), AdventurePlayer.BAG_MOST)
