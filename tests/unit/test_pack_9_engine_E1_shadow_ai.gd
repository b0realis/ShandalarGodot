extends GameTest
## SHADOW AND THE FAIR AI'S COMBAT (Pack 9 engine package E1).
##
## The AI's attack and block planning — the cohort planner, the crack-back
## search (`engine/ai/combat_search.gd`, its model built by
## `AiPlayer._build_combat_model`) and the block ladder — asks
## [method CombatState.block_illegality] for every legality, so shadow's
## two directions (CR 702.28b) reach it through that one predicate. These
## boards pin that it does: a shade swings past blockers that cannot touch
## it, a shade is not held home "to block" a creature it cannot block, and
## a defender blocks a shade only with what may block it. The valuation
## half (`Evaluator`'s SHADOW weight and defensive discount) is pinned in
## `test_pack_9_engine_E1_shadow.gd`.


static func _shade(name := "Test Shade", power := 2, toughness := 1) -> CardData:
	return CardData.new(name, "{1}{B}", Mtg.CardType.CREATURE) \
		.pt(power, toughness).with_keywords([Mtg.Keyword.SHADOW])


static func _dryad() -> CardData:
	return CardData.new("Test Dryad", "{1}{G}", Mtg.CardType.CREATURE) \
		.pt(2, 4).static_ability(CombatState.blocks_shadow())


func _wizard(seat: int) -> AiPlayer:
	return AiPlayer.new(seat, AiProfile.wizard())


## How many attackers seat 0's AI declares on the board now on the table.
func _attack_count(ai: AiPlayer) -> int:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	ai.act(g)
	assert_false(g.awaiting_attackers, "the AI left the attack step open")
	return g.combat.attackers.size()


## Let seat 1's AI answer seat 0's attack, and hand back its blocks.
func _blocks(ai: AiPlayer, attacker_ids: Array) -> Dictionary:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, attacker_ids))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	ai.act(g)
	assert_false(g.awaiting_blockers, "the AI left the block step open")
	assert_false(g.game_over, "the AI found a legal declaration")
	return g.combat.blocks


# ------------------------------------------------------------ attacking --

## A 2/2 shade into an untapped 4/4: nothing on their side may block it, so
## the swing is free.
func test_a_shade_swings_past_a_bigger_blocker_without_shadow() -> void:
	var ai := _wizard(0)
	put_synthetic(0, _shade("Test Shade", 2, 2))
	put_battlefield(1, "Craw Wurm")
	assert_eq(_attack_count(ai), 1, "the Wurm cannot block a shade")


## The crack-back board of `tests/ai/test_ai_crack_back_2026_09_05.gd`:
## at 3 life a Hill Giant stays home to block a tapped Craw Wurm. A shade
## CANNOT block the Wurm, so holding it back buys nothing — it swings.
func test_a_shade_is_not_held_home_to_block_what_it_cannot_block() -> void:
	var ai := _wizard(0)
	put_synthetic(0, _shade("Test Shade", 2, 1))
	var wurm := put_battlefield(1, "Craw Wurm")
	wurm.tapped = true
	g.players[0].life = 3
	assert_eq(_attack_count(ai), 1, "a shade is no wall against the Wurm")


## ...and the control arm: the same board with a Hill Giant still holds
## it home, so the shade's swing above is shadow's doing.
func test_control_the_giant_still_stays_home() -> void:
	var ai := _wizard(0)
	put_battlefield(0, "Hill Giant")
	var wurm := put_battlefield(1, "Craw Wurm")
	wurm.tapped = true
	g.players[0].life = 3
	assert_eq(_attack_count(ai), 0)


# ------------------------------------------------------------- blocking --

## The defender's only body without shadow is never offered to the engine
## against a shade (the engine would refuse it, and a refused ladder ends
## in a concession).
func test_no_block_on_a_shade_with_only_ordinary_creatures() -> void:
	var ai := _wizard(1)
	var shade := put_synthetic(0, _shade("Test Shade", 2, 2))
	put_battlefield(1, "Grizzly Bears")
	var blocks := _blocks(ai, [shade.id])
	assert_eq(blocks.size(), 0)


## A Dryad ("as though it had shadow") kills the 2/2 shade and lives: the
## block a competent player makes.
func test_the_dryad_blocks_a_shade() -> void:
	var ai := _wizard(1)
	var shade := put_synthetic(0, _shade("Test Shade", 2, 2))
	put_battlefield(1, "Grizzly Bears")
	var dryad := put_synthetic(1, _dryad())
	var blocks := _blocks(ai, [shade.id])
	assert_eq(int(blocks.get(dryad.id, -1)), shade.id)
	assert_eq(blocks.size(), 1, "only the Dryad may block it")


## A shade of our own blocks THEIR shade when it kills it and survives.
func test_our_shade_blocks_their_smaller_shade() -> void:
	var ai := _wizard(1)
	var theirs := put_synthetic(0, _shade("Test Small Shade", 1, 1))
	var ours := put_synthetic(1, _shade("Test Big Shade", 2, 3))
	put_battlefield(1, "Grizzly Bears")
	var blocks := _blocks(ai, [theirs.id])
	assert_eq(int(blocks.get(ours.id, -1)), theirs.id)
