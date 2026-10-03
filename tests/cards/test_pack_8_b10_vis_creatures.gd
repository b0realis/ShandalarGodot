extends GameTest
## Pack 8, batch B10: the Visions creatures with rules text
## (cards/sets/vis/_creatures.gd). Each test drives the card through the
## public API — cast, activate, combat — and pins the clause that makes it
## that card. Chronatog uses the E8 skip-a-turn API, King Cheetah the E3
## FLASH keyword.

const DONE := ["Daraja Griffin", "Infantry Veteran", "Jamuraan Lion", "Resistance Fighter", "Crypt Rats",
	"Necrosavant", "Urborg Mindsucker", "Wake of Vultures", "Keeper of Kookus", "Spitting Drake",
	"Giant Caterpillar", "Kyscu Drake", "Quirion Druid", "River Boa", "Army Ants", "Guiding Spirit",
	"Mundungu", "Viashivan Dragon", "Brass-Talon Chimera", "Iron-Heart Chimera", "Lead-Belly Chimera",
	"Matopi Golem", "Phyrexian Marauder", "Tin-Wing Chimera", "Chronatog", "King Cheetah"]


## Answers every yes/no with [member says] and every card choice with the
## candidate named [member pick] when it is offered.
class Seat extends DecisionAgent:
	var says := true
	var pick := ""
	func answer_yes_no(_g: MtgGame, _pid: int, _prompt: String, _hint: bool) -> bool:
		return says
	func answer_card(_g: MtgGame, _pid: int, candidates: Array[CardInstance], _prompt: String) -> CardInstance:
		for c in candidates:
			if c.data.card_name == pick: return c
		return null if candidates.is_empty() else candidates[0]


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

func _pending(name: String) -> bool:
	var c := CardRegistry.get_card(name)
	return c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"

func cast(name: String, targets: Array = [], pid := 0, x := 0) -> CardInstance:
	var c := give_hand(pid, name)
	for color in Mtg.WUBRG: add_mana(pid, color, 20)
	if g.priority_player != pid: assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.cast_spell(pid, c, targets, x))
	resolve_stack()
	return c

func grave(pid: int, name: String) -> CardInstance:
	var inst := _make_instance(pid, name)
	g.put_into_graveyard(inst)
	return inst

func library_top(pid: int, name: String) -> CardInstance:
	var inst := _make_instance(pid, name)
	inst.zone = Mtg.Zone.LIBRARY
	g.players[pid].library.append(inst)
	return inst

func to_upkeep(pid: int) -> void:
	var guard := 0
	while g.current_step() == Mtg.Step.UPKEEP and not g.game_over and guard < 50:
		_advance_once()   # leave the upkeep we may be standing in
		guard += 1
	while not (g.current_step() == Mtg.Step.UPKEEP and g.active_player == pid) and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400, "never reached the upkeep")


func test_batch_cards_are_all_claimed() -> void:
	for name in DONE: assert_false(_pending(name), name)


func test_chronatog_pumps_once_and_skips_your_next_turn() -> void:
	var atog := put_battlefield(0, "Chronatog")
	assert_ok(g.activate_ability(0, atog, 0, []))
	assert_refused(g.activate_ability(0, atog, 0, []), "once")
	resolve_stack()
	assert_eq([atog.cur_power, atog.cur_toughness], [4, 5])
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	advance_to_next_turn()
	assert_eq(g.active_player, 1, "P0's turn was skipped: the opponent goes again")
	advance_to_next_turn()
	assert_eq(g.active_player, 0)
	assert_eq([atog.cur_power, atog.cur_toughness], [1, 2])


func test_chronatog_skip_happens_even_if_it_left() -> void:
	var atog := put_battlefield(0, "Chronatog")
	assert_ok(g.activate_ability(0, atog, 0, []))
	g.destroy(atog)
	resolve_stack()
	assert_eq(g.players[0].turns_to_skip, 1, "\"you skip\" does not need the Atog")


