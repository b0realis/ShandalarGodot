extends GameTest
## KAERVEK'S TORCH AND THE CASTABLE CHECK (Pack 8, 2026-10-03; engine
## package E5's `CardData.with_targeting_surcharge`, CR 601.2f).
##
## "As long as Kaervek's Torch is on the stack, spells that target it cost
## {2} more to cast." [method MtgGame.spell_payment] has always charged it
## once the TARGETS are known, so the cast itself was right — but every
## castable check is made before a target is chosen: the duel screen's
## highlight ([method MtgGame.can_afford], [method MtgGame.could_afford])
## and the AI's counter ranking said a Counterspell on two Islands was
## castable, and the AI then tapped both Islands and had the cast refused
## "plus {2} more", the mana lost.
##
## The fix is the FLOOR ([method MtgGame.targeting_surcharge_floor]): the
## cheapest surcharge any legal target set could carry — {2} when the
## Torch is the only spell a counter can name, nothing when another spell
## on the stack is a legal target too — read by both checks, and the AI
## prices its counter against the spell it actually aims at
## ([method MtgGame.targets_surcharge]).


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-8", true)
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


func _wizard(seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, AiProfile.wizard())
	g.set_agent(seat, ai)
	return ai


## Seat 1's first main phase, seat 1 holding priority.
func _their_main() -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.MAIN1) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)
	assert_eq(g.priority_player, 1)


## Seat 1 casts Kaervek's Torch for [param x] at [param target]; seat 0
## then holds priority with the Torch on the stack.
func _torch_at(target: TargetRef, x := 5) -> CardInstance:
	var torch := give_hand(1, "Kaervek's Torch")
	add_mana(1, Mtg.ManaColor.R)
	add_mana(1, Mtg.ManaColor.C, x)
	assert_ok(g.cast_spell(1, torch, [target], x))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	return torch


func _islands(seat: int, n: int) -> Array:
	var out: Array = []
	for _i in n:
		out.append(put_battlefield(seat, "Island"))
	return out


# ------------------------------------------------------------ the floor --

func test_floor_is_two_when_the_torch_is_the_only_target() -> void:
	_their_main()
	var counter := give_hand(0, "Counterspell")
	_torch_at(TargetRef.player(0))
	assert_eq(g.targeting_surcharge_floor(0, counter.data, counter), 2)
	assert_eq(g.targets_surcharge([TargetRef.card(g.stack.back().card)], counter), 2)


func test_floor_is_zero_with_no_torch_on_the_stack() -> void:
	var counter := give_hand(0, "Counterspell")
	assert_eq(g.targeting_surcharge_floor(0, counter.data, counter), 0)


func test_floor_is_zero_when_another_spell_is_a_legal_target() -> void:
	# The Torch is on the stack and seat 0 answers with a Bolt of its own:
	# a counter may now name the Bolt for nothing extra, so the cheapest
	# legal target set is free — a floor, never a guess at the aim.
	_their_main()
	var counter := give_hand(0, "Counterspell")
	_torch_at(TargetRef.player(0))
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_eq(g.targeting_surcharge_floor(0, counter.data, counter), 0)
	assert_eq(g.targets_surcharge([TargetRef.card(bolt)], counter), 0)


func test_a_spell_that_cannot_target_a_spell_has_no_floor() -> void:
	_their_main()
	var bolt := give_hand(0, "Lightning Bolt")
	_torch_at(TargetRef.player(0))
	assert_eq(g.targeting_surcharge_floor(0, bolt.data, bolt), 0)


# ------------------------------------------------- the castable check --

func test_could_afford_refuses_a_counter_two_islands_cannot_pay() -> void:
	_their_main()
	var counter := give_hand(0, "Counterspell")
	_islands(0, 2)
	_torch_at(TargetRef.player(0))
	assert_false(g.could_afford(0, counter.data, {}, counter),
		"{U}{U} plus {2} more is four mana")
	assert_false(g.could_afford(0, counter.data),
		"the duel screen's call without the instance reads the floor too")


func test_could_afford_admits_the_counter_with_four_islands() -> void:
	_their_main()
	var counter := give_hand(0, "Counterspell")
	_islands(0, 4)
	_torch_at(TargetRef.player(0))
	assert_true(g.could_afford(0, counter.data, {}, counter))


func test_can_afford_reads_the_floor_from_the_pool() -> void:
	_their_main()
	var counter := give_hand(0, "Counterspell")
	_torch_at(TargetRef.player(0))
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_false(g.can_afford(0, counter.data, counter))
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_true(g.can_afford(0, counter.data, counter))


# ------------------------------------------------------------ the pilot --

func test_wizard_does_not_tap_out_for_a_counter_it_cannot_pay() -> void:
	# The Torch is lethal (X=5 at five life): the counter is wanted, but
	# two Islands cannot pay {U}{U} + {2}. The pilot used to tap both and
	# have the cast refused; now it passes with both Islands standing.
	var ai := _wizard()
	_their_main()
	give_hand(0, "Counterspell")
	var islands := _islands(0, 2)
	g.players[0].life = 5
	_torch_at(TargetRef.player(0))
	var said := ai.act(g)
	assert_false(said.contains("Counterspell"), "no cast it cannot pay for: %s" % said)
	for island in islands:
		assert_false(island.tapped, "no mana spent on a refused cast")
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_wizard_counters_the_torch_paying_the_surcharge() -> void:
	var ai := _wizard()
	_their_main()
	var counter := give_hand(0, "Counterspell")
	_islands(0, 4)
	g.players[0].life = 5
	var torch := _torch_at(TargetRef.player(0))
	assert_string_contains(ai.act(g), "Counterspell")
	assert_eq(counter.zone, Mtg.Zone.STACK)
	resolve_stack()
	assert_eq(torch.zone, Mtg.Zone.GRAVEYARD, "countered")
	assert_eq(g.players[0].life, 5)
