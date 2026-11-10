extends GameTest
## GAP FIX G1a (gap review 2026-11-10, r1a-1 and r1a-2): two Fallen
## Empires combat readings that paid for nothing.
##
## r1a-1 — Vodalian War Machine's "+2/+1" was bought for a blocker the pump
## could not save, and the Merfolk tapped for it was destroyed with the
## Machine ("destroy all Merfolk tapped this turn to pay for its
## abilities"). The pump is bought now only while the crew still untapped
## can raise its toughness past the damage coming.
##
## r1a-2 — Tourach's Gate's "+2/-1" counted only the unblocked attackers'
## extra damage, and the -1 killed a blocked attacker that survived its
## block. That attacker is now priced as lost.
##
## Both are [member AiProfile.forecasts_tactics]: off keeps the old
## decision. Public board only — a hidden card swapped in their hand does
## not move either decision.


func before_each() -> void:
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	CardPacks.set_enabled(CardPacks.ID, false)


func pilot(forecasts := true) -> AiPlayer:
	var ai := AiPlayer.new(0, AiProfile.wizard())
	ai.profile.develops_late = false
	ai.profile.forecasts_tactics = forecasts
	g.set_agent(0, ai)
	return ai


## Seat 1 attacks with [param attackers]; seat 0 blocks as [param blocks];
## seat 0 then holds priority in the declare blockers step.
func _their_attack(attackers: Array, blocks: Dictionary) -> void:
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, attackers))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, blocks))
	if g.priority_player == 1: assert_ok(g.pass_priority(1))


## Seat 0 acts until it passes, handing priority back after each answer.
func _act_until_pass(ai: AiPlayer) -> Array:
	var lines: Array = []
	for _i in 8:
		if g.game_over: break
		if g.priority_player == 1 and g.stack.is_empty(): assert_ok(g.pass_priority(1))
		if g.priority_player != 0: break
		var did := ai.act(g)
		lines.append(did)
		if did == "pass" or did == "": break
		resolve_stack()
	return lines


static func _digest(option: Dictionary) -> Array:
	if option.is_empty(): return []
	var ids: Array = []
	for ref in option.get("targets", []):
		ids.append(ref.player_id if ref.is_player else ref.instance_id)
	return [snappedf(float(option["value"]), 0.001), ids]


# --- r1a-1: Vodalian War Machine ------------------------------------------

func test_a_doomed_war_machine_buys_no_pump() -> void:
	var machine := put_battlefield(0, "Vodalian War Machine")
	var crew := put_battlefield(0, "Merfolk of the Pearl Trident")
	var wurm := put_battlefield(1, "Craw Wurm")   # 6/4: a 2/5 dies to it as surely as a 0/4
	_their_attack([wurm.id], {machine.id: wurm.id})
	var ai := pilot()
	assert_true(ai._ability_option(g, machine, 1, AiPlayer.Moment.RESPONSE).is_empty(),
		"one Merfolk cannot raise a 0/4 past six damage")
	_act_until_pass(ai)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(machine.zone, Mtg.Zone.GRAVEYARD, "setup: the Wurm kills the Machine either way")
	assert_eq(crew.zone, Mtg.Zone.BATTLEFIELD, "the Merfolk was not tapped for a pump that saved nothing")


func test_a_pump_that_saves_the_machine_is_bought() -> void:
	var machine := put_battlefield(0, "Vodalian War Machine")
	var crew := put_battlefield(0, "Merfolk of the Pearl Trident")
	var elemental := put_battlefield(1, "Earth Elemental")   # 4/5: kills a 0/4, not a 2/5
	_their_attack([elemental.id], {machine.id: elemental.id})
	var ai := pilot()
	assert_false(ai._ability_option(g, machine, 1, AiPlayer.Moment.RESPONSE).is_empty())
	_act_until_pass(ai)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(machine.zone, Mtg.Zone.BATTLEFIELD, "one pump: 2/5 against four damage")
	assert_eq(crew.zone, Mtg.Zone.BATTLEFIELD)


