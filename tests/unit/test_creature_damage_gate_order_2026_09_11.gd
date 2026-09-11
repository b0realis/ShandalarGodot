extends GameTest
## CR 616.1 ON THE CREATURE BRANCH — 2026-09-11.
##
## "If two or more replacement and/or prevention effects are attempting to
## modify the way an event affects an object or player, THE AFFECTED
## OBJECT'S CONTROLLER or the affected player chooses one to apply, and
## then the rule is applied again." The pass earlier the same day built
## that for a packet aimed at a PLAYER and left this half NARROWED: its
## gates ran in one fixed order, they SPANNED TWO METHODS
## (MtgGame._land_damage_impl and the old _land_damage_rest), and THREE OF
## THEM ARE METERED rather than one-shot — Rock Hydra's counters, Personal
## Incarnation's points and the per-creature prevention pool each absorb
## what they can and let the rest of the event carry on.
##
## THE TWO QUESTIONS THAT HALF WAS LEFT ON, ANSWERED HERE.
##
## 1. CAN A METERED GATE BE ORDERED AT ALL WITHOUT CHANGING WHAT IT MEANS?
##    Yes. It is applied ONCE, in full, exactly as the fixed chain applied
##    it, and CR 616.1 is then put again to what is left — the rule never
##    asks an effect to apply by halves. What it is not is interchangeable,
##    and a single rare says so on its own: a Rock Hydra with three +1/+1
##    counters and two points of its own {R} prevention on it ends a
##    2-damage event either as a 1/1 with its pool intact or as a 3/3 with
##    its pool spent. Two points of power and toughness, from the order
##    alone.
##
## 2. WHOSE CHOICE IS IT? The rule's own words: the affected OBJECT'S
##    CONTROLLER. Not the seat the damage may end up on — a Jade Monolith
##    the opponent activated on your blocker is still your blocker's event
##    to order, and the opponent is never asked (below).
##
## The hint is index 0 — the head of the old order — and
## DecisionAgent.answer_option returns its hint, so every heuristic seat
## plays the board this engine always played and the whole suite is
## unmoved. A human seat gets a prompt it never got.


## Answers the CR 616.1 ordering question with whichever index the test
## parked (negative = take the hint, which is the old fixed order) and
## records every question it was asked.
class Chooser extends DecisionAgent:
	var take := -1
	var asked: Array[String] = []
	var yes_no: Array[String] = []

	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String,
			hint: bool) -> bool:
		yes_no.append(prompt)
		return hint

	func answer_option(_game: MtgGame, _pid: int, _prompt: String,
			options: Array[String], hint: int) -> int:
		asked.append(", ".join(options))
		return hint if take < 0 else take


# ================== THE REPRODUCTION: TWO METERED GATES ==================

## A Rock Hydra with [param heads] +1/+1 counters and [param shields]
## points bought with its own printed `{R}`, then [param amount] damage
## from a Grizzly Bears. Both gates want the same points and the two orders
## do not agree about what the Hydra is afterwards.
func _hydra_under_two_meters(take: int, heads := 3, shields := 2,
		amount := 2) -> Chooser:
	var chooser := Chooser.new()
	chooser.take = take
	g.set_agent(0, chooser)
	var hydra := put_battlefield(0, "Rock Hydra")
	g.add_counters(hydra, "+1/+1", heads)
	g.recalculate()
	advance_to_step(Mtg.Step.MAIN1)
	for i in shields:
		add_mana(0, Mtg.ManaColor.R)
		assert_ok(g.activate_ability(0, hydra, 0))
		resolve_stack()
	assert_eq(hydra.prevention, shields, "the {R} shields are in the pool")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.deal_damage(bear, TargetRef.card(hydra), amount)
	return chooser


## THE REPRODUCTION. Two effects apply to one packet aimed at a CREATURE,
## so its controller is asked which applies first (CR 616.1) — once, for
## the one packet, with both on the list.
func test_the_creatures_controller_is_asked_which_gate_applies_first() -> void:
	var chooser := _hydra_under_two_meters(0)
	assert_eq(chooser.asked.size(), 1, "asked once, for the one packet")
	assert_true(chooser.asked[0].contains("Rock Hydra sheds +1/+1 counters"),
		"the replacement is on the list: %s" % chooser.asked[0])
	assert_true(chooser.asked[0].contains("prevented damage"),
		"and so is the prevention pool: %s" % chooser.asked[0])


