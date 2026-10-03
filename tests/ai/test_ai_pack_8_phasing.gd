extends GameTest
## PHASING, READ BY THE FAIR AI (Pack 8, 2026-10-03; engine package E1,
## CR 702.26; [member AiProfile.forecasts_tactics]).
##
## The card batch tags every "phases out" with a role (cards/sets/{mir,
## vis,wth}/_phasing.gd: `phase_out` — a target, `phase_out_self`,
## `phase_out_host` — the Vanishing on it, `phase_swap` — Time and Tide),
## and mirage_tactics.gd reads the roles, never a name:
##  * THE SAVE: a removal spell aimed at our creature, or a combat it dies
##    in, is answered by phasing it out — the spell has no legal target and
##    the combat goes on without it (CR 702.26b);
##  * THE TEMPO: their attacker phased out before blocks (it stays away
##    through OUR next turn too: it returns at its controller's next untap
##    step), and their blocker phased out at our beginning of combat when
##    the attack it opens is worth the card;
##  * THE VALUE: a creature with phasing is there half the time — its
##    worth is discounted ([constant Evaluator.PHASING_SHARE]) — and the
##    phased-out ones are PUBLIC: their attack next turn is counted where
##    the clocks are read, a present phaser of theirs is not an attacker
##    next turn, and a sweeper waits while most of its targets are away.
## Hidden information: the opponent's hand and both libraries are
## substituted and no decision moves; a public change does.

const M := preload("res://engine/ai/mirage_tactics.gd")


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-8", true)
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


func _ai(profile: AiProfile = null, seat := 0) -> AiPlayer:
	var p := profile if profile != null else AiProfile.wizard()
	p.develops_late = false
	var ai := AiPlayer.new(seat, p)
	g.set_agent(seat, ai)
	return ai


func _null() -> AiProfile:
	var p := AiProfile.wizard()
	p.forecasts_tactics = false
	return p


func _islands(n: int) -> void:
	for _i in n: put_battlefield(0, "Island")


## Seat 1's main phase, seat 1 holding priority.
func _their_main() -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.MAIN1) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)


## Seat 1 attacks with [param ids]; seat 0 then holds priority in the
## declare-attackers step, before blocks.
func _they_attack(ids: Array) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.awaiting_attackers) and guard < 400:
		_advance_once()
		guard += 1
	assert_ok(g.declare_attackers(1, ids))
	guard = 0
	while g.priority_player != 0 and guard < 20:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_eq(g.current_step(), Mtg.Step.DECLARE_ATTACKERS)


## Our own beginning of combat, seat 0 holding priority.
func _our_combat_begin() -> void:
	var guard := 0
	while not (g.active_player == 0 and g.current_step() == Mtg.Step.COMBAT_BEGIN) \
			and guard < 400:
		_advance_once()
		guard += 1
	assert_eq(g.priority_player, 0)


func _terror_at(victim: CardInstance) -> void:
	_their_main()
	var terror := give_hand(1, "Terror")
	add_mana(1, Mtg.ManaColor.B)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, terror, [TargetRef.card(victim)]))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


# ---------------------------------------------------------- the value --

func test_a_phasing_creature_is_worth_about_half() -> void:
	var croc := put_battlefield(0, "Sandbar Crocodile")
	var on := Evaluator.permanent_value(croc, AiProfile.wizard())
	var off := Evaluator.permanent_value(croc, _null())
	assert_lt(on, off * 0.6, "present half the time")
	assert_gt(on, 0.0)


func test_their_returning_attacker_is_counted_and_their_phaser_is_not() -> void:
	var ai := _ai()
	var wurm := put_battlefield(1, "Craw Wurm")
	var croc := put_battlefield(1, "Sandbar Crocodile")
	assert_true(g.phase_out(wurm))
	assert_false(ai._could_attack_next_turn(g, croc), "it phases out at their untap step")
	assert_eq(ai._race_reach(g, 1, 0), 6, "the Wurm returns before it attacks; the Crocodile leaves")


# ---------------------------------------------------------- the save --

func test_rainbow_efreet_phases_out_of_a_terror() -> void:
	var ai := _ai()
	var efreet := put_battlefield(0, "Rainbow Efreet")
	_islands(2)
	_terror_at(efreet)
	assert_string_contains(ai.act(g), "phases out")
	resolve_stack()
	assert_true(efreet.phased_out, "out of reach (CR 702.26b)")
	assert_ne(efreet.zone, Mtg.Zone.GRAVEYARD)


