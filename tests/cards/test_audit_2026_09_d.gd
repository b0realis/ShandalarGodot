extends GameTest
## 2026-09 audit pins, FINAL batch (D): the delayed-trigger, intervening-if
## and "the ability resolves without its source" findings, plus the four
## cards whose printed line this engine still cannot express.
## Every test quotes the printed clause it protects. The behavioural ones
## failed before the fix recorded beside them; the ones marked SIMPLIFIED
## pin the GAP on purpose and carry the ledger row in their comment.


# ------------------------------------------------------------ Time Elemental --

func test_time_elemental_burns_its_controller_even_when_it_dies_blocking() -> void:
	# "When this creature attacks or blocks, AT END OF COMBAT, sacrifice it
	# and it deals 5 damage to you." — the sacrifice and the damage are a
	# DELAYED trigger created when it fought (CR 603.7a). It outlives the
	# Elemental: dying in combat only makes the sacrifice do nothing, the
	# five damage still lands.
	var giant := put_battlefield(0, "Hill Giant")          # 3/3
	var elemental := put_battlefield(1, "Time Elemental")  # 0/2
	run_combat([giant.id], {elemental.id: giant.id})
	assert_eq(elemental.zone, Mtg.Zone.GRAVEYARD, "the 0/2 died blocking")
	assert_eq(g.players[1].life, 15, "the delayed trigger still fires")


func test_time_elemental_immolation_survives_a_bounce() -> void:
	# Same delayed trigger, the other way round: bounce the Elemental in
	# response and the sacrifice fails, but the 5 damage does not.
	var elemental := put_battlefield(0, "Time Elemental")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [elemental.id]))
	resolve_stack()                 # the attack trigger schedules the doom
	g.return_to_hand(elemental)     # an Unsummon in response
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(elemental.zone, Mtg.Zone.HAND, "nothing to sacrifice")
	assert_eq(g.players[0].life, 15, "the 5 damage still happens")


func test_time_elemental_sacrifices_itself_after_a_quiet_attack() -> void:
	var elemental := put_battlefield(0, "Time Elemental")
	run_combat([elemental.id])
	assert_eq(elemental.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 15)


func test_time_elemental_that_stayed_home_is_safe() -> void:
	var elemental := put_battlefield(0, "Time Elemental")
	run_combat([])
	assert_eq(elemental.zone, Mtg.Zone.BATTLEFIELD, "it never fought")
	assert_eq(g.players[0].life, 20)


# ------------------------------------------------------------ Blazing Effigy --

func test_blazing_effigy_chain_counts_the_damage_not_the_sources() -> void:
	# "X is 3 plus the AMOUNT OF DAMAGE dealt to this creature this turn by
	# other sources named Blazing Effigy" — the first Effigy's 3 damage
	# makes the second one's X six, not four.
	var colossus := put_battlefield(0, "Colossus of Sardia")   # 9/9, survives it
	var first := put_battlefield(0, "Blazing Effigy")
	var second := put_battlefield(1, "Blazing Effigy")         # 0/3
	advance_to_step(Mtg.Step.MAIN1)
	g.destroy(first, false)
	resolve_stack()
	assert_eq(second.zone, Mtg.Zone.GRAVEYARD, "3 damage kills the 0/3")
	assert_eq(colossus.damage, 6, "3 + the 3 the first Effigy dealt it")


func test_blazing_effigy_alone_deals_exactly_three() -> void:
	var effigy := put_battlefield(0, "Blazing Effigy")
	var giant := put_battlefield(1, "Hill Giant")   # 3/3
	advance_to_step(Mtg.Step.MAIN1)
	g.destroy(effigy, false)
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "no other Effigy hurt it — just 3")


# --------------------------------------------------------- Sword of the Ages --

func test_sword_of_the_ages_sacrifices_its_army_before_exiling_it() -> void:
	# "Sacrifice this artifact and any number of creatures you control:
	# ... then exile this artifact and those creature cards." The creatures
	# are SACRIFICED (their dies-triggers fire) and only the resulting
	# CARDS are exiled afterwards.
	var sword := put_battlefield(0, "Sword of the Ages")
	sword.tapped = false
	var onulet := put_battlefield(0, "Onulet")   # 2/2, "when this dies, you gain 2 life"
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, sword, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 18, "2 total power")
	assert_eq(g.players[0].life, 22, "the Onulet DIED on its way out")
	assert_eq(onulet.zone, Mtg.Zone.EXILE, "and the card is exiled after that")
	assert_eq(sword.zone, Mtg.Zone.EXILE)
	assert_eq(g.players[0].graveyard.size(), 0, "nothing is left in the graveyard")


# ------------------------------------------------------------- Hasran Ogress --

func test_hasran_ogress_bites_even_when_it_is_sacrificed_in_response() -> void:
	# A triggered ability resolves independently of its source (CR 603.6,
	# and 608.2h for what it needs to know about it) — sacrificing the
	# Ogress with the trigger on the stack does not refund the 3 damage.
	var ogress := put_battlefield(0, "Hasran Ogress")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [ogress.id]))
	g.sacrifice_permanent(ogress)   # in response to its own attack trigger
	resolve_stack()
	assert_eq(g.players[0].life, 17, "the tax is owed whatever happened to the Ogress")


# ------------------------------- Powerleech / Haunting Wind (GAP — CLOSED) --

