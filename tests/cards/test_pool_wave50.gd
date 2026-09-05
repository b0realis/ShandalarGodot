extends GameTest
## Wave-50 tests: COMBAT RE-ARRANGEMENT — the cards that reach into a
## combat after it has been declared. Blocks can now be re-assigned
## (MtgGame.set_block), a creature can be ordered to block
## (CardInstance.must_block_this_turn), blocks can be rolled instead of
## declared (Camouflage), and an attacker can be borrowed outright
## (MtgGame.gain_control_until_eot).


func test_registry_loaded_wave50() -> void:
	for name in ["Blaze of Glory", "Camouflage", "False Orders", "Raging River",
			"Sorrow's Path", "Two-Headed Giant of Foriys", "Wall of Caltrops",
			"Disharmony", "Feint"]:
		assert_not_null(CardRegistry.get_card(name), name)


# ------------------------------------------------------------------- Feint --

func test_feint_calls_off_the_fight() -> void:
	var attacker := put_battlefield(0, "Hill Giant")     # 3/3
	var blocker := put_battlefield(1, "Grizzly Bears")   # 2/2
	var feint := give_hand(0, "Feint")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {blocker.id: attacker.id}))
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, feint, [TargetRef.card(attacker)]))
	resolve_stack()
	assert_true(blocker.tapped, "the blockers are tapped")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(blocker.damage, 0, "no combat damage either way")
	assert_eq(attacker.damage, 0)
	assert_eq(g.players[1].life, 20)


# -------------------------------------------------------------- Disharmony --

func test_disharmony_borrows_an_attacker() -> void:
	var attacker := put_battlefield(1, "Hill Giant")
	var dis := give_hand(0, "Disharmony")
	advance_to_next_turn()                       # player 1 attacks us
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [attacker.id]))
	resolve_stack()
	assert_true(attacker.tapped)
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, dis, [TargetRef.card(attacker)]))
	resolve_stack()
	assert_false(attacker.tapped, "untapped")
	assert_false(g.combat.attackers.has(attacker.id), "and out of combat")
	assert_eq(attacker.controller_id, 0, "we control it now")
	advance_to_next_turn()
	assert_eq(attacker.controller_id, 1, "until end of turn only")


# ------------------------------------------------------------ False Orders --

func test_false_orders_re_points_a_blocker() -> void:
	var big := put_battlefield(0, "Hill Giant")          # 3/3
	var small := put_battlefield(0, "Mons's Goblin Raiders")   # 1/1
	var blocker := put_battlefield(1, "Grizzly Bears")   # 2/2
	var orders := give_hand(0, "False Orders")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [big.id, small.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {blocker.id: big.id}))
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, orders, [TargetRef.card(blocker)]))
	resolve_stack()
	assert_eq(g.combat.blockers_of(big.id).size(), 0,
		"the Bears stopped blocking the Giant")
	assert_eq(g.combat.blockers_of(small.id).size(), 1,
		"the blocker was re-pointed at the goblin")
	advance_to_step(Mtg.Step.COMBAT_END)
	# "Creatures it was blocking that had become blocked by ONLY that
	# creature this combat become unblocked" — False Orders' printed
	# exception to CR 509.1h, which is the whole point of the card.
	assert_eq(g.players[1].life, 17, "3 unblocked damage")
	assert_eq(g.combat.blocks.get(blocker.id, -1), small.id)


func test_false_orders_only_during_declare_blockers() -> void:
	put_battlefield(1, "Grizzly Bears")
	var orders := give_hand(0, "False Orders")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(0, orders,
		[TargetRef.card(g.players[1].battlefield[0])]), "declare blockers")


# ----------------------------------------------------------- Blaze of Glory --

