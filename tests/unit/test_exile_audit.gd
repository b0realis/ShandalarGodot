extends GameTest
## EXILE audit (2026-08): every invariant the exile zone has to hold.
##
## Exile is the 1997 rulebook's "removed from the game" pile: a card that
## goes there is out of the duel — no graveyard, no regrowth, no
## reanimation, nothing to target. These tests pin the whole surface of
## MtgGame.exile_permanent / exile_from_graveyard / exile_top_of_library
## and the three return paths, so that a card that leaves through exile
## can never quietly reappear.


# ------------------------------------------------------- leaving for exile --

func test_exile_wipes_every_scrap_of_battlefield_state() -> void:
	# CR 400.7: the object in exile remembers nothing of the permanent.
	var bear := put_battlefield(0, "Grizzly Bears")
	bear.tapped = true
	bear.damage = 1
	g.add_counters(bear, "+1/+1", 2)
	bear.memory["note"] = 7
	g.exile_permanent(bear)
	assert_eq(bear.zone, Mtg.Zone.EXILE)
	assert_true(g.players[0].exile.has(bear), "it rests in its owner's exile")
	assert_false(bear.tapped, "untapped")
	assert_eq(bear.damage, 0, "no marked damage")
	assert_true(bear.counters.is_empty(), "no counters")
	assert_true(bear.memory.is_empty(), "no card memory")
	assert_eq(g.players[0].battlefield.size(), 0)
	assert_eq(g.players[0].graveyard.size(), 0, "exile is not the graveyard")


func test_an_exiled_creature_drops_its_auras_in_the_graveyard() -> void:
	# The Aura is not exiled with its host: it becomes an orphan and the
	# state-based action (CR 704.5m) puts it into its owner's graveyard.
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := give_hand(0, "Holy Strength")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_power, 3, "the Aura is on")
	g.exile_permanent(bear)
	assert_eq(aura.zone, Mtg.Zone.GRAVEYARD, "the Aura falls off into the graveyard")
	assert_true(bear.attachments.is_empty(), "and the exiled card keeps no attachment")


func test_exiling_a_stealing_aura_hands_the_creature_back() -> void:
	# Control Magic exiled (Dust to Dust's cousin) ends the theft.
	var bear := put_battlefield(1, "Grizzly Bears")
	var steal := give_hand(0, "Control Magic")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 4)
	assert_ok(g.cast_spell(0, steal, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.controller_id, 0, "stolen")
	g.exile_permanent(steal)
	assert_eq(bear.controller_id, 1, "and returned when the Aura is exiled")


func test_regeneration_cannot_save_a_creature_from_exile() -> void:
	# Exile is not destruction (CR 701.15a replaces destruction only).
	var bear := put_battlefield(0, "Grizzly Bears")
	bear.regeneration_shields = 1
	g.exile_permanent(bear)
	assert_eq(bear.zone, Mtg.Zone.EXILE)
	assert_eq(bear.regeneration_shields, 0, "the shield went with the wipe")


func test_exile_fires_no_dies_trigger() -> void:
	# Sengir Vampire grows on a creature that DIES; Swords to Plowshares
	# gives it nothing.
	var vampire := put_battlefield(0, "Sengir Vampire")
	var bear := put_battlefield(1, "Grizzly Bears")
	var sword := give_hand(0, "Swords to Plowshares")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, sword, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.EXILE)
	assert_eq(vampire.cur_power, 4, "no +1/+1 counter — nothing died")


# ---------------------------------------------------------- staying exiled --

func test_an_exiled_creature_cannot_be_targeted() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var bolt := give_hand(0, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	g.exile_permanent(bear)
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(0, bolt, [TargetRef.card(bear)]))


func test_a_spell_fizzles_when_its_target_is_exiled_in_response() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var bolt := give_hand(0, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	g.exile_permanent(bear)          # in response
	resolve_stack()
	assert_eq(g.players[1].life, 20, "the Bolt fizzled — no redirection")
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)


func test_an_exiled_card_is_out_of_reach_of_the_graveyard_cards() -> void:
	# Raise Dead may not fish a card out of exile.
	var bear := put_battlefield(0, "Grizzly Bears")
	g.exile_permanent(bear)
	var raise := give_hand(0, "Raise Dead")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	# §6.10: the 1997 refusal for the right kind of card in the wrong
	# ZONE is `,where`, which is exactly what this test is about.
	assert_refused(g.cast_spell(0, raise, [TargetRef.card(bear)]),
		"Illegal target (where).")
	assert_eq(bear.zone, Mtg.Zone.EXILE, "still exiled")


