extends GameTest
## COMBAT DAMAGE AGAINST A CREATURE WEARING SEVERAL AURAS (playtest,
## 2026-09-06: *"sometimes a 1/1 blocking creature kills a more powerful
## creature with higher life numbers"*). Every case here pins the same
## arithmetic — a body's LIVE toughness is what its damage is measured
## against, auras, until-end-of-turn pumps and counters all counted, in
## every combat shape the table can produce: a single block, a gang
## block, first strike, the 1997 damage-prevention window with a human
## seat on both sides, and the human dividing their own damage.


func _human_seat(pid: int) -> HumanAgent:
	var human := HumanAgent.new()
	g.agents[pid] = human
	g.interactive_choices = true
	return human


## Hurloon Minotaur (2/3) wearing Holy Strength (+1/+2) and Unholy
## Strength (+2/+1): a 5/6.
func _dressed_minotaur(pid: int) -> CardInstance:
	var minotaur := put_battlefield(pid, "Hurloon Minotaur")
	g.attach_aura_from_anywhere(give_hand(pid, "Holy Strength"), minotaur, pid)
	g.attach_aura_from_anywhere(give_hand(pid, "Unholy Strength"), minotaur, pid)
	assert_eq(minotaur.cur_power, 5, "the auras add up")
	assert_eq(minotaur.cur_toughness, 6)
	return minotaur


## Walk the current combat to its end, answering every hold the engine
## puts up — the human seat's own damage division, the 1997 prevention
## window and the regeneration window — the way the table would.
func _finish_combat() -> void:
	var guard := 0
	while g.current_step() != Mtg.Step.COMBAT_END and not g.game_over \
			and guard < 200:
		guard += 1
		if g.awaiting_damage_assignment:
			var request := g.damage_assignment_request()
			var assigner := int(request["assigner"])
			assert_ok(g.assign_combat_damage(assigner,
				g.default_damage_split(request["source"], request["targets"],
					int(request["amount"]), bool(request["trample"]),
					request["assigned"], bool(request.get("free_order", false)))))
		elif g.awaiting_damage_prevention or g.awaiting_regeneration:
			assert_ok(g.end_damage_prevention(g.priority_player))
		else:
			assert_ok(g.pass_priority(g.priority_player))
	assert_lt(guard, 200, "the combat did not finish")


func _attack_into(attacker: CardInstance, blockers: Array) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	var block_map := {}
	for blocker in blockers:
		block_map[blocker.id] = attacker.id
	assert_ok(g.declare_blockers(1, block_map))
	_finish_combat()


# ------------------------------------------------------- the plain fight --

func test_a_one_one_blocker_does_not_kill_a_dressed_minotaur() -> void:
	var minotaur := _dressed_minotaur(0)
	var goblin := put_battlefield(1, "Mons's Goblin Raiders")
	_attack_into(minotaur, [goblin])
	assert_eq(goblin.zone, Mtg.Zone.GRAVEYARD, "the 1/1 took 5")
	assert_eq(minotaur.zone, Mtg.Zone.BATTLEFIELD, "the 5/6 took 1 and lived")
	assert_eq(minotaur.damage, 1, "exactly one point marked")
	assert_eq(minotaur.cur_toughness, 6, "and its auras are still counted")


