extends GameTest
## THE CONSCRIPTIONS (2026-09-26). Nettling Imp, Norritt and Arcum's
## Whistle order a creature of the active player's to attack this turn or
## be destroyed at the end step, and may only be activated on an
## opponent's turn before attackers are declared. The engine has read
## that rider since 2026-09-25 ([method MtgGame.ability_timing_refusal]);
## the AI never activated one, because the only windows its ability
## scorer knew were their upkeep and their end step. Now their beginning
## of combat is a moment of its own ([constant AiPlayer.Moment]
## PRE_ATTACK, [method AiPlayer._pre_attack_option]), gated by
## [member AiProfile.casts_timed_spells], and the three cards share one
## declarative reading ([member EffectIntent.conscripts_attacker]).
##
## Every decision test acts through AiPlayer.act / the public MtgGame
## API, or asks the scorer's own moment ([method AiPlayer._try_activate])
## the way tests/cards/test_pack_3_library.gd does. Ice Age (Pack 3) is
## on for the script and off again after it.


func before_each() -> void:
	CardPacks.set_enabled(IceAgePack.ID, true)
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled(IceAgePack.ID, false)


func _wizard(seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, AiProfile.wizard())
	g.set_agent(seat, ai)
	return ai


## On to [param step] of seat 1's turn with the declarations made
## ([param attackers] are seat 1's) and seat 0 holding priority — the
## walker tests/unit/test_timing_riders_2026_09_25.gd uses.
func _their_step(step: int, attackers: Array = []) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == step
			and not g.awaiting_attackers and not g.awaiting_blockers
			and g.priority_player == 0) and not g.game_over and guard < 400:
		if g.awaiting_attackers:
			assert_ok(g.declare_attackers(g.active_player,
				attackers if g.active_player == 1 else []))
		elif g.awaiting_blockers:
			assert_ok(g.declare_blockers(g.opponent_of(g.active_player), {}))
		else:
			assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_lt(guard, 400, "never reached their %s" % Mtg.step_name(step))


func _tap(inst: CardInstance) -> void:
	inst.tapped = true


# ============================================================== the reader --

func test_the_reader_flags_the_three_conscriptions() -> void:
	var imp := put_battlefield(0, "Nettling Imp")
	var norritt := put_battlefield(0, "Norritt")
	var whistle := put_battlefield(0, "Arcum's Whistle")
	var bears := put_battlefield(0, "Grizzly Bears")
	var read := EffectIntent.read(imp.cur_activated_abilities[0].effects, "Nettling Imp")
	assert_true(read.conscripts_attacker, "the Imp")
	assert_eq(read.conscription_ransom, "", "no ransom on the Imp")
	read = EffectIntent.read(whistle.cur_activated_abilities[0].effects, "Arcum's Whistle")
	assert_true(read.conscripts_attacker, "the Whistle")
	assert_eq(read.conscription_ransom, "mana_value", "the Whistle's ransom")
	assert_eq(norritt.cur_activated_abilities.size(), 2)
	read = EffectIntent.read(norritt.cur_activated_abilities[0].effects, "Norritt")
	assert_true(read.untaps, "the Norritt's first ability untaps")
	assert_false(read.conscripts_attacker)
	read = EffectIntent.read(norritt.cur_activated_abilities[1].effects, "Norritt")
	assert_true(read.conscripts_attacker, "the Norritt's second conscripts")
	assert_eq(read.conscription_ransom, "")
	assert_true(bears.cur_activated_abilities.is_empty())


# ============================================================ the decision --

func test_the_imp_conscripts_a_tapped_creature_before_they_declare() -> void:
	# They tapped their Bears in their first main phase (a Rod, a mana
	# ability, whatever it was); a creature that cannot attack is one the
	# Imp destroys at their end step.
	var ai := _wizard(0)
	var imp := put_battlefield(0, "Nettling Imp")
	var bears := put_battlefield(1, "Grizzly Bears")
	_their_step(Mtg.Step.COMBAT_BEGIN)
	_tap(bears)
	assert_eq(ai.act(g), "activated Nettling Imp")
	resolve_stack()
	assert_true(imp.tapped, "the Imp paid its tap")
	assert_true(bears.must_attack_this_turn, "the Bears are ordered to attack")
	_their_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "destroyed at the end step for staying home")


func test_the_imp_conscripts_a_creature_that_cannot_attack() -> void:
	# Their Bears under our Moat: untapped, but "can't attack" is the same
	# clause as tapped for the Imp's second sentence.
	var ai := _wizard(0)
	put_battlefield(0, "Nettling Imp")
	put_battlefield(0, "Moat")
	var bears := put_battlefield(1, "Grizzly Bears")
	_their_step(Mtg.Step.COMBAT_BEGIN)
	assert_ne(CombatState.attack_illegality(g, bears, 0), "", "the Moat grounds it")
	assert_eq(ai.act(g), "activated Nettling Imp")
	resolve_stack()
	assert_true(bears.must_attack_this_turn)