## Chronatog's +3/+3 costs a whole turn: the AI only takes that trade when
## the pump wins on the spot (the AI's Pack 8 rule, tests/ai/
## test_ai_pack_8_mana.gd), never as a free bonus.
func _run_chronatog_turns(ai: AiPlayer) -> void:
	var guard := 0
	while g.turn_number <= 2 and not g.game_over and guard < 300:
		guard += 1
		if g.awaiting_blockers and g.block_chooser() == 1:
			assert_ok(g.declare_blockers(1, {}))
		elif (g.awaiting_attackers and g.active_player == 0) or (g.priority_player == 0 and not g.awaiting_attackers):
			if ai.act(g) == "" and g.priority_player == 0: assert_ok(g.pass_priority(0))
		elif g.awaiting_attackers:
			assert_ok(g.declare_attackers(g.active_player, []))
		else:
			assert_ok(g.pass_priority(g.priority_player))


func test_the_ai_never_trades_a_turn_for_chronatogs_pump() -> void:
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	var atog := put_battlefield(0, "Chronatog")
	for n in 3: put_battlefield(0, "Island")
	g.players[1].life = 5   # +3/+3 on a 1/2 is 4: not lethal, so not worth a turn
	_run_chronatog_turns(ai)
	assert_eq(g.players[0].turns_to_skip, 0)
	assert_eq(int(atog.ability_uses.get(0, 0)), 0)


func test_the_ai_pumps_chronatog_when_the_swing_is_lethal() -> void:
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	put_battlefield(0, "Chronatog")
	for n in 3: put_battlefield(0, "Island")
	g.players[1].life = 4   # unblocked 1/2 + 3/+3 is exactly lethal
	_run_chronatog_turns(ai)
	assert_true(g.game_over, "the skipped turn never comes")
	assert_eq(g.players[1].life <= 0, true)


func test_king_cheetah_has_flash() -> void:
	var cheetah := give_hand(1, "King Cheetah")
	var bear := give_hand(1, "Grizzly Bears")
	add_mana(1, Mtg.ManaColor.G, 6)
	assert_ok(g.pass_priority(0))
	assert_refused(g.cast_spell(1, bear, []), "main phase")
	assert_ok(g.cast_spell(1, cheetah, []))
	resolve_stack()
	assert_eq(cheetah.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(cheetah.controller_id, 1)


func test_daraja_griffin_sacrifices_to_destroy_only_a_black_creature() -> void:
	var griffin := put_battlefield(0, "Daraja Griffin")
	var bear := put_battlefield(1, "Grizzly Bears")
	var knight := put_battlefield(1, "Scathe Zombies")
	assert_refused(g.activate_ability(0, griffin, 0, [TargetRef.card(bear)]))
	assert_eq(griffin.zone, Mtg.Zone.BATTLEFIELD, "a refused activation costs nothing")
	assert_ok(g.activate_ability(0, griffin, 0, [TargetRef.card(knight)]))
	assert_eq(griffin.zone, Mtg.Zone.GRAVEYARD, "sacrifice is the cost")
	resolve_stack()
	assert_eq(knight.zone, Mtg.Zone.GRAVEYARD)


func test_infantry_veteran_pumps_only_an_attacking_creature() -> void:
	var veteran := put_battlefield(0, "Infantry Veteran")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_refused(g.activate_ability(0, veteran, 0, [TargetRef.card(bear)]))
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	assert_ok(g.activate_ability(0, veteran, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq([bear.cur_power, bear.cur_toughness], [3, 3])
	assert_true(veteran.tapped)


func test_jamuraan_lion_stops_a_blocker_this_turn_only() -> void:
	var lion := put_battlefield(0, "Jamuraan Lion")
	var attacker := put_battlefield(0, "Hill Giant")
	var wall := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.activate_ability(0, lion, 0, [TargetRef.card(wall)]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {wall.id: attacker.id}))
	assert_ok(g.declare_blockers(1, {}))
	advance_to_next_turn()
	assert_true(wall.cur_cant_block_filter.is_null(), "the restriction ended with the turn")


func test_resistance_fighter_fogs_one_creatures_combat_damage() -> void:
	var fighter := put_battlefield(1, "Resistance Fighter")
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id, bear.id]))
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, fighter, 0, [TargetRef.card(giant)]))
	assert_eq(fighter.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 18, "only the bear's 2 got through")
	g.deal_damage(giant, TargetRef.player(1), 1)
	assert_eq(g.players[1].life, 17, "noncombat damage from it is untouched")


