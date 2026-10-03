extends GameTest
## §1.4 / §6.9 of docs/duel-todo.md — THE ATTACKER ASSIGNS COMBAT DAMAGE.
##
## `@PROMPT_RESOLVECOMBAT` (Program/UIStrings.txt:999) is the 1997 loop,
## verbatim: `%s: Assign damage to blockers, %d points left` /
## `%s: Assign trample damage to blockers, %d points left` /
## `Assign %d damage` / `Assign %d trample damage`, plus the mirror pass
## `%s: Assign damage to attackers, %d points left`. The engine used to
## spread damage lethal-first in block-declaration order and never ask.
##
## THE FORK: the 1997 game ran Fifth Edition rules, which had NO damage
## assignment order — the attacker divided the damage among the blockers
## however they liked, which is exactly what a `%d points left` click loop
## is. The announced order with "lethal to each before the next" came with
## Magic 2010 (CR 509.2/510.1c) and left with Foundations (2024), so free
## division is the default again (owner's playtest, 2026-09-18) and
## RulesOptions.free_damage_assignment = false is the 2009-2024 order.


## A seat that puts one chosen blocker first in the order and hands it the
## whole packet — the two halves CR 509.2 and 510.1c give the attacker.
class PickyAgent extends DecisionAgent:
	var favourite := -1

	func order_blockers(_game: MtgGame, _attacker: CardInstance,
			blocker_ids: Array) -> Array:
		if not blocker_ids.has(favourite):
			return blocker_ids
		var out: Array = [favourite]
		for id in blocker_ids:
			if id != favourite:
				out.append(id)
		return out

	func assign_combat_damage(_game: MtgGame, _source: CardInstance,
			targets: Array, amount: int, _trample: bool,
			_already: Dictionary, _free_order := false) -> Dictionary:
		if targets.has(favourite):
			return {favourite: amount}
		return {}


## A seat that reverses the damage assignment order (CR 509.2).
class ReversingAgent extends DecisionAgent:
	func order_blockers(_game: MtgGame, _attacker: CardInstance,
			blocker_ids: Array) -> Array:
		var out := blocker_ids.duplicate()
		out.reverse()
		return out


## A seat that wants the prompt — what HumanAgent does.
class PromptAgent extends DecisionAgent:
	func wants_to_assign_combat_damage() -> bool:
		return true


func _gang_block(attacker_name := "Hill Giant") -> Array:
	var attacker := put_battlefield(0, attacker_name)
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {a.id: attacker.id, b.id: attacker.id}))
	return [attacker, a, b]


func test_free_division_is_the_default_and_both_editions_agree() -> void:
	# The owner's playtest (2026-09-18): blocked by two, they could only
	# put damage on the first blocker. The 2009-2024 order was the modern
	# default; Foundations (2024) dropped it, so a fresh engine, the
	# modern preset and the 1997 preset all divide freely.
	assert_true(RulesOptions.new().free_damage_assignment, "a fresh engine")
	for edition in ["modern", "fifth"]:
		var rules := RulesOptions.new()
		rules.set_edition(edition)
		assert_true(rules.free_damage_assignment, edition)
		assert_eq(rules.preset(), edition, "the shared answer keeps the preset readable")
	var rules := RulesOptions.new()
	rules.set_edition("modern")
	rules.free_damage_assignment = false
	assert_eq(rules.preset(), "custom", "the 2009-2024 order is a custom choice")
	g.agents[0] = PromptAgent.new()
	var cast := _gang_block()
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_eq(g.assign_combat_damage(0, {cast[1].id: 1, cast[2].id: 2}), "",
		"the second blocker may take the points first")
	assert_eq(cast[1].damage, 1)
	assert_eq(cast[2].zone, Mtg.Zone.GRAVEYARD)


func test_the_default_spread_is_still_lethal_first_in_order() -> void:
	var cast := _gang_block()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(cast[1].zone, Mtg.Zone.GRAVEYARD, "the first blocker takes lethal")
	assert_eq(cast[2].zone, Mtg.Zone.BATTLEFIELD, "the second takes the remainder")
	assert_eq(cast[2].damage, 1)


