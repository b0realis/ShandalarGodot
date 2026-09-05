extends GameTest
## Pins for the 2026-09-01 audit against the 30th-anniversary remake
## (docs/audit-vs-s30.md). One test per finding; every one of them FAILED
## before its fix.


# --------------------------------------------------------------- Pyramids --

func test_pyramids_cannot_destroy_an_aura_on_a_creature() -> void:
	# "Destroy target Aura attached to a LAND" — the host's type is part of
	# the target restriction, not a rider. mage-go filters with
	# `IsAuraOnLand`, and the card's own 1997 prompt (`@PYRAMIDS`,
	# Program/promptsX1.txt) carries "Illegal target (not enchanting a
	# land)" as one of its four strings.
	var pyramids := put_battlefield(0, "Pyramids")
	var bear := put_battlefield(1, "Grizzly Bears")
	var aura := put_battlefield(1, "Holy Strength")
	g.attach_aura_from_anywhere(aura, bear, 1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, pyramids, 0, [TargetRef.card(aura)]),
		"target")


# --------------------------------------------------------------- Soul Net --

func test_soul_net_offers_its_life_for_an_animated_land() -> void:
	# "Whenever a CREATURE dies" — CR 608.2h says the question is answered
	# from last known information, and the engine snapshots it in
	# CardInstance.last_types (which is why creatures_died_this_turn counts
	# an animated Mishra's Factory). Soul Net's own condition was still
	# reading the PRINTED type, so the Factory died as a land to it.
	var net := put_battlefield(0, "Soul Net")
	assert_not_null(net)
	var factory := put_battlefield(0, "Mishra's Factory")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, factory, 0, []))
	resolve_stack()
	assert_true(factory.is_creature(), "the Factory is a 2/2 now")
	var life := g.players[0].life
	add_mana(0, Mtg.ManaColor.C)
	g.destroy(factory, false)
	resolve_stack()
	assert_eq(g.players[0].life, life + 1,
		"a creature died, so the Net offered its {1}")


# ----------------------------------------------------- Remove Enchantments --

func test_remove_enchantments_returns_your_aura_on_their_land() -> void:
	# Group 1 of the printed card is "all ENCHANTMENTS you both own and
	# control" — and an Aura is an enchantment (CR 303.4). A Psychic Venom
	# you own and control, sitting on an opponent's land, is caught by that
	# group; the Aura-specific groups 2 and 3 exist to reach Auras you own
	# but do NOT control. Our predicate branched on is_aura() first, so an
	# Aura was only ever tested against groups 2 and 3.
	var their_land := put_battlefield(1, "Forest")
	var venom := _make_instance(0, "Psychic Venom")
	g.attach_aura_from_anywhere(venom, their_land, 0)
	var sweep := give_hand(0, "Remove Enchantments")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, sweep, []))
	resolve_stack()
	assert_eq(venom.zone, Mtg.Zone.HAND,
		"you own and control it, so it comes back")


# ----------------------------------------------------------- Ydwen Efreet --

func _ydwen_trial(seed_value: int) -> Dictionary:
	before_each()
	g.rng.seed = seed_value
	var efreet := put_battlefield(1, "Ydwen Efreet")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {efreet.id: bear.id}))
	resolve_stack()
	var lost: bool = not g.combat.blocks.has(efreet.id)
	advance_to_step(Mtg.Step.COMBAT_END)
	return {"lost": lost, "life": g.players[1].life}


func test_ydwen_efreet_unblocks_the_creature_it_was_blocking_alone() -> void:
	# The printed third sentence is the CR 509.1h EXCEPTION that False
	# Orders also carries: "Creatures it was blocking that had become
	# blocked by only this creature this combat become unblocked."
	# MtgGame.remove_from_combat implements it behind an opt-in flag and
	# names Ydwen Efreet in its own doc comment; the card never passed it,
	# so a lost flip turned the Efreet into a Fog.
	var trials := 0
	for seed_value in 60:
		var r := _ydwen_trial(seed_value)
		if r["lost"]:
			trials += 1
			assert_eq(r["life"], 18,
				"the flip was lost, so the bear is unblocked and connects")
			if trials >= 3:
				return
	assert_gt(trials, 0, "no seed in 60 produced a lost flip")


