extends GameTest
## CLOCKWORK BEAST AND CLOCKWORK AVIAN WIND DOWN ONCE PER COMBAT THEY FOUGHT
## IN (bug hunt 2026-10-21, cardsA).
##
## "At end of combat, if this creature attacked or blocked THIS COMBAT,
## remove a +1/+0 counter from it." Both read the per-TURN flags
## (`attacked_this_turn` / `blocked_this_turn`), so in a turn with an extra
## combat (Relentless Assault, pack 6) a Beast that fought only in the
## first lost a counter at the end of the second as well. They now ask
## the combat's own record of who took part (`CombatState.
## participant_stamps`, kept after a creature is removed from combat and
## cleared as the combat phase ends).


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids():
		CardPacks.set_enabled(id, false)


## The first combat with [param fighter] attacking alone, unblocked, then
## Relentless Assault in the second main phase and a second combat in
## which nothing attacks.
func _fight_once_then_sit_out(fighter: CardInstance) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [fighter.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.MAIN2)
	CardPacks.set_enabled("pack-6", true)
	var assault := give_hand(0, "Relentless Assault")
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, assault))
	resolve_stack()
	g.players[0].mana_pool.clear()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)   # the extra combat
	assert_ok(g.declare_attackers(0, []))
	advance_to_step(Mtg.Step.MAIN2)
	resolve_stack()


func test_clockwork_beast_loses_one_counter_for_one_fight() -> void:
	var beast := put_battlefield(0, "Clockwork Beast")
	assert_eq(int(beast.counters.get("+1/+0", 0)), 7)
	_fight_once_then_sit_out(beast)
	assert_eq(int(beast.counters.get("+1/+0", 0)), 6,
		"it sat out the second combat")


func test_clockwork_avian_loses_one_counter_for_one_fight() -> void:
	var avian := put_battlefield(0, "Clockwork Avian")
	assert_eq(int(avian.counters.get("+1/+0", 0)), 4)
	_fight_once_then_sit_out(avian)
	assert_eq(int(avian.counters.get("+1/+0", 0)), 3,
		"it sat out the second combat")


func test_clockwork_beast_still_winds_down_after_a_block() -> void:
	var beast := put_battlefield(1, "Clockwork Beast")
	var bear := put_battlefield(0, "Grizzly Bears")
	run_combat([bear.id], {beast.id: bear.id})
	resolve_stack()
	assert_eq(int(beast.counters.get("+1/+0", 0)), 6)