func test_crypt_rats_x_is_black_only_and_hits_everything() -> void:
	var rats := put_battlefield(0, "Crypt Rats")
	var giant := put_battlefield(1, "Hill Giant")
	add_mana(0, Mtg.ManaColor.R, 5)
	assert_refused(g.activate_ability(0, rats, 0, [], 2))
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.activate_ability(0, rats, 0, [], 2))
	resolve_stack()
	assert_eq(g.players[0].life, 18)
	assert_eq(g.players[1].life, 18)
	assert_eq(giant.damage, 2)
	assert_eq(rats.zone, Mtg.Zone.GRAVEYARD, "the Rats hit themselves too")


func test_necrosavant_returns_from_the_graveyard_only_in_your_upkeep() -> void:
	var savant := grave(0, "Necrosavant")
	var fodder := put_battlefield(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.B, 5)
	assert_refused(g.activate_ability(0, savant, 0, []), "")
	to_upkeep(0)
	add_mana(0, Mtg.ManaColor.B, 5)
	assert_ok(g.activate_ability(0, savant, 0, []))
	assert_eq(fodder.zone, Mtg.Zone.GRAVEYARD, "a creature is sacrificed as the cost")
	resolve_stack()
	assert_eq(savant.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(savant.controller_id, 0)


func test_necrosavant_needs_a_creature_to_sacrifice() -> void:
	var savant := grave(0, "Necrosavant")
	to_upkeep(0)
	add_mana(0, Mtg.ManaColor.B, 5)
	assert_refused(g.activate_ability(0, savant, 0, []), "sacrifice")


func test_urborg_mindsucker_is_sorcery_speed_random_discard() -> void:
	var sucker := put_battlefield(0, "Urborg Mindsucker")
	give_hand(1, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.B)
	assert_refused(g.activate_ability(0, sucker, 0, [TargetRef.player(0)]), "")
	assert_ok(g.activate_ability(0, sucker, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 0)
	assert_eq(g.players[1].graveyard.size(), 1)
	var other := put_battlefield(0, "Urborg Mindsucker")
	advance_to_next_turn()
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.B)
	assert_refused(g.activate_ability(0, other, 0, [TargetRef.player(1)]), "sorcery")
	assert_eq(other.zone, Mtg.Zone.BATTLEFIELD)


func test_wake_of_vultures_eats_another_creature_for_a_shield() -> void:
	var wake := put_battlefield(0, "Wake of Vultures")
	var bear := put_battlefield(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.activate_ability(0, wake, 0, []))
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "the bear is offered before the Wake itself")
	resolve_stack()
	assert_eq(wake.regeneration_shields, 1)
	g.destroy(wake)
	assert_eq(wake.zone, Mtg.Zone.BATTLEFIELD)


func test_keeper_of_kookus_gains_protection_from_red() -> void:
	var keeper := put_battlefield(0, "Keeper of Kookus")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, keeper, 0, []))
	resolve_stack()
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(1, bolt, [TargetRef.card(keeper)]))
	advance_to_next_turn()
	assert_eq(keeper.cur_protection & Mtg.ManaColor.R, 0)


func test_spitting_drake_firebreathes_once_each_turn() -> void:
	var drake := put_battlefield(0, "Spitting Drake")
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.activate_ability(0, drake, 0, []))
	assert_refused(g.activate_ability(0, drake, 0, []), "once")
	resolve_stack()
	assert_eq(drake.cur_power, 3)


func test_viashivan_dragon_pumps_both_ways() -> void:
	var dragon := put_battlefield(0, "Viashivan Dragon")
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.G, 1)
	assert_ok(g.activate_ability(0, dragon, 0, []))
	assert_ok(g.activate_ability(0, dragon, 0, []))
	assert_ok(g.activate_ability(0, dragon, 1, []))
	resolve_stack()
	assert_eq([dragon.cur_power, dragon.cur_toughness], [6, 5])