# ------------------------------------------------- Wall-only targeting ban --

func test_dwarven_demolition_team_cannot_target_wall_of_shadows() -> void:
	# Wall of Shadows: "can't be the target of spells that can target only
	# Walls or of abilities that can target only Walls." An ability whose
	# filter can name nothing but a Wall is exactly one of those, and the
	# engine has the flag (TargetSpec.only_walls) — this ability never set it.
	var team := put_battlefield(0, "Dwarven Demolition Team")
	var wall := put_battlefield(1, "Wall of Shadows")
	assert_refused(g.activate_ability(0, team, 0, [TargetRef.card(wall)]),
		"target")


func test_tunnel_cannot_target_wall_of_shadows() -> void:
	var wall := put_battlefield(1, "Wall of Shadows")
	var tunnel := give_hand(0, "Tunnel")
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(0, tunnel, [TargetRef.card(wall)]), "target")


func test_goblin_digging_team_cannot_target_wall_of_shadows() -> void:
	var team := put_battlefield(0, "Goblin Digging Team")
	var wall := put_battlefield(1, "Wall of Shadows")
	assert_refused(g.activate_ability(0, team, 0, [TargetRef.card(wall)]),
		"target")


# ------------------------------------------------------------ Howling Mine --

func test_howling_mine_rechecks_untapped_on_resolution() -> void:
	# "if this artifact is untapped" is an intervening "if": checked when
	# the ability would trigger AND again as it resolves (CR 603.4). Tapping
	# the Mine in response (Icy Manipulator, Relic Barrier) must stop the
	# extra card; ours drew it anyway.
	var mine := put_battlefield(0, "Howling Mine")
	advance_to_step(Mtg.Step.DRAW)
	assert_false(g.stack.is_empty(), "the draw-step trigger is waiting")
	var hand := g.players[0].hand.size()
	g.tap_permanent(mine)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand,
		"the Mine was tapped before the trigger resolved")


# ---------------------------------------------------------- Ghazbán Ogre --

func test_ghazban_ogre_does_not_trigger_while_the_life_totals_are_tied() -> void:
	# "if a player has more life than each other player" is an intervening
	# "if", so it is checked when the ability WOULD TRIGGER as well as on
	# resolution (CR 603.4). Tied at 20, the ability must not go on the
	# stack at all.
	put_battlefield(0, "Ghazbán Ogre")
	advance_to_step(Mtg.Step.MAIN1)   # past the upkeep we started in
	var guard := 0
	while not (g.active_player == 0 and g.current_step() == Mtg.Step.UPKEEP) \
			and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400, "reached player 0's upkeep")
	assert_eq(g.players[0].life, g.players[1].life, "tied")
	assert_true(g.stack.is_empty(), "no leader, so nothing triggered")


# ------------------------------------------ Circle of Protection: Artifacts --

func test_cop_artifacts_stops_a_creature_that_became_an_artifact() -> void:
	# "an artifact source of your choice" is a question about what the
	# source IS when it deals the damage (CR 109.5), not what is printed on
	# it. Ashnod's Transmogrant makes a creature an artifact; the shield's
	# predicate was reading data.types and never saw it.
	var cop := put_battlefield(0, "Circle of Protection: Artifacts")
	var bear := put_battlefield(0, "Grizzly Bears")
	var tm := put_battlefield(0, "Ashnod's Transmogrant")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, tm, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.is_type(Mtg.CardType.ARTIFACT), "it is an artifact now")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, cop, 0, []))
	resolve_stack()
	var life := g.players[0].life
	g.deal_damage(bear, TargetRef.player(0), 3)
	assert_eq(g.players[0].life, life, "an artifact source was prevented")


# ------------------------------------------------------- Tablet of Epityr --

