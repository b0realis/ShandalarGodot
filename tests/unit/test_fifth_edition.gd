extends GameTest
## THE FIFTH-EDITION RULESET AS A WHOLE — `--rules fifth`, every fork on
## at once (2026-09-02 audit).
##
## Seven forks live in [RulesOptions] and each had tests of its own; what
## nobody had ever asked was whether the 1997 side is as finished as the
## modern one WHEN THE SEVEN ARE ON TOGETHER. The forks are not
## independent — four of them key off the same phase boundary, and two of
## those write to the same life total on it — so "each works alone" was
## never the same claim as "the ruleset works".
##
## Every test here runs `rules.set_edition("fifth")` and nothing else, so
## it is a test of the shipped preset rather than of a hand-mixed one.


func _fifth() -> void:
	g.rules.set_edition("fifth")


func test_the_preset_really_turns_every_fork_to_1997() -> void:
	_fifth()
	assert_eq(g.rules.edition(), "fifth")
	for fork in RulesOptions.FORKS:
		assert_eq(g.rules.get_fork(fork["key"]), fork["fifth_value"],
			"%s is at its 1997 answer" % fork["key"])


# ------------------------------------- mana burn meets the phase-end check --

func test_mana_burn_kills_at_the_boundary_it_is_charged_on() -> void:
	# THE INTERACTION. Under the full preset both rules key off the SAME
	# phase boundary: the pool empties and burns there (manual p.176), and
	# the lethal-life check happens there (p.174). Charging the burn AFTER
	# the check gives a player a whole free phase at negative life that
	# 1997 never gave them — and the manual's own escape clause ("if you
	# manage to gain back enough life before the end of the phase") cannot
	# apply to burn anyway, because the burn IS the end of the phase.
	_fifth()
	g.players[0].life = 3
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 5)
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	assert_true(g.game_over, "burned from 3 to -2 and did not survive it")
	assert_eq(g.winner, 1)


func test_a_survivable_burn_is_still_survivable() -> void:
	_fifth()
	g.players[0].life = 6
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 5)
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	assert_false(g.game_over)
	assert_eq(g.players[0].life, 1)


func test_both_seats_burning_out_together_is_a_draw() -> void:
	# CR 104.4b / manual p.168 — the phase-end check already collected its
	# losers simultaneously; the burn must not turn that into a race.
	_fifth()
	g.players[0].life = 2
	g.players[1].life = 2
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 3)
	add_mana(1, Mtg.ManaColor.U, 3)
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	assert_true(g.game_over)
	assert_true(g.is_draw, "both duelists burned out on the same boundary")
	assert_eq(g.winner, -1)


func test_life_gained_inside_the_phase_still_saves_a_player() -> void:
	# The rule the phase-end check exists FOR (manual p.174) must survive
	# the reordering: damage inside a phase is not lethal until the phase
	# ends, and life gained before then rescues it.
	_fifth()
	g.players[0].life = 2
	advance_to_step(Mtg.Step.MAIN1)
	g.deal_damage(put_battlefield(1, "Lightning Bolt"), TargetRef.player(0), 3)
	resolve_stack()
	assert_false(g.game_over, "-1 life, and the phase is not over")
	g.adjust_life(0, 5)
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	assert_false(g.game_over, "gained it back in time")
	assert_eq(g.players[0].life, 4)


# ------------------------------------- the pool that outlives a step, burnt --

func test_the_1997_pool_survives_a_step_and_burns_at_the_phase() -> void:
	# `pool_empties_on_attack` and `mana_burn` are one mechanism under the
	# preset: mana floated in the upkeep is still there in the draw step,
	# and is charged for exactly once, when the phase ends.
	_fifth()
	g.players[0].life = 20
	advance_to_step(Mtg.Step.UPKEEP)
	add_mana(0, Mtg.ManaColor.R, 2)
	advance_to_step(Mtg.Step.DRAW)
	assert_eq(g.players[0].mana_pool.total(), 2,
		"a step boundary inside the beginning phase does not empty it")
	assert_eq(g.players[0].life, 20, "and nothing has been burned yet")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(g.players[0].mana_pool.total(), 0)
	assert_eq(g.players[0].life, 18, "burned once, at the phase boundary")