## Taking the counters is what the engine always did: two heads come off
## and the {R} shields are still waiting.
func test_taking_the_counters_leaves_the_pool_and_a_smaller_hydra() -> void:
	_hydra_under_two_meters(0)
	var hydra := g.players[0].battlefield[0]
	assert_eq(hydra.damage, 0, "prevented either way")
	assert_eq(int(hydra.counters.get("+1/+1", 0)), 1, "two heads paid for it")
	assert_eq(hydra.cur_power, 1, "so it is a 1/1 now")
	assert_eq(hydra.prevention, 2, "and the pool was never touched")


## Taking the pool spends the two {R} shields instead, and the Hydra is
## still the 3/3 it was. Neither line is the engine's to pick.
func test_taking_the_pool_leaves_the_counters_and_a_3_3() -> void:
	_hydra_under_two_meters(1)
	var hydra := g.players[0].battlefield[0]
	assert_eq(hydra.damage, 0, "prevented either way")
	assert_eq(int(hydra.counters.get("+1/+1", 0)), 3, "every head is still on")
	assert_eq(hydra.cur_power, 3, "so it is still a 3/3")
	assert_eq(hydra.prevention, 0, "and the pool paid for it")


## A METERED GATE IS APPLIED ONCE, IN FULL, and CR 616.1 is then put again
## only to what still applies — a spent meter is not offered a second time,
## so a board with two gates asks exactly ONE question however many times
## the rule is re-applied, and the points nobody could absorb still land.
func test_a_spent_meter_is_not_offered_again() -> void:
	var chooser := Chooser.new()
	chooser.take = 0
	g.set_agent(0, chooser)
	var avatar := put_battlefield(0, "Personal Incarnation")
	g.add_point_redirect(avatar, 0, 1)
	avatar.prevention = 1
	var bear := put_battlefield(1, "Grizzly Bears")
	g.deal_damage(bear, TargetRef.card(avatar), 3)
	assert_eq(chooser.asked.size(), 1,
		"asked once: the second round had one candidate left")
	assert_eq(avatar.damage_point_redirects, 0, "the one booked point moved")
	assert_eq(avatar.prevention, 0, "and the one shield was spent")
	assert_eq(g.players[0].life, 19, "the moved point landed on the owner")
	assert_eq(avatar.damage, 1, "the third point had nothing left to meet it")


# ============ WHOSE CHOICE: THE AFFECTED OBJECT'S CONTROLLER ============

## A Jade Monolith the OPPONENT activated on your Wall, against the Wall's
## own prevention pool. CR 616.1 gives the ordering to the affected
## object's controller — the Wall's — even though every point the Monolith
## moves lands on the opponent. The opponent is not asked anything.
func _monolith_on_their_wall(take: int) -> Array[Chooser]:
	var mine := Chooser.new()
	mine.take = take
	var theirs := Chooser.new()
	g.set_agent(0, mine)
	g.set_agent(1, theirs)
	var wall := put_battlefield(0, "Wall of Stone")
	# SETUP, not the path under test: what Jade Monolith's resolution
	# writes onto the creature it targeted (cards/sets/2ed/jade_monolith.gd,
	# MonolithEffect) — a booked one-shot redirect toward its activator.
	wall.damage_redirect_to = 1
	wall.damage_redirects = 1
	wall.prevention = 4
	var bear := put_battlefield(1, "Grizzly Bears")
	g.deal_damage(bear, TargetRef.card(wall), 2)
	return [mine, theirs]


func test_the_creatures_controller_orders_it_and_the_opponent_does_not() -> void:
	var seats := _monolith_on_their_wall(0)
	assert_eq(seats[0].asked.size(), 1, "the Wall's controller was asked")
	assert_eq(seats[1].asked, [],
		"the seat the damage lands on was not (CR 616.1: the object's controller)")


func test_taking_the_monolith_sends_it_to_the_activator() -> void:
	_monolith_on_their_wall(0)
	var wall := g.players[0].battlefield[0]
	assert_eq(g.players[1].life, 18, "they took the blow they signed up for")
	assert_eq(wall.prevention, 4, "the Wall's own pool was never touched")
	assert_eq(wall.damage_redirects, 0, "and the one-shot was spent")


func test_taking_the_pool_leaves_the_monolith_booked() -> void:
	_monolith_on_their_wall(1)
	var wall := g.players[0].battlefield[0]
	assert_eq(g.players[1].life, 20, "nothing reached them")
	assert_eq(wall.prevention, 2, "the pool paid instead")
	assert_eq(wall.damage_redirects, 1,
		"and the Monolith is still booked (CR 616.1 re-applies only to an "
		+ "event that still exists)")


