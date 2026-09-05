extends GameTest
## Fidelity lifts of 2026-09-02 — the three ledger rows that rested on a
## target stated RELATIVE TO ANOTHER TARGET of the same object
## (TargetSpec.sibling_filter, pinned on its own in
## tests/unit/test_sibling_targets.gd):
##
##   Gauntlets of Chaos  — "… that shares one of those types WITH IT" is a
##                         targeting requirement: a mismatched pair is
##                         refused at activation, not silently wasted.
##   Glyph of Delusion   — targets a creature AND the Wall that blocked it,
##                         as printed, instead of one creature with the
##                         Wall folded into a filter.
##   Drafna's Restoration — "target player" is a real slot, and the
##                         artifact cards must come from THAT player's
##                         graveyard (`@DRAFNAS_RESTORATION`,
##                         Program/promptsX1.txt:138: "Select target
##                         player." / "Select an artifact." / "Done").


func _bury(pid: int, card_name: String) -> CardInstance:
	var inst := give_hand(pid, card_name)
	g.players[pid].hand.erase(inst)
	inst.zone = Mtg.Zone.GRAVEYARD
	g.players[pid].graveyard.append(inst)
	return inst


# ------------------------------------------------------ Gauntlets of Chaos --

func _gauntlets_swap(mine: CardInstance, theirs: CardInstance) -> String:
	var gauntlets := put_battlefield(0, "Gauntlets of Chaos")
	add_mana(0, Mtg.ManaColor.C, 5)
	return g.activate_ability(0, gauntlets, 0,
		[TargetRef.card(mine), TargetRef.card(theirs)])


func test_gauntlets_refuses_a_pair_that_shares_no_type() -> void:
	var my_land := put_battlefield(0, "Forest")
	var their_bear := put_battlefield(1, "Grizzly Bears")
	assert_refused(_gauntlets_swap(my_land, their_bear), "Illegal target (type).")
	assert_not_null(g.find_on_battlefield(0, "Gauntlets of Chaos"),
		"refused before the cost: the artifact was not sacrificed")
	assert_eq(g.players[0].mana_pool.total(), 5, "and the mana is unspent")
	assert_true(g.stack.is_empty())


func test_gauntlets_trades_a_land_for_a_land() -> void:
	var my_land := put_battlefield(0, "Forest")
	var their_land := put_battlefield(1, "Mountain")
	assert_ok(_gauntlets_swap(my_land, their_land))
	resolve_stack()
	assert_eq(my_land.controller_id, 1)
	assert_eq(their_land.controller_id, 0)


func test_gauntlets_trades_an_artifact_creature_for_a_plain_artifact() -> void:
	# Artifact creature for a non-creature artifact: they share "artifact".
	var my_beast := put_battlefield(0, "Clockwork Beast")
	var their_statue := put_battlefield(1, "Jade Statue")
	assert_ok(_gauntlets_swap(my_beast, their_statue))
	resolve_stack()
	assert_eq(my_beast.controller_id, 1)
	assert_eq(their_statue.controller_id, 0)


func test_gauntlets_partner_list_is_narrowed_by_what_you_give() -> void:
	# What the UI (and the AI) would be offered for the second slot once
	# the first is known: only the opponent's permanents sharing a type.
	var my_land := put_battlefield(0, "Forest")
	put_battlefield(1, "Grizzly Bears")
	var their_land := put_battlefield(1, "Mountain")
	var gauntlets := put_battlefield(0, "Gauntlets of Chaos")
	var spec: TargetSpec = gauntlets.cur_activated_abilities[0].effects[1].target_spec
	var refs := spec.legal_targets(g, gauntlets, [TargetRef.card(my_land)])
	assert_eq(refs.size(), 1)
	assert_eq(refs[0].instance_id, their_land.id)


func test_gauntlets_still_needs_your_own_permanent_first() -> void:
	var theirs := put_battlefield(1, "Serra Angel")
	var also_theirs := put_battlefield(1, "Grizzly Bears")
	assert_refused(_gauntlets_swap(theirs, also_theirs), "Illegal target")


# ------------------------------------------------------- Glyph of Delusion --

