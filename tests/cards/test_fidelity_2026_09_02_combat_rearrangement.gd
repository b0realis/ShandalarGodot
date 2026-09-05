extends GameTest
## COMBAT RE-ARRANGEMENT, lifted 2026-09-02 (docs/simplified-cards.md row
## "Combat re-arrangement"): the three divisions the engine used to make
## on the players' behalf are now the PLAYERS' choices, put through the
## DecisionAgent funnel with the old engine pick as the hint.
##
## - Raging River: the DEFENDER sorts each non-flyer onto a bank, then the
##   attacking player picks a bank per attacker (`@RAGING_RIVER`,
##   Program/promptsX1.txt: "Select blockers on this bank." / "attack on
##   left bank." / "attack on right bank.").
## - Camouflage: the defender builds the piles (any number of creatures,
##   one pile per attacker), the piles are dealt to the attackers at
##   random, and a pile member that can block its attacker does so. Asked
##   at declare-blockers time through the turn-based hold, so a human
##   seat answers pile by pile.
## - False Orders: "an attacking creature of your choice" — the caster
##   picks the attacker, or declines ("you may").


## Answers an OPTION question whose prompt contains a scripted key with
## the option whose label contains the scripted value; anything else
## follows the hint.
class LabelSeat extends DecisionAgent:
	var plan: Dictionary = {}

	func answer_option(_game: MtgGame, _pid: int, prompt: String,
			options: Array[String], hint: int) -> int:
		for key in plan:
			if not prompt.contains(String(key)):
				continue
			var want := String(plan[key])
			for i in options.size():
				if options[i].contains(want):
					return i
		return hint


func _last_option_for(pid: int, source: String) -> PlayerChoice:
	for i in range(g.choice_log.size() - 1, -1, -1):
		var c: PlayerChoice = g.choice_log[i]
		if c.pid == pid and c.kind == PlayerChoice.Kind.OPTION \
				and String(c.source) == source:
			return c
	return null


# ------------------------------------------------------------ Raging River --

func test_raging_river_defender_chooses_the_banks() -> void:
	var river := put_battlefield(0, "Raging River")
	var attacker := put_battlefield(0, "Hill Giant")
	var one := put_battlefield(1, "Grizzly Bears")
	var two := put_battlefield(1, "Mons's Goblin Raiders")
	var defender := LabelSeat.new()
	defender.plan = {"Grizzly Bears": "right", "Goblin Raiders": "right"}
	g.set_agent(1, defender)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	var left: Array = river.memory.get("left", [])
	var right: Array = river.memory.get("right", [])
	assert_eq(left, [], "the defender put nobody on the left bank")
	assert_eq(right.size(), 2, "both on the right")
	# The attacker follows the hint — the smaller (empty) bank — so nobody
	# may block it.
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {one.id: attacker.id}), "can't be blocked except by")
	assert_refused(g.declare_blockers(1, {two.id: attacker.id}), "can't be blocked except by")


func test_raging_river_attacker_chooses_a_bank() -> void:
	var river := put_battlefield(0, "Raging River")
	var attacker := put_battlefield(0, "Hill Giant")
	var one := put_battlefield(1, "Grizzly Bears")
	var two := put_battlefield(1, "Mons's Goblin Raiders")
	var general := LabelSeat.new()
	general.plan = {"Hill Giant": "right bank"}
	g.set_agent(0, general)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	# The defender's default split alternates: Bears left, Raiders right.
	var left: Array = river.memory.get("left", [])
	var right: Array = river.memory.get("right", [])
	assert_eq(left, [one.id])
	assert_eq(right, [two.id])
	assert_eq(String(river.memory["labels"][attacker.id]), "right",
		"the attacking player chose the right bank, not the engine's 'smaller pile'")
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {one.id: attacker.id}), "can't be blocked except by")
	assert_ok(g.declare_blockers(1, {two.id: attacker.id}))


func test_raging_river_asks_in_the_1997_words() -> void:
	put_battlefield(0, "Raging River")
	var attacker := put_battlefield(0, "Hill Giant")
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	var bank := _last_option_for(1, "Raging River")
	assert_not_null(bank, "the defender was asked")
	assert_eq(bank.options, ["left bank", "right bank"])
	var side := _last_option_for(0, "Raging River")
	assert_not_null(side, "the attacking player was asked")
	assert_eq(side.options, ["attack on left bank.", "attack on right bank."],
		"`@RAGING_RIVER` entries 2 and 3")
	assert_true(side.prompt.contains("Hill Giant"))


func test_raging_river_flyers_are_never_sorted() -> void:
	var river := put_battlefield(0, "Raging River")
	var attacker := put_battlefield(0, "Hill Giant")
	var flyer := put_battlefield(1, "Wall of Air")
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	var left: Array = river.memory.get("left", [])
	var right: Array = river.memory.get("right", [])
	assert_false(left.has(flyer.id) or right.has(flyer.id),
		"creatures with flying are on neither bank")
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {flyer.id: attacker.id}))   # and may block either side


# -------------------------------------------------------------- Camouflage --