func test_giant_caterpillar_butterfly_arrives_at_the_next_end_step() -> void:
	var caterpillar := put_battlefield(0, "Giant Caterpillar")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, caterpillar, 0, []))
	resolve_stack()
	assert_eq(caterpillar.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].battlefield.size(), 0, "nothing yet")
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(g.players[0].battlefield.size(), 1)
	var butterfly: CardInstance = g.players[0].battlefield[0]
	assert_eq(butterfly.data.card_name, "Butterfly")
	assert_true(butterfly.has_keyword(Mtg.Keyword.FLYING))
	assert_eq([butterfly.cur_power, butterfly.cur_toughness], [1, 1])
	assert_true(butterfly.has_color(Mtg.ManaColor.G))
	assert_true(butterfly.has_subtype("insect"))


func test_kyscu_drake_pumps_once_and_trades_the_pair_for_the_dragon() -> void:
	var kyscu := put_battlefield(0, "Kyscu Drake")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.activate_ability(0, kyscu, 0, []))
	assert_refused(g.activate_ability(0, kyscu, 0, []), "once")
	resolve_stack()
	assert_eq(kyscu.cur_toughness, 3)
	assert_refused(g.activate_ability(0, kyscu, 1, []), "Spitting Drake")
	var spitting := put_battlefield(0, "Spitting Drake")
	var dragon := library_top(0, "Viashivan Dragon")
	g.players[0].library.push_front(g.players[0].library.pop_back())   # buried, not on top
	assert_ok(g.activate_ability(0, kyscu, 1, []))
	assert_eq(kyscu.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(spitting.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(dragon.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(dragon.controller_id, 0)


func test_quirion_druid_animates_a_land_for_good() -> void:
	var druid := put_battlefield(0, "Quirion Druid")
	var land := put_battlefield(1, "Plains")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, druid, 0, [TargetRef.card(land)]))
	resolve_stack()
	assert_true(land.is_creature() and land.is_land())
	assert_eq([land.cur_power, land.cur_toughness], [2, 2])
	assert_eq(land.cur_colors, Mtg.ManaColor.G)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_true(land.is_creature(), "indefinite, not until end of turn")


func test_river_boa_islandwalks_and_regenerates() -> void:
	var boa := put_battlefield(0, "River Boa")
	assert_true(boa.cur_landwalk.has("island"))
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, boa, 0, []))
	resolve_stack()
	g.destroy(boa)
	assert_eq(boa.zone, Mtg.Zone.BATTLEFIELD)


func test_army_ants_trade_a_land_for_a_land() -> void:
	var ants := put_battlefield(0, "Army Ants")
	var mine := put_battlefield(0, "Forest")
	var theirs := put_battlefield(1, "Island")
	assert_ok(g.activate_ability(0, ants, 0, [TargetRef.card(theirs)]))
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD)
	assert_true(ants.tapped)


func test_guiding_spirit_moves_only_a_creature_card_on_top() -> void:
	var spirit := put_battlefield(0, "Guiding Spirit")
	var bear := grave(1, "Grizzly Bears")
	var bolt := grave(1, "Lightning Bolt")
	assert_ok(g.activate_ability(0, spirit, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD, "the top card is not a creature card: nothing happens")
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "a creature card below the top is not reached")
	advance_to_next_turn()
	advance_to_next_turn()
	var giant := grave(1, "Hill Giant")
	assert_ok(g.activate_ability(0, spirit, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[1].library.back(), giant)


func test_mundungu_counters_unless_one_and_one_life_are_paid() -> void:
	var mundungu := put_battlefield(1, "Mundungu")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, mundungu, 0, [TargetRef.card(bolt)]))
	resolve_stack()
	assert_eq(g.players[0].life, 19, "paid 1 life")
	assert_eq(g.players[1].life, 17, "the Bolt resolved")
	advance_to_next_turn()
	advance_to_next_turn()
	var second := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R, 1)
	assert_ok(g.cast_spell(0, second, [TargetRef.player(1)]))
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, mundungu, 0, [TargetRef.card(second)]))
	resolve_stack()
	assert_eq(second.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 17, "no {1} left: countered")
	assert_eq(g.players[0].life, 19, "and no life was taken for nothing")


