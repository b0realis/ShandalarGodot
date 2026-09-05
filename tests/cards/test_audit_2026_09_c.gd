extends GameTest
## 2026-09 audit pins, batch C — Antiquities, The Dark and Fourth Edition
## cards (plus the two neighbours the same findings reach: Legends'
## Knowledge Vault and Arabian Nights' Desert Nomads).
## Every test here quotes the printed line it protects and, where the card
## keeps a deliberate shortcut, pins the GAP instead and says so. Each one
## failed before the fix recorded beside it.


# -------------------------------------------------------- Xenic Poltergeist --

func test_xenic_poltergeist_animation_outlives_its_source() -> void:
	# "{T}: Until your next upkeep, target noncreature artifact becomes an
	# artifact creature..." — a ONE-SHOT effect with its own duration
	# (CR 611.2b), not a static of the Poltergeist. Killing the Poltergeist
	# does not un-animate the artifact.
	var poltergeist := put_battlefield(0, "Xenic Poltergeist")
	var ring := put_battlefield(1, "Sol Ring")   # mana value 1
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, poltergeist, 0, [TargetRef.card(ring)]))
	resolve_stack()
	assert_true(ring.is_creature(), "the artifact is animated")
	assert_eq(ring.cur_power, 1)
	g.destroy(poltergeist, false)
	g.check_state_based_actions()
	assert_true(ring.is_creature(), "the effect is independent of its source")
	assert_eq(ring.cur_toughness, 1)


func test_xenic_poltergeist_can_hold_two_artifacts_at_once() -> void:
	# Two activations are two separate effects; the second must not cancel
	# the first (the old card-memory implementation could hold only one).
	var poltergeist := put_battlefield(0, "Xenic Poltergeist")
	var ring := put_battlefield(1, "Sol Ring")          # mana value 1
	var icy := put_battlefield(1, "Icy Manipulator")    # mana value 4
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, poltergeist, 0, [TargetRef.card(ring)]))
	resolve_stack()
	g.untap_permanent(poltergeist)   # a Twiddle-style untap
	assert_ok(g.activate_ability(0, poltergeist, 0, [TargetRef.card(icy)]))
	resolve_stack()
	assert_true(ring.is_creature(), "the first animation still stands")
	assert_eq(ring.cur_power, 1)
	assert_true(icy.is_creature())
	assert_eq(icy.cur_power, 4)


func test_xenic_poltergeist_animation_runs_to_your_next_upkeep() -> void:
	# "Until your next upkeep" — the GAP this test used to pin (the
	# animation registry counted only to the cleanup step) was closed by
	# ContinuousEffects.Duration.UNTIL_UPKEEP_OF; the full behaviour lives
	# in tests/unit/test_effect_durations.gd.
	var poltergeist := put_battlefield(0, "Xenic Poltergeist")
	var ring := put_battlefield(1, "Sol Ring")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, poltergeist, 0, [TargetRef.card(ring)]))
	resolve_stack()
	advance_to_next_turn()
	assert_true(ring.is_creature(),
		"it stays animated through the opponent's turn")


# --------------------------------------------------------- Tawnos's Coffin --

func test_tawnos_coffin_exiles_the_auras_and_brings_them_back() -> void:
	# "Exile target creature AND ALL AURAS ATTACHED TO IT... return the
	# other exiled cards to the battlefield... attached to that permanent."
	var coffin := put_battlefield(0, "Tawnos's Coffin")
	var angel := put_battlefield(1, "Serra Angel")
	var strength := give_hand(0, "Holy Strength")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, strength, [TargetRef.card(angel)]))
	resolve_stack()
	assert_eq(angel.cur_power, 5, "4/4 plus +1/+2")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, coffin, 0, [TargetRef.card(angel)]))
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.EXILE)
	assert_eq(strength.zone, Mtg.Zone.EXILE, "the Aura is exiled with its host")
	g.untap_permanent(coffin)
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(strength.zone, Mtg.Zone.BATTLEFIELD, "and comes back with it")
	assert_eq(strength.attached_to, angel.id, "re-attached to that permanent")
	assert_true(angel.attachments.has(strength.id))
	assert_eq(angel.cur_power, 5, "the Aura is doing its job again")


# ------------------------------------------------------------ Urza's Miter --

func test_urzas_miter_pays_for_its_own_death() -> void:
	# "Whenever an artifact you control is put into a graveyard from the
	# battlefield" — the Miter is itself such an artifact, and leave-the-
	# battlefield triggers look back in time (CR 603.6d / 603.10).
	var miter := put_battlefield(0, "Urza's Miter")
	for _i in 3:
		put_battlefield(0, "Forest")
	var before := g.players[0].hand.size()
	g.destroy(miter, false)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), before + 1, "{3} paid, a card drawn")


