extends GutTest
## THE OPENING ANTE — docs/duel-todo.md §6.19, `MtgGame.stake_ante`.
##
## The manual, p.60: *"Before the duel begins, both players put up one or
## more cards from their decks as ante. In Shandalar, whoever wins the duel
## will get to keep the ante cards."* The stake comes off the deck BEFORE
## the shuffle (p.118, in passing: the minimum-deck padding is added
## *"after the ante but before the shuffle"*), it is ONE card by default
## (p.138: the option is *"whether you play each duel for AN ANTE CARD"*),
## and the player's stake spares basic lands while the opponent's does not
## (FAQ 1.9, and the owner's screenshot: your Animate Dead, Cromer's
## Mountain).
##
## THE POINT OF MOST OF THIS FILE IS THAT ANTE IS OPT-IN. Staking removes a
## card from a library and spends one `rng` draw, so a duel that did not ask
## for one must be bit-for-bit the duel it was before ante existed — the
## Deck Lab's win/loss split included.

const SPELLS := ["Grizzly Bears", "Hill Giant", "Lightning Bolt",
	"Giant Growth", "Healing Salve", "Dark Ritual"]


func _deck(lands := 20, spells := 20) -> Array:
	var out: Array = []
	for i in lands:
		out.append("Forest")
	for i in spells:
		out.append(SPELLS[i % SPELLS.size()])
	return out


func _game(seed_value := 424242) -> MtgGame:
	var game := MtgGame.new()
	game.setup(_deck(), _deck(), "P0", "P1", 20, 20, seed_value)
	return game