func test_shuffling_the_graveyard_away_leaves_exile_alone() -> void:
	# Feldon's Cane's shuffle is a GRAVEYARD effect: an exiled card must
	# not ride back into the library with it.
	var exiled := put_battlefield(0, "Grizzly Bears")
	var dead := put_battlefield(0, "Grizzly Bears")
	g.exile_permanent(exiled)
	g.destroy(dead)
	var library_before := g.players[0].library.size()
	g.shuffle_graveyard_into_library(0)
	assert_eq(g.players[0].library.size(), library_before + 1,
		"only the graveyard card went back")
	assert_eq(exiled.zone, Mtg.Zone.EXILE)
	assert_true(g.players[0].exile.has(exiled))


func test_exile_permanent_ignores_a_card_that_is_not_on_the_battlefield() -> void:
	var card := give_hand(0, "Grizzly Bears")
	g.exile_permanent(card)
	assert_eq(card.zone, Mtg.Zone.HAND, "hands are not exiled by this helper")
	assert_eq(g.players[0].exile.size(), 0)


func test_a_card_exiled_from_a_graveyard_leaves_the_graveyard() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	g.destroy(bear)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	g.exile_from_graveyard(bear)
	assert_eq(bear.zone, Mtg.Zone.EXILE)
	assert_eq(g.players[0].graveyard.size(), 0)
	assert_true(g.players[0].exile.has(bear))


# --------------------------------------------------------- coming back out --

func test_a_creature_returning_from_exile_is_a_new_object() -> void:
	# CR 400.7: no counters, no until-end-of-turn pump, and it is newly
	# under its controller's control (summoning sick).
	var bear := put_battlefield(0, "Grizzly Bears")
	var growth := give_hand(0, "Giant Growth")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_power, 5, "pumped")
	g.add_counters(bear, "+1/+1", 1)
	g.exile_permanent(bear)
	g.return_from_exile_to_play(bear, 0)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.cur_power, 2, "the pump did not follow it back")
	assert_true(bear.counters.is_empty(), "nor did the counter")
	assert_true(bear.summoning_sick, "it is a new arrival")
	assert_eq(g.players[0].exile.size(), 0, "and it left the exile pile")


func test_return_from_exile_to_hand_empties_the_exile_pile() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	g.exile_permanent(bear)
	g.return_from_exile_to_hand(bear)
	assert_eq(bear.zone, Mtg.Zone.HAND)
	assert_true(g.players[0].hand.has(bear))
	assert_eq(g.players[0].exile.size(), 0)


func test_return_from_exile_to_graveyard_empties_the_exile_pile() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	g.exile_permanent(bear)
	g.return_from_exile_to_graveyard(bear)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.players[0].graveyard.has(bear))
	assert_eq(g.players[0].exile.size(), 0)


func test_a_card_exiled_face_down_comes_back_face_up() -> void:
	# Knowledge Vault exiles face down; its payout hands the cards over.
	var top := g.exile_top_of_library(0)
	assert_not_null(top)
	assert_true(top.face_down)
	g.return_from_exile_to_hand(top)
	assert_false(top.face_down, "a card in hand is never face down")


func test_an_exiled_attacker_that_returns_is_no_longer_attacking() -> void:
	# CR 506.4: a permanent that leaves the battlefield is removed from
	# combat, and what comes back is a NEW object (400.7) that was never
	# declared as an attacker. Tawnos's Coffin can do exactly this mid-combat.
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	resolve_stack()
	g.exile_permanent(bear)
	g.return_from_exile_to_play(bear, 0)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20, "it dealt no combat damage")


func test_an_exiled_blocker_that_returns_is_no_longer_blocking() -> void:
	var attacker := put_battlefield(0, "Hill Giant")   # 3/3, survives the block
	var blocker := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {blocker.id: attacker.id}))
	g.exile_permanent(blocker)
	g.return_from_exile_to_play(blocker, 1)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(attacker.damage, 0, "the creature that came back deals no damage")
	assert_eq(blocker.damage, 0, "and takes none")
	assert_eq(g.players[1].life, 20, "the attacker stays blocked (CR 509.1h)")
