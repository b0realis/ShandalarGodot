extends GameTest
## THE SECOND BUG HUNT (2026-10-21), the handover: five base-set cards that
## read "blocking" and "blocked by" off the declaration alone.
##
## WAS: Abu Ja'far, The Wretched, Spitting Slug, Wall of Caltrops and Feint
## asked who was declared against ONE creature (`CombatState.blockers_of`,
## `attackers_blocked_by`). A creature blocking any member of a BAND blocks
## every member (CR 702.22h), so a Bears blocking the Benalish Hero banded
## with The Wretched was not "blocking The Wretched" and stayed home; and
## the declaration still names an attacker that has LEFT combat (regenerated,
## removed — `CombatState.forget` keeps the blocker's entry on purpose), so
## Abu Ja'far destroyed a creature that was no longer blocked by it. The
## same readings were fixed for Packs 2-9 earlier today (cardsB).
## NOW they ask the band (`blockers_of_band`, `opposing_attackers`) and only
## attackers still in combat.


func before_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, true)
	CardRegistry.ensure_loaded()


func after_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


## Hero + [param partner] attack as one band; returns after blockers are
## declared from [param blocks].
func _band_attack(partner: CardInstance, hero: CardInstance, blocks: Dictionary) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [hero.id, partner.id], [[hero.id, partner.id]]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, blocks))


# ------------------------------------------------------------- Abu Ja'far --

func test_abu_ja_far_in_a_band_takes_the_band_s_blocker() -> void:
	var hero := put_battlefield(0, "Benalish Hero")
	var abu := put_battlefield(0, "Abu Ja'far")
	var bear := put_battlefield(1, "Grizzly Bears")
	_band_attack(abu, hero, {bear.id: hero.id})
	g.destroy(abu)
	resolve_stack()
	assert_eq(abu.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD,
		"the Bears blocking the Hero were blocking Abu Ja'far too")


func test_abu_ja_far_blocking_a_band_takes_every_member() -> void:
	var hero := put_battlefield(0, "Benalish Hero")
	var bear := put_battlefield(0, "Grizzly Bears")
	var abu := put_battlefield(1, "Abu Ja'far")
	_band_attack(bear, hero, {abu.id: hero.id})
	g.destroy(abu)
	resolve_stack()
	assert_eq(hero.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "blocking the Hero, it blocked the band")


func test_abu_ja_far_spares_an_attacker_that_left_combat() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var abu := put_battlefield(1, "Abu Ja'far")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {abu.id: bear.id}))
	g.remove_from_combat(bear)
	g.destroy(abu)
	resolve_stack()
	assert_eq(abu.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "no longer blocked by it (CR 506.4)")


# ------------------------------------------------------------- The Wretched --

func test_the_wretched_in_a_band_takes_the_band_s_blocker() -> void:
	var hero := put_battlefield(0, "Benalish Hero")
	var wretched := put_battlefield(0, "The Wretched")
	var wall := put_battlefield(1, "Wall of Stone")
	_band_attack(wretched, hero, {wall.id: hero.id})
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(wall.controller_id, 0, "the Wall was blocking The Wretched's band")


func test_the_wretched_out_of_combat_takes_nothing() -> void:
	var wretched := put_battlefield(0, "The Wretched")
	var wall := put_battlefield(1, "Wall of Stone")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wretched.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: wretched.id}))
	g.remove_from_combat(wretched)
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(wall.controller_id, 1, "nothing is blocking a creature out of combat")


func test_the_wretched_takes_its_blocker() -> void:
	# Control.
	var wretched := put_battlefield(0, "The Wretched")
	var wall := put_battlefield(1, "Wall of Stone")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wretched.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: wretched.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(wall.controller_id, 0)


# ------------------------------------------------------------ Spitting Slug --

func test_spitting_slug_in_a_band_becomes_blocked() -> void:
	var hero := put_battlefield(0, "Benalish Hero")
	var slug := put_battlefield(0, "Spitting Slug")
	var bear := put_battlefield(1, "Grizzly Bears")
	_band_attack(slug, hero, {bear.id: hero.id})
	resolve_stack()   # no {1}{G} to pay: what fights the Slug strikes first
	assert_true(bear.has_keyword(Mtg.Keyword.FIRST_STRIKE),
		"the Slug became blocked when its band did")


func test_spitting_slug_arms_no_attacker_that_left_combat() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var slug := put_battlefield(1, "Spitting Slug")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {slug.id: bear.id}))
	assert_false(g.stack.is_empty(), "control: the Slug's trigger waits")
	g.remove_from_combat(bear)
	resolve_stack()
	assert_false(bear.has_keyword(Mtg.Keyword.FIRST_STRIKE),
		"the Bears are no longer blocked by the Slug")


# --------------------------------------------------------- Wall of Caltrops --

func test_wall_of_caltrops_counts_a_wall_on_the_band() -> void:
	# Control: a Wall on another member of the band is a Wall on this one.
	var hero := put_battlefield(0, "Benalish Hero")
	var bear := put_battlefield(0, "Grizzly Bears")
	var caltrops := put_battlefield(1, "Wall of Caltrops")
	var stone := put_battlefield(1, "Wall of Stone")
	_band_attack(bear, hero, {caltrops.id: hero.id, stone.id: bear.id})
	resolve_stack()
	assert_true(caltrops.has_keyword(Mtg.Keyword.BANDING),
		"the Wall of Stone blocking the band is blocking the Hero too")


func test_wall_of_caltrops_sees_a_non_wall_on_the_band() -> void:
	var hero := put_battlefield(0, "Benalish Hero")
	var bear := put_battlefield(0, "Grizzly Bears")
	var caltrops := put_battlefield(1, "Wall of Caltrops")
	var stone := put_battlefield(1, "Wall of Stone")
	var guard := put_battlefield(1, "Grizzly Bears")
	_band_attack(bear, hero, {caltrops.id: hero.id, stone.id: hero.id, guard.id: bear.id})
	resolve_stack()
	assert_false(caltrops.has_keyword(Mtg.Keyword.BANDING),
		"a non-Wall is blocking the Hero through its band")


# -------------------------------------------------------------------- Feint --

func test_feint_taps_a_creature_blocking_the_band() -> void:
	var hero := put_battlefield(0, "Benalish Hero")
	var bear := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Stone")
	var feint := give_hand(0, "Feint")
	_band_attack(bear, hero, {wall.id: hero.id})
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, feint, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(wall.tapped, "the Wall blocking the Hero is blocking the Bears too")
