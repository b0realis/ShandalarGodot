extends GameTest
## Campaign fix-engine w3-1 — a BLOCKED BAND stays blocked when the member
## its blocker was declared against leaves combat.
##
## CR 702.22h: if an attacking creature with banding becomes blocked by a
## creature, each other creature in the same band becomes blocked by that
## same blocking creature; CR 509.1h: blocked it stays. Benalish Hero +
## Craw Wurm attack as a band and Grizzly Bears block the Hero; the Hero
## then leaves combat — phased out (Reality Ripple), bounced (Unsummon) or
## removed from combat. The Wurm used to become UNBLOCKED (the blocker's
## record named only the Hero, and only the Hero was marked blocked), hit
## the player for 6, and the Bears survived.


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, true)
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


## The band attacks, the Bears block the Hero; returns [hero, wurm, bear].
func _blocked_band() -> Array:
	var hero := put_battlefield(0, "Benalish Hero")
	var wurm := put_battlefield(0, "Craw Wurm")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [hero.id, wurm.id], [[hero.id, wurm.id]]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {bear.id: hero.id}))
	return [hero, wurm, bear]


func _remove_hero_with(spell_name: String, hero: CardInstance) -> void:
	if g.priority_player != 1:
		assert_ok(g.pass_priority(g.priority_player))
	var spell := give_hand(1, spell_name)
	add_mana(1, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(1, spell, [TargetRef.card(hero)]))
	resolve_stack()


func test_declaring_a_block_on_one_member_blocks_the_whole_band() -> void:
	var trio := _blocked_band()
	assert_true(g.combat.blocked_attackers.has((trio[1] as CardInstance).id),
		"the Wurm is blocked too (CR 702.22h) — 'target blocked creature' sees it")


func test_the_band_stays_blocked_when_its_blocked_member_phases_out() -> void:
	var trio := _blocked_band()
	_remove_hero_with("Reality Ripple", trio[0])
	assert_true((trio[0] as CardInstance).phased_out, "precondition: the Hero phased out")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20, "the Wurm is still blocked: no damage to the player")
	assert_eq((trio[2] as CardInstance).zone, Mtg.Zone.GRAVEYARD, "the Bears still fight the Wurm and die")
	assert_eq((trio[1] as CardInstance).damage, 2, "and deal it their 2")


func test_the_band_stays_blocked_when_its_blocked_member_is_bounced() -> void:
	var trio := _blocked_band()
	_remove_hero_with("Unsummon", trio[0])
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20, "the Wurm is still blocked")
	assert_eq((trio[2] as CardInstance).zone, Mtg.Zone.GRAVEYARD, "the Bears still block the Wurm and die")


func test_the_band_stays_blocked_when_its_blocked_member_is_removed_from_combat() -> void:
	var trio := _blocked_band()
	g.remove_from_combat(trio[0])
	assert_true(g.combat.is_blocking((trio[2] as CardInstance).id, (trio[1] as CardInstance).id),
		"the Bears now block the band's remaining member")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20)
	assert_eq((trio[2] as CardInstance).zone, Mtg.Zone.GRAVEYARD)


## A SOLO attacker that leaves combat is unchanged: its blocker keeps the
## standing entry (still "a blocking creature", CR 506.4) and fights nobody.
func test_a_solo_attackers_blocker_is_left_standing() -> void:
	var wurm := put_battlefield(0, "Craw Wurm")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {bear.id: wurm.id}))
	g.remove_from_combat(wurm)
	assert_true(g.combat.blocks.has(bear.id), "still a blocking creature")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[1].life, 20)


## False Orders' printed exception, for a band: removing the ONLY blocker
## of a band unblocks every member that had become blocked by it alone.
func test_removing_a_bands_only_blocker_with_the_false_orders_rider_unblocks_the_band() -> void:
	var trio := _blocked_band()
	g.remove_from_combat(trio[2], true)
	assert_false(g.combat.was_blocked([(trio[0] as CardInstance).id, (trio[1] as CardInstance).id]),
		"both members become unblocked")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 13, "the band's 1 + 6 reach the player")