func test_three_merfolk_pump_the_machine_out_of_reach() -> void:
	var machine := put_battlefield(0, "Vodalian War Machine")
	for _i in 3: put_battlefield(0, "Merfolk of the Pearl Trident")
	var wurm := put_battlefield(1, "Craw Wurm")   # six damage: three pumps make a 6/7
	_their_attack([wurm.id], {machine.id: wurm.id})
	var ai := pilot()
	_act_until_pass(ai)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(machine.zone, Mtg.Zone.BATTLEFIELD, "three pumps take it past the Wurm's six")
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD, "and its six power kills the Wurm")


func test_war_machine_gate_off_keeps_the_old_pump() -> void:
	var machine := put_battlefield(0, "Vodalian War Machine")
	put_battlefield(0, "Merfolk of the Pearl Trident")
	var wurm := put_battlefield(1, "Craw Wurm")
	_their_attack([wurm.id], {machine.id: wurm.id})
	var ai := pilot(false)
	assert_false(ai._ability_option(g, machine, 1, AiPlayer.Moment.RESPONSE).is_empty(),
		"forecasts_tactics off: the pre-fix reading, unchanged")


func test_war_machine_reads_no_hidden_card() -> void:
	var machine := put_battlefield(0, "Vodalian War Machine")
	put_battlefield(0, "Merfolk of the Pearl Trident")
	var elemental := put_battlefield(1, "Earth Elemental")
	var hidden := give_hand(1, "Giant Growth")
	put_battlefield(1, "Forest")
	_their_attack([elemental.id], {machine.id: elemental.id})
	var ai := pilot()
	var before := _digest(ai._ability_option(g, machine, 1, AiPlayer.Moment.RESPONSE))
	hidden.data = CardRegistry.get_card("Lightning Bolt")
	var after := _digest(ai._ability_option(g, machine, 1, AiPlayer.Moment.RESPONSE))
	assert_eq(after, before, "the card in their hand is not the War Machine's business")
	assert_false(before.is_empty())


# --- r1a-2: Tourach's Gate ------------------------------------------------

func _gate() -> CardInstance:
	var land := put_battlefield(0, "Swamp")
	var gate := give_hand(0, "Tourach's Gate")
	g.attach_aura_from_anywhere(gate, land, 0)
	return gate


func _our_attack(attackers: Array, blocks: Dictionary) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, attackers))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, blocks))


func test_tourachs_gate_does_not_kill_its_own_blocked_attacker() -> void:
	var gate := _gate()
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var their_bear := put_battlefield(1, "Grizzly Bears")
	_our_attack([a.id, b.id, giant.id], {their_bear.id: giant.id})
	var ai := pilot()
	assert_true(ai._ability_option(g, gate, 1, AiPlayer.Moment.RESPONSE).is_empty(),
		"four more damage is not worth the Hill Giant the -1 kills")
	_act_until_pass(ai)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "a 3/3 blocked by a 2/2 survives; a 5/2 would not")
	assert_eq(g.players[1].life, 16)


func test_tourachs_gate_still_boosts_an_unblocked_attack() -> void:
	var gate := _gate()
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	_our_attack([a.id, b.id, giant.id], {})
	var ai := pilot()
	assert_false(ai._ability_option(g, gate, 1, AiPlayer.Moment.RESPONSE).is_empty())
	_act_until_pass(ai)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20 - 7 - 6, "+2 for each of three unblocked attackers")


func test_tourachs_gate_gate_off_keeps_the_old_reading() -> void:
	var gate := _gate()
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var their_bear := put_battlefield(1, "Grizzly Bears")
	_our_attack([a.id, b.id, giant.id], {their_bear.id: giant.id})
	var ai := pilot(false)
	assert_false(ai._ability_option(g, gate, 1, AiPlayer.Moment.RESPONSE).is_empty(),
		"forecasts_tactics off: the pre-fix reading, unchanged")


func test_tourachs_gate_reads_no_hidden_card() -> void:
	var gate := _gate()
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var their_bear := put_battlefield(1, "Grizzly Bears")
	var hidden := give_hand(1, "Giant Growth")
	_our_attack([a.id, b.id, giant.id], {their_bear.id: giant.id})
	var ai := pilot()
	var before := _digest(ai._ability_option(g, gate, 1, AiPlayer.Moment.RESPONSE))
	hidden.data = CardRegistry.get_card("Terror")
	assert_eq(_digest(ai._ability_option(g, gate, 1, AiPlayer.Moment.RESPONSE)), before)
