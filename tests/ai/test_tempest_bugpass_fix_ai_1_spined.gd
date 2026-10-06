extends GameTest
## Pack 9 bug pass (h6-9): the block planner reads Spined Sliver
## ([member AiProfile.forecasts_tactics]).
##
## "Whenever a Sliver becomes blocked, that Sliver gets +1/+1 until end of
## turn for each creature blocking it." The planner read only printed
## rampage ([member CardInstance.cur_rampage]), and Spined Sliver is a
## trigger on ANOTHER permanent: a 2/2 Muscle Sliver beside two Spined
## Slivers was blocked by Hill Giant as a 2/2, became a 4/4, and the Giant
## died. The growth is now read off every "becomes blocked" trigger whose
## condition hears the attacker ([method AiPlayer._blocked_growth]),
## counted from the first blocker, in the ladder and in the combat study's
## model ([member CombatSearch.d_growth]). Gate off: the old block. Their
## hidden hand never moves it.


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-9", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(on := true, studies := true) -> AiPlayer:
	var p := AiProfile.wizard()
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	p.studies_combat = studies
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


## Seat 1 attacks with [param attacker]; the AI (seat 0) declares its
## blocks; combat runs to its end.
func _they_attack_and_we_block(ai: AiPlayer, attacker: CardInstance) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.MAIN1) and guard < 400:
		_advance_once()
		guard += 1
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [attacker.id]))
	resolve_stack()
	guard = 0
	while not g.awaiting_blockers and guard < 50:
		g.pass_priority(g.priority_player)
		guard += 1
	ai.act(g)
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)


func _board(spined: int, their_hand: Array = []) -> Array:
	var giant := put_battlefield(0, "Hill Giant")
	for k in spined: put_battlefield(1, "Spined Sliver")
	if spined == 0: put_battlefield(1, "Metallic Sliver")
	var muscle := put_battlefield(1, "Muscle Sliver")
	for card_name in their_hand: give_hand(1, card_name)
	return [giant, muscle]


func test_no_block_into_two_spined_slivers() -> void:
	var ai := _ai()
	var pair := _board(2)
	_they_attack_and_we_block(ai, pair[1])
	assert_eq((pair[0] as CardInstance).zone, Mtg.Zone.BATTLEFIELD,
		"two Spined Sliver triggers make the 2/2 a 4/4: the Giant does not block it")


func test_the_ladder_reads_it_too() -> void:
	var ai := _ai(true, false)
	var pair := _board(2)
	_they_attack_and_we_block(ai, pair[1])
	assert_eq((pair[0] as CardInstance).zone, Mtg.Zone.BATTLEFIELD,
		"the block ladder (no combat study) prices the grown Sliver")


func test_control_without_spined_slivers_the_giant_blocks_and_kills() -> void:
	var ai := _ai()
	var pair := _board(0)
	_they_attack_and_we_block(ai, pair[1])
	assert_eq((pair[0] as CardInstance).zone, Mtg.Zone.BATTLEFIELD)
	assert_eq((pair[1] as CardInstance).zone, Mtg.Zone.GRAVEYARD)


func test_gate_off_blocks_as_before() -> void:
	var ai := _ai(false)
	var pair := _board(2)
	_they_attack_and_we_block(ai, pair[1])
	assert_eq((pair[0] as CardInstance).zone, Mtg.Zone.GRAVEYARD,
		"gate off: the old block, and the Giant it costs")


func test_the_block_ignores_their_hidden_hand() -> void:
	var zones: Array = []
	for hand in [["Giant Growth", "Counterspell"], ["Forest"], []]:
		g = null
		before_each()
		var ai := _ai()
		var pair := _board(2, hand)
		_they_attack_and_we_block(ai, pair[1])
		zones.append((pair[0] as CardInstance).zone)
	assert_eq(zones, [Mtg.Zone.BATTLEFIELD, Mtg.Zone.BATTLEFIELD, Mtg.Zone.BATTLEFIELD])


func test_the_line_reader() -> void:
	assert_eq(EffectIntent.growth_per_blocker(
		"Whenever a Sliver becomes blocked, that Sliver gets +1/+1 until end of turn for each creature blocking it."), 1)
	assert_eq(EffectIntent.growth_per_blocker(
		"Whenever this creature becomes blocked, it gets -1/-1 until end of turn for each creature blocking it beyond the first."), 0,
		"a shrink beyond the first is not growth")
	assert_eq(EffectIntent.growth_per_blocker(
		"Whenever this creature becomes blocked, it gets +3/+0 and gains trample until end of turn."), 0)