# --------------------------------- the damage window under the whole preset --

## A seat that asks for the window — the same stand-in
## `tests/unit/test_damage_window.gd` uses, because both gates
## (`DecisionAgent.wants_damage_prevention_window` and the fork) have to
## be open and the preset only supplies one of them.
class Duelist extends DecisionAgent:
	func wants_damage_prevention_window() -> bool:
		return true


func test_lethal_combat_damage_can_be_answered_inside_the_window() -> void:
	# THREE FORKS AT ONCE, and the 1997 duel's whole tactical layer: the
	# damage waits in a packet (`damage_prevention_window`), the seat that
	# took it is not dead while it waits (`life_checked_at_phase_end`),
	# and a Circle answers it after the fact. Each fork had tests; the
	# three together had none.
	_fifth()
	g.set_agent(1, Duelist.new())
	g.players[1].life = 2
	var wurm := put_battlefield(0, "Craw Wurm")            # 6/4, GREEN
	var circle := put_battlefield(1, "Circle of Protection: Green")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_prevention)
	assert_false(g.game_over, "six damage at 2 life, and nobody has died")
	assert_ok(g.end_damage_prevention(0))
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(1, circle, 0))
	resolve_stack()
	assert_ok(g.end_damage_prevention(g.priority_player))
	if g.awaiting_damage_prevention or g.awaiting_regeneration:
		assert_ok(g.end_damage_prevention(g.priority_player))
	assert_eq(g.players[1].life, 2, "the Wurm's damage never landed")
	advance_to_step(Mtg.Step.MAIN2)
	assert_false(g.game_over, "and the phase boundary found nothing wrong")


func test_unanswered_lethal_damage_still_kills_at_the_phase_boundary() -> void:
	# The other half of the same interaction: the window is a chance, not
	# an immunity. Nothing is spent, the damage lands, and the seat lives
	# on at -4 until the combat phase ends — which is exactly what
	# `life_checked_at_phase_end` promises and what the modern default
	# would never do.
	_fifth()
	g.set_agent(1, Duelist.new())
	g.players[1].life = 2
	var wurm := put_battlefield(0, "Craw Wurm")
	put_battlefield(1, "Circle of Protection: Green")       # opens the window
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_ok(g.end_damage_prevention(g.priority_player))
	if g.awaiting_damage_prevention or g.awaiting_regeneration:
		assert_ok(g.end_damage_prevention(g.priority_player))
	assert_eq(g.players[1].life, -4, "it landed")
	assert_false(g.game_over, "and the phase is not over yet")
	advance_to_step(Mtg.Step.MAIN2)
	assert_true(g.game_over, "the combat phase ended and the check ran")
	assert_eq(g.winner, 0)


# ==== THE INTERACTIONS, PAIR BY PAIR (2026-09-02, the coverage pass) ========
#
# The audit that opened this file found its HIGH defect in an INTERACTION —
# mana burn charged after the phase-end lethal check, both firing on the
# same boundary — and measured that the seven forks were covered very
# unevenly (17 test references for the damage-prevention window against 2
# for `pool_empties_on_attack`). Everything below is a pair or a triple of
# forks that no single-fork test can reach, weighted towards the forks the
# count said were thin.
#
# WHICH PAIRS CAN INTERACT AT ALL, written out so a reader can see what is
# deliberately absent rather than forgotten:
#
#   mana_burn x pool_empties_on_attack        — one mechanism; above.
#   mana_burn x life_checked_at_phase_end     — the audit's defect; above.
#   mana_burn x damage_prevention_window      — burn is life LOSS, so a
#                                               shield raised in the window
#                                               does not stop it.
#   pool x damage_prevention_window           — the pool that survives a
#                                               combat step is what PAYS
#                                               for prevention.
#   free_damage_assignment x window           — the split the attacker
#                                               chose is what waits in the
#                                               packets.
#   tapped_artifacts_stop x mana_burn         — the fork suspends
#                                               CONTINUOUS effects only, so
#                                               a tapped artifact's TRIGGER
#                                               still makes mana that still
#                                               burns.
#   attackers_revocable x anything            — none, and that is the
#                                               finding: it is the one fork
#                                               with no engine branch at
#                                               all. See its test below.


