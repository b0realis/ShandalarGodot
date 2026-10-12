extends GameTest
## Campaign 2026-10-12 — two combat facts.
##
## b3-6, CR 506.4: a permanent that stops being a creature is removed from
##   combat. A Forest animated by Living Lands kept attacking (or blocking)
##   after the Living Lands was destroyed and was dealt combat damage as a
##   land. MtgGame drops any attacker or blocker that is no longer a
##   creature, as state-based actions are checked and as a permanent goes
##   to the graveyard.
## b4-2, Fyndhorn Druid — "When this creature dies, if it was BLOCKED this
##   turn, you gain 4 life." It read "this creature blocked" and paid out
##   backwards. A creature now remembers the turn it became blocked
##   (CardInstance.became_blocked_turn, stamped on BECOMES_BLOCKED), and
##   the Druid reads that as it left (last_became_blocked_turn).

const PRESETS := ["modern_mana_burn", "fifth"]


func before_each() -> void:
	CardPacks.set_enabled(AlliancesPack.ID, true)
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled(AlliancesPack.ID, false)


func _start(preset: String) -> void:
	before_each()
	g.rules.set_preset(preset)
	advance_to_step(Mtg.Step.MAIN1)


func _disenchant(pid: int, victim: CardInstance) -> void:
	var spell := give_hand(pid, "Disenchant")
	add_mana(pid, Mtg.ManaColor.W, 2)
	assert_ok(g.cast_spell(pid, spell, [TargetRef.card(victim)]))
	resolve_stack()
	assert_eq(victim.zone, Mtg.Zone.GRAVEYARD)


func _bolt(pid: int, victim: CardInstance) -> void:
	var bolt := give_hand(pid, "Lightning Bolt")
	add_mana(pid, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(pid, bolt, [TargetRef.card(victim)]))
	resolve_stack()


# ------------------------------------------------------------- b3-6 --

func test_an_attacking_forest_that_stops_being_a_creature_leaves_combat() -> void:
	for preset in PRESETS:
		_start(preset)
		var lands := put_battlefield(0, "Living Lands")
		var forest := put_battlefield(0, "Forest")
		g.recalculate()
		assert_true(forest.is_creature())
		var bears := put_battlefield(1, "Grizzly Bears")
		advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
		assert_ok(g.declare_attackers(0, [forest.id]))
		resolve_stack()
		advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
		assert_ok(g.declare_blockers(1, {bears.id: forest.id}))
		_disenchant(0, lands)
		assert_false(forest.is_creature())
		assert_false(g.combat.attackers.has(forest.id), "no longer attacking (%s)" % preset)
		advance_to_step(Mtg.Step.COMBAT_END)
		assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)
		assert_eq(forest.damage, 0, "a land is dealt no combat damage (%s)" % preset)
		assert_eq(bears.damage, 0, "and deals none (%s)" % preset)


func test_an_unblocked_forest_that_stops_being_a_creature_deals_nothing() -> void:
	for preset in PRESETS:
		_start(preset)
		var lands := put_battlefield(0, "Living Lands")
		var forest := put_battlefield(0, "Forest")
		g.recalculate()
		advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
		assert_ok(g.declare_attackers(0, [forest.id]))
		resolve_stack()
		advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
		assert_ok(g.declare_blockers(1, {}))
		_disenchant(0, lands)
		advance_to_step(Mtg.Step.COMBAT_END)
		assert_eq(g.players[1].life, 20, "a land deals no combat damage (%s)" % preset)


# A blocking Forest leaves combat too; the attacker it blocked stays
# blocked (CR 509.1h) and, without trample, deals no damage.
func test_a_blocking_forest_that_stops_being_a_creature_leaves_combat() -> void:
	for preset in PRESETS:
		_start(preset)
		var bears := put_battlefield(0, "Grizzly Bears")
		var lands := put_battlefield(1, "Living Lands")
		var forest := put_battlefield(1, "Forest")
		g.recalculate()
		advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
		assert_ok(g.declare_attackers(0, [bears.id]))
		resolve_stack()
		advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
		assert_ok(g.declare_blockers(1, {forest.id: bears.id}))
		_disenchant(0, lands)
		assert_false(g.combat.blocks.has(forest.id), "no longer blocking (%s)" % preset)
		assert_true(g.combat.was_blocked(g.combat.band_of(bears.id)), "the Bears stay blocked")
		advance_to_step(Mtg.Step.COMBAT_END)
		assert_eq(forest.damage, 0, "the land is dealt no damage (%s)" % preset)
		assert_eq(bears.damage, 0)
		assert_eq(g.players[1].life, 20, "a blocked attacker without trample deals nothing (%s)" % preset)