func test_blaze_of_glory_conscripts_a_blocker() -> void:
	var attacker := put_battlefield(0, "Hill Giant")
	var lazy := put_battlefield(1, "Grizzly Bears")
	var blaze := give_hand(0, "Blaze of Glory")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, blaze, [TargetRef.card(lazy)]))
	resolve_stack()
	assert_true(lazy.must_block_this_turn)
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	# The refusal NAMES THE ATTACKER since one-to-many blocks landed
	# (2026-09-02): a conscript under Blaze of Glory must block EACH
	# attacker it can, so "must block if able" alone would not say which
	# block is missing.
	assert_refused(g.declare_blockers(1, {}),
		"Grizzly Bears must block Hill Giant if able")
	assert_ok(g.declare_blockers(1, {lazy.id: attacker.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(lazy.zone, Mtg.Zone.GRAVEYARD, "3 damage kills the 2/2")


# ------------------------------------------------------------- Camouflage --

func test_camouflage_rolls_the_blocks() -> void:
	var attacker := put_battlefield(0, "Hill Giant")
	var blocker := put_battlefield(1, "Wall of Stone")
	var camo := give_hand(0, "Camouflage")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, camo, []))
	resolve_stack()
	assert_true(g.camouflage_this_turn)
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	# The defender's declaration is ignored: the only legal block is rolled.
	assert_ok(g.declare_blockers(1, {}))
	assert_eq(g.combat.blockers_of(attacker.id).size(), 1,
		"the Wall was drafted at random")


func test_camouflage_expires_with_the_turn() -> void:
	var camo := give_hand(0, "Camouflage")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, []))
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, camo, []))
	resolve_stack()
	advance_to_next_turn()
	assert_false(g.camouflage_this_turn)


# ----------------------------------------------------------- Sorrow's Path --

func test_sorrows_path_swaps_two_blockers() -> void:
	var a := put_battlefield(0, "Hill Giant")            # 3/3
	var b := put_battlefield(0, "Grizzly Bears")         # 2/2
	var x := put_battlefield(1, "Wall of Stone")         # 0/8
	var y := put_battlefield(1, "Wall of Air")           # 0/5 flying
	var path := put_battlefield(0, "Sorrow's Path")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [a.id, b.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {x.id: a.id, y.id: b.id}))
	assert_ok(g.activate_ability(0, path, 0,
		[TargetRef.card(x), TargetRef.card(y)]))
	resolve_stack()
	assert_eq(g.combat.blocks[x.id], b.id, "the Walls traded places")
	assert_eq(g.combat.blocks[y.id], a.id)


func test_sorrows_path_hurts_you_when_it_taps() -> void:
	var path := put_battlefield(0, "Sorrow's Path")
	var mine := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	g.tap_permanent(path)
	resolve_stack()
	assert_eq(g.players[0].life, 18, "2 damage to you")
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD, "and 2 to each of your creatures")


# ------------------------------------------------------------ Raging River --

func test_raging_river_splits_the_defenders() -> void:
	var river := put_battlefield(0, "Raging River")
	var attacker := put_battlefield(0, "Hill Giant")
	var one := put_battlefield(1, "Grizzly Bears")
	var two := put_battlefield(1, "Mons's Goblin Raiders")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	var left: Array = river.memory.get("left", [])
	var right: Array = river.memory.get("right", [])
	assert_eq(left.size() + right.size(), 2, "both defenders were sorted")
	assert_false(attacker.cur_block_restrictions.is_empty(),
		"the attacker can only be blocked from one bank")
	# Exactly one of the two may block it.
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	var wrong_bank := two if left.has(one.id) else one
	assert_refused(g.declare_blockers(1, {wrong_bank.id: attacker.id}),
		"can't be blocked except by")


# ------------------------------------------------ the two remaining bodies --

func test_two_headed_giant_tramples() -> void:
	var giant := put_battlefield(0, "Two-Headed Giant of Foriys")
	assert_true(giant.has_keyword(Mtg.Keyword.TRAMPLE))
	var chump := put_battlefield(1, "Mons's Goblin Raiders")   # 1/1
	run_combat([giant.id], {chump.id: giant.id})
	assert_eq(g.players[1].life, 17, "4 power minus a 1/1 tramples for 3")


func test_wall_of_caltrops_bands_with_other_walls() -> void:
	var attacker := put_battlefield(0, "Hill Giant")
	var caltrops := put_battlefield(1, "Wall of Caltrops")
	var other := put_battlefield(1, "Wall of Stone")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {caltrops.id: attacker.id, other.id: attacker.id}))
	resolve_stack()
	assert_true(caltrops.has_keyword(Mtg.Keyword.BANDING),
		"two Walls and nothing else — it bands")


func test_wall_of_caltrops_alone_does_not_band() -> void:
	var attacker := put_battlefield(0, "Hill Giant")
	var caltrops := put_battlefield(1, "Wall of Caltrops")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {caltrops.id: attacker.id}))
	resolve_stack()
	assert_false(caltrops.has_keyword(Mtg.Keyword.BANDING))