## A seat that wants BOTH prompts — the damage split (CR 509.2's choice)
## and the prevention window. `Duelist` above only asks for the window, and
## an interaction between those two forks needs one seat to hold both.
class Divider extends DecisionAgent:
	func wants_damage_prevention_window() -> bool:
		return true

	func wants_to_assign_combat_damage() -> bool:
		return true


func _end_window() -> void:
	assert_ok(g.end_damage_prevention(g.priority_player))
	if g.awaiting_damage_prevention or g.awaiting_regeneration:
		assert_ok(g.end_damage_prevention(g.priority_player))


# ------------------------- the pool that pays for the prevention window ----

func test_mana_floated_in_combat_is_what_pays_for_the_prevention() -> void:
	# THE REASON THE 1997 POOL RULE EXISTS, and the pair no single-fork
	# test could show. Modern rules empty the pool at every STEP, so mana
	# floated when blockers are declared is gone by the damage step and
	# there is nothing to answer the damage WITH; the 1997 rule keeps it
	# for the whole combat PHASE (manual p.176), which is exactly the span
	# `Duel.hlp`'s damage prevention step lives inside. Then mana burn
	# charges whatever was not spent, on the boundary that ends combat.
	_fifth()
	g.set_agent(1, Duelist.new())
	var wurm := put_battlefield(0, "Craw Wurm")             # 6/4, GREEN
	var circle := put_battlefield(1, "Circle of Protection: Green")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	add_mana(1, Mtg.ManaColor.C, 3)     # floated with the blockers
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_prevention, "the window is open")
	assert_eq(g.players[1].mana_pool.total(), 3,
		"and the mana is STILL THERE — a step inside combat did not empty it")
	assert_ok(g.end_damage_prevention(0))
	assert_ok(g.activate_ability(1, circle, 0))             # {1}
	resolve_stack()
	_end_window()
	assert_eq(g.players[1].life, 20, "the Wurm's six never landed")
	assert_eq(g.players[1].mana_pool.total(), 2, "one of the three is spent")
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(g.players[1].mana_pool.total(), 0, "the combat PHASE has ended")
	assert_eq(g.players[1].life, 18, "and the two it did not spend burned")


# ------------------- a burn and an unanswered lethal on one boundary -------

