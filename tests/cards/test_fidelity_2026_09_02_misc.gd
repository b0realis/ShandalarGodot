extends GameTest
## 2026-09-02 fidelity pass — card-shaped lifts that needed no new engine
## machinery: rows whose behaviour turned out to be the printed one already
## (pinned here so the ledger can drop them), and small fixes.


# ---------------------------------------------------------- Tawnos's Coffin --

func test_tawnos_coffin_restores_the_creatures_counters_not_the_auras() -> void:
	# "Note the number and kind of counters that were on THAT CREATURE ...
	# return that exiled card ... with the noted number and kind of
	# counters on it. If you do, return the other exiled cards ... attached
	# to that permanent." The creature's counters are restored by the
	# Coffin's own wording; an Aura comes back as a NEW object (CR 400.7)
	# and so, per the rules, with none of the counters it carried
	# (CR 122.2) — which is exactly what the printed card says happens.
	var coffin := put_battlefield(0, "Tawnos's Coffin")
	var angel := put_battlefield(1, "Serra Angel")
	var strength := give_hand(0, "Holy Strength")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, strength, [TargetRef.card(angel)]))
	resolve_stack()
	g.add_counters(angel, "+1/+1", 2)
	g.add_counters(strength, "test", 3)   # no pool Aura carries counters; planted
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, coffin, 0, [TargetRef.card(angel)]))
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.EXILE)
	g.untap_permanent(coffin)
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(int(angel.counters.get("+1/+1", 0)), 2, "the noted counters are back")
	assert_eq(strength.attached_to, angel.id)
	assert_eq(int(strength.counters.get("test", 0)), 0,
		"the Aura is a new object and carries none of its old counters")