func test_camouflage_defender_builds_the_piles() -> void:
	var giant := put_battlefield(0, "Hill Giant")            # 3/3
	var bears := put_battlefield(0, "Grizzly Bears")         # 2/2
	var wall := put_battlefield(1, "Wall of Stone")          # 0/8
	var raiders := put_battlefield(1, "Mons's Goblin Raiders")   # 1/1
	var camo := give_hand(0, "Camouflage")
	var defender := LabelSeat.new()
	defender.plan = {"Wall of Stone": "Pile 1", "Goblin Raiders": "No pile"}
	g.set_agent(1, defender)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id, bears.id]))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, camo, []))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	assert_eq(g.combat.blocks.size(), 1, "only the Wall was put in a pile")
	assert_true(g.combat.blocks.has(wall.id), "the Wall blocks whichever attacker its pile drew")
	assert_false(g.combat.blocks.has(raiders.id), "the Raiders stayed out of the piles")


func test_camouflage_a_pile_member_that_cannot_block_its_attacker_stays_home() -> void:
	var flyer := put_battlefield(0, "Phantom Monster")       # 3/3 flying
	var giant := put_battlefield(0, "Hill Giant")
	var bears := put_battlefield(1, "Grizzly Bears")
	var camo := give_hand(0, "Camouflage")
	var defender := LabelSeat.new()
	defender.plan = {"Grizzly Bears": "Pile 1"}
	g.set_agent(1, defender)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [flyer.id, giant.id]))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, camo, []))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	assert_false(g.combat.blockers_of(flyer.id).has(bears.id),
		"a pile dealt to the flyer blocks nothing: the Bears can't block it")
	if g.combat.blocks.has(bears.id):
		assert_eq(int(g.combat.blocks[bears.id]), giant.id)


func test_camouflage_offers_one_pile_per_attacker() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var bears := put_battlefield(0, "Grizzly Bears")
	var raiders := put_battlefield(0, "Mons's Goblin Raiders")
	put_battlefield(1, "Wall of Stone")
	var camo := give_hand(0, "Camouflage")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id, bears.id, raiders.id]))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, camo, []))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	var asked := _last_option_for(1, "Camouflage")
	assert_not_null(asked, "the defender was asked")
	assert_eq(asked.options, ["No pile", "Pile 1", "Pile 2", "Pile 3"],
		"a number of piles equal to the number of attacking creatures")
	assert_true(asked.prompt.contains("Wall of Stone"))


func test_camouflage_holds_for_a_seat_that_wants_asking() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var wall := put_battlefield(1, "Wall of Stone")
	var camo := give_hand(0, "Camouflage")
	var human := HumanAgent.new()
	g.agents[1] = human
	g.interactive_choices = true
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, camo, []))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	assert_not_null(g.awaiting_choice, "held on the Wall's pile question")
	assert_eq(String(g.awaiting_choice.source), "Camouflage")
	assert_true(g.awaiting_blockers, "nothing was declared yet")
	assert_ok(g.answer_choice(1))          # Pile 1
	assert_null(g.awaiting_choice)
	assert_false(g.awaiting_blockers, "the replay declared the blocks")
	assert_eq(g.combat.blocks.get(wall.id, -1), giant.id)


# ------------------------------------------------------------ False Orders --

func _orders_setup() -> Dictionary:
	var big := put_battlefield(0, "Hill Giant")                 # 3/3
	var small := put_battlefield(0, "Mons's Goblin Raiders")     # 1/1
	var blocker := put_battlefield(1, "Grizzly Bears")          # 2/2
	var orders := give_hand(0, "False Orders")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [big.id, small.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {blocker.id: big.id}))
	add_mana(0, Mtg.ManaColor.R)
	return {"big": big, "small": small, "blocker": blocker, "orders": orders}


func test_false_orders_lets_the_caster_pick_the_attacker() -> void:
	var s := _orders_setup()
	var caster := LabelSeat.new()
	caster.plan = {"new creature to block": "Hill Giant"}
	g.set_agent(0, caster)
	assert_ok(g.cast_spell(0, s["orders"], [TargetRef.card(s["blocker"])]))
	resolve_stack()
	assert_eq(g.combat.blocks.get(s["blocker"].id, -1), s["big"].id,
		"'an attacking creature of your choice' — the Giant, not the engine's smallest")
	assert_eq(g.combat.blockers_of(s["small"].id).size(), 0)


func test_false_orders_may_decline_the_new_block() -> void:
	var s := _orders_setup()
	var caster := LabelSeat.new()
	caster.plan = {"new creature to block": "Don't block"}
	g.set_agent(0, caster)
	assert_ok(g.cast_spell(0, s["orders"], [TargetRef.card(s["blocker"])]))
	resolve_stack()
	assert_false(g.combat.blocks.has(s["blocker"].id), "'you MAY have it block'")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 16, "both attackers connect: 3 + 1")


func test_false_orders_hint_is_the_smallest_unblocked_attacker() -> void:
	var s := _orders_setup()
	assert_ok(g.cast_spell(0, s["orders"], [TargetRef.card(s["blocker"])]))
	resolve_stack()
	var asked := _last_option_for(0, "False Orders")
	assert_not_null(asked, "the caster was asked")
	assert_eq(asked.options, ["Hill Giant", "Mons's Goblin Raiders", "Don't block"])
	assert_eq(int(asked.hint), 1, "the old engine pick is the hint")
	assert_eq(g.combat.blocks.get(s["blocker"].id, -1), s["small"].id,
		"the default seat follows it")