func test_powerleech_and_haunting_wind_catch_tapless_artifact_activations() -> void:
	# The gap this audit found — both cards' second printed clause, "or a
	# player activates an artifact's ability without {T} in its activation
	# cost", had no event to listen to — CLOSED on 2026-09-01 by
	# Mtg.EventType.ABILITY_ACTIVATED (wave 62). Both ledger rows are gone;
	# this test now pins the printed behaviour instead of the shortfall.
	put_battlefield(0, "Powerleech")
	put_battlefield(0, "Haunting Wind")
	var monolith := put_battlefield(1, "Jade Monolith")   # "{1}:" — no {T}
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(1, monolith, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(g.players[0].life, 21,
		"Powerleech gains 1 life off an opponent's tapless activation")
	assert_eq(g.players[1].life, 19,
		"Haunting Wind stings the Monolith's controller for 1")


func test_haunting_wind_and_powerleech_still_watch_taps() -> void:
	# The clause that IS implemented, so the gap above stays honest.
	put_battlefield(0, "Powerleech")
	put_battlefield(0, "Haunting Wind")
	var monolith := put_battlefield(1, "Jade Monolith")
	advance_to_step(Mtg.Step.MAIN1)
	g.tap_permanent(monolith)
	resolve_stack()
	assert_eq(g.players[0].life, 21, "an opponent's artifact became tapped")
	assert_eq(g.players[1].life, 19, "and the Wind is symmetric")


# ----------------------------------------------------------- Field of Dreams --

func test_field_of_dreams_reveals_the_tops_and_polices_the_world_slot() -> void:
	# "Players play with the top card of their libraries revealed" — lifted
	# 2026-09-02 (MtgGame.revealed_top_card; pinned in
	# test_fidelity_2026_09_02_permanents.gd). It is still a world
	# enchantment (CR 704.5k).
	var field := put_battlefield(0, "Field of Dreams")
	assert_eq(g.revealed_top_card(1), g.players[1].library[-1],
		"the opponent's top card is public")
	assert_ne(field.data.supertypes & Mtg.Supertype.WORLD, 0,
		"the world rule still applies to it")


# ---------------------------------------------------------- Wall of Caltrops --

func test_wall_of_caltrops_rechecks_its_intervening_if_on_resolution() -> void:
	# "Whenever this creature blocks a creature, IF at least one other Wall
	# creature is blocking that creature..." — an intervening "if" is
	# checked twice: when the trigger would go on the stack AND again as it
	# resolves (CR 603.4). Kill the other Wall in response and no banding.
	var attacker := put_battlefield(0, "Hill Giant")
	var caltrops := put_battlefield(1, "Wall of Caltrops")
	var other := put_battlefield(1, "Wall of Stone")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {caltrops.id: attacker.id, other.id: attacker.id}))
	g.destroy(other, false)         # the gang breaks up with the trigger on the stack
	resolve_stack()
	assert_false(caltrops.has_keyword(Mtg.Keyword.BANDING),
		"CR 603.4: the condition is tested again on resolution")


func test_wall_of_caltrops_still_bands_with_an_intact_gang() -> void:
	var attacker := put_battlefield(0, "Hill Giant")
	var caltrops := put_battlefield(1, "Wall of Caltrops")
	var other := put_battlefield(1, "Wall of Stone")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {caltrops.id: attacker.id, other.id: attacker.id}))
	resolve_stack()
	assert_true(caltrops.has_keyword(Mtg.Keyword.BANDING), "two Walls, no one else")


# ------------------------------------------------------ Rasputin Dreamweaver --

func test_rasputin_gets_no_dream_when_he_started_the_turn_tapped() -> void:
	# "At the beginning of your upkeep, if Rasputin STARTED THE TURN
	# untapped, put a dream counter on it." The untap step has already
	# freed him by the time the upkeep trigger looks, so the check must
	# read what he was when the turn began, not what he is now.
	var rasputin := put_battlefield(0, "Rasputin Dreamweaver")
	rasputin.counters["dream"] = 5
	advance_to_next_turn()          # the opponent's turn
	g.tap_permanent(rasputin)       # tapped down on their turn (an Icy)
	resolve_stack()
	advance_to_next_turn()          # our turn — the untap step frees him
	resolve_stack()
	assert_false(rasputin.tapped, "he did untap")
	assert_eq(int(rasputin.counters.get("dream", 0)), 5,
		"he did not START the turn untapped")


func test_rasputin_refills_again_after_a_calm_turn() -> void:
	# ...and the bookkeeping clears itself, so the next quiet turn pays.
	var rasputin := put_battlefield(0, "Rasputin Dreamweaver")
	rasputin.counters["dream"] = 5
	advance_to_next_turn()
	g.tap_permanent(rasputin)
	resolve_stack()
	advance_to_next_turn()          # skipped: he started this one tapped
	resolve_stack()
	assert_eq(int(rasputin.counters.get("dream", 0)), 5)
	advance_to_next_turn()
	advance_to_next_turn()          # a turn he started untapped
	resolve_stack()
	assert_eq(int(rasputin.counters.get("dream", 0)), 6, "back on the payroll")


# --------------------------------------------------------- Scarwood Hag (GAP) --

func test_scarwood_hag_loss_strips_forestwalk_only() -> void:
	# Lifted 2026-09-02 (the "Landwalk stripping" ledger row): the floating
	# ability-loss carries a land-type list, so "loses forestwalk" leaves
	# an islandwalker its islandwalk.
	var hag := put_battlefield(0, "Scarwood Hag")
	var leviathan := put_battlefield(1, "Segovian Leviathan")   # islandwalk
	assert_true(leviathan.cur_landwalk.has("island"))
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, hag, 1, [TargetRef.card(leviathan)]))
	resolve_stack()
	assert_eq(leviathan.cur_landwalk, ["island"],
		"'loses forestwalk' strips forestwalk and nothing else")