func test_tablet_of_epityr_pays_for_its_own_death() -> void:
	var tablet := put_battlefield(0, "Tablet of Epityr")
	put_battlefield(0, "Forest")
	g.destroy(tablet, false)
	resolve_stack()
	assert_eq(g.players[0].life, 21, "the Tablet is an artifact you control")


func test_urzas_miter_ignores_a_sacrificed_artifact() -> void:
	# "...IF IT WASN'T SACRIFICED, you may pay {3}." The GAP this test used
	# to pin (no cause on the departure event) was closed by the
	# `sacrificed` flag; the pair of tests lives in
	# tests/cards/test_fidelity_2026_09.gd.
	put_battlefield(0, "Urza's Miter")
	var ring := put_battlefield(0, "Sol Ring")
	for _i in 3:
		put_battlefield(0, "Forest")
	var before := g.players[0].hand.size()
	g.sacrifice_permanent(ring)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), before,
		"a sacrificed artifact draws nothing")


# ------------------------------------------------- Frankenstein's Monster --

func test_frankensteins_monster_survives_being_cast_for_zero() -> void:
	# "As this creature enters, exile X creature cards from your graveyard.
	# If you can't, put this creature into its owner's graveyard instead" —
	# exiling ZERO cards always succeeds, so X=0 is a legal (if feeble) cast.
	var monster := give_hand(0, "Frankenstein's Monster")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, monster, [], 0))
	resolve_stack()
	assert_eq(monster.zone, Mtg.Zone.BATTLEFIELD, "a 0/1 zombie, but a live one")
	assert_eq(monster.cur_power, 0)
	assert_eq(monster.cur_toughness, 1)


func test_frankensteins_monster_still_collapses_when_short() -> void:
	# X=2 with an empty graveyard: it really can't pay, so it is buried.
	var monster := give_hand(0, "Frankenstein's Monster")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, monster, [], 2))
	resolve_stack()
	assert_eq(monster.zone, Mtg.Zone.GRAVEYARD)


# ----------------------------------------------------------- Eternal Flame --

func test_eternal_flame_really_targets_the_opponent() -> void:
	# "Eternal Flame deals X damage to TARGET OPPONENT" — a real target
	# slot, so the choice is made on casting and the usual targeting rules
	# (CR 115) can apply to it. The self-damage half is untargeted.
	put_battlefield(0, "Mountain")
	var flame := give_hand(0, "Eternal Flame")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.cast_spell(0, flame, []), "target")
	assert_refused(g.cast_spell(0, flame, [TargetRef.player(0)]),
		"Illegal target")   # you are not your own opponent
	assert_ok(g.cast_spell(0, flame, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 19, "one Mountain → 1 damage")
	assert_eq(g.players[0].life, 19, "half of 1, rounded up, to you")


# ------------------------------------------------------ Transmute Artifact --

func test_transmute_artifact_sacrifices_on_resolution_not_on_casting() -> void:
	# "Sacrifice an artifact. If you do, search your library..." — the
	# sacrifice is part of the RESOLUTION, not an additional cost
	# (CR 601.2h lists the costs; this clause is in the rules text), so a
	# countered Transmute Artifact costs its caster no artifact at all.
	var fodder := put_battlefield(0, "Sol Ring")
	var transmute := give_hand(0, "Transmute Artifact")
	var counter := give_hand(1, "Counterspell")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, transmute, []))
	assert_eq(fodder.zone, Mtg.Zone.BATTLEFIELD, "nothing is eaten on casting")
	add_mana(1, Mtg.ManaColor.U, 2)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, counter, [TargetRef.card(transmute)]))
	resolve_stack()
	assert_eq(transmute.zone, Mtg.Zone.GRAVEYARD, "countered")
	assert_eq(fodder.zone, Mtg.Zone.BATTLEFIELD,
		"a countered Transmute Artifact eats nothing")


func test_transmute_artifact_still_trades_up_when_it_resolves() -> void:
	var fodder := put_battlefield(0, "Sol Ring")      # mana value 1
	var prize := _make_instance(0, "Black Lotus")     # mana value 0
	prize.zone = Mtg.Zone.LIBRARY
	g.players[0].library.append(prize)
	var transmute := give_hand(0, "Transmute Artifact")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, transmute, []))
	resolve_stack()
	assert_eq(fodder.zone, Mtg.Zone.GRAVEYARD, "sacrificed as it resolved")
	assert_eq(prize.zone, Mtg.Zone.BATTLEFIELD)


func test_transmute_artifact_may_be_cast_with_no_artifact() -> void:
	# Nothing about the printed card stops the cast — "if you do" simply
	# never happens, and the spell does nothing.
	var transmute := give_hand(0, "Transmute Artifact")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, transmute, []))
	resolve_stack()
	assert_eq(transmute.zone, Mtg.Zone.GRAVEYARD, "it resolved and did nothing")