## P0's [param attacker] attacks, P1's [param wall] blocks it; the game is
## left in the declare-blockers step with P1 holding priority.
func _blocked_by(attacker: CardInstance, wall: CardInstance) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: attacker.id}))
	assert_ok(g.pass_priority(0))


func test_glyph_of_delusion_targets_the_creature_and_the_wall_that_blocked_it() -> void:
	var attacker := put_battlefield(0, "Hill Giant")     # 3 power → 3 counters
	var wall := put_battlefield(1, "Wall of Stone")
	var glyph := give_hand(1, "Glyph of Delusion")
	_blocked_by(attacker, wall)
	add_mana(1, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(1, glyph, [TargetRef.card(attacker), TargetRef.card(wall)]))
	assert_eq(g.stack[0].targets.size(), 2, "two real targets")
	resolve_stack()
	assert_eq(int(attacker.counters.get("glyph", 0)), 3)


func test_glyph_of_delusion_needs_both_targets() -> void:
	var attacker := put_battlefield(0, "Hill Giant")
	var wall := put_battlefield(1, "Wall of Stone")
	var glyph := give_hand(1, "Glyph of Delusion")
	_blocked_by(attacker, wall)
	add_mana(1, Mtg.ManaColor.U)
	assert_refused(g.cast_spell(1, glyph, [TargetRef.card(attacker)]), "needs 1 target")


func test_glyph_of_delusion_refuses_a_wall_that_blocked_something_else() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(0, "Grizzly Bears")
	var stone := put_battlefield(1, "Wall of Stone")
	var wood := put_battlefield(1, "Wall of Wood")
	var glyph := give_hand(1, "Glyph of Delusion")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id, bear.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {stone.id: giant.id, wood.id: bear.id}))
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.U)
	# The Giant with the Wall that blocked the BEAR: not "that target Wall
	# blocked".
	assert_refused(g.cast_spell(1, glyph, [TargetRef.card(giant), TargetRef.card(wood)]),
		"Illegal target (blocked).")
	assert_ok(g.cast_spell(1, glyph, [TargetRef.card(giant), TargetRef.card(stone)]))
	resolve_stack()
	assert_eq(int(giant.counters.get("glyph", 0)), 3)
	assert_eq(int(bear.counters.get("glyph", 0)), 0)


func test_glyph_of_delusion_second_target_must_be_a_wall() -> void:
	# The Giant is double-blocked, by a Wall and by a Bear: the Bear
	# blocked it too, but it is no Wall.
	var attacker := put_battlefield(0, "Hill Giant")
	var wall := put_battlefield(1, "Wall of Stone")
	var bear := put_battlefield(1, "Grizzly Bears")
	var glyph := give_hand(1, "Glyph of Delusion")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: attacker.id, bear.id: attacker.id}))
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.U)
	assert_refused(g.cast_spell(1, glyph, [TargetRef.card(attacker), TargetRef.card(bear)]),
		"Illegal target (subtype).")
	assert_ok(g.cast_spell(1, glyph, [TargetRef.card(attacker), TargetRef.card(wall)]))


func test_glyph_of_delusion_creature_no_wall_blocked_is_refused_first() -> void:
	var attacker := put_battlefield(0, "Hill Giant")
	var blocker := put_battlefield(1, "Grizzly Bears")
	var glyph := give_hand(1, "Glyph of Delusion")
	_blocked_by(attacker, blocker)
	add_mana(1, Mtg.ManaColor.U)
	assert_refused(g.cast_spell(1, glyph, [TargetRef.card(attacker), TargetRef.card(blocker)]),
		"Illegal target (blocked).")


func test_glyph_of_delusion_wall_of_shadows_is_immune_as_a_wall_only_target() -> void:
	# "Can't be the target of spells that can target only Walls": the
	# Glyph's Wall slot can target only Walls.
	var attacker := put_battlefield(0, "Hill Giant")
	var shadows := put_battlefield(1, "Wall of Shadows")
	var glyph := give_hand(1, "Glyph of Delusion")
	_blocked_by(attacker, shadows)
	add_mana(1, Mtg.ManaColor.U)
	assert_refused(g.cast_spell(1, glyph, [TargetRef.card(attacker), TargetRef.card(shadows)]),
		"Illegal target (walls).")


