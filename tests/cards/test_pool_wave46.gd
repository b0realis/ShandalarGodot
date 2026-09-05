extends GameTest
## Wave-46 tests: the ANTE cluster — the cards that play for keeps. The
## engine now has a real ante zone (Mtg.Zone.ANTE, one array per owner) and
## a permanent change of OWNERSHIP, which is the thing that outlives a duel
## and drives Shandalar's whole card economy.


func test_registry_loaded_wave46() -> void:
	for name in ["Contract from Below", "Darkpact", "Demonic Attorney",
			"Jeweled Bird", "Bronze Tablet", "Rebirth", "Tempest Efreet"]:
		assert_not_null(CardRegistry.get_card(name), name)


# --------------------------------------------------------- the ante zone --

func test_the_ante_starts_empty_and_takes_a_library_top() -> void:
	assert_eq(g.all_ante().size(), 0)
	var staked := g.ante_top_of_library(0)
	assert_not_null(staked)
	assert_eq(staked.zone, Mtg.Zone.ANTE)
	assert_eq(g.all_ante().size(), 1)
	assert_eq(g.players[0].ante[0], staked, "a card sits with its OWNER")


func test_changing_owner_moves_the_card_between_the_ante_piles() -> void:
	var staked := g.ante_top_of_library(0)
	g.change_owner(staked, 1)
	assert_eq(g.players[0].ante.size(), 0)
	assert_eq(g.players[1].ante.size(), 1)
	assert_eq(staked.owner_id, 1)


func test_a_battlefield_permanent_can_be_anted() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	g.move_to_ante(bear)
	assert_eq(bear.zone, Mtg.Zone.ANTE)
	assert_eq(g.players[0].battlefield.size(), 0)


func test_tokens_cant_be_anted() -> void:
	var made := g.create_token(0, CardRegistry.get_card("Grizzly Bears"))
	g.move_to_ante(made[0])
	assert_eq(made[0].zone, Mtg.Zone.BATTLEFIELD, "tokens stay put")


# ---------------------------------------------------- Contract from Below --

func test_contract_from_below_trades_your_hand_for_seven() -> void:
	give_hand(0, "Grizzly Bears")
	give_hand(0, "Hill Giant")
	var contract := give_hand(0, "Contract from Below")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, contract, []))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 7, "seven fresh cards")
	assert_eq(g.all_ante().size(), 1, "and one card staked")
	assert_eq(g.players[0].graveyard.size(), 3,
		"the old hand plus the Contract itself")


# ------------------------------------------------------- Demonic Attorney --

func test_demonic_attorney_makes_both_players_ante() -> void:
	var attorney := give_hand(0, "Demonic Attorney")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, attorney, []))
	resolve_stack()
	assert_eq(g.players[0].ante.size(), 1)
	assert_eq(g.players[1].ante.size(), 1)


# ---------------------------------------------------------------- Darkpact --

func test_darkpact_takes_a_card_from_the_ante() -> void:
	var theirs := g.ante_top_of_library(1)
	var my_top: CardInstance = g.players[0].library.back()
	var darkpact := give_hand(0, "Darkpact")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_ok(g.cast_spell(0, darkpact, [TargetRef.card(theirs)]))
	resolve_stack()
	assert_eq(theirs.owner_id, 0, "we own it now")
	assert_eq(theirs.zone, Mtg.Zone.LIBRARY, "and it came back to our library")
	assert_eq(my_top.zone, Mtg.Zone.ANTE, "our top card took its place")


func test_darkpact_needs_a_card_in_the_ante() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var darkpact := give_hand(0, "Darkpact")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_refused(g.cast_spell(0, darkpact, [TargetRef.card(bear)]),
		"Illegal target")


# ------------------------------------------------------------ Jeweled Bird --

func test_jeweled_bird_swaps_your_stake_for_a_card() -> void:
	var stake := g.ante_top_of_library(0)
	var theirs := g.ante_top_of_library(1)
	var bird := put_battlefield(0, "Jeweled Bird")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, bird, 0, []))
	resolve_stack()
	assert_eq(bird.zone, Mtg.Zone.ANTE, "the Bird itself is the new stake")
	assert_eq(stake.zone, Mtg.Zone.GRAVEYARD, "our other stake is rescued")
	assert_eq(theirs.zone, Mtg.Zone.ANTE, "their stake is untouched")
	assert_eq(g.players[0].hand.size(), 1, "and we drew a card")


# ---------------------------------------------------------------- Rebirth --

func test_rebirth_resets_a_losing_players_life() -> void:
	g.adjust_life(0, -12)                       # down to 8
	var rebirth := give_hand(0, "Rebirth")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 3)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, rebirth, []))
	resolve_stack()
	assert_eq(g.players[0].life, 20, "back to 20")
	assert_eq(g.players[0].ante.size(), 1, "at the cost of a card")
	assert_eq(g.players[1].life, 20)
	assert_eq(g.players[1].ante.size(), 0,
		"a player already at 20 has no reason to pay")


# ----------------------------------------------------------- Bronze Tablet --

func test_bronze_tablet_ransom_paid_buries_the_tablet() -> void:
	var tablet := put_battlefield(0, "Bronze Tablet")
	tablet.tapped = false
	var hostage := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, tablet, 0, [TargetRef.card(hostage)]))
	resolve_stack()
	assert_eq(g.players[1].life, 10, "they paid the ransom")
	assert_eq(tablet.zone, Mtg.Zone.GRAVEYARD, "and the Tablet is buried")
	assert_eq(hostage.owner_id, 1, "the hostage stays theirs")


