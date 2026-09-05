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
## is. The announced order with "lethal to each before the next" arrived in
## Sixth Edition (CR 509.2/510.1c) and is our default.
## RulesOptions.free_damage_assignment switches between them.


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


func test_the_default_spread_is_still_lethal_first_in_order() -> void:
	var cast := _gang_block()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(cast[1].zone, Mtg.Zone.GRAVEYARD, "the first blocker takes lethal")
	assert_eq(cast[2].zone, Mtg.Zone.BATTLEFIELD, "the second takes the remainder")
	assert_eq(cast[2].damage, 1)


func test_the_attacker_chooses_which_blocker_dies() -> void:
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


func test_modern_rules_enforce_lethal_before_the_next_blocker() -> void:
	g.agents[0] = PromptAgent.new()
	var cast := _gang_block()
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_refused(g.assign_combat_damage(0, {cast[1].id: 1, cast[2].id: 2}),
		"lethal")
	assert_ok(g.assign_combat_damage(0, {cast[1].id: 2, cast[2].id: 1}))


func test_the_1997_fork_lets_the_attacker_split_freely() -> void:
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