func test_tablet_of_epityr_pays_for_a_creature_that_became_an_artifact() -> void:
	# "Whenever an ARTIFACT you control is put into a graveyard from the
	# battlefield" is answered from last known information (CR 608.2h) —
	# CardInstance.last_types — not from the printed type mask.
	var tablet := put_battlefield(0, "Tablet of Epityr")
	assert_not_null(tablet)
	var bear := put_battlefield(0, "Grizzly Bears")
	var tm := put_battlefield(0, "Ashnod's Transmogrant")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, tm, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.is_type(Mtg.CardType.ARTIFACT))
	add_mana(0, Mtg.ManaColor.C)
	var life := g.players[0].life
	g.destroy(bear)
	resolve_stack()
	assert_eq(g.players[0].life, life + 1, "the artifact creature's death paid")


# --------------------------------------------------------- Sylvan Library --

func test_sylvan_library_digs_even_after_it_is_destroyed_in_response() -> void:
	# CR 603.6 / 608.2h: a triggered ability on the stack resolves whatever
	# happened to its source. Nothing in this ability's effect refers back to
	# the enchantment, so Disenchanting it in response must not refund the
	# two cards.
	put_battlefield(0, "Sylvan Library")
	advance_to_step(Mtg.Step.DRAW)
	assert_false(g.stack.is_empty(), "the draw-step trigger is waiting")
	var lib: CardInstance = null
	for inst in g.players[0].battlefield:
		if inst.data.card_name == "Sylvan Library":
			lib = inst
	g.destroy(lib)
	resolve_stack()
	assert_eq(g.players[0].life, 12,
		"drew two and paid 4 life for each of them")


# ------------------------------------------------------------- Spell Blast --

func test_spell_blast_reads_the_x_a_spell_on_the_stack_was_cast_for() -> void:
	# CR 202.3b — while a spell is on the stack, X in its mana cost is the
	# value chosen for it. A Fireball cast for X=3 has mana value 4, so a
	# Spell Blast for 4 must be able to name it (and ManaCost.mana_value(),
	# which counts an unresolved X as 0, must not be the answer).
	var bear := put_battlefield(1, "Grizzly Bears")
	var fireball := give_hand(0, "Fireball")
	var blast := give_hand(0, "Spell Blast")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 4)
	assert_ok(g.cast_spell(0, fireball, [TargetRef.card(bear)], 3))
	add_mana(0, Mtg.ManaColor.U, 5)
	assert_ok(g.cast_spell(0, blast, [TargetRef.card(fireball)], 4))


# ------------------------------------------------------ In the Eye of Chaos --

func test_in_the_eye_of_chaos_taxes_the_x_an_instant_was_cast_for() -> void:
	# "counter it unless that player pays {X}, where X is its MANA VALUE" —
	# and a spell on the stack has the X it was cast for (CR 202.3b). An
	# Alabaster Potion for X=3 costs {3}{W}{W}, mana value 5, so the toll is
	# {5}; we were charging the printed {2}.
	put_battlefield(0, "In the Eye of Chaos")
	var potion := give_hand(0, "Alabaster Potion")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 7)
	assert_ok(g.cast_spell(0, potion, [TargetRef.player(0)], 3, 0))
	resolve_stack()
	assert_eq(potion.zone, Mtg.Zone.GRAVEYARD, "countered")
	assert_eq(g.players[0].life, 20, "two floating mana could not pay {5}")


# ------------------------------------------------------- Land Equilibrium --

func _land_count(pid: int) -> int:
	var n := 0
	for inst in g.players[pid].battlefield:
		if inst.is_land():
			n += 1
	return n


func test_land_equilibrium_compares_land_counts_before_the_land_arrives() -> void:
	# "If an opponent who controls AT LEAST AS MANY lands as you do WOULD
	# PUT a land onto the battlefield" — the applicability test of a
	# replacement effect, so it is asked before the land enters. With four
	# lands to their three, their fourth land is safe.
	put_battlefield(0, "Land Equilibrium")
	for i in 4:
		put_battlefield(0, "Forest")
	for i in 3:
		put_battlefield(1, "Forest")
	advance_to_next_turn()
	var land := give_hand(1, "Forest")
	assert_ok(g.play_land(1, land))
	resolve_stack()
	assert_eq(_land_count(1), 4, "3 < 4 when the land would be put, so no toll")


# -------------------------------------------------------------------- Kudzu --