func test_the_imp_orders_a_body_our_blocker_kills() -> void:
	# Their untapped Bears CAN attack — into our Craw Wurm, which kills it
	# and survives. Attack and die, or stay home and die: the Imp fires.
	var ai := _wizard(0)
	put_battlefield(0, "Nettling Imp")
	put_battlefield(0, "Craw Wurm")
	var bears := put_battlefield(1, "Grizzly Bears")
	_their_step(Mtg.Step.COMBAT_BEGIN)
	assert_eq(ai.act(g), "activated Nettling Imp")
	resolve_stack()
	assert_true(bears.must_attack_this_turn)


func test_the_imp_leaves_a_profitable_attacker_alone() -> void:
	# Their Craw Wurm against our lone Imp: no blocker of ours punishes
	# the swing, so ordering it is ordering six damage at our face. The
	# option is the null, and the Imp stays untapped.
	var ai := _wizard(0)
	var imp := put_battlefield(0, "Nettling Imp")
	var wurm := put_battlefield(1, "Craw Wurm")
	_their_step(Mtg.Step.COMBAT_BEGIN)
	assert_true(ai._ability_available(g, imp, 0), "the engine allows it")
	assert_eq(ai._try_activate(g, AiPlayer.Moment.PRE_ATTACK), "")
	assert_eq(ai.act(g), "pass")
	assert_false(imp.tapped)
	assert_false(wurm.must_attack_this_turn)


func test_the_conscription_refuses_our_own_turn() -> void:
	# The rider ("activate only during an opponent's turn") is the
	# engine's; the scorer refuses the moment itself — and the Norritt's
	# rider, "before attackers are declared", says nothing about whose
	# turn, so the policy must.
	var ai := _wizard(0)
	var imp := put_battlefield(0, "Nettling Imp")
	var norritt := put_battlefield(0, "Norritt")
	var bears := put_battlefield(1, "Grizzly Bears")
	_tap(bears)
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	assert_eq(g.active_player, 0)
	assert_eq(g.ability_timing_refusal(0, norritt, norritt.cur_activated_abilities[1]), "",
		"the Norritt's own rider allows our turn")
	assert_true(ai._pre_attack_option(g, norritt, 1).is_empty(), "the policy does not")
	assert_true(ai._pre_attack_option(g, imp, 0).is_empty())
	assert_eq(ai._try_activate(g, AiPlayer.Moment.PRE_ATTACK), "")
	assert_false(bears.must_attack_this_turn)


func test_the_conscription_refuses_once_attackers_are_declared() -> void:
	var ai := _wizard(0)
	var imp := put_battlefield(0, "Nettling Imp")
	put_battlefield(0, "Craw Wurm")
	var bears := put_battlefield(1, "Grizzly Bears")
	var lions := put_battlefield(1, "Savannah Lions")
	_their_step(Mtg.Step.DECLARE_ATTACKERS, [lions.id])
	assert_false(ai._ability_available(g, imp, 0), "the engine's rider")
	assert_true(ai._pre_attack_option(g, imp, 0).is_empty(), "and the policy's moment")
	assert_eq(ai._try_activate(g, AiPlayer.Moment.PRE_ATTACK), "")
	assert_false(bears.must_attack_this_turn)


func test_the_conscription_refuses_when_their_swing_is_lethal() -> void:
	# At three life against five power of attackers, ordering one more
	# body into the swing buys nothing; the Imp is a chump blocker now.
	var ai := _wizard(0)
	put_battlefield(0, "Nettling Imp")
	put_battlefield(0, "Craw Wurm")
	put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var elves := put_battlefield(1, "Llanowar Elves")
	_their_step(Mtg.Step.COMBAT_BEGIN)
	_tap(elves)
	g.players[0].life = 3
	assert_eq(ai._try_activate(g, AiPlayer.Moment.PRE_ATTACK), "")
	g.players[0].life = 20
	assert_eq(ai._try_activate(g, AiPlayer.Moment.PRE_ATTACK), "activated Nettling Imp",
		"the same board at twenty life")
	resolve_stack()
	# The Giant, not the tapped Elves: attack into the Wurm and die, or
	# stay home and die — the bigger body is the better order.
	assert_true(giant.must_attack_this_turn)
	assert_false(elves.must_attack_this_turn)