func test_the_attacker_chooses_which_blocker_dies() -> void:
	g.rules.free_damage_assignment = false     # the 2009-2024 order
	var picky := PickyAgent.new()
	g.agents[0] = picky
	var giant := put_battlefield(0, "Hill Giant")
	var first := put_battlefield(1, "Grizzly Bears")
	var second := put_battlefield(1, "Grizzly Bears")
	picky.favourite = second.id        # the SECOND blocker, not the first
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {first.id: giant.id, second.id: giant.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(first.zone, Mtg.Zone.BATTLEFIELD, "the first blocker was spared")
	assert_eq(second.zone, Mtg.Zone.GRAVEYARD, "the attacker picked the second")


func test_the_declaration_order_can_be_reordered() -> void:
	g.rules.free_damage_assignment = false     # the 2009-2024 order
	g.agents[0] = ReversingAgent.new()
	var cast := _gang_block()
	assert_eq(g.combat.ordered_blockers_of_band([cast[0].id]),
		[cast[2].id, cast[1].id] as Array[int])
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(cast[2].zone, Mtg.Zone.GRAVEYARD, "the reordered first takes lethal")
	assert_eq(cast[1].zone, Mtg.Zone.BATTLEFIELD)


func test_an_interactive_seat_is_asked_and_the_step_waits() -> void:
	g.agents[0] = PromptAgent.new()
	var cast := _gang_block()
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_assignment, "the damage step waits for the split")
	var req := g.damage_assignment_request()
	assert_eq(req["source"], cast[0])
	assert_eq(int(req["amount"]), 3)
	assert_eq(int(req["assigner"]), 0)
	assert_eq(req["targets"].size(), 2)
	assert_eq(cast[1].damage, 0, "nothing is dealt until the split arrives")
	# Nothing else may happen while it waits.
	assert_refused(g.pass_priority(0), "damage")
	assert_ok(g.assign_combat_damage(0, {cast[1].id: 2, cast[2].id: 1}))
	assert_false(g.awaiting_damage_assignment)
	assert_eq(cast[1].zone, Mtg.Zone.GRAVEYARD)
	assert_eq(cast[2].damage, 1)


## Bug pass 2026-10-03: the gang block of [method _gang_block] plus an
## unblocked Grizzly Bears beside the giant and an Ashnod's Altar.
func _held_step_with_an_unblocked_bear() -> Array:
	g.agents[0] = PromptAgent.new()
	var bear := put_battlefield(0, "Grizzly Bears")
	var altar := put_battlefield(0, "Ashnod's Altar")
	var giant := put_battlefield(0, "Hill Giant")
	var a := put_battlefield(1, "Savannah Lions")
	var b := put_battlefield(1, "Savannah Lions")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id, giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {a.id: giant.id, b.id: giant.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_assignment)
	return [bear, altar, giant, a, b]


func test_no_mana_ability_while_the_damage_split_is_held() -> void:
	# Nobody has priority and no cost is being paid while the step waits
	# for a division (CR 605.3a), so Ashnod's Altar cannot eat the unblocked
	# attacker mid-step — it used to, and the dead Bears still dealt 2.
	var cast := _held_step_with_an_unblocked_bear()
	assert_refused(g.tap_for_mana(0, cast[1], 0), "damage")
	assert_eq(cast[0].zone, Mtg.Zone.BATTLEFIELD)


func test_a_creature_gone_while_the_split_is_held_deals_no_damage() -> void:
	# The requests are planned when the step begins; a source that has left
	# the battlefield (or combat) by the time they land deals nothing
	# (CR 510.1, 506.4). Removed here by hand, standing in for any path
	# that can still reach it.
	var cast := _held_step_with_an_unblocked_bear()
	g.sacrifice_permanent(cast[0])
	assert_ok(g.assign_combat_damage(0, {cast[3].id: 1, cast[4].id: 2}))
	assert_eq(g.players[1].life, 20, "the sacrificed Bears hit nobody")
	assert_eq(cast[3].zone, Mtg.Zone.GRAVEYARD, "the giant's split still landed")


func test_every_point_must_be_assigned() -> void:
	g.agents[0] = PromptAgent.new()
	var cast := _gang_block()
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_refused(g.assign_combat_damage(0, {cast[1].id: 2}), "points left")
	assert_refused(g.assign_combat_damage(0, {cast[1].id: 4}), "only 3")
	assert_refused(g.assign_combat_damage(0, {cast[1].id: 2, 999: 1}),
		"not blocking")
	assert_refused(g.assign_combat_damage(1, {cast[1].id: 3}), "yours to assign")
	assert_true(g.awaiting_damage_assignment, "a refusal leaves the split open")


func test_the_2009_order_enforces_lethal_before_the_next_blocker() -> void:
	g.rules.free_damage_assignment = false
	g.agents[0] = PromptAgent.new()
	var cast := _gang_block()
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_refused(g.assign_combat_damage(0, {cast[1].id: 1, cast[2].id: 2}),
		"lethal")
	assert_ok(g.assign_combat_damage(0, {cast[1].id: 2, cast[2].id: 1}))


