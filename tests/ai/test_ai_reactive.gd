extends GameTest
## AI PHASE 2 tests: instant-speed responses — counterspells, Fog, removal
## on attackers, Giant Growth tricks, firebreathing, band declarations,
## and the difficulty gating (the Apprentice plays none of this).


func _reactive_ai(seat: int) -> AiPlayer:
	var ai := AiPlayer.new(seat, AiProfile.wizard())
	g.set_agent(seat, ai)
	return ai


func test_ai_counters_a_big_threat() -> void:
	var ai := _reactive_ai(1)
	give_hand(1, "Counterspell")
	put_battlefield(1, "Island")
	put_battlefield(1, "Island")
	var shivan := give_hand(0, "Shivan Dragon")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, shivan, []))
	assert_ok(g.pass_priority(0))
	assert_string_contains(ai.act(g), "responded with Counterspell")
	resolve_stack()
	assert_eq(shivan.zone, Mtg.Zone.GRAVEYARD, "the dragon never landed")


func test_ai_lets_small_fry_resolve() -> void:
	var ai := _reactive_ai(1)
	give_hand(1, "Counterspell")
	put_battlefield(1, "Island")
	put_battlefield(1, "Island")
	var bears := give_hand(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, bears, []))
	assert_ok(g.pass_priority(0))
	assert_eq(ai.act(g), "pass", "a 2/2 is beneath the counter threshold")
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[1].hand.size(), 1, "Counterspell still in hand")


func test_apprentice_never_counters() -> void:
	var ai := AiPlayer.new(1, AiProfile.apprentice())
	g.set_agent(1, ai)
	give_hand(1, "Counterspell")
	put_battlefield(1, "Island")
	put_battlefield(1, "Island")
	var shivan := give_hand(0, "Shivan Dragon")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, shivan, []))
	assert_ok(g.pass_priority(0))
	assert_eq(ai.act(g), "pass", "phase-1 Magic only at Apprentice")
	resolve_stack()
	assert_eq(shivan.zone, Mtg.Zone.BATTLEFIELD)


func test_ai_fogs_a_lethal_swing() -> void:
	var ai := _reactive_ai(1)
	give_hand(1, "Fog")
	put_battlefield(1, "Forest")
	g.players[1].life = 8
	var serra := put_battlefield(0, "Serra Angel")
	var mammoth := put_battlefield(0, "War Mammoth")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [serra.id, mammoth.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	assert_ok(g.pass_priority(0))
	assert_string_contains(ai.act(g), "responded with Fog")
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 8, "seven power, zero damage — Fog held")


func test_ai_bolts_an_attacking_angel() -> void:
	var ai := _reactive_ai(1)
	give_hand(1, "Lightning Bolt")
	give_hand(1, "Lightning Bolt")   # 3+3 >= Serra's 4 toughness? No — one
	# bolt won't kill a 4/4; give a juicier, killable attacker instead.
	var ai2 := ai   # keep reference style consistent
	put_battlefield(1, "Mountain")
	var wurm := put_battlefield(0, "Craw Wurm")   # 6/4... still 4 toughness
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	assert_ok(g.pass_priority(0))
	assert_eq(ai2.act(g), "pass", "one bolt can't kill the 6/4 — holds it")
	# Now a killable but valuable attacker: Hypnotic Specter (2/2, value>5).
	advance_to_step(Mtg.Step.COMBAT_END)
	advance_to_next_turn()
	advance_to_next_turn()   # back to P0's turn
	var hyppie := put_battlefield(0, "Hypnotic Specter")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [hyppie.id, wurm.id]))
	assert_ok(g.pass_priority(0))
	assert_string_contains(ai2.act(g), "responded with Lightning Bolt")
	resolve_stack()
	assert_eq(hyppie.zone, Mtg.Zone.GRAVEYARD, "the specter died mid-attack")


func test_ai_growth_saves_its_blocker() -> void:
	var ai := _reactive_ai(1)
	give_hand(1, "Giant Growth")
	put_battlefield(1, "Forest")
	var bears0 := put_battlefield(0, "Grizzly Bears")
	var bears1 := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bears0.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {bears1.id: bears0.id}))
	assert_ok(g.pass_priority(0))
	assert_string_contains(ai.act(g), "responded with Giant Growth")
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bears1.zone, Mtg.Zone.BATTLEFIELD, "5/5 blocker survived the trade")
	assert_eq(bears0.zone, Mtg.Zone.GRAVEYARD)


func test_ai_declares_a_band() -> void:
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	put_battlefield(0, "Benalish Hero")
	put_battlefield(0, "Mesa Pegasus")
	put_battlefield(0, "Serra Angel")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_string_contains(ai.act(g), "banded")
	assert_eq(g.combat.bands.size(), 1)
	assert_eq(g.combat.bands[0].size(), 3, "two banders + the angel riding along")


func test_ai_holds_counter_mana_over_marginal_casts() -> void:
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	give_hand(0, "Counterspell")
	give_hand(0, "Merfolk of the Pearl Trident")   # 1/1: value ~2, marginal
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	advance_to_step(Mtg.Step.MAIN1)
	var did := ai.act(g)
	assert_eq(did, "pass", "keeps {U}{U} open instead of a 1/1")
	assert_eq(g.players[0].hand.size(), 2)


func test_reactive_soak_still_completes() -> void:
	# The response framework must not stall full games.
	var game := MtgGame.new()
	game.setup(StarterDecks.WHITE_KNIGHTS, StarterDecks.BLACK_RED_RAIDERS,
		"A", "B", 20, 20, 777)
	var ai0 := AiPlayer.new(0, AiProfile.wizard())
	var ai1 := AiPlayer.new(1, AiProfile.wizard())
	game.set_agent(0, ai0)
	game.set_agent(1, ai1)
	game.start()
	assert_true(AiPlayer.play_out(game, ai0, ai1), "reactive game ran to a conclusion")
	assert_true(game.winner in [0, 1])