# Still a creature: nothing changes (a Forest that stays animated fights).
func test_a_forest_that_stays_a_creature_still_fights() -> void:
	_start("modern_mana_burn")
	put_battlefield(0, "Living Lands")
	var forest := put_battlefield(0, "Forest")
	g.recalculate()
	run_combat([forest.id])
	assert_eq(g.players[1].life, 19)


# ------------------------------------------------------------- b4-2 --

func test_an_attacking_druid_that_was_blocked_and_dies_gains_four() -> void:
	for preset in PRESETS:
		_start(preset)
		var druid := put_battlefield(0, "Fyndhorn Druid")
		var giant := put_battlefield(1, "Hill Giant")
		run_combat([druid.id], {giant.id: druid.id})
		resolve_stack()
		assert_eq(druid.zone, Mtg.Zone.GRAVEYARD)
		assert_eq(g.players[0].life, 24, "it was blocked this turn (%s)" % preset)


func test_a_blocking_druid_that_dies_gains_nothing() -> void:
	for preset in PRESETS:
		_start(preset)
		var druid := put_battlefield(1, "Fyndhorn Druid")
		var giant := put_battlefield(0, "Hill Giant")
		run_combat([giant.id], {druid.id: giant.id})
		resolve_stack()
		assert_eq(druid.zone, Mtg.Zone.GRAVEYARD)
		assert_eq(g.players[1].life, 20, "a blocker is not 'blocked' (%s)" % preset)


func test_an_unblocked_druid_killed_after_combat_gains_nothing() -> void:
	_start("modern_mana_burn")
	var druid := put_battlefield(0, "Fyndhorn Druid")
	run_combat([druid.id])
	advance_to_step(Mtg.Step.MAIN2)
	_bolt(0, druid)
	assert_eq(druid.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 20)


# "This turn": blocked by a Wall, it survives combat and dies later in the
# turn — still blocked this turn.
func test_a_druid_blocked_earlier_this_turn_pays_when_it_dies_later() -> void:
	for preset in PRESETS:
		_start(preset)
		var druid := put_battlefield(0, "Fyndhorn Druid")
		var wall := put_battlefield(1, "Wall of Wood")
		run_combat([druid.id], {wall.id: druid.id})
		assert_eq(druid.zone, Mtg.Zone.BATTLEFIELD)
		advance_to_step(Mtg.Step.MAIN2)
		_bolt(0, druid)
		assert_eq(druid.zone, Mtg.Zone.GRAVEYARD)
		assert_eq(g.players[0].life, 24, "blocked this turn (%s)" % preset)


func test_a_druid_blocked_last_turn_pays_nothing() -> void:
	_start("modern_mana_burn")
	var druid := put_battlefield(0, "Fyndhorn Druid")
	var wall := put_battlefield(1, "Wall of Wood")
	run_combat([druid.id], {wall.id: druid.id})
	advance_to_next_turn()
	_bolt(1, druid)
	assert_eq(druid.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 20, "that was another turn")


# Blocked by an EFFECT (Dazzling Beauty's "becomes blocked", CR 509.1h).
func test_a_druid_made_blocked_by_an_effect_was_blocked() -> void:
	_start("modern_mana_burn")
	var druid := put_battlefield(0, "Fyndhorn Druid")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [druid.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	assert_true(g.make_blocked(druid))
	_bolt(0, druid)
	assert_eq(druid.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 24)


# A new object (CR 400.7): bounced and recast, it was never blocked.
func test_a_recast_druid_is_a_new_object() -> void:
	_start("modern_mana_burn")
	var druid := put_battlefield(0, "Fyndhorn Druid")
	var wall := put_battlefield(1, "Wall of Wood")
	run_combat([druid.id], {wall.id: druid.id})
	advance_to_step(Mtg.Step.MAIN2)
	var unsummon := give_hand(0, "Unsummon")
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, unsummon, [TargetRef.card(druid)]))
	resolve_stack()
	assert_eq(druid.zone, Mtg.Zone.HAND)
	add_mana(0, Mtg.ManaColor.G, 3)
	assert_ok(g.cast_spell(0, druid, []))
	resolve_stack()
	assert_eq(druid.zone, Mtg.Zone.BATTLEFIELD)
	_bolt(0, druid)
	assert_eq(druid.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 20, "the recast Druid was never blocked")


# The stamp is journaled: a search that explores a block unmakes it.
func test_a_searched_block_leaves_no_stamp() -> void:
	_start("modern_mana_burn")
	var druid := put_battlefield(0, "Fyndhorn Druid")
	var wall := put_battlefield(1, "Wall of Wood")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [druid.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	var m := g.make_mark()
	assert_ok(g.declare_blockers(1, {wall.id: druid.id}))
	assert_eq(druid.became_blocked_turn, g.turn_number)
	g.unmake_to(m)
	g.end_search()
	assert_eq(druid.became_blocked_turn, -1)