func test_reality_ripple_saves_a_serra_angel() -> void:
	var ai := _ai()
	var angel := put_battlefield(0, "Serra Angel")
	_islands(2)
	var ripple := give_hand(0, "Reality Ripple")
	_terror_at(angel)
	assert_string_contains(ai.act(g), "Reality Ripple")
	resolve_stack()
	assert_true(angel.phased_out)
	assert_eq(ripple.zone, Mtg.Zone.GRAVEYARD)


func test_no_phasing_out_of_a_bolt_it_survives() -> void:
	var ai := _ai()
	var angel := put_battlefield(0, "Serra Angel")
	_islands(2)
	var ripple := give_hand(0, "Reality Ripple")
	_their_main()
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(angel)]))
	assert_ok(g.pass_priority(1))
	ai.act(g)
	assert_eq(ripple.zone, Mtg.Zone.HAND, "three damage does not kill a 4/4")


func test_null_arm_lets_the_terror_resolve() -> void:
	var ai := _ai(_null())
	var efreet := put_battlefield(0, "Rainbow Efreet")
	_islands(2)
	_terror_at(efreet)
	ai.act(g)
	resolve_stack()
	assert_eq(efreet.zone, Mtg.Zone.GRAVEYARD, "the pilot as it was")


# ---------------------------------------------------------- the tempo --

func test_their_lethal_attacker_is_phased_out_before_blocks() -> void:
	var ai := _ai()
	var illusionist := put_battlefield(0, "Vodalian Illusionist")
	_islands(2)
	var wurm := put_battlefield(1, "Craw Wurm")
	g.players[0].life = 6
	_they_attack([wurm.id])
	assert_string_contains(ai.act(g), "Vodalian Illusionist")
	resolve_stack()
	assert_true(wurm.phased_out)
	assert_true(illusionist.tapped)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 6, "nothing got through")


func test_a_small_attacker_is_not_worth_the_card() -> void:
	var ai := _ai()
	_islands(2)
	var ripple := give_hand(0, "Reality Ripple")
	var elves := put_battlefield(1, "Llanowar Elves")
	_they_attack([elves.id])
	ai.act(g)
	assert_eq(ripple.zone, Mtg.Zone.HAND, "one damage at twenty is not a card")


func test_their_only_blocker_is_phased_out_for_the_lethal_swing() -> void:
	var ai := _ai()
	_islands(2)
	var wurm := put_battlefield(0, "Craw Wurm")
	var ripple := give_hand(0, "Reality Ripple")
	var bears := put_battlefield(1, "Grizzly Bears")
	g.players[1].life = 6
	advance_to_step(Mtg.Step.MAIN1)
	var said := ai.act(g)
	assert_false(said.contains("Reality Ripple"), "held for the combat: %s" % said)
	_our_combat_begin()
	assert_string_contains(ai.act(g), "Reality Ripple")
	resolve_stack()
	assert_true(bears.phased_out)
	assert_eq(ripple.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)


func test_the_blocker_decision_ignores_their_hidden_cards() -> void:
	# The same public board twice, their hand and library permuted: the
	# answer cannot move. Then a PUBLIC change (their life high) does.
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		_islands(2)
		put_battlefield(0, "Craw Wurm")
		give_hand(0, "Reality Ripple")
		put_battlefield(1, "Grizzly Bears")
		g.players[1].life = 6
		give_hand(1, "Giant Growth" if variant == 0 else "Lightning Bolt")
		g.players[1].library.reverse()
		_our_combat_begin()
		answers.append(ai.act(g).contains("Reality Ripple"))
	assert_eq(answers[0], answers[1], "hidden cards changed the decision")
	assert_true(answers[0])


# ---------------------------------------------------------- the sweeper --

func test_a_sweeper_waits_while_its_targets_are_phased_out() -> void:
	var ai := _ai()
	for _i in 4: put_battlefield(0, "Plains")
	var wrath := give_hand(0, "Wrath of God")
	var a := put_battlefield(1, "Craw Wurm")
	var b := put_battlefield(1, "Serra Angel")
	put_battlefield(1, "Grizzly Bears")
	assert_true(g.phase_out(a))
	assert_true(g.phase_out(b))
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_eq(wrath.zone, Mtg.Zone.HAND, "the Wurm and the Angel return at their untap")


# ---------------------------------------------------------- time and tide --

func test_time_and_tide_brings_our_army_back() -> void:
	var ai := _ai()
	var angel := put_battlefield(0, "Serra Angel")
	assert_true(g.phase_out(angel))
	assert_gt(M.phase_swap_value(g, ai), 2.5)
	var croc := put_battlefield(0, "Sandbar Crocodile")
	g.phase_in(angel)
	assert_lt(M.phase_swap_value(g, ai), 0.0, "it would only send our own Crocodile away")
	assert_eq(croc.zone, Mtg.Zone.BATTLEFIELD)