func test_overkill_must_be_assigned_even_after_all_blockers_have_lethal() -> void:
	for edition in ["modern", "fifth"]:
		before_each()
		g.rules.set_edition(edition)
		g.agents[0] = PromptAgent.new()
		var cast := _gang_block("Craw Wurm")
		advance_to_step(Mtg.Step.COMBAT_DAMAGE)
		assert_refused(g.assign_combat_damage(0, {cast[1].id: 2, cast[2].id: 2}), "points left")
		assert_true(g.awaiting_damage_assignment, edition)
		assert_ok(g.assign_combat_damage(0, {cast[1].id: 2, cast[2].id: 4}))


func test_the_1997_rule_lets_the_attacker_split_freely() -> void:
	g.rules.free_damage_assignment = true
	g.agents[0] = PromptAgent.new()
	var cast := _gang_block()
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	# Fifth Edition had no assignment order: 1 and 2 is a legal division
	# even though neither blocker is dealt lethal in order.
	assert_ok(g.assign_combat_damage(0, {cast[1].id: 1, cast[2].id: 2}))
	assert_eq(cast[1].damage, 1)
	assert_eq(cast[2].zone, Mtg.Zone.GRAVEYARD)


func test_trample_may_only_spill_once_every_blocker_has_lethal() -> void:
	g.agents[0] = PromptAgent.new()
	var mammoth := put_battlefield(0, "War Mammoth")   # 3/3 trample
	var wall := put_battlefield(1, "Grizzly Bears")    # 2/2
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [mammoth.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: mammoth.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_assignment, "trample is a choice too")
	assert_refused(g.assign_combat_damage(0,
		{wall.id: 1, MtgGame.DAMAGE_TO_PLAYER: 2}), "lethal")
	assert_ok(g.assign_combat_damage(0,
		{wall.id: 2, MtgGame.DAMAGE_TO_PLAYER: 1}))
	assert_eq(g.players[1].life, 19)
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD)


func test_a_lone_blocker_is_never_asked() -> void:
	g.agents[0] = PromptAgent.new()
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {bear.id: giant.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_false(g.awaiting_damage_assignment, "one blocker, no division to make")
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


# ---------------------------------------------------- DEFENSIVE BANDING --
#
# CR 702.22f-h: if any creature blocking an attacker has banding, the
# DEFENDING player — not the attacking one — divides that attacker's combat
# damage among its blockers, and divides it FREELY: the lethal-first order
# of CR 510.1c does not apply. It was the missing half of banding, tracked
# in docs/ROADMAP.md until this section.

func test_a_banding_blocker_hands_the_division_to_the_defender() -> void:
	# Benalish Hero (1/1, banding) and Grizzly Bears (2/2) both block a
	# Craw Wurm (6/4). Lethal-first would kill BOTH — 1 to the Hero, 2 to
	# the Bears, three points spare. With the division in the defender's
	# hands the whole six goes onto one body, and only that one dies; the
	# engine's default answer for a defender feeds it the cheaper body.
	var wurm := put_battlefield(0, "Craw Wurm")
	var hero := put_battlefield(1, "Benalish Hero")
	var bears := put_battlefield(1, "Grizzly Bears")
	assert_true(hero.has_keyword(Mtg.Keyword.BANDING))
	run_combat([wurm.id], {hero.id: wurm.id, bears.id: wurm.id})
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD,
		"the better body walked away — lethal-first would have buried it")
	assert_eq(hero.zone, Mtg.Zone.GRAVEYARD, "one blocker, not two")


func test_without_banding_the_attacker_still_kills_both() -> void:
	# The control: two ordinary blockers, lethal-first, both die.
	var wurm := put_battlefield(0, "Craw Wurm")     # 6/4
	var giant := put_battlefield(1, "Hill Giant")   # 3/3
	var bears := put_battlefield(1, "Grizzly Bears")
	run_combat([wurm.id], {giant.id: wurm.id, bears.id: wurm.id})
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)


func test_a_banding_blocker_denies_a_trampler_its_spill() -> void:
	# Trample only reaches the player once EVERY blocker has lethal
	# (CR 702.19b). With the division in the defender's hands, they simply
	# never assign that lethal — so nothing tramples through.
	var wurm := put_battlefield(0, "Craw Wurm")
	wurm.added_keywords.append(Mtg.Keyword.TRAMPLE)
	g.recalculate()
	var hero := put_battlefield(1, "Benalish Hero")
	var bears := put_battlefield(1, "Grizzly Bears")
	run_combat([wurm.id], {hero.id: wurm.id, bears.id: wurm.id})
	assert_eq(g.players[1].life, 20, "the defender kept every point on a body")
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)


