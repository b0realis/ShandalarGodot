extends GameTest
## BERSERK IS REMOVAL ON THEIR ATTACKER (2026-09-27). The owner, on the
## finisher's *"never on the opponent's attacker"*: *"beserk can be
## removal in certain cases!"* It can: *"destroy that creature if it
## attacked this turn"* is a destroy at the end step, and an attacker of
## theirs has attacked. The price is what the doubling and the trample it
## grants land on us and on our blockers first — so
## [method AiPlayer._berserk_their_attacker] prices each attacker with
## the blocks in: its worth, less the blockers of ours the doubling newly
## kills, less the extra damage at the reaper's rate (a third of a life
## point above ten, the whole point below); the best is taken when the
## margin is worth the card (four), never when the doubled swing would
## leave us under seven, never on a body that dies in the combat anyway,
## that they can regenerate, that is already doomed, or that bands.
##
## The seat under test is P0 (the Wizard); P1 attacks on its own turn.
## Every test acts through AiPlayer.act / the public MtgGame API; the
## blocks are declared by the test so the reading is the one under test.


func _wizard(seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, AiProfile.wizard())
	g.set_agent(seat, ai)
	return ai


## Their [param attacker] attacks us at [param our_life]; our [param
## blockers] (by name, all of them on the attacker) block; the Wizard,
## holding [param berserks] Berserks with two Forests open, acts through
## their whole combat. Returns `{acts, attacker, blockers, berserks}` at
## their second main phase.
func _their_attack(ai: AiPlayer, attacker: String, our_life: int,
		blockers: Array = [], berserks := 1) -> Dictionary:
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	var held: Array = []
	for _i in berserks:
		held.append(give_hand(0, "Berserk"))
	var bodies: Array = []
	for name in blockers:
		bodies.append(put_battlefield(0, name))
	var theirs := put_battlefield(1, attacker)
	g.players[0].life = our_life
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [theirs.id]))
	var blocks := {}
	for body in bodies:
		blocks[body.id] = theirs.id
	var acts: Array = []
	var guard := 0
	while g.current_step() != Mtg.Step.MAIN2 and not g.game_over and guard < 30:
		if g.awaiting_blockers:
			assert_ok(g.declare_blockers(0, blocks))
		elif g.priority_player == 0:
			var a := ai.act(g)
			if a != "pass" and a != "":
				acts.append(a)
		else:
			assert_ok(g.pass_priority(1))
		guard += 1
	assert_lt(guard, 30, "their combat ran to the second main phase")
	return {"acts": acts, "attacker": theirs, "blockers": bodies, "berserks": held}


## Their end step: the doom falls (or does not) as the step begins.
func _to_their_end_step() -> void:
	advance_to_step(Mtg.Step.END)
	resolve_stack()


# --------------------------------------------------------- the owner's ear --

func test_the_giant_unblocked_at_twenty_is_berserked_and_dies() -> void:
	# Six from a Hill Giant instead of three, at twenty life, for the
	# Giant: worth 6, price 3 × 0.34 — the honest trade.
	var ai := _wizard()
	var r := _their_attack(ai, "Hill Giant", 20)
	assert_eq(r["acts"], ["responded with Berserk"])
	assert_eq(g.players[0].life, 14, "the doubled Giant landed six")
	assert_eq(r["attacker"].zone, Mtg.Zone.BATTLEFIELD, "alive through the combat")
	_to_their_end_step()
	assert_eq(r["attacker"].zone, Mtg.Zone.GRAVEYARD, "destroyed at the end step")


func test_the_classic_the_giant_held_by_a_wall() -> void:
	# Hill Giant into Wall of Stone (0/8): doubled to six it still does
	# not get through, nothing tramples over, the Wall lives — and the
	# Giant dies for one green mana.
	var ai := _wizard()
	var r := _their_attack(ai, "Hill Giant", 20, ["Wall of Stone"])
	assert_eq(r["acts"], ["responded with Berserk"])
	assert_eq(g.players[0].life, 20, "nothing came through the Wall")
	var wall: CardInstance = r["blockers"][0]
	assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD, "the Wall stands")
	assert_eq(wall.damage, 6, "with the doubled Giant's six on it")
	_to_their_end_step()
	assert_eq(r["attacker"].zone, Mtg.Zone.GRAVEYARD)