func _names(cards: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for inst in cards:
		out.append(inst.data.card_name)
	return out


# ------------------------------------------------------------- opt-in --

func test_a_duel_that_did_not_ask_stakes_nothing() -> void:
	var game := _game()
	assert_false(game.ante_enabled, "not playing for ante")
	assert_eq(game.all_ante().size(), 0)
	game.start(7, 0)
	assert_eq(game.all_ante().size(), 0, "start() never stakes")
	assert_eq(game.players[0].library.size() + game.players[0].hand.size(), 40,
		"and no card left the deck")


func test_not_staking_costs_no_rng_draw_so_the_deal_is_unchanged() -> void:
	# The determinism proof the Deck Lab depends on: two games on the same
	# seed that never stake are identical, and a game that DOES stake is
	# reproducible in its own right — the two streams simply differ.
	var plain_a := _game()
	plain_a.start(7, 0)
	var plain_b := _game()
	plain_b.start(7, 0)
	assert_eq(_names(plain_a.players[0].hand), _names(plain_b.players[0].hand),
		"the no-ante opening hand is reproducible")
	assert_eq(_names(plain_a.players[1].hand), _names(plain_b.players[1].hand))

	var ante_a := _game()
	ante_a.stake_ante(0)
	ante_a.stake_ante(1)
	ante_a.start(7, 0)
	var ante_b := _game()
	ante_b.stake_ante(0)
	ante_b.stake_ante(1)
	ante_b.start(7, 0)
	assert_eq(_names(ante_a.all_ante()), _names(ante_b.all_ante()),
		"and so is the staked one — same seed, same two cards")
	assert_eq(_names(ante_a.players[0].hand), _names(ante_b.players[0].hand))


func test_the_same_seed_stakes_the_same_card() -> void:
	assert_eq(_names(_staked(11)), _names(_staked(11)))


func _staked(seed_value: int) -> Array:
	var game := _game(seed_value)
	game.stake_ante(0)
	return game.players[0].ante


# ------------------------------------------------------------ the stake --

func test_the_stake_comes_out_of_the_library_and_into_the_ante() -> void:
	var game := _game()
	var before := game.players[0].library.size()
	var staked := game.stake_ante(0)
	assert_eq(staked.size(), 1, "one card, as the original's checkbox says")
	assert_eq(staked[0].zone, Mtg.Zone.ANTE)
	assert_eq(game.players[0].ante, staked, "and it sits with its owner")
	assert_eq(game.players[0].library.size(), before - 1,
		"lifted OUT of the deck, before the hands are dealt")
	assert_true(game.ante_enabled, "the duel is now played for ante")


func test_a_bigger_stake_takes_that_many_cards() -> void:
	# The manual says "one or more"; the Challenge screen offers "the card
	# (or one of the cards) you stand to win".
	var game := _game()
	assert_eq(game.stake_ante(0, 3).size(), 3)
	assert_eq(game.players[0].ante.size(), 3)
	assert_eq(game.players[0].library.size(), 37)


func test_the_stake_is_never_dealt_into_the_opening_hand() -> void:
	var game := _game()
	var staked := game.stake_ante(0)[0]
	game.start(7, 0)
	assert_eq(staked.zone, Mtg.Zone.ANTE)
	assert_false(game.players[0].hand.has(staked))
	assert_false(game.players[0].library.has(staked))


func test_a_mulligan_does_not_shuffle_the_stake_back_in() -> void:
	var game := MtgGame.new()
	# An all-land deck guarantees a mulligan hand for seat 0.
	game.setup(_deck(40, 0), _deck(), "P0", "P1", 20, 20, 7)
	var staked := game.stake_ante(0)[0]
	game.deal_opening_hands(7)
	assert_true(game.may_mulligan(0), "all land — the Shandalar rule")
	assert_eq(game.take_mulligan(0), "")
	assert_eq(staked.zone, Mtg.Zone.ANTE, "the stake stayed staked")
	assert_eq(game.players[0].ante.size(), 1)


func test_the_ante_is_visible_from_both_sides() -> void:
	var game := _game()
	game.stake_ante(0)
	game.stake_ante(1)
	assert_eq(game.all_ante().size(), 2, "a public zone, both stakes in it")


# ------------------------------------- Shandalar's basic-land exemption --

func test_the_players_stake_spares_basic_lands() -> void:
	# FAQ 1.9: "Why don't I ante basic lands? Basic lands are too weak a
	# card to ante." One spell in a deck of forests: it is always the stake.
	for seed_value in [1, 2, 3, 4, 5]:
		var game := MtgGame.new()
		var deck := _deck(39, 0)
		deck.append("Grizzly Bears")
		game.setup(deck, _deck(), "P0", "P1", 20, 20, seed_value)
		var staked := game.stake_ante(0, 1, true)
		assert_eq(staked[0].data.card_name, "Grizzly Bears",
			"seed %d spared the forests" % seed_value)


func test_the_opponents_stake_does_not_spare_them() -> void:
	# Cromer antes a Mountain in the owner's 1997 screenshot. Over enough
	# seeds a half-land deck must produce at least one land stake.
	var lands := 0
	for seed_value in range(1, 25):
		var game := _game(seed_value)
		if game.stake_ante(1)[0].is_land():
			lands += 1
	assert_gt(lands, 0, "a creature's stake may perfectly well be a land")


func test_a_nonbasic_land_is_a_real_stake() -> void:
	# Only BASIC lands are spared: a Strip Mine is a card worth winning.
	var deck := _deck(39, 0)
	deck.append("Strip Mine")
	var game := MtgGame.new()
	game.setup(deck, _deck(), "P0", "P1", 20, 20, 3)
	assert_eq(game.stake_ante(0, 1, true)[0].data.card_name, "Strip Mine")


func test_an_all_basic_deck_still_stakes_something() -> void:
	# The original loses that duel outright (FAQ 1.9) — an adventure-layer
	# verdict. The engine falls back rather than refusing to start a duel.
	var game := MtgGame.new()
	game.setup(_deck(40, 0), _deck(), "P0", "P1", 20, 20, 5)
	var staked := game.stake_ante(0, 1, true)
	assert_eq(staked.size(), 1)
	assert_true(staked[0].is_land())


func test_an_empty_library_stakes_nothing() -> void:
	var game := _game()
	game.players[0].library.clear()
	assert_eq(game.stake_ante(0).size(), 0)
	assert_false(game.ante_enabled)


func test_a_count_of_zero_stakes_nothing() -> void:
	var game := _game()
	assert_eq(game.stake_ante(0, 0).size(), 0)
	assert_false(game.ante_enabled)