# --------------------------------------- live characteristics (rule 5) --

func test_argothian_treefolk_reads_live_artifact_types() -> void:
	# CONTRIBUTING.md rule 5: rules code reads LIVE characteristics. A Grizzly
	# Bears that Ashnod's Transmogrant has turned into an artifact IS an
	# artifact source, printed type line or not.
	var treefolk := put_battlefield(0, "Argothian Treefolk")
	var bear := put_battlefield(1, "Grizzly Bears")
	var transmogrant := put_battlefield(1, "Ashnod's Transmogrant")
	advance_to_next_turn()   # player 1's turn
	assert_ok(g.activate_ability(1, transmogrant, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.is_type(Mtg.CardType.ARTIFACT), "live type")
	assert_false(bear.data.is_type(Mtg.CardType.ARTIFACT), "printed type says no")
	run_combat([bear.id], {treefolk.id: bear.id})
	assert_eq(treefolk.damage, 0, "an artifact source can't damage the Treefolk")


func test_desert_nomads_shrug_off_a_desert() -> void:
	# Regression pin for the same rule-5 rewrite on Desert Nomads (the
	# filter now reads cur_types/cur_subtypes). No card in the 1997 pool
	# can turn something INTO a Desert, so the printed-vs-live difference
	# is not observable yet — this pins that the immunity still works.
	var nomads := put_battlefield(0, "Desert Nomads")
	var desert := put_battlefield(1, "Desert")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [nomads.id]))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, desert, 0, [TargetRef.card(nomads)]))
	resolve_stack()
	assert_eq(nomads.damage, 0, "Deserts can't hurt them")


# ------------------------------------------------------------- War Barge --

func test_war_barge_drowns_this_turns_passenger() -> void:
	var barge := put_battlefield(0, "War Barge")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, barge, 0, [TargetRef.card(bear)]))
	resolve_stack()
	g.destroy(barge)
	g.check_state_based_actions()
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "it went down with the ship")


func test_war_barge_forgets_last_turns_passengers() -> void:
	# "When this artifact leaves the battlefield THIS TURN, destroy that
	# creature" — the delayed trigger is set up for the turn the ability
	# was activated only; a Barge sunk two turns later drowns nobody.
	var barge := put_battlefield(0, "War Barge")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, barge, 0, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_next_turn()
	advance_to_next_turn()   # our next turn — last turn's ferry is over
	g.destroy(barge)
	g.check_state_based_actions()
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD,
		"the Barge only drowns the creature it ferried THIS turn")


# ------------------------------------------------------ Worms of the Earth --

func test_worms_of_the_earth_stop_a_fetched_land_too() -> void:
	# The printed card has TWO bans — "Players can't play lands" AND "Lands
	# can't enter the battlefield" — and only the second one stops Untamed
	# Wilds, which does not PLAY the land it fetches. The GAP this test used
	# to pin was closed by CardData.enters_ban_rule / MtgGame.entry_refused.
	put_battlefield(0, "Worms of the Earth")
	var wilds := give_hand(0, "Untamed Wilds")
	advance_to_step(Mtg.Step.MAIN1)
	var land := give_hand(0, "Forest")
	assert_refused(g.play_land(0, land), "Worms of the Earth")
	assert_eq(land.zone, Mtg.Zone.HAND, "a refused land drop costs nothing")
	assert_eq(g.players[0].lands_played_this_turn, 0,
		"and does not spend the turn's land drop")
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, wilds, []))
	resolve_stack()
	assert_null(g.find_on_battlefield(0, "Forest"),
		"no land may ENTER the battlefield either")
	# The search found it and could not put it down, so it stays in the
	# library the search shuffled — not in a graveyard, not in exile.
	var still_in_library := 0
	for card in g.players[0].library:
		if card.data.card_name == "Forest":
			still_in_library += 1
	assert_gt(still_in_library, 0, "the fetched land goes back to the library")
	assert_eq(g.players[0].graveyard.size(), 1, "only the Wilds itself")


# ---------------------------------------------------------------- Preacher --

func test_preacher_takes_the_creature_the_victim_would_give() -> void:
	# "gain control of target creature OF AN OPPONENT'S CHOICE they
	# control" — the choice is the victim's, so they hand over their worst
	# creature, not their best.
	var preacher := put_battlefield(0, "Preacher")
	var angel := put_battlefield(1, "Serra Angel")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, preacher, 0, []))   # their target, their pick
	resolve_stack()
	assert_eq(bear.controller_id, 0, "they give up the cheapest body")
	assert_eq(angel.controller_id, 1, "and keep the Angel")