func test_through_a_chump_the_trample_is_priced() -> void:
	# Fire Elemental (5/4) into our Grizzly Bears: the Bears die either
	# way; doubled and trampling, the Elemental lands eight on us past
	# them (CR 702.19b — the engine's own division). Eight at 0.34 is
	# 2.72 against a body worth nine: taken, at twenty.
	var ai := _wizard()
	var r := _their_attack(ai, "Fire Elemental", 20, ["Grizzly Bears"])
	assert_eq(r["acts"], ["responded with Berserk"])
	assert_eq(g.players[0].life, 12, "eight trampled over the Bears")
	assert_eq(r["blockers"][0].zone, Mtg.Zone.GRAVEYARD, "the Bears died as they would have")
	_to_their_end_step()
	assert_eq(r["attacker"].zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------------------- the holds --

func test_holds_it_when_the_life_is_dear() -> void:
	# At twelve, the doubled Giant would leave us at six — under the
	# floor of seven. Three from the Giant, Berserk kept.
	var ai := _wizard()
	var r := _their_attack(ai, "Hill Giant", 12)
	assert_eq(r["acts"], [])
	assert_eq(g.players[0].life, 9)
	assert_eq(r["berserks"][0].zone, Mtg.Zone.HAND)
	_to_their_end_step()
	assert_eq(r["attacker"].zone, Mtg.Zone.BATTLEFIELD)


func test_holds_it_at_thirteen_where_every_point_is_whole() -> void:
	# At thirteen the swing leaves seven — on the floor, but every extra
	# point is priced whole below ten: worth 6 less 3 is 3, under the bar.
	var ai := _wizard()
	var r := _their_attack(ai, "Hill Giant", 13)
	assert_eq(r["acts"], [])
	assert_eq(g.players[0].life, 10)


func test_never_at_a_bear() -> void:
	# Grizzly Bears unblocked at twenty: worth 4 less two points at 0.34
	# is 3.32 — a card for a Bear is not the trade.
	var ai := _wizard()
	var r := _their_attack(ai, "Grizzly Bears", 20)
	assert_eq(r["acts"], [])
	assert_eq(g.players[0].life, 18)
	assert_eq(r["berserks"][0].zone, Mtg.Zone.HAND)


func test_holds_it_when_the_doubling_would_kill_our_wall() -> void:
	# Grizzly Bears into Wall of Wood (0/3): at two the Wall lives; at
	# four it dies and one tramples over. The Wall (worth 2) and the
	# point come off the Bears' 4 — nothing left for the card.
	var ai := _wizard()
	var r := _their_attack(ai, "Grizzly Bears", 20, ["Wall of Wood"])
	assert_eq(r["acts"], [])
	assert_eq(g.players[0].life, 20)
	assert_eq(r["blockers"][0].zone, Mtg.Zone.BATTLEFIELD, "the Wall stands")
	assert_eq(r["blockers"][0].damage, 2)


func test_holds_it_when_the_attacker_dies_anyway() -> void:
	# Hill Giant into our Hill Giant: it dies in the combat. No doom
	# needed, no Berserk spent.
	var ai := _wizard()
	var r := _their_attack(ai, "Hill Giant", 20, ["Hill Giant"])
	assert_eq(r["acts"], [])
	assert_eq(r["attacker"].zone, Mtg.Zone.GRAVEYARD, "dead in the combat")
	assert_eq(r["berserks"][0].zone, Mtg.Zone.HAND)


func test_holds_it_when_they_can_regenerate() -> void:
	# The doom is a destroy; a Giant with a regeneration shield up
	# shrugs it off. Not worth six life and a card.
	var ai := _wizard()
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	var berserk := give_hand(0, "Berserk")
	var theirs := put_battlefield(1, "Hill Giant")
	advance_to_next_turn()
	theirs.regeneration_shields = 1   # after the cleanup that wipes shields
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [theirs.id]))
	var acts: Array = []
	var guard := 0
	while g.current_step() != Mtg.Step.MAIN2 and not g.game_over and guard < 30:
		if g.awaiting_blockers:
			assert_ok(g.declare_blockers(0, {}))
		elif g.priority_player == 0:
			var a := ai.act(g)
			if a != "pass" and a != "":
				acts.append(a)
		else:
			assert_ok(g.pass_priority(1))
		guard += 1
	assert_eq(acts, [])
	assert_eq(berserk.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].life, 17)


func test_never_a_second_time() -> void:
	# Two Berserks, one Giant: the first dooms it; the second reads the
	# doom already on it and stays in hand — twelve from a Giant for
	# nothing more is no trade.
	var ai := _wizard()
	var r := _their_attack(ai, "Hill Giant", 20, [], 2)
	assert_eq(r["acts"], ["responded with Berserk"])
	assert_eq(g.players[0].life, 14, "six, not twelve")
	var in_hand := 0
	for b in r["berserks"]:
		if b.zone == Mtg.Zone.HAND:
			in_hand += 1
	assert_eq(in_hand, 1, "the second Berserk is held")
	assert_true(g.is_doomed_at_end_step(r["attacker"]))
	_to_their_end_step()
	assert_eq(r["attacker"].zone, Mtg.Zone.GRAVEYARD)


func test_the_finisher_still_fires_on_our_own_attack() -> void:
	# The removal did not take the finisher's place: our Hill Giant
	# unblocked at their six is still the kill.
	var ai := _wizard()
	put_battlefield(0, "Forest")
	give_hand(0, "Berserk")
	var giant := put_battlefield(0, "Hill Giant")
	g.players[1].life = 6
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	assert_eq(ai.act(g), "responded with Berserk")
	resolve_stack()
	advance_to_step(Mtg.Step.MAIN2)
	assert_true(g.game_over)
	assert_eq(g.winner, 0)