func test_kudzu_may_hop_onto_a_land_its_controller_does_not_control() -> void:
	# "That land's controller may attach this Aura to A LAND OF THEIR
	# CHOICE" — any land, not merely one they control. Handing the vine back
	# to its owner is the whole defence, and mage-go scans the whole
	# battlefield for it.
	var their_land := put_battlefield(1, "Forest")
	var my_land := put_battlefield(0, "Forest")
	var kudzu := _make_instance(0, "Kudzu")
	g.attach_aura_from_anywhere(kudzu, their_land, 0)
	g.tap_permanent(their_land)
	resolve_stack()
	assert_eq(their_land.zone, Mtg.Zone.GRAVEYARD, "the host is destroyed")
	assert_eq(kudzu.attached_to, my_land.id,
		"their choice reaches a land they do not control")


# ------------------------------------------------------- Token mana values --

func _token_named(pid: int, name: String) -> CardInstance:
	for inst in g.players[pid].battlefield:
		if inst.data.card_name == name:
			return inst
	return null


func test_a_minor_demon_token_has_mana_value_zero() -> void:
	# CR 111.4 / 202.3a: a token has no mana cost, so its mana value is 0.
	# The pool was giving colour to its tokens by handing them a real mana
	# cost, which also handed them a mana value — and Great Defender,
	# Subdue, Kry Shield and Juxtapose all read that number.
	var boris := put_battlefield(0, "Boris Devilboon")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, boris, 0, []))
	resolve_stack()
	var demon := _token_named(0, "Minor Demon")
	assert_not_null(demon, "the token arrived")
	assert_eq(demon.cur_colors, Mtg.ManaColor.B | Mtg.ManaColor.R,
		"still black and red")
	var defender := give_hand(0, "Great Defender")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, defender, [TargetRef.card(demon)]))
	resolve_stack()
	assert_eq(demon.cur_toughness, 1, "+0/+X where X is a token's 0")


# ------------------------------------------------------------ Spitting Slug --

func test_spitting_slug_becomes_blocked_only_once_per_combat() -> void:
	# "Whenever this creature blocks or BECOMES BLOCKED" — with no "by a
	# creature", becoming blocked is one event however many creatures block
	# (CR 509.1h). The engine dispatches BLOCKED once per declared PAIR, so
	# a double block was charging the rent twice and then arming the
	# blockers when the second payment failed.
	var slug := put_battlefield(0, "Spitting Slug")
	var b1 := put_battlefield(1, "Grizzly Bears")
	var b2 := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [slug.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.declare_blockers(1, {b1.id: slug.id, b2.id: slug.id}))
	resolve_stack()
	assert_true(slug.cur_keywords.has(Mtg.Keyword.FIRST_STRIKE),
		"the rent was paid")
	assert_false(b1.cur_keywords.has(Mtg.Keyword.FIRST_STRIKE),
		"one trigger, and it was paid — the blockers get nothing")
	assert_false(b2.cur_keywords.has(Mtg.Keyword.FIRST_STRIKE))


# ------------------------------------------------------------- Dark Sphere --

func test_dark_sphere_can_brace_against_your_own_source() -> void:
	# "The next time A SOURCE OF YOUR CHOICE would deal damage to you" — no
	# controller restriction. Your own City of Brass, Electric Eel, Mana
	# Crypt or Wormwood Treefolk are sources that deal damage to you, and
	# they are exactly what a defensive artifact is pointed at.
	var sphere := put_battlefield(0, "Dark Sphere")
	var mine := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, sphere, 0, []))
	resolve_stack()
	var life := g.players[0].life
	g.deal_damage(mine, TargetRef.player(0), 4)
	assert_eq(g.players[0].life, life - 2, "half of 4 was prevented")


# ------------------------------------------------------- Wormwood Treefolk --

func test_wormwood_treefolk_still_bites_when_killed_in_response() -> void:
	# CR 608.2h — an activated ability on the stack resolves using last
	# known information. Only the landwalk grant has nothing to attach to;
	# "and deals 2 damage to you" is not conditional on the source.
	var tree := put_battlefield(0, "Wormwood Treefolk")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.activate_ability(0, tree, 0, []))
	g.destroy(tree)
	resolve_stack()
	assert_eq(g.players[0].life, 18, "the 2 damage is owed either way")
