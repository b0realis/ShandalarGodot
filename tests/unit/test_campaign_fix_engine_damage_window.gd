extends GameTest
## Campaign fix-engine — the 1997 damage-prevention and regeneration steps
## (RulesOptions.damage_prevention_window, docs/duel-todo.md §6.8).
##
## w4-3 (= w5-8, engine side): whether a step opened depended on a card
## HIDDEN in a hand — a seat with nothing to use learned that the other
## held a Healing Salve. It now opens on PUBLIC information only: damage
## pending (or a creature about to die), the fork armed, and some seat that
## could act — an ability on the battlefield, a paid prevention, or ANY card
## in hand (a hand's size is public, its contents are not). Each seat then
## passes on its own information (the AI at once; the duel screen auto-passes
## a human with no usable window effect — fix-ui).
## w4-2: both players passing in the step resolved the top of the stack
## whatever it was, so a Giant Growth cast BEFORE the Bolt resolved inside
## the Bolt's prevention step. The step resolves only what was cast IN it.


class WindowAgent extends DecisionAgent:
	func wants_damage_prevention_window() -> bool:
		return true


func _arm_both() -> void:
	g.rules.set_edition("fifth")
	g.set_agent(0, WindowAgent.new())
	g.set_agent(1, WindowAgent.new())


# --------------------------------------------------- w4-3: public opening --

## Bolt at P1's Bears while P1 holds [param p1_card]: did the step open?
func _prevention_opens_with(p1_card: String) -> bool:
	before_each()
	_arm_both()
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	if p1_card != "":
		give_hand(1, p1_card)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	return g.awaiting_damage_prevention


func test_the_prevention_step_does_not_depend_on_a_hidden_card() -> void:
	var with_salve := _prevention_opens_with("Healing Salve")
	var with_bears := _prevention_opens_with("Grizzly Bears")
	assert_true(with_salve, "a seat holding a prevention spell gets the step")
	assert_eq(with_bears, with_salve,
		"the same hand SIZE opens the same step whatever the card is (hidden-hand permutation)")


func test_a_step_nobody_could_act_in_publicly_is_still_skipped() -> void:
	# The public control: no card in either hand, no window ability on
	# the battlefield — nobody could act, and everybody can see that.
	assert_false(_prevention_opens_with(""), "empty hands, empty boards: no step")


## The regeneration step, the same way: Death Ward (a regeneration
## instant) or a Grizzly Bears in P1's hand opens it alike.
func _regeneration_opens_with(p1_card: String) -> bool:
	before_each()
	_arm_both()
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	give_hand(1, p1_card)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	# Through the prevention step (it opens: P1 holds a card).
	var guard := 0
	while g.awaiting_damage_prevention and guard < 4:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	return g.awaiting_regeneration


func test_the_regeneration_step_does_not_depend_on_a_hidden_card() -> void:
	var with_ward := _regeneration_opens_with("Death Ward")
	var with_bears := _regeneration_opens_with("Grizzly Bears")
	assert_true(with_ward, "a seat holding a regeneration spell gets the step")
	assert_eq(with_bears, with_ward, "hidden-hand permutation: the same step either way")


## The AI passes the step at once on its own information: nothing in its
## hand or on its board fits, so its first action in the step ends it.
func test_the_ai_passes_a_step_it_cannot_use_at_once() -> void:
	g.rules.set_edition("fifth")
	var profile := AiProfile.wizard()
	profile.mistake_chance = 0.0
	var ai := AiPlayer.new(0, profile)
	g.set_agent(0, ai)
	g.set_agent(1, WindowAgent.new())
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	give_hand(1, "Healing Salve")
	give_hand(0, "Grizzly Bears")      # nothing of the window's family
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))       # the active AI seat yields
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	assert_ok(g.pass_priority(0))
	assert_true(g.awaiting_damage_prevention, "precondition: the step is open")
	assert_eq(g.priority_player, 0, "the active seat (the AI) has priority in it")
	assert_eq(ai.act(g), "ends damage prevention", "the AI passes the step at once")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


# ---------------------------------------- w4-2: older stack items stay put --

func test_the_prevention_step_does_not_resolve_an_older_spell() -> void:
	_arm_both()
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	give_hand(1, "Healing Salve")
	var growth := give_hand(0, "Giant Growth")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(0))
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(1))
	assert_ok(g.pass_priority(0))     # the Bolt resolves; its 3 wait in the step
	assert_true(g.awaiting_damage_prevention)
	assert_eq(g.stack.size(), 1, "precondition: the Growth is still on the stack")
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))
	assert_false(g.awaiting_damage_prevention, "both passed: the step is over")
	assert_eq(g.stack.size(), 1, "and the Growth did NOT resolve inside it")
	# The Bears are about to die and P1 holds a card — publicly it might be
	# a regeneration spell — so the regeneration step follows; it does not
	# resolve the Growth either.
	assert_true(g.awaiting_regeneration)
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))
	assert_false(g.awaiting_regeneration)
	assert_eq(g.stack.size(), 1, "nor inside the regeneration step")
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "the Bolt's damage was final: the Bears died")
	resolve_stack()                   # the Growth now has no target
	assert_eq(g.players[0].graveyard.has(growth), true)


func test_a_prevention_spell_cast_in_the_step_still_resolves_in_it() -> void:
	# The other half: what is cast INSIDE the step resolves inside it.
	_arm_both()
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	var growth := give_hand(1, "Giant Growth")
	var salve := give_hand(1, "Healing Salve")
	add_mana(1, Mtg.ManaColor.G)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, growth, [TargetRef.card(bear)]))   # an older item
	assert_ok(g.pass_priority(1))
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	assert_true(g.awaiting_damage_prevention)
	if g.priority_player == 0:
		assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(1, salve, [TargetRef.card(bear)], 0, 1))
	assert_eq(g.stack.size(), 2)
	assert_ok(g.pass_priority(1))
	assert_ok(g.pass_priority(0))     # the Salve resolves INSIDE the step
	assert_true(g.awaiting_damage_prevention, "still the same step")
	assert_eq(g.stack.size(), 1, "only the Salve left the stack")
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))
	assert_false(g.awaiting_damage_prevention)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "the Salve prevented the Bolt's 3")
	assert_eq(bear.damage, 0)
	assert_eq(g.stack.size(), 1, "the Growth still waits")


func test_the_regeneration_step_does_not_resolve_an_older_spell() -> void:
	_arm_both()
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	give_hand(1, "Death Ward")
	var growth := give_hand(0, "Giant Growth")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(0))
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(1))
	assert_ok(g.pass_priority(0))
	var guard := 0
	while g.awaiting_damage_prevention and guard < 4:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_true(g.awaiting_regeneration, "precondition: the Bears are about to die")
	assert_eq(g.stack.size(), 1, "precondition: the Growth still waits")
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))
	assert_false(g.awaiting_regeneration)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "nobody regenerated it, and the Growth came too late")
