extends GameTest
## LANDS WITH AN ENTRY COST (Pack 8, 2026-10-03; [member
## AiProfile.forecasts_tactics]).
##
## [method AiPlayer._try_play_land] picked a land by the colour the hand is
## short of and never asked what the land costs to KEEP: Lotus Vale and
## Scorched Ruins ("If this land would enter, sacrifice two untapped lands
## instead ... If you don't, put it into its owner's graveyard"), a Karoo
## ("sacrifice this land unless you return an untapped Plains you
## control") and Alliances' Soldevi Excavations / Lake of the Dead (Pack 5)
## went down with nothing to pay and were lost — the card and the land
## drop. [code]mirage_tactics.gd[/code] [code]land_entry[/code] reads both shapes: an entry
## payment is dry-run under the search journal (the engine's own callable,
## nothing card-named) and a bounce trigger is read off its printed line.
## A land whose entry eats TWO lands is played only when the mana it makes
## unlocks a cast in hand; a one-for-one swap (Soldevi Excavations for an
## Island) is played whenever it is payable.

const M := preload("res://engine/ai/mirage_tactics.gd")


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-8", true)
	CardPacks.set_enabled("pack-5", true)
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)
	CardPacks.set_enabled("pack-5", false)


func _ai(profile: AiProfile = null) -> AiPlayer:
	var ai := AiPlayer.new(0, profile if profile != null else AiProfile.wizard())
	g.set_agent(0, ai)
	return ai


func _null() -> AiProfile:
	var p := AiProfile.wizard()
	p.forecasts_tactics = false
	return p


func _main() -> void:
	advance_to_step(Mtg.Step.MAIN1)


# ------------------------------------------------------ the double sac --

func test_lotus_vale_is_held_without_two_untapped_lands() -> void:
	var ai := _ai()
	put_battlefield(0, "Forest")
	var vale := give_hand(0, "Lotus Vale")
	give_hand(0, "Craw Wurm")
	_main()
	assert_ne(ai.act(g), "played a land")
	assert_eq(vale.zone, Mtg.Zone.HAND, "one land cannot pay for it: kept")


func test_lotus_vale_is_held_with_two_lands_and_nothing_to_unlock() -> void:
	var ai := _ai()
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	var vale := give_hand(0, "Lotus Vale")
	_main()
	ai.act(g)
	assert_eq(vale.zone, Mtg.Zone.HAND, "two lands for one with nothing to cast is a loss")
	assert_eq(g.players[0].battlefield.size(), 2)


func test_lotus_vale_is_played_when_it_unlocks_a_cast() -> void:
	# Two Mountains make {R}{R}; a Gray Ogre wants {2}{R}. The Vale eats
	# both and makes three red: the Ogre is cast this turn.
	var ai := _ai()
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	var vale := give_hand(0, "Lotus Vale")
	var ogre := give_hand(0, "Gray Ogre")
	_main()
	assert_eq(ai.act(g), "played a land")
	assert_eq(vale.zone, Mtg.Zone.BATTLEFIELD, "paid for, not lost")
	assert_string_contains(ai.act(g), "cast Gray Ogre")
	resolve_stack()
	assert_eq(ogre.zone, Mtg.Zone.BATTLEFIELD)


func test_a_plain_land_goes_before_the_costly_one() -> void:
	var ai := _ai()
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	var vale := give_hand(0, "Lotus Vale")
	var mountain := give_hand(0, "Mountain")
	give_hand(0, "Gray Ogre")
	_main()
	assert_eq(ai.act(g), "played a land")
	assert_eq(mountain.zone, Mtg.Zone.BATTLEFIELD, "the free land drop")
	assert_eq(vale.zone, Mtg.Zone.HAND)


func test_scorched_ruins_is_held_when_the_lands_are_tapped() -> void:
	var ai := _ai()
	var a := put_battlefield(0, "Swamp")
	var b := put_battlefield(0, "Swamp")
	a.tapped = true
	b.tapped = true
	var ruins := give_hand(0, "Scorched Ruins")
	give_hand(0, "Craw Wurm")
	_main()
	ai.act(g)
	assert_eq(ruins.zone, Mtg.Zone.HAND, "two TAPPED lands cannot pay")


# ----------------------------------------------------------- the karoo --

func test_karoo_is_held_without_an_untapped_plains() -> void:
	var ai := _ai()
	put_battlefield(0, "Island")
	var karoo := give_hand(0, "Karoo")
	_main()
	ai.act(g)
	assert_eq(karoo.zone, Mtg.Zone.HAND, "no Plains to return: it would be sacrificed")


func test_karoo_is_played_onto_an_untapped_plains() -> void:
	var ai := _ai()
	var plains := put_battlefield(0, "Plains")
	var karoo := give_hand(0, "Karoo")
	_main()
	assert_eq(ai.act(g), "played a land")
	resolve_stack()
	assert_eq(karoo.zone, Mtg.Zone.BATTLEFIELD, "kept")
	assert_eq(plains.zone, Mtg.Zone.HAND, "the Plains went home, a land drop for later")


# ------------------------------------------------- Pack 5, the same gap --

func test_soldevi_excavations_waits_for_an_untapped_island() -> void:
	var ai := _ai()
	var island := put_battlefield(0, "Island")
	island.tapped = true
	var dig := give_hand(0, "Soldevi Excavations")
	_main()
	ai.act(g)
	assert_eq(dig.zone, Mtg.Zone.HAND)


func test_soldevi_excavations_is_a_one_for_one_swap() -> void:
	var ai := _ai()
	var island := put_battlefield(0, "Island")
	var dig := give_hand(0, "Soldevi Excavations")
	_main()
	assert_eq(ai.act(g), "played a land")
	assert_eq(dig.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(island.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------------------- the null --

func test_null_arm_plays_the_vale_and_loses_it() -> void:
	# forecasts_tactics off is the pilot as it was: the land drop is spent
	# and the Vale goes to the graveyard with one land to pay.
	var ai := _ai(_null())
	put_battlefield(0, "Forest")
	var vale := give_hand(0, "Lotus Vale")
	_main()
	assert_eq(ai.act(g), "played a land")
	assert_eq(vale.zone, Mtg.Zone.GRAVEYARD)