# ================= THE LIFE TOTALS DISAGREE TOO =================

## Personal Incarnation's METERED redirect against a prevention pool on the
## same body. The points move damage onto the owner; the pool prevents it
## outright. The two orders disagree about the owner's life total by
## exactly the size of the packet.
func _incarnation_under_two_meters(take: int) -> Chooser:
	var chooser := Chooser.new()
	chooser.take = take
	g.set_agent(0, chooser)
	var avatar := put_battlefield(0, "Personal Incarnation")
	g.add_point_redirect(avatar, 0, 2)
	avatar.prevention = 2
	var bear := put_battlefield(1, "Grizzly Bears")
	g.deal_damage(bear, TargetRef.card(avatar), 2)
	return chooser


func test_taking_the_points_costs_the_owner_two_life() -> void:
	var chooser := _incarnation_under_two_meters(0)
	var avatar := g.players[0].battlefield[0]
	assert_eq(chooser.asked.size(), 1, "asked once")
	assert_eq(g.players[0].life, 18, "the owner took the two points")
	assert_eq(avatar.damage_point_redirects, 0, "both booked points moved")
	assert_eq(avatar.prevention, 2, "and the pool is untouched")
	assert_eq(avatar.damage, 0)


func test_taking_the_pool_costs_the_owner_nothing() -> void:
	_incarnation_under_two_meters(1)
	var avatar := g.players[0].battlefield[0]
	assert_eq(g.players[0].life, 20,
		"prevented, so there was never a point to move")
	assert_eq(avatar.damage_point_redirects, 2, "both points are still booked")
	assert_eq(avatar.prevention, 0, "the pool paid instead")
	assert_eq(avatar.damage, 0)


# ==================== COMBAT DAMAGE, IN ANGER ====================

## The path the note named: a real combat-damage wave, where this branch
## runs for every creature in every combat. Gaseous Form on a Wall of Stone
## and a Jade Monolith booked on the same Wall both apply to the Craw
## Wurm's six, and they disagree about the Monolith controller's life by
## all six of them.
func _wurm_into_a_gassed_wall(take: int) -> Chooser:
	var chooser := Chooser.new()
	chooser.take = take
	g.set_agent(0, chooser)
	var wall := put_battlefield(0, "Wall of Stone")
	var form := put_battlefield(0, "Gaseous Form")
	form.attached_to = wall.id
	g.recalculate()
	assert_true(wall.cur_prevent_combat_damage_taken, "the Form is on")
	var wurm := put_battlefield(1, "Craw Wurm")
	advance_to_next_turn()          # their turn, so the Wurm can attack
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [wurm.id]))
	resolve_stack()
	# SETUP, and it has to happen on THIS turn: a Jade Monolith they
	# activated on your Wall books a one-shot redirect toward its activator
	# (cards/sets/2ed/jade_monolith.gd), and the booking is cleared at
	# cleanup like every other this-turn shield.
	wall.damage_redirect_to = 1
	wall.damage_redirects = 1
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, {wall.id: wurm.id}))
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	return chooser


func test_combat_damage_takes_the_redirect_by_default() -> void:
	var chooser := _wurm_into_a_gassed_wall(0)
	assert_eq(chooser.asked.size(), 1, "asked once, in the damage wave")
	assert_eq(g.players[1].life, 14, "the Monolith moved all six onto them")


func test_combat_damage_can_take_gaseous_form_instead() -> void:
	_wurm_into_a_gassed_wall(1)
	var wall := g.players[0].battlefield[0]
	assert_eq(g.players[1].life, 20, "the Form prevented it outright")
	assert_eq(wall.damage_redirects, 1, "and the Monolith is still booked")


# ============================== THE NULLS ==============================

## ONE applicable gate is not a choice and nobody is asked — which is
## nearly every shielded creature, and all of the ordinary ones.
func test_one_applicable_gate_asks_nothing() -> void:
	var chooser := Chooser.new()
	g.set_agent(0, chooser)
	var istvan := put_battlefield(0, "Uncle Istvan")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.deal_damage(bear, TargetRef.card(istvan), 2)
	assert_eq(chooser.asked, [], "nobody was asked to order one effect")
	assert_eq(istvan.damage, 0, "and Uncle Istvan still worked")