func test_glyph_of_delusion_fizzles_when_the_wall_leaves() -> void:
	var attacker := put_battlefield(0, "Hill Giant")
	var wall := put_battlefield(1, "Wall of Stone")
	var glyph := give_hand(1, "Glyph of Delusion")
	_blocked_by(attacker, wall)
	add_mana(1, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(1, glyph, [TargetRef.card(attacker), TargetRef.card(wall)]))
	g.destroy(wall)
	resolve_stack()
	assert_eq(int(attacker.counters.get("glyph", 0)), 0,
		"the Wall was an illegal target: the creature gets no counters")


func test_glyph_of_delusion_ai_pairs_the_attacker_with_its_wall() -> void:
	var attacker := put_battlefield(0, "Hill Giant")
	var wall := put_battlefield(1, "Wall of Stone")
	put_battlefield(1, "Wall of Wood")   # a Wall that blocked nothing
	var glyph := give_hand(1, "Glyph of Delusion")
	_blocked_by(attacker, wall)
	var ai := AiPlayer.new(1)
	var picks = ai._choose_targets(g, glyph, 0)
	assert_not_null(picks)
	assert_eq(picks.size(), 2)
	assert_eq(picks[0].instance_id, attacker.id)
	assert_eq(picks[1].instance_id, wall.id, "the Wall that blocked it, not the idle one")
	add_mana(1, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(1, glyph, picks))


# ---------------------------------------------------- Drafna's Restoration --

func test_drafnas_restoration_names_a_player_and_stacks_their_artifacts() -> void:
	var lotus := _bury(0, "Black Lotus")
	var statue := _bury(0, "Jade Statue")
	var drafna := give_hand(0, "Drafna's Restoration")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, drafna,
		[TargetRef.player(0), TargetRef.card(lotus), TargetRef.card(statue)]))
	assert_eq(g.stack[0].targets.size(), 3, "the player is a real target")
	resolve_stack()
	assert_eq(lotus.zone, Mtg.Zone.LIBRARY)
	assert_eq(statue.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[0].library.back(), statue, "named last, on top")


func test_drafnas_restoration_only_reaches_the_named_players_graveyard() -> void:
	var mine := _bury(0, "Black Lotus")
	var theirs := _bury(1, "Jade Statue")
	var drafna := give_hand(0, "Drafna's Restoration")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_refused(g.cast_spell(0, drafna,
		[TargetRef.player(0), TargetRef.card(mine), TargetRef.card(theirs)]),
		"Illegal target (owner).")
	assert_refused(g.cast_spell(0, drafna, [TargetRef.player(1), TargetRef.card(mine)]),
		"Illegal target (owner).")
	assert_ok(g.cast_spell(0, drafna, [TargetRef.player(1), TargetRef.card(theirs)]))
	resolve_stack()
	assert_eq(theirs.zone, Mtg.Zone.LIBRARY)
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD)


func test_drafnas_restoration_needs_the_player_even_for_none() -> void:
	var drafna := give_hand(0, "Drafna's Restoration")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_refused(g.cast_spell(0, drafna, []), "needs 1 target")
	assert_ok(g.cast_spell(0, drafna, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(drafna.zone, Mtg.Zone.GRAVEYARD)


func test_drafnas_restoration_ai_restores_its_own_artifacts_or_stays_home() -> void:
	var drafna := give_hand(0, "Drafna's Restoration")
	_bury(1, "Black Lotus")   # THEIR dead artifact is no reason to cast
	var ai := AiPlayer.new(0)
	assert_null(ai._choose_targets(g, drafna, 0), "nothing of ours to restore")
	var mine := _bury(0, "Jade Statue")
	var picks = ai._choose_targets(g, drafna, 0)
	assert_not_null(picks)
	assert_eq(picks.size(), 2)
	assert_true(picks[0].is_player)
	assert_eq(picks[0].player_id, 0, "aimed at itself")
	assert_eq(picks[1].instance_id, mine.id)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, drafna, picks))
