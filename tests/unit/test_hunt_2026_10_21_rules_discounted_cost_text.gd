extends GameTest
## Hunt 2026-10-21 (rules) — A DISCOUNTED COST SAYS WHAT IT COSTS.
##
## [method ManaCost.minus_generic] made the cheaper copy but kept the
## printed TEXT, and the text is what every surface shows: the refusal
## ("not enough mana ({3})"), the log and the mini card's ability badge.
## Under Power Artifact a Basalt Monolith's untap costs {1} and was paid
## as {1}, yet the game told the player it cost {3} (whole-project review
## 2026-10-21, "Seen by the reviewers, unchecked"). The copy now spells
## its own cost whenever the discount changed it.


func test_power_artifact_monolith_untap_reads_one() -> void:
	var monolith := put_battlefield(0, "Basalt Monolith")   # {3}: untap
	var aura := give_hand(0, "Power Artifact")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(monolith)]))
	resolve_stack()
	var ability: ActivatedAbility = monolith.cur_activated_abilities[0]
	assert_eq(ability.cost.generic, 1, "{3} became {1}")
	assert_eq(ability.cost.text, "{1}", "and it says so")
	assert_eq(str(ability.cost), "{1}")


func test_the_refusal_names_the_discounted_cost() -> void:
	var monolith := put_battlefield(0, "Basalt Monolith")
	var aura := give_hand(0, "Power Artifact")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(monolith)]))
	resolve_stack()
	monolith.tapped = true
	var why := g.activate_ability(0, monolith, 0, [])
	assert_string_contains(why, "{1}")
	assert_false(why.contains("{3}"), "not the printed {3}: '%s'" % why)


func test_minus_generic_spells_pips_and_x() -> void:
	var cost := ManaCost.parse("{X}{3}{U}{U}")
	assert_eq(cost.minus_generic(2).text, "{X}{1}{U}{U}")
	assert_eq(cost.minus_generic(5).text, "{X}{U}{U}", "generic gone, pips stay")
	assert_eq(ManaCost.parse("{2}{W}{B}").minus_generic(1).text, "{1}{W}{B}")
	assert_eq(ManaCost.parse("{4}").minus_generic(9).text, "{0}", "a free cost reads {0}")


func test_an_unchanged_copy_keeps_the_printed_text() -> void:
	# The planner copies a cost with a zero discount; a land's "" cost
	# stays "" (a free cost is shown as such by its readers).
	assert_eq(ManaCost.parse("{G}{2}").minus_generic(0).text, "{G}{2}")
	assert_eq(ManaCost.parse("").minus_generic(3).text, "")
