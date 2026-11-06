extends GameTest
## Pack 10 (the Urza block), the fair AI's CYCLING (stage 4; CR 702.29a;
## engine/ai/urza_spells.gd `cycling_sources`, hooked from [method
## AiPlayer._activation_sources], [member AiProfile.forecasts_tactics]).
##
## Engine package E2 cycles a card dead on the public board at THEIR end
## step (tests/unit/test_pack_10_engine_E2_ai.gd pins it). The Urza AI adds
## the Runes of Protection whose colour the opponent has never shown, what
## a free cycle (Fluctuator) is worth — a card no turn soon pays for — and
## the vetoes: our own Energy Field is sacrificed by the discard. Our own
## hand and the public board only. With the gate off nothing is cycled.


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-10", true)
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(on := true) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func _lands(pid: int, land: String, n: int) -> void:
	for _i in n:
		put_battlefield(pid, land)


## Walk to the opponent's [param step] with seat 0 holding priority.
func _their_turn_at(step: int) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == step) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	if g.priority_player == 1:
		assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


# ----------------------------------------------------------- the Runes' colours --

func test_a_rune_against_a_colour_never_shown_is_cycled() -> void:
	var ai := _ai()
	_lands(0, "Plains", 3)
	_lands(1, "Forest", 3)
	put_battlefield(1, "Grizzly Bears")
	var rune := give_hand(0, "Rune of Protection: Red")
	_their_turn_at(Mtg.Step.END)
	assert_true(ai._activation_sources(g).has(rune))
	assert_eq(ai.act(g), "activated Rune of Protection: Red")


func test_a_rune_is_kept_against_their_mountains() -> void:
	var ai := _ai()
	_lands(0, "Plains", 3)
	_lands(1, "Mountain", 3)
	var rune := give_hand(0, "Rune of Protection: Red")
	_their_turn_at(Mtg.Step.END)
	assert_false(ai._activation_sources(g).has(rune), "a red mana source is red shown")


func test_a_rune_is_kept_against_a_red_card_in_their_graveyard() -> void:
	var ai := _ai()
	_lands(0, "Plains", 3)
	_lands(1, "Forest", 3)
	var bolt := _make_instance(1, "Lightning Bolt")
	bolt.zone = Mtg.Zone.GRAVEYARD
	g.players[1].graveyard.append(bolt)
	var rune := give_hand(0, "Rune of Protection: Red")
	_their_turn_at(Mtg.Step.END)
	assert_false(ai._activation_sources(g).has(rune))


func test_the_rune_reading_ignores_their_hand_and_libraries() -> void:
	var ai := _ai()
	_lands(0, "Plains", 3)
	_lands(1, "Forest", 3)
	var rune := give_hand(0, "Rune of Protection: Red")
	_their_turn_at(Mtg.Step.END)
	var before := ai._activation_sources(g).has(rune)
	give_hand(1, "Lightning Bolt")
	give_hand(1, "Mountain")
	g.players[0].library.reverse()
	g.players[1].library.reverse()
	assert_eq(ai._activation_sources(g).has(rune), before)


func test_the_null_arm_cycles_nothing() -> void:
	var ai := _ai(false)
	_lands(0, "Plains", 3)
	_lands(1, "Forest", 3)
	var rune := give_hand(0, "Rune of Protection: Red")
	_their_turn_at(Mtg.Step.END)
	assert_false(ai._activation_sources(g).has(rune))


# ------------------------------------------------------------------- Fluctuator --

func test_a_free_cycle_takes_a_card_no_turn_soon_pays_for() -> void:
	var ai := _ai()
	_lands(0, "Island", 1)
	put_battlefield(0, "Fluctuator")
	var drake := give_hand(0, "Pendrell Drake")
	_their_turn_at(Mtg.Step.END)
	assert_true(ai._activation_sources(g).has(drake), "a free cycle for a four-drop on one land")


func test_without_fluctuator_the_drake_is_kept() -> void:
	var ai := _ai()
	_lands(0, "Island", 1)
	var drake := give_hand(0, "Pendrell Drake")
	_their_turn_at(Mtg.Step.END)
	assert_false(ai._activation_sources(g).has(drake))


# ------------------------------------------------------------------ the vetoes --

func test_our_energy_field_forbids_the_discard() -> void:
	var ai := _ai()
	_lands(0, "Plains", 6)
	put_battlefield(0, "Energy Field")
	var rune := give_hand(0, "Rune of Protection: Red")
	_lands(1, "Forest", 3)
	_their_turn_at(Mtg.Step.END)
	assert_false(ai._activation_sources(g).has(rune), "the Field would be sacrificed")


func test_the_least_worth_card_is_offered_first() -> void:
	var ai := _ai()
	_lands(0, "Plains", 6)
	_lands(1, "Forest", 3)
	var rune := give_hand(0, "Rune of Protection: Red")
	var land := give_hand(0, "Drifting Meadow")
	_their_turn_at(Mtg.Step.END)
	var sources := ai._activation_sources(g)
	assert_true(sources.has(rune))
	assert_true(sources.has(land))
	assert_lt(sources.find(land), sources.find(rune), "a spare land before a card")