func test_the_whistle_waits_while_they_can_pay_the_ransom() -> void:
	# "unless that creature's controller pays {X}": two open Forests pay
	# for the Bears, so the Whistle waits; tap them and it fires.
	var ai := _wizard(0)
	var whistle := put_battlefield(0, "Arcum's Whistle")
	for _i in 3:
		put_battlefield(0, "Swamp")
	var bears := put_battlefield(1, "Grizzly Bears")
	var forests: Array[CardInstance] = []
	for _i in 2:
		forests.append(put_battlefield(1, "Forest"))
	_their_step(Mtg.Step.COMBAT_BEGIN)
	_tap(bears)
	assert_true(ai._ability_available(g, whistle, 0))
	assert_eq(ai._try_activate(g, AiPlayer.Moment.PRE_ATTACK), "", "they can pay two")
	for forest in forests:
		_tap(forest)
	assert_eq(ai._try_activate(g, AiPlayer.Moment.PRE_ATTACK), "activated Arcum's Whistle")
	resolve_stack()
	assert_true(bears.must_attack_this_turn, "unpaid: ordered")


func test_the_norritt_prefers_the_conscription_to_the_untap() -> void:
	# Both of the Norritt's abilities want its tap: their tapped Craw Wurm
	# is worth more dead than our Air Elemental is worth standing up.
	var ai := _wizard(0)
	var norritt := put_battlefield(0, "Norritt")
	var elemental := put_battlefield(0, "Air Elemental")
	_tap(elemental)
	var wurm := put_battlefield(1, "Craw Wurm")
	put_battlefield(1, "Hill Giant")
	_their_step(Mtg.Step.COMBAT_BEGIN)
	_tap(wurm)
	assert_false(ai._pre_attack_option(g, norritt, 0).is_empty(), "the untap is on offer")
	assert_false(ai._pre_attack_option(g, norritt, 1).is_empty(), "so is the conscription")
	assert_eq(ai.act(g), "activated Norritt")
	resolve_stack()
	assert_true(wurm.must_attack_this_turn, "the Wurm was ordered")
	assert_true(elemental.tapped, "the Elemental was not stood up")
	assert_true(norritt.tapped)


func test_the_norritt_stands_our_blocker_back_up_and_never_theirs() -> void:
	# Nothing to conscript (their Giant can attack and nothing of ours
	# untapped kills it; their Wall is no conscript); our tapped Air
	# Elemental would block the Giant. Their own tapped blue creature is
	# never the untap's target.
	var ai := _wizard(0)
	var norritt := put_battlefield(0, "Norritt")
	var elemental := put_battlefield(0, "Air Elemental")
	_tap(elemental)
	put_battlefield(1, "Hill Giant")
	var wall := put_battlefield(1, "Wall of Air")
	_their_step(Mtg.Step.COMBAT_BEGIN)
	_tap(wall)
	assert_true(ai._pre_attack_option(g, norritt, 1).is_empty(), "the Giant is left alone")
	assert_eq(ai.act(g), "activated Norritt")
	resolve_stack()
	assert_false(elemental.tapped, "our blocker stands")
	assert_true(wall.tapped, "theirs does not")


func test_the_norritt_declines_the_untap_with_nothing_to_block() -> void:
	var ai := _wizard(0)
	put_battlefield(0, "Norritt")
	var elemental := put_battlefield(0, "Air Elemental")
	_tap(elemental)
	_their_step(Mtg.Step.COMBAT_BEGIN)
	assert_eq(ai._try_activate(g, AiPlayer.Moment.PRE_ATTACK), "", "no attacker to meet")
	assert_true(elemental.tapped)


func test_the_lower_difficulties_have_no_window() -> void:
	# A capability, like the window caster's: Apprentice and Magician do
	# not know the moment exists.
	var ai := AiPlayer.new(0, AiProfile.magician())
	g.set_agent(0, ai)
	var imp := put_battlefield(0, "Nettling Imp")
	var bears := put_battlefield(1, "Grizzly Bears")
	_their_step(Mtg.Step.COMBAT_BEGIN)
	_tap(bears)
	assert_false(ai.profile.casts_timed_spells)
	assert_true(ai._ability_available(g, imp, 0))
	assert_eq(ai._try_activate(g, AiPlayer.Moment.PRE_ATTACK), "")
	assert_false(bears.must_attack_this_turn)


func test_the_reading_is_public_and_deterministic() -> void:
	# Hidden information (their hand, either library's order) and the
	# random generator play no part in the option.
	var ai := _wizard(0)
	var imp := put_battlefield(0, "Nettling Imp")
	put_battlefield(0, "Craw Wurm")
	put_battlefield(1, "Grizzly Bears")
	var elves := put_battlefield(1, "Llanowar Elves")
	_their_step(Mtg.Step.COMBAT_BEGIN)
	_tap(elves)
	var first: Dictionary = ai._pre_attack_option(g, imp, 0)
	give_hand(1, "Counterspell")
	give_hand(1, "Wrath of God")
	g.players[0].library.reverse()
	g.players[1].library.reverse()
	var state := g.rng.state
	var second: Dictionary = ai._pre_attack_option(g, imp, 0)
	assert_eq(float(first["value"]), float(second["value"]))
	assert_eq(first["targets"][0].instance_id, second["targets"][0].instance_id)
	assert_eq(g.rng.state, state)