func test_a_burn_and_an_unanswered_lethal_on_one_boundary_is_a_draw() -> void:
	# THREE FORKS ON ONE BOUNDARY, which is one more than the audit's own
	# defect needed. Seat 1 takes six it chose not to prevent and sits at
	# -4 through the rest of combat (`life_checked_at_phase_end` +
	# `damage_prevention_window`); seat 0 burns five off three on the very
	# boundary that then checks them both (`mana_burn` +
	# `pool_empties_on_attack`). Neither is alive when the phase ends, and
	# manual p.168 says that is a DRAW rather than a race won by seat
	# order. Under the pre-audit ordering seat 0 would have WON this.
	_fifth()
	g.set_agent(1, Duelist.new())
	g.players[0].life = 3
	g.players[1].life = 2
	var wurm := put_battlefield(0, "Craw Wurm")
	put_battlefield(1, "Circle of Protection: Green")       # opens the window
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	add_mana(0, Mtg.ManaColor.R, 5)     # floated, and never spent
	assert_ok(g.declare_attackers(0, [wurm.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	_end_window()
	assert_eq(g.players[1].life, -4, "it landed, and nobody answered it")
	assert_false(g.game_over, "and the combat phase is not over yet")
	advance_to_step(Mtg.Step.MAIN2)
	assert_true(g.game_over)
	assert_true(g.is_draw, "one burned out, one bled out, on one boundary")
	assert_eq(g.winner, -1)


func test_a_prevention_shield_raised_in_the_window_does_not_stop_a_burn() -> void:
	# `mana_burn` x `damage_prevention_window`. Mana burn is LIFE LOSS and
	# never damage, so the one thing the window is for cannot touch it —
	# `tests/unit/test_mana_burn.gd` pins that against a bare shield, and
	# this pins it with the 1997 window actually open around it.
	_fifth()
	g.set_agent(1, Duelist.new())
	var wurm := put_battlefield(0, "Craw Wurm")
	put_battlefield(1, "Circle of Protection: Green")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	add_mana(1, Mtg.ManaColor.C, 2)
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	g.players[1].damage_prevention = 10       # a shield, inside the window
	_end_window()
	assert_eq(g.players[1].life, 20, "the shield ate the Wurm's six")
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(g.players[1].life, 18, "and did nothing at all about the burn")
	assert_eq(g.players[1].damage_prevention, 4,
		"the burn did not even spend it")


# ------------------------ the free split, and what the window holds --------

func test_the_free_split_is_exactly_what_the_window_then_holds() -> void:
	# `free_damage_assignment` x `damage_prevention_window`. Two and four
	# onto two 3/3s is a division MODERN RULES REFUSE — neither blocker is
	# dealt lethal before the next — and Fifth Edition allows, because it
	# had no assignment order at all. The pair matters because the window
	# turns damage into objects that sit on the table: whatever the
	# attacker divided is what waits there, and closing the window is what
	# lands it.
	_fifth()
	g.set_agent(0, Divider.new())
	var wurm := put_battlefield(0, "Craw Wurm")            # 6 power, GREEN
	var first := put_battlefield(1, "Hill Giant")          # 3/3
	var second := put_battlefield(1, "Hill Giant")         # 3/3
	# The window AUTO-SKIPS when no seat holds a prevention effect at all
	# (`_maybe_open_damage_window` — a window whose only legal action is a
	# prevention effect can only be passed). A Circle is what makes it a
	# window rather than a formality, exactly as in a real duel.
	put_battlefield(1, "Circle of Protection: Green")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {first.id: wurm.id, second.id: wurm.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_assignment, "the attacker is asked first")
	assert_ok(g.assign_combat_damage(0, {first.id: 2, second.id: 4}))
	assert_true(g.awaiting_damage_prevention,
		"and only THEN does the damage go into the window")
	assert_eq(first.damage, 0, "nothing has landed while it waits")
	_end_window()
	assert_eq(first.damage, 2, "two, exactly as divided")
	assert_eq(first.zone, Mtg.Zone.BATTLEFIELD, "and it lived on it")
	assert_eq(second.zone, Mtg.Zone.GRAVEYARD, "while four killed the other")


func test_trample_keeps_its_own_rule_under_the_whole_preset() -> void:
	# The other half of `free_damage_assignment`, and the half the fork's
	# own doc comment promises: every blocker must have lethal before a
	# single point spills to the player (CR 702.19b), and the original
	# enforced that too — `@PROMPT_RESOLVECOMBAT` has a SECOND prompt,
	# `%s: Assign trample damage to blockers, %d points left`. Only the
	# modern branch was tested; this is the 1997 one, with every other fork
	# on around it.
	_fifth()
	g.set_agent(0, Divider.new())
	var mammoth := put_battlefield(0, "War Mammoth")       # 3/3 trample, GREEN
	var bear := put_battlefield(1, "Grizzly Bears")        # 2/2
	put_battlefield(1, "Circle of Protection: Green")      # arms the window
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [mammoth.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {bear.id: mammoth.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_refused(g.assign_combat_damage(0,
		{bear.id: 1, MtgGame.DAMAGE_TO_PLAYER: 2}), "lethal")
	assert_ok(g.assign_combat_damage(0,
		{bear.id: 2, MtgGame.DAMAGE_TO_PLAYER: 1}))
	_end_window()
	assert_eq(g.players[1].life, 19)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


# --------------- a tapped artifact: which half of it actually stops --------

func test_a_tapped_artifact_loses_its_anthem_and_keeps_its_trigger() -> void:
	# `tapped_artifacts_stop` x `mana_burn`, and the exact seam between
	# them. Manual p.124 suspends a tapped artifact's CONTINUOUS effects
	# and says nothing about anything else, so Gauntlet of Might is the
	# card that separates one permanent's two halves: `Red creatures get
	# +1/+1` is a static and stops, `Whenever a Mountain is tapped for
	# mana...` is a trigger and does not — and the extra {R} it goes on
	# making is still charged for when the phase ends.
	#
	# Tapped through the public API by the opponent's Icy Manipulator,
	# which is also the only way a 1997 player could have done it: an
	# artifact with no tap ability of its own cannot tap itself.
	_fifth()
	var gauntlet := put_battlefield(0, "Gauntlet of Might")
	var elemental := put_battlefield(0, "Fire Elemental")   # 5/4, RED
	var mountain := put_battlefield(0, "Mountain")
	var icy := put_battlefield(1, "Icy Manipulator")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(elemental.cur_power, 6, "the anthem is on while it is untapped")
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.pass_priority(0))       # the active player yields first
	assert_ok(g.activate_ability(1, icy, 0, [TargetRef.card(gauntlet)]))
	resolve_stack()
	assert_true(gauntlet.tapped)
	assert_true(gauntlet.cur_statics_suspended, "manual p.124")
	assert_eq(elemental.cur_power, 5, "so the anthem is off")
	assert_ok(g.tap_for_mana(0, mountain))
	assert_eq(g.players[0].mana_pool.total(), 2,
		"but the TRIGGER still fires — it is not a continuous effect")
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	assert_eq(g.players[0].life, 18,
		"and both points of it burned when the phase ended")


# ------------------- the one fork with nothing to interact WITH ------------

func test_the_engine_has_no_undeclare_which_is_why_that_fork_is_the_screens() -> void:
	# `attackers_revocable` is the odd one of the seven: it is in
	# [constant RulesOptions.IMPLEMENTED] and it has NO engine branch —
	# `MtgGame.declare_attackers` takes the declaration once and refuses a
	# second call under BOTH rulesets, so "revocable" can only ever mean
	# that the SCREEN holds the selection open until Done. Pinned here so
	# that a reader counting fork coverage knows the engine is not where
	# the rest of it lives: `game/duel/duel_screen.gd`, `_can_cancel` and
	# `_on_cancel`.
	_fifth()
	assert_false(g.rules.attackers_revocable, "the 1997 answer")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	assert_refused(g.declare_attackers(0, []), "not the time")
	assert_true(g.combat.attackers.has(bear.id), "the declaration stands")
	# ...and identically with the fork at its modern answer, which is the
	# whole point: the engine never reads it.
	g.rules.attackers_revocable = true
	assert_refused(g.declare_attackers(0, []), "not the time")
	assert_true(g.combat.attackers.has(bear.id))


# ------------------------------ the boundary that ends the turn -----------

func test_the_turn_boundary_burns_and_checks_like_any_other() -> void:
	# Every other test here uses a phase boundary INSIDE a turn. The end of
	# the turn is a boundary too — `_phase_ends_now` returns true when
	# there is no next step, and the pool empties there under either
	# ruleset — so the pair that killed a player at the combat boundary has
	# to kill them at this one as well.
	_fifth()
	g.players[0].life = 3
	advance_to_step(Mtg.Step.END)
	add_mana(0, Mtg.ManaColor.R, 4)
	advance_to_next_turn()
	assert_true(g.game_over, "burned from 3 to -1 as the turn ended")
	assert_eq(g.winner, 1)


# ---------------- the half of a tapped artifact that does NOT stop ---------

func test_a_tapped_artifact_can_still_answer_the_1997_window() -> void:
	# `tapped_artifacts_stop` x `damage_prevention_window`, and the exact
	# boundary the fork's own doc comment claims: manual p.124 suspends
	# CONTINUOUS effects, so an ACTIVATED ability on a tapped artifact is
	# untouched — and the 1997 window's whole content is activated
	# prevention effects. A Forcefield that an Icy Manipulator has just
	# tapped must therefore still arm the window and still be usable
	# INSIDE it. Nothing tested that; the fork's tests were all statics.
	#
	# Everything here goes through the public API — the Icy is the way a
	# 1997 player really tapped somebody else's artifact — and the {1} the
	# Forcefield needs is floated when blockers are declared, which is
	# `pool_empties_on_attack` paying for the window a third time.
	_fifth()
	g.set_agent(1, Duelist.new())
	var wurm := put_battlefield(0, "Craw Wurm")            # 6/4
	var icy := put_battlefield(0, "Icy Manipulator")
	var field := put_battlefield(1, "Forcefield")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	add_mana(1, Mtg.ManaColor.C)        # floated for the Forcefield
	assert_ok(g.declare_blockers(1, {}))
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, icy, 0, [TargetRef.card(field)]))
	resolve_stack()
	assert_true(field.tapped, "tapped by the opponent, mid-combat")
	assert_true(field.cur_statics_suspended, "manual p.124 applies to it")
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_prevention,
		"a TAPPED artifact still arms the window: the ability is activated")
	assert_ok(g.end_damage_prevention(0))
	assert_ok(g.activate_ability(1, field, 0))
	resolve_stack()
	_end_window()
	assert_eq(g.players[1].life, 19,
		"all but one of the Wurm's six, from a tapped Forcefield")


# ------------------------- combat has SIX steps, and one boundary ---------

func test_the_pool_survives_first_strike_and_is_charged_once() -> void:
	# `pool_empties_on_attack` x `mana_burn` across the LONGEST combat
	# there is. First strike adds a sixth step (CR 510.5), and the 1997
	# rule makes all six one phase — so mana floated when blockers are
	# declared has to be charged for exactly ONCE, when combat ends.
	# Charging per damage step would bill a player twice for one float,
	# and the existing pool tests all use the three-step beginning phase.
	_fifth()
	var knight := put_battlefield(0, "White Knight")       # 2/2 first strike
	var bear := put_battlefield(1, "Grizzly Bears")        # 2/2
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [knight.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	add_mana(0, Mtg.ManaColor.W, 3)
	assert_ok(g.declare_blockers(1, {bear.id: knight.id}))
	advance_to_step(Mtg.Step.FIRST_STRIKE_DAMAGE)
	assert_eq(g.players[0].mana_pool.total(), 3,
		"there for the first-strike step")
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_eq(g.players[0].mana_pool.total(), 3,
		"and still there for the regular one")
	assert_eq(g.players[0].life, 20, "nothing charged yet")
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(g.players[0].mana_pool.total(), 0, "combat is over")
	assert_eq(g.players[0].life, 17,
		"charged ONCE for the float, not once per damage step")


# ---------------- the parts of a fork the MODERN branch tests and the ------
# ---------------- 1997 branch did not -------------------------------------

func test_the_free_split_still_has_to_spend_every_point() -> void:
	# `free_damage_assignment` removes the ORDER, not the arithmetic. The
	# original's own prompt is a countdown — `%s: Assign damage to
	# blockers, %d points left` (`@PROMPT_RESOLVECOMBAT`) — so it reaches
	# zero or it is not finished. `tests/unit/test_damage_assignment.gd`
	# pins that for the modern branch and nothing pinned it for the 1997
	# one, which is exactly where a fork loosens one rule too many.
	_fifth()
	g.set_agent(0, Divider.new())
	var wurm := put_battlefield(0, "Craw Wurm")            # 6 power
	var first := put_battlefield(1, "Hill Giant")          # 3/3
	var second := put_battlefield(1, "Hill Giant")         # 3/3
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {first.id: wurm.id, second.id: wurm.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_refused(g.assign_combat_damage(0, {first.id: 2, second.id: 3}),
		"points left")
	assert_refused(g.assign_combat_damage(0, {first.id: 3, second.id: 4}),
		"only 6")
	assert_refused(g.assign_combat_damage(0, {first.id: 6, 999: 0}),
		"not blocking")
	assert_true(g.awaiting_damage_assignment,
		"and a refusal leaves the division open, as it does under modern rules")
	assert_ok(g.assign_combat_damage(0, {first.id: 1, second.id: 5}))


func test_poison_outranks_the_whole_preset_and_not_just_the_life_fork() -> void:
	# Manual p.177: poison kills at once, and does not wait for the end of
	# the phase the way a life total does. `tests/unit/test_mana_burn.gd`
	# pins that against `life_checked_at_phase_end` ALONE; here the two
	# rules that share that boundary are both on, and a player who would
	# have been saved by the burn arriving first still dies of poison
	# before either of them runs.
	_fifth()
	g.players[0].life = 20
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 5)     # a burn is queued for the boundary
	g.add_poison(0, 10)
	assert_true(g.game_over, "poison does not wait for the phase to end")
	assert_eq(g.winner, 1)
	assert_eq(g.players[0].life, 20, "and the burn never happened")
