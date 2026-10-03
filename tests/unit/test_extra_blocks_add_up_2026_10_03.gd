extends GameTest
## "Can block an additional creature" permissions ADD UP (CR 509.1b: each
## says "additional"): Two-Headed Giant of Foriys' printed one plus a granted
## "up to two additional creatures this turn" (Yare, Pack 8) is four blocks,
## not three. Found by the Pack 8 combat batch on 2026-10-03, when
## MtgGame.blocks_allowed took the larger of the two instead of their sum.
## "Any number" (Blaze of Glory, -1) still wins over any count.


func _attack_with(count: int) -> Array:
	var ids := []
	for i in count:
		ids.append(put_battlefield(0, "Grizzly Bears").id)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, ids))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	return ids


func test_a_printed_and_a_granted_permission_add_up() -> void:
	var giant := put_battlefield(1, "Two-Headed Giant of Foriys")
	assert_eq(g.blocks_allowed(giant), 2, "its own 'one additional creature'")
	giant.extra_blocks_this_turn = 2    # Yare's grant
	assert_eq(g.blocks_allowed(giant), 4, "1 + 1 printed + 2 granted")


func test_the_giant_under_a_grant_blocks_four_attackers() -> void:
	var giant := put_battlefield(1, "Two-Headed Giant of Foriys")
	var ids := _attack_with(4)
	giant.extra_blocks_this_turn = 2
	assert_ok(g.declare_blockers(1, {giant.id: ids}))


func test_five_attackers_are_still_one_too_many() -> void:
	var giant := put_battlefield(1, "Two-Headed Giant of Foriys")
	var ids := _attack_with(5)
	giant.extra_blocks_this_turn = 2
	assert_false(g.declare_blockers(1, {giant.id: ids}).is_empty(),
		"four is the allowance, so a fifth block is refused")


func test_any_number_still_wins() -> void:
	var giant := put_battlefield(1, "Two-Headed Giant of Foriys")
	giant.extra_blocks_this_turn = -1   # Blaze of Glory
	assert_eq(g.blocks_allowed(giant), -1)