# ---------------------------------------------------- OFFENSIVE BANDING --
#
# CR 702.22j, first sentence (Fifth Edition: "the attacking player divides
# the damage from blocking creatures among the band"): when a creature
# blocks an attacking band, the ATTACKING player — not the blocker's
# controller — divides that blocker's combat damage among the band's
# members, freely. The 1997 game's `%s: Assign damage to attackers, %d
# points left` pass (Program/UIStrings.txt:1007). Found in a referee game
# on 2026-10-03: an Air Elemental blocking a White Knight + Pikemen band
# was let kill both, when four points divided by the attacker keep the
# Knight. Until 0.50.4 combat.gd called the lethal-first spread an
# approximation of this rule; it was the opposite seat's choice.

func test_a_blocked_band_hands_the_blocker_s_division_to_the_attacker() -> void:
	# Benalish Hero (1/1, banding) and Grizzly Bears (2/2) attack as a
	# band; Hill Giant (3/3) blocks the Bears. Its three points reach the
	# whole band. Lethal-first in band order would kill BOTH (1 + 2); the
	# engine's answer for the attacker feeds the cheaper body the lot.
	var hero := put_battlefield(0, "Benalish Hero")
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [hero.id, bears.id], [[hero.id, bears.id]]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {giant.id: bears.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(hero.zone, Mtg.Zone.GRAVEYARD, "the lamb")
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD,
		"the better body walked away — lethal-first would have buried it")
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "the band's pooled 1 + 2 still lands")


func test_the_attacker_can_answer_the_blocker_s_division_themselves() -> void:
	# The choice is the attacking seat's and it is real: an attacker that
	# would rather lose the Bears and keep the Hero gets exactly that.
	var hero := put_battlefield(0, "Benalish Hero")
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var picky := PickyAgent.new()
	picky.favourite = bears.id     # the OPPOSITE of the engine's default
	g.agents[0] = picky
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [hero.id, bears.id], [[hero.id, bears.id]]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {giant.id: bears.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "the attacker's own answer")
	assert_eq(hero.zone, Mtg.Zone.BATTLEFIELD)


func test_the_blocker_s_controller_is_not_asked_for_a_band_s_division() -> void:
	# An interactive DEFENDER is never prompted for it, and an answer from
	# that seat is refused; the interactive ATTACKER is the one the step
	# waits on, with the blocker as the request's source and the band as
	# its targets, free of the lethal-first order.
	g.agents[0] = PromptAgent.new()
	g.agents[1] = PromptAgent.new()
	var hero := put_battlefield(0, "Benalish Hero")
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [hero.id, bears.id], [[hero.id, bears.id]]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {giant.id: bears.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_assignment, "the step waits")
	var request := g.damage_assignment_request()
	assert_eq(int(request.assigner), 0, "the attacking player's division")
	assert_eq((request.source as CardInstance).id, giant.id, "the blocker's damage")
	assert_true(bool(request.free_order), "no lethal-first order")
	assert_eq(request.targets, [hero.id, bears.id] as Array, "the whole band")
	assert_eq(g.log_lines[g.log_lines.size() - 1], "Hill Giant: Assign damage to attackers, 3 points left",
		"the 1997 banding pass, entry 7 of @PROMPT_RESOLVECOMBAT")
	assert_refused(g.assign_combat_damage(1, {hero.id: 3}), "not yours")
	assert_eq(g.assign_combat_damage(0, {bears.id: 1, hero.id: 2}), "",
		"any division totalling the amount is legal")
	assert_false(g.awaiting_damage_assignment)
	assert_eq(hero.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bears.damage, 1)
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)


func test_a_lone_attacker_s_blocker_damage_is_still_the_defender_s() -> void:
	# The control: no band, one blocked attacker — the blocker's damage is
	# a single packet with nothing to divide, and nobody is asked.
	g.agents[0] = PromptAgent.new()
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bears.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {giant.id: bears.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_false(g.awaiting_damage_assignment)
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)


func test_the_defender_can_answer_the_division_themselves() -> void:
	# The choice is real, not a fixed heuristic: an agent that would rather
	# lose the Bears and keep the Hero gets exactly that.
	var wurm := put_battlefield(0, "Craw Wurm")
	var hero := put_battlefield(1, "Benalish Hero")
	var bears := put_battlefield(1, "Grizzly Bears")
	var picky := PickyAgent.new()
	picky.favourite = bears.id     # the OPPOSITE of the engine's default
	g.agents[1] = picky
	run_combat([wurm.id], {hero.id: wurm.id, bears.id: wurm.id})
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "the defender's own answer")
	assert_eq(hero.zone, Mtg.Zone.BATTLEFIELD)