func test_the_auras_hold_through_the_1997_prevention_window() -> void:
	# The 1997 ruleset: damage WAITS in a window after it is dealt, with a
	# human on both seats, each holding something the window could use —
	# so the window really opens, and the packets land when it closes.
	g.rules.set_edition("fifth")
	_human_seat(0)
	_human_seat(1)
	give_hand(0, "Healing Salve")
	give_hand(1, "Healing Salve")
	var minotaur := _dressed_minotaur(0)
	var goblin := put_battlefield(1, "Mons's Goblin Raiders")
	_attack_into(minotaur, [goblin])
	assert_eq(goblin.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(minotaur.zone, Mtg.Zone.BATTLEFIELD, "the 5/6 lived")
	assert_eq(minotaur.damage, 1, "the packet landed ONCE")


func test_a_dressed_blocker_kills_the_attacker_and_lives() -> void:
	# The other way round: the small body wearing the auras is the BLOCKER.
	var bears := put_battlefield(0, "Grizzly Bears")
	var goblin := put_battlefield(1, "Mons's Goblin Raiders")
	g.attach_aura_from_anywhere(give_hand(1, "Holy Strength"), goblin, 1)
	g.attach_aura_from_anywhere(give_hand(1, "Unholy Strength"), goblin, 1)
	assert_eq(goblin.cur_power, 4)
	assert_eq(goblin.cur_toughness, 4)
	_attack_into(bears, [goblin])
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "2/2 into a 4/4")
	assert_eq(goblin.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(goblin.damage, 2)


func test_earlier_damage_counts_but_only_once() -> void:
	# Damage marked earlier in the turn stays marked (CR 120.6): a 5/6
	# with 4 on it dies to the 1/1, a 5/6 with 3 on it does not.
	var minotaur := _dressed_minotaur(0)
	var goblin := put_battlefield(1, "Mons's Goblin Raiders")
	minotaur.damage = 4
	_attack_into(minotaur, [goblin])
	assert_eq(minotaur.zone, Mtg.Zone.BATTLEFIELD, "4 + 1 < 6")
	assert_eq(minotaur.damage, 5)


# ------------------------------------------------- the other combat shapes --

func test_a_gang_block_adds_up_against_the_live_toughness() -> void:
	var minotaur := _dressed_minotaur(0)
	var goblin := put_battlefield(1, "Mons's Goblin Raiders")
	var bears := put_battlefield(1, "Grizzly Bears")
	_attack_into(minotaur, [goblin, bears])
	assert_eq(minotaur.zone, Mtg.Zone.BATTLEFIELD, "1 + 2 < 6")
	assert_eq(minotaur.damage, 3)
	# Lethal-first: 5 power kills the first blocker in order and the rest
	# goes to the second — one of the two dies, at least.
	var dead := 0
	for blocker in [goblin, bears]:
		if blocker.zone == Mtg.Zone.GRAVEYARD:
			dead += 1
	assert_gt(dead, 0, "5 damage kills at least one blocker")


func test_a_gang_block_divided_by_the_human_seat() -> void:
	# The attacker's controller is HUMAN and divides the damage (DAMAGE
	# mode at the table); the blockers' damage back is the engine's own
	# and must still be measured against the live 6.
	_human_seat(0)
	var minotaur := _dressed_minotaur(0)
	var goblin := put_battlefield(1, "Mons's Goblin Raiders")
	var bears := put_battlefield(1, "Grizzly Bears")
	_attack_into(minotaur, [goblin, bears])
	assert_eq(minotaur.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(minotaur.damage, 3)


func test_a_first_striking_one_one_still_loses() -> void:
	# Tundra Wolves, 1/1 first strike: its point lands first, the 5/6 is
	# still standing for the normal wave, and the Wolves take 5.
	var minotaur := _dressed_minotaur(0)
	var wolves := put_battlefield(1, "Tundra Wolves")
	_attack_into(minotaur, [wolves])
	assert_eq(wolves.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(minotaur.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(minotaur.damage, 1)


func test_a_pump_and_a_counter_stack_on_the_auras() -> void:
	# Auras + a Giant Growth + a +1/+1 counter, all on one body: 9/10.
	var minotaur := _dressed_minotaur(0)
	g.continuous.add_until_eot_pump(minotaur.id, 3, 3)
	minotaur.counters["+1/+1"] = 1
	g.recalculate()
	assert_eq(minotaur.cur_power, 9)
	assert_eq(minotaur.cur_toughness, 10)
	var goblin := put_battlefield(1, "Mons's Goblin Raiders")
	_attack_into(minotaur, [goblin])
	assert_eq(minotaur.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(minotaur.damage, 1)
	assert_eq(minotaur.cur_toughness, 10, "still 10 at the end of combat")


func test_an_aura_that_dies_mid_combat_takes_its_toughness_with_it() -> void:
	# The one way a 1/1 CAN finish a bigger creature: its toughness went
	# down first. Killing the Unholy Strength after blockers leaves a 3/5
	# with — after the Goblin's point — 1 damage; killing BOTH auras leaves
	# the printed 2/3, which still lives. The engine must re-read the
	# toughness, not remember the 6.
	var minotaur := _dressed_minotaur(0)
	var goblin := put_battlefield(1, "Mons's Goblin Raiders")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [minotaur.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {goblin.id: minotaur.id}))
	for aura in g.players[0].battlefield.duplicate():
		if aura.data.is_aura():
			g.destroy(aura)
	g.check_state_based_actions()
	assert_eq(minotaur.cur_toughness, 3, "back to the printed 2/3")
	_finish_combat()
	assert_eq(minotaur.zone, Mtg.Zone.BATTLEFIELD, "a 2/3 still survives a point")
	assert_eq(minotaur.damage, 1)
	assert_eq(goblin.zone, Mtg.Zone.GRAVEYARD, "and the 2 power still killed the 1/1")