func test_mundungu_declined_payment_counters() -> void:
	var mundungu := put_battlefield(1, "Mundungu")
	var seat := Seat.new()
	seat.says = false
	g.agents[0] = seat
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R, 3)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, mundungu, 0, [TargetRef.card(bolt)]))
	resolve_stack()
	assert_eq(g.players[1].life, 20)
	assert_eq(g.players[0].life, 20)


func test_chimeras_grow_a_chimera_and_hand_it_their_keyword_for_good() -> void:
	var tin := put_battlefield(0, "Tin-Wing Chimera")
	var lead := put_battlefield(0, "Lead-Belly Chimera")
	var brass := put_battlefield(0, "Brass-Talon Chimera")
	var iron := put_battlefield(0, "Iron-Heart Chimera")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_refused(g.activate_ability(0, tin, 0, [TargetRef.card(bear)]))
	assert_ok(g.activate_ability(0, tin, 0, [TargetRef.card(lead)]))
	resolve_stack()
	assert_eq(tin.zone, Mtg.Zone.GRAVEYARD)
	assert_eq([lead.cur_power, lead.cur_toughness], [4, 4])
	assert_true(lead.has_keyword(Mtg.Keyword.FLYING))
	assert_ok(g.activate_ability(0, brass, 0, [TargetRef.card(lead)]))
	assert_ok(g.activate_ability(0, iron, 0, [TargetRef.card(lead)]))
	resolve_stack()
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq([lead.cur_power, lead.cur_toughness], [8, 8])
	for k in [Mtg.Keyword.FLYING, Mtg.Keyword.FIRST_STRIKE, Mtg.Keyword.VIGILANCE, Mtg.Keyword.TRAMPLE]:
		assert_true(lead.has_keyword(k), "kept keyword %d" % k)


func test_matopi_golem_shrinks_when_it_regenerates_this_way() -> void:
	var golem := put_battlefield(0, "Matopi Golem")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, golem, 0, []))
	assert_ok(g.activate_ability(0, golem, 0, []))
	resolve_stack()
	assert_eq(golem.regeneration_shields, 2)
	g.destroy(golem)
	assert_eq(golem.zone, Mtg.Zone.BATTLEFIELD)
	assert_false(g.stack.is_empty(), "the counter is a trigger")
	resolve_stack()
	assert_eq(int(golem.counters.get("-1/-1", 0)), 1, "one regeneration, one counter")
	g.destroy(golem)
	resolve_stack()
	assert_eq(int(golem.counters.get("-1/-1", 0)), 2)
	assert_eq([golem.cur_power, golem.cur_toughness], [1, 1])


func test_matopi_golem_spends_another_shield_first_and_unused_entries_expire() -> void:
	var golem := put_battlefield(0, "Matopi Golem")
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_ok(g.activate_ability(0, golem, 0, []))
	resolve_stack()
	golem.regeneration_shields += 1   # a shield from some other source
	g.destroy(golem)
	resolve_stack()
	assert_eq(int(golem.counters.get("-1/-1", 0)), 0, "the other shield went first")
	advance_to_next_turn()
	assert_eq(golem.regeneration_shields, 0)
	g.destroy(golem)
	assert_eq(golem.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.stack.is_empty(), "the stale entry expired with its shield")


func test_phyrexian_marauder_counters_cant_block_and_attack_tax() -> void:
	var marauder := cast("Phyrexian Marauder", [], 0, 3)
	assert_eq(int(marauder.counters.get("+1/+1", 0)), 3)
	assert_eq([marauder.cur_power, marauder.cur_toughness], [3, 3])
	assert_false(marauder.cur_cant_block_filter.is_null(), "can't block")
	marauder.summoning_sick = false
	for p in g.players: p.mana_pool.clear()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [marauder.id]))
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.declare_attackers(0, [marauder.id]))
	assert_eq(g.players[0].mana_pool.total(), 0, "{1} per counter was paid")


func test_phyrexian_marauder_for_zero_dies() -> void:
	var marauder := cast("Phyrexian Marauder", [], 0, 0)
	assert_eq(marauder.zone, Mtg.Zone.GRAVEYARD)
