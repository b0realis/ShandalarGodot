extends GameTest
## Pack 10 engine package E2 — THE FAIR AI'S MINIMAL CYCLING
## ([method AiPlayer._activation_sources], gate
## [member AiProfile.forecasts_tactics]).
##
## The minimum the package brief asks for, the deeper policy being the
## Urza AI stage's (AI.md "Cycling"): a card whose ability works from the
## hand is offered to the activation scorer only at THEIR end step with
## the stack empty — the mana sink — and only when it is dead on the
## public board: a removal spell with nothing to aim at, or a land beyond a
## working mana base. With the gate off the pilot never cycles, as before
## Pack 10. The reading is of the pilot's own hand and the public board:
## the opponent's hand and either library may change without changing it.


func _ai(forecasts := true, seat := 0) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.forecasts_tactics = forecasts
	var ai := AiPlayer.new(seat, p)
	g.set_agent(seat, ai)
	return ai


static func _is_artifact(c: CardInstance) -> bool:
	return c.is_type(Mtg.CardType.ARTIFACT)


## Scrap's shape: "Destroy target artifact. Cycling {2}".
static func _scrap() -> CardData:
	return CardData.new("Test Scrap", "{2}{R}", Mtg.CardType.INSTANT) \
		.spell(DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact", _is_artifact))) \
		.with_cycling()


static func _cycling_land() -> CardData:
	return CardData.new("Test Landscape", "", Mtg.CardType.LAND) \
		.mana(ManaAbility.new(Mtg.ManaColor.C, 1)) \
		.with_cycling()


func _lands(seat: int, land_name: String, count: int) -> void:
	for _i in count:
		put_battlefield(seat, land_name)


## Walk to the opponent's [param step] with seat 0 holding priority.
func _their_turn_at(step: int) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == step) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400, "never reached the opponent's %s" % Mtg.step_name(step))
	if g.priority_player == 1:
		assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


func test_a_dead_removal_spell_is_cycled_at_their_end_step() -> void:
	var ai := _ai(true)
	_lands(0, "Mountain", 2)
	var scrap := give_synthetic(0, _scrap())
	_their_turn_at(Mtg.Step.END)
	assert_true(ai._activation_sources(g).has(scrap))
	var hand_before := g.players[0].hand.size()
	assert_eq(ai.act(g), "activated Test Scrap")
	assert_eq(scrap.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand_before, "a fresh card for the dead one")


func test_null_arm_the_gate_off_never_cycles() -> void:
	var ai := _ai(false)
	_lands(0, "Mountain", 2)
	var scrap := give_synthetic(0, _scrap())
	_their_turn_at(Mtg.Step.END)
	assert_false(ai._activation_sources(g).has(scrap))
	ai.act(g)
	assert_eq(scrap.zone, Mtg.Zone.HAND)


func test_a_spell_with_something_to_hit_is_kept() -> void:
	var ai := _ai(true)
	_lands(0, "Mountain", 2)
	put_battlefield(1, "Sol Ring")
	var scrap := give_synthetic(0, _scrap())
	_their_turn_at(Mtg.Step.END)
	assert_false(ai._activation_sources(g).has(scrap), "an artifact to destroy: not dead")


func test_nothing_is_cycled_in_our_own_main_phase() -> void:
	var ai := _ai(true)
	_lands(0, "Mountain", 2)
	var scrap := give_synthetic(0, _scrap())
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(g.active_player, 0)
	assert_false(ai._activation_sources(g).has(scrap), "only the mana sink")


func test_a_spare_cycling_land_is_cycled_when_the_mana_base_is_built() -> void:
	var ai := _ai(true)
	_lands(0, "Mountain", 6)
	var land := give_synthetic(0, _cycling_land())
	_their_turn_at(Mtg.Step.END)
	assert_true(ai._activation_sources(g).has(land))
	assert_eq(ai.act(g), "activated Test Landscape")
	assert_eq(land.zone, Mtg.Zone.GRAVEYARD)


func test_a_cycling_land_is_kept_while_land_light() -> void:
	var ai := _ai(true)
	_lands(0, "Mountain", 3)
	var land := give_synthetic(0, _cycling_land())
	_their_turn_at(Mtg.Step.END)
	assert_false(ai._activation_sources(g).has(land), "three lands: the land is the card")


func test_the_reading_ignores_their_hand_and_both_libraries() -> void:
	var ai := _ai(true)
	_lands(0, "Mountain", 2)
	var scrap := give_synthetic(0, _scrap())
	_their_turn_at(Mtg.Step.END)
	var before := ai._activation_sources(g).has(scrap)
	# The hidden zones changed: an artifact in THEIR HAND (not on the
	# board), both libraries reordered.
	give_hand(1, "Sol Ring")
	give_hand(1, "Lightning Bolt")
	g.players[0].library.reverse()
	g.players[1].library.reverse()
	assert_eq(ai._activation_sources(g).has(scrap), before)
	# A public change does move it: the artifact cast onto the board.
	put_battlefield(1, "Sol Ring")
	assert_ne(ai._activation_sources(g).has(scrap), before)
