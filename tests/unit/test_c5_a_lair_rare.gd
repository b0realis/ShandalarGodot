extends GutTest
## A LAIR'S RARE AND THE COPY LIMIT (campaign c5, fixer A; P3-4): 1997 threw
## a lair's rare back while the deck in use held more of it than it may
## (`GetRemainingAllowedCardCopies(card) < 0`, world_lair_monster_encounter.c
## 997–1001); ours never looked. With the Embark's copy limit on it does now;
## off, as 1997 shipped it, nothing changes (no copy is counted).

var player: AdventurePlayer


func before_each() -> void:
	CardRegistry.ensure_loaded()
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	var record := setup.resolve({})
	player = AdventurePlayer.begin(record, AdventureSetup.make_world(record))


func after_each() -> void:
	CardValue.forget()
	CardShop.forget()
	LairEvent.forget()


## The rare waiting in a lair of colour [param color] entered on die
## [param seed] (drawn first, [method LairEvent.begin]).
func _rare(seed: int, color := 4) -> String:
	player.dice = seed
	return String(LairEvent.begin(player, {"slot": 1, "color": color})["lair_rare"])


func _left(card_name: String, facts: Dictionary) -> int:
	return DuelSpoils.copies_left(player, card_name, facts, CardShop.deck_counts(player),
		CardShop.copies_allowed(player))


## [param copies] more copies of [param card_name] in the deck in use.
func _hold(card_name: String, copies: int) -> void:
	for i in copies:
		player.cards.append({"card": card_name, "decks": [player.current_deck]})


func test_a_rare_the_deck_holds_too_many_of_is_thrown_back_with_the_limit_on() -> void:
	# A rare the dice give with nothing counted.
	player.copy_limit = false
	var drawn := ""
	var seeds: Array[int] = []
	for seed in range(1, 400):
		var card_name := _rare(seed)
		if card_name == "":
			continue
		if drawn == "":
			drawn = card_name
		if card_name == drawn:
			seeds.append(seed)
	assert_ne(drawn, "", "a red lair gives a rare")
	assert_gt(seeds.size(), 0)
	# The deck in use holds one more than it may.
	var facts := CardValue.facts(CardRegistry.get_card(drawn))
	while _left(drawn, facts) >= 0:
		_hold(drawn, 1)
	assert_lt(_left(drawn, facts), 0, "over its allowance")
	player.copy_limit = true
	for seed in range(1, 400):
		assert_ne(_rare(seed), drawn, "limit on: never %s (die %d)" % [drawn, seed])
	player.copy_limit = false
	for seed in seeds:
		assert_eq(_rare(seed), drawn, "limit off: as 1997 shipped, the same card on the same die")


func test_a_rare_the_deck_holds_its_allowance_of_may_still_come() -> void:
	# `< 0`, not `<= 0`: a deck at its allowance (none left) is not refused.
	player.copy_limit = false
	var drawn := _rare(7)
	assert_ne(drawn, "")
	var facts := CardValue.facts(CardRegistry.get_card(drawn))
	while _left(drawn, facts) > 0:
		_hold(drawn, 1)
	player.copy_limit = true
	assert_eq(_left(drawn, facts), 0, "none left to take")
	assert_eq(_rare(7), drawn, "still given, as 1997's `< 0` gave it")


func test_with_nothing_over_its_allowance_the_dice_give_what_they_gave() -> void:
	player.cards = []
	_hold("Mountain", 40)
	player.copy_limit = false
	var off: Array[String] = []
	for seed in range(1, 60):
		off.append(_rare(seed, 1 + seed % 5))
	player.copy_limit = true
	var on: Array[String] = []
	for seed in range(1, 60):
		on.append(_rare(seed, 1 + seed % 5))
	assert_eq(on, off, "no rare over its allowance: the same rares on the same dice")