## And a creature with NOTHING on it never builds a candidate list at all
## — the early-out (MtgGame._has_creature_damage_gates) that keeps the
## combat-damage path the price it was.
func test_an_unshielded_creature_asks_nothing() -> void:
	var chooser := Chooser.new()
	g.set_agent(0, chooser)
	var wall := put_battlefield(0, "Wall of Stone")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.deal_damage(bear, TargetRef.card(wall), 2)
	assert_eq(chooser.asked, [], "nothing applied, nothing was asked")
	assert_eq(wall.damage, 2, "and the damage marked as it always did")


## Whippoorwill's "damage ... can't be prevented or dealt instead to
## another permanent or player" takes every prevention and redirection gate
## off the list — so a Hydra with a pool on it is left with ONE candidate
## (its counters) and is asked nothing. The three gates above the flag are
## unchanged by this pass; docs/duel-todo.md carries the reading that they
## are preventions and redirections too.
func test_whippoorwill_leaves_no_choice_to_make() -> void:
	var chooser := Chooser.new()
	g.set_agent(0, chooser)
	var hydra := put_battlefield(0, "Rock Hydra")
	g.add_counters(hydra, "+1/+1", 3)
	g.recalculate()
	hydra.prevention = 2
	hydra.damage_unpreventable_this_turn = true
	var bear := put_battlefield(1, "Grizzly Bears")
	g.deal_damage(bear, TargetRef.card(hydra), 2)
	assert_eq(chooser.asked, [], "one candidate is not a choice")
	assert_eq(hydra.prevention, 2, "the pool was not a candidate at all")
	assert_eq(int(hydra.counters.get("+1/+1", 0)), 1, "the counters still ate it")


# ======================= THE SURVEY, PINNED =======================
#
# The choice is only worth its prompt while the pool holds cards that can
# contend on this branch. These readings are the survey the build rested
# on, written so that a new card changes a reading rather than a paragraph.

## THE THREE METERED GATES, one writer family each. Rock Hydra is the only
## counter-eater and Personal Incarnation the only point-redirect in the
## 897-card pool; the prevention POOL is the wide one, and it is the gate
## every other can be ordered against.
func test_the_pool_has_one_counter_eater_and_one_point_redirect() -> void:
	assert_eq(_cards_containing("damage_eats_counters"), ["rock_hydra.gd"],
		"a second counter-eater: re-take the CR 616.1 survey")
	assert_eq(_cards_containing("add_point_redirect"),
		["personal_incarnation.gd"],
		"a second metered redirect: re-take the CR 616.1 survey")
	var pools := _cards_containing("PreventDamageEffect")
	assert_eq(pools.size(), 11, "the prevention-pool family: %s" % [pools])


## THE ONE-SHOT AND CONTINUOUS GATES that can meet them on one packet: the
## whole-event redirect (Jade Monolith), the seat-level offer (Blood of the
## Martyr), the replacement on the SOURCE (Reverberation), Uncle Istvan,
## and the two shield families — combat-damage preventions and
## source-filtered immunities.
func test_the_pool_has_the_seven_creature_side_gate_writers() -> void:
	assert_eq(_cards_containing("damage_redirect_sources"),
		["jade_monolith.gd"], "a second whole-event redirect on a creature")
	assert_eq(_cards_containing("may_take_creature_damage"),
		["blood_of_the_martyr.gd"], "a second seat-level damage taker")
	assert_eq(_cards_containing("damage_all_redirect_to"),
		["reverberation.gd"], "a second replacement on the source")
	assert_eq(_cards_containing("cur_prevent_damage_from_creatures"),
		["uncle_istvan.gd"], "a second blanket creature-damage prevention")
	var immunities := _cards_containing("cur_damage_immunity")
	assert_eq(immunities.size(), 12,
		"the source-filtered immunities: %s" % [immunities])
	var combat_shields := _cards_containing("add_until_eot_combat_prevention")
	assert_eq(combat_shields.size(), 9,
		"the floating combat-damage preventions: %s" % [combat_shields])


## Card FILES under cards/sets/ whose source contains [param needle],
## sorted so the reading does not depend on directory order.
func _cards_containing(needle: String) -> Array[String]:
	var hits: Array[String] = []
	for set_dir in DirAccess.get_directories_at("res://cards/sets"):
		var dir_path := "res://cards/sets/%s" % set_dir
		for file in DirAccess.get_files_at(dir_path):
			if not file.ends_with(".gd"):
				continue
			if FileAccess.get_file_as_string("%s/%s" % [dir_path, file]).contains(needle):
				hits.append(file)
	hits.sort()
	return hits
