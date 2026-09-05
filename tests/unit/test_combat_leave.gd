extends GameTest
## CR 506.4 — "a permanent that leaves the battlefield is removed from
## combat". The exile audit (2026-08-31) fixed this for exile and for
## anything ARRIVING, but left the other three ways off the battlefield:
## dying, bouncing and being anted. A stale attacker entry lets the
## defender waste a blocker on a creature that is already gone.


func _attacking_bear() -> CardInstance:
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	assert_true(g.combat.attackers.has(bear.id), "it really is attacking")
	return bear


func test_a_blocker_cannot_be_spent_on_a_dead_attacker() -> void:
	# The symptom that matters at the table. The dead attacker's combat
	# ENTRY is deliberately left standing until its own dies-trigger has
	# resolved — Abu Ja'far destroys everything blocking or blocked by it
	# and reads that state as it dies — so the refusal lives in
	# block_illegality rather than in a mutation on death.
	var bear := _attacking_bear()
	var wall := put_battlefield(1, "Wall of Stone")
	g.destroy(bear)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "it died")
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {wall.id: bear.id}),
		"no longer on the battlefield")


func test_a_bounced_attacker_is_out_of_combat() -> void:
	var bear := _attacking_bear()
	g.return_to_hand(bear)
	assert_eq(bear.zone, Mtg.Zone.HAND, "it bounced")
	assert_false(g.combat.attackers.has(bear.id), "and stopped attacking")


func test_an_anted_attacker_is_out_of_combat() -> void:
	var bear := _attacking_bear()
	g.move_to_ante(bear)
	assert_eq(bear.zone, Mtg.Zone.ANTE, "it was staked")
	assert_false(g.combat.attackers.has(bear.id), "and stopped attacking")


func test_a_dead_blocker_leaves_its_attacker_blocked() -> void:
	# CR 509.1h: removing a blocker does NOT make the attacker unblocked.
	var bear := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Stone")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: bear.id}))
	g.destroy(wall)
	# The blocker's ENTRY is left standing until its own dies-trigger has
	# resolved (see the note in block_illegality); what matters, and what
	# 509.1h actually says, is that the attacker stays BLOCKED.
	assert_true(g.combat.blocked_attackers.has(bear.id),
		"the bear stays blocked — 509.1h")
	var before: int = g.players[1].life
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, before,
		"and a blocked attacker still hits nobody, dead blocker or not")


func test_a_dead_attacker_deals_no_damage() -> void:
	# The consequence that matters at the table.
	var bear := _attacking_bear()
	var before: int = g.players[1].life
	g.destroy(bear)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, before, "a dead attacker hits nobody")