# --------------------------------------------------------- Knowledge Vault --

func test_knowledge_vault_discards_nothing_if_it_never_sacrificed() -> void:
	# "{0}: Sacrifice this artifact. IF YOU DO, discard your hand, then
	# put all cards exiled with this artifact into their owner's hand." —
	# a Vault destroyed in response cannot be sacrificed, so none of the
	# payload happens (CR 701.17b: you can't sacrifice what you don't
	# control).
	var vault := put_battlefield(0, "Knowledge Vault")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, vault, 0, []))
	resolve_stack()
	var hoarded: CardInstance = g.players[0].exile[0]
	var keeper := give_hand(0, "Grizzly Bears")
	assert_ok(g.activate_ability(0, vault, 1, []))   # cash-in on the stack
	g.destroy(vault)                                 # ... destroyed in response
	g.check_state_based_actions()
	resolve_stack()
	assert_eq(keeper.zone, Mtg.Zone.HAND, "no sacrifice, no discard")
	assert_eq(g.players[0].hand.size(), 1)
	assert_eq(hoarded.zone, Mtg.Zone.GRAVEYARD, "the hoard was buried instead")


func test_knowledge_vault_still_cashes_in_when_it_can() -> void:
	var vault := put_battlefield(0, "Knowledge Vault")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, vault, 0, []))
	resolve_stack()
	give_hand(0, "Grizzly Bears")
	assert_ok(g.activate_ability(0, vault, 1, []))
	resolve_stack()
	assert_eq(vault.zone, Mtg.Zone.GRAVEYARD, "it sacrificed itself")
	assert_eq(g.players[0].hand.size(), 1, "old hand out, hoard in")
	assert_eq(g.players[0].exile.size(), 0)


# -------------------------------------------------------------- Energy Flux --

func test_energy_flux_spares_an_artifact_that_arrives_in_response() -> void:
	# Lifted 2026-09-02: the Flux GRANTS every artifact its own "at the
	# beginning of your upkeep" trigger (CardInstance.cur_triggered_
	# abilities), so an artifact that arrives after that moment is not
	# taxed this turn (CR 603.2). It used to be one trigger on the Flux
	# that walked the battlefield at resolution and taxed the latecomer.
	put_battlefield(1, "Sol Ring")
	put_battlefield(0, "Energy Flux")
	var guard := 0
	while (g.turn_number < 2 or g.current_step() != Mtg.Step.UPKEEP) and guard < 200:
		_advance_once()
		guard += 1
	assert_eq(g.active_player, 1, "their upkeep")
	assert_eq(g.stack.size(), 1, "the first Ring's own tax is waiting")
	var ring := put_battlefield(1, "Sol Ring")   # arrives while it is on the stack
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.BATTLEFIELD,
		"an artifact that arrived after upkeep began is spared this turn")


# ------------------------------------------------------------ Fortified Area --

func test_fortified_area_banding_grant_is_inert() -> void:
	# SIMPLIFIED (see the card header): the +1/+0 is real, but the granted
	# BANDING does nothing in this engine — Walls have defender and cannot
	# attack in a band, and DEFENSIVE banding is unimplemented
	# (engine/combat.gd, docs/ROADMAP.md).
	var wall := put_battlefield(0, "Wall of Wood")   # 0/3 defender
	put_battlefield(0, "Fortified Area")
	g.recalculate()
	assert_eq(wall.cur_power, 1, "+1/+0 lands")
	assert_true(wall.has_keyword(Mtg.Keyword.BANDING), "the keyword is granted")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [wall.id]),
		"")   # defender: banding can never be used offensively either


# -------------------------------------------------------- Armageddon Clock --

func test_armageddon_clock_burns_after_the_turn_based_draw() -> void:
	# NOT a simplification: the active player draws as a turn-based action
	# first (CR 504.1), and "at the beginning of your draw step" triggers
	# only go on the stack when a player would next receive priority
	# (CR 117.5) — i.e. after the draw. The engine's DRAW_STEP dispatch
	# sits in exactly that spot.
	put_battlefield(0, "Armageddon Clock")
	var guard := 0
	while (g.turn_number < 3 or g.current_step() != Mtg.Step.DRAW) and guard < 400:
		_advance_once()
		guard += 1
	assert_eq(g.active_player, 0, "our draw step")
	assert_eq(g.players[0].hand.size(), 1, "the card was already drawn")
	assert_eq(g.players[0].life, 20, "and nothing has burned yet")
	assert_false(g.stack.is_empty(), "the burn trigger is on the stack")
	resolve_stack()
	assert_eq(g.players[0].life, 19, "one doom counter, one damage each")
	assert_eq(g.players[1].life, 19)