func test_bronze_tablet_ransom_refused_swaps_ownership() -> void:
	var tablet := put_battlefield(0, "Bronze Tablet")
	tablet.tapped = false
	var hostage := put_battlefield(1, "Grizzly Bears")
	g.adjust_life(1, -12)                       # 8 life: they can't pay
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, tablet, 0, [TargetRef.card(hostage)]))
	resolve_stack()
	assert_eq(g.players[1].life, 8, "nothing was paid")
	assert_eq(hostage.owner_id, 0, "we own their creature now")
	assert_eq(tablet.owner_id, 1, "and they own the Tablet")
	assert_eq(hostage.zone, Mtg.Zone.EXILE)


func test_bronze_tablet_enters_tapped() -> void:
	var tablet := put_battlefield(0, "Bronze Tablet")
	assert_true(tablet.tapped)


# ---------------------------------------------------------- Tempest Efreet --

func test_tempest_efreet_takes_a_card_when_the_ransom_is_refused() -> void:
	var efreet := put_battlefield(0, "Tempest Efreet")
	var theirs := give_hand(1, "Grizzly Bears")
	g.adjust_life(1, -12)                       # 8 life: they can't pay
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, efreet, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(theirs.owner_id, 0, "the revealed card is ours now")
	assert_eq(theirs.zone, Mtg.Zone.HAND)
	assert_true(g.players[0].hand.has(theirs))
	assert_eq(efreet.owner_id, 1, "and the Efreet is theirs")
	assert_eq(efreet.zone, Mtg.Zone.GRAVEYARD)


func test_tempest_efreet_ransom_paid_costs_ten_life() -> void:
	var efreet := put_battlefield(0, "Tempest Efreet")
	var theirs := give_hand(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, efreet, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 10)
	assert_eq(theirs.owner_id, 1, "they keep their card")
	assert_eq(efreet.zone, Mtg.Zone.GRAVEYARD, "the Efreet was sacrificed anyway")
	assert_eq(efreet.owner_id, 0)


# ============================================================================
# THE THREE ANTE CARDS OVER A REAL OPENING STAKE (docs/duel-todo.md §6.19).
#
# Until stake_ante existed, no duel ever put a card in the ante, so every
# test above staked one by hand with ante_top_of_library. These run the same
# cards over the stake a real duel now starts with — which is the only state
# Bronze Tablet, Demonic Attorney and Jeweled Bird will ever meet in play.
# ============================================================================

func test_jeweled_bird_dumps_the_opening_stake_and_not_theirs() -> void:
	var mine := g.stake_ante(0)[0]
	var theirs := g.stake_ante(1)[0]
	var bird := put_battlefield(0, "Jeweled Bird")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, bird, 0, []))
	resolve_stack()
	assert_eq(bird.zone, Mtg.Zone.ANTE, "the Bird is the new stake")
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD, "the opening stake is rescued")
	assert_eq(theirs.zone, Mtg.Zone.ANTE, "the opponent's is untouched")
	assert_eq(g.players[1].ante, [theirs] as Array[CardInstance])


func test_demonic_attorney_adds_to_the_opening_stake() -> void:
	g.stake_ante(0)
	g.stake_ante(1)
	var attorney := give_hand(0, "Demonic Attorney")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, attorney, []))
	resolve_stack()
	assert_eq(g.players[0].ante.size(), 2, "the Attorney adds to the stake")
	assert_eq(g.players[1].ante.size(), 2)


func test_bronze_tablet_cannot_hold_a_staked_card_to_ransom() -> void:
	# CARD_IN_ANTE is its own target kind and the ante is not the
	# battlefield: the Tablet takes a PERMANENT, so the opening stake is
	# never a legal hostage (§1.2).
	var staked := g.stake_ante(1)[0]
	var tablet := put_battlefield(0, "Bronze Tablet")
	tablet.tapped = false
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_refused(g.activate_ability(0, tablet, 0, [TargetRef.card(staked)]),
		"Illegal target")
	assert_eq(staked.zone, Mtg.Zone.ANTE, "and it stayed staked")


func test_bronze_tablet_still_works_with_an_ante_on_the_table() -> void:
	g.stake_ante(0)
	var staked := g.stake_ante(1)[0]
	var tablet := put_battlefield(0, "Bronze Tablet")
	tablet.tapped = false
	var hostage := put_battlefield(1, "Grizzly Bears")
	g.adjust_life(1, -12)                       # 8 life: they can't pay
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, tablet, 0, [TargetRef.card(hostage)]))
	resolve_stack()
	assert_eq(hostage.owner_id, 0, "the ransom settled as it always did")
	assert_eq(tablet.owner_id, 1)
	assert_eq(staked.zone, Mtg.Zone.ANTE, "and neither stake moved")
	assert_eq(g.all_ante().size(), 2)


func test_darkpact_can_take_the_opening_stake() -> void:
	var theirs := g.stake_ante(1)[0]
	var my_top: CardInstance = g.players[0].library.back()
	var darkpact := give_hand(0, "Darkpact")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_ok(g.cast_spell(0, darkpact, [TargetRef.card(theirs)]))
	resolve_stack()
	assert_eq(theirs.owner_id, 0, "their opening stake is ours")
	assert_eq(my_top.zone, Mtg.Zone.ANTE, "and our top card took its place")
