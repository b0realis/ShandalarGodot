extends GameTest
## COMBAT & TRIGGER TARGETING (Pack 8 engine package E9) — four
## capabilities the Mirage block asks for, each pinned on synthetic cards:
##
## * N_make_blocked — "target creature BECOMES BLOCKED" (Dazzling Beauty,
##   Choking Vines): [method MtgGame.make_blocked] / [MakeBlockedEffect].
##   CR 509.1h, 702.19e, 702.22i, 509.3c-d.
## * N_block_life_tax — "can't block creatures you control unless their
##   controller pays 1 life for each blocking creature" (Heat Wave):
##   [method CombatState.add_block_life_tax], paid as blockers are
##   declared (CR 509.1d, 119.4).
## * N_attacks_with_others — "if a creature you control attacks, this
##   creature also attacks if able" (Ekundu Cyclops):
##   [member CardInstance.cur_attacks_if_others_attack] and
##   [method CombatState.attacks_with_others], a CR 508.1d requirement.
## * N_trigger_multi_target — "destroy target creature AND target land"
##   (Goblin Grenadiers): [method TriggeredAbility.and_targeting], one
##   target per slot chosen as the trigger goes on the stack (CR 603.3d),
##   partial fizzle on resolution (CR 608.2b), read back with
##   [method MtgGame.current_trigger_target].

const CombatDeclaration := preload("res://engine/core/combat_declaration.gd")


# ------------------------------------------------------------ the cards --

static func _beauty() -> CardData:
	return CardData.new("Test Beauty", "{2}{W}", Mtg.CardType.INSTANT) \
		.spell(MakeBlockedEffect.new())


static func _vines() -> CardData:
	return CardData.new("Test Vines", "{X}{G}", Mtg.CardType.INSTANT) \
		.spell(MakeBlockedEffect.attacking().then_damage(1).x_targets())


static func _creature(name: String, power: int, toughness: int,
		keywords: Array = [], cost := "{1}{R}") -> CardData:
	return CardData.new(name, cost, Mtg.CardType.CREATURE) \
		.pt(power, toughness).with_keywords(keywords)


static func _heat_wave() -> CardData:
	return CardData.new("Test Heat Wave", "{2}{R}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_tax_blocks,
			"Nonblue creatures can't block creatures you control unless their controller pays 1 life for each blocking creature they control."))


static func _tax_blocks(game: MtgGame, source: CardInstance) -> void:
	for inst in game.players[source.controller_id].battlefield:
		if inst.is_creature():
			CombatState.add_block_life_tax(inst, source, 1, _nonblue, "pay 1 life")


static func _nonblue(blocker: CardInstance) -> bool:
	return not blocker.has_color(Mtg.ManaColor.U)


static func _cyclops() -> CardData:
	return _creature("Test Cyclops", 3, 4) \
		.static_ability(CombatState.attacks_with_others())


static func _grenadiers() -> CardData:
	return _creature("Test Grenadiers", 2, 2, [], "{3}{R}") \
		.triggered(TriggeredAbility.new(Mtg.EventType.UNBLOCKED_ATTACKER,
			_grenade, "Whenever Test Grenadiers attacks and isn't blocked, you may sacrifice it. If you do, destroy target creature and target land.",
			_is_self) \
			.targeting(TargetSpec.creature(), _enemy_first, "Select target creature.") \
			.and_targeting(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _is_land),
				_enemy_first, "Select target land."))


static func _is_self(_g: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


static func _is_land(inst: CardInstance) -> bool:
	return inst.is_land()


static func _enemy_first(game: MtgGame, source: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	var ia := game.find_instance(a.instance_id)
	var ib := game.find_instance(b.instance_id)
	var ea := ia.controller_id != source.controller_id
	var eb := ib.controller_id != source.controller_id
	if ea != eb:
		return ea
	return ia.id < ib.id


static func _grenade(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	if not game.agents[source.controller_id].choose_yes_no(game, source.controller_id,
			"Sacrifice Test Grenadiers?", true):
		return
	game.sacrifice_permanent(source)
	for slot in 2:
		var ref := game.current_trigger_target(slot)
		if ref != null:
			game.destroy(game.find_instance(ref.instance_id))


## "Each creature loses all abilities" — the silencing flag Titania's Song
## raises (CR 613 layer 6).
static func _song() -> CardData:
	return CardData.new("Test Song", "{3}{G}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_silence, "Creatures lose all abilities.") \
			.silencing_abilities())


static func _silence(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_creature():
			inst.cur_abilities_silenced = true


# ------------------------------------------------------------- helpers --

func _in_hand(pid: int, data: CardData) -> CardInstance:
	var inst := CardInstance.new(data, g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	inst.zone = Mtg.Zone.HAND
	g.players[pid].hand.append(inst)
	return inst


func _attack(ids: Array, blocks: Dictionary = {}, bands: Array = []) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, ids, bands))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, blocks))
	resolve_stack()


## Seat 1 casts [param card] with [param targets] in the declare-blockers
## step (seat 0 passes to it first).
func _defender_casts(card: CardInstance, targets: Array, x := 0) -> String:
	if g.priority_player == 0:
		assert_ok(g.pass_priority(0))
	return g.cast_spell(1, card, targets, x)


func _events(type: int) -> Array:
	var seen: Array = []
	g.event_occurred.connect(func(e: GameEvent) -> void:
		if e.type == type: seen.append(e))
	return seen


# ===================================================== N_make_blocked ==

func test_an_unblocked_attacker_becomes_blocked_and_deals_no_damage() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var beauty := _in_hand(1, _beauty())
	var became := _events(Mtg.EventType.BECOMES_BLOCKED)
	_attack([bear.id])
	add_mana(1, Mtg.ManaColor.W, 3)
	assert_ok(_defender_casts(beauty, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(g.combat.was_blocked([bear.id]), "it is a blocked creature (CR 509.1h)")
	assert_eq(became.size(), 1, "BECOMES_BLOCKED fired once (CR 509.3c)")
	assert_true(g.combat.blockers_of(bear.id).is_empty(), "with no creature blocking it")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20, "a blocked creature with no blocker deals no damage")


func test_it_works_on_a_creature_that_can_t_be_blocked() -> void:
	var ghost := put_synthetic(0, _creature("Test Ghost", 3, 3, [Mtg.Keyword.UNBLOCKABLE]))
	_attack([ghost.id])
	assert_true(g.make_blocked(ghost), "unblockable restricts DECLARING blockers only")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20)


func test_a_trampler_made_blocked_assigns_everything_to_the_player() -> void:
	var mammoth := put_battlefield(0, "War Mammoth")
	_attack([mammoth.id])
	assert_true(g.make_blocked(mammoth))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 17, "CR 702.19e: no blockers to assign to, all to the player")


func test_a_trampler_made_blocked_tramples_over_under_the_fifth_edition_too() -> void:
	g.rules.set_edition("fifth")
	var mammoth := put_battlefield(0, "War Mammoth")
	var bear := put_battlefield(0, "Grizzly Bears")
	_attack([mammoth.id, bear.id])
	assert_true(g.make_blocked(mammoth))
	assert_true(g.make_blocked(bear))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 17, "the trampler's 3; the bear's 2 is stopped")


func test_only_an_unblocked_attacking_creature_is_a_legal_target() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var home := put_battlefield(0, "Llanowar Elves")
	var wall := put_battlefield(1, "Hill Giant")
	_attack([bear.id, giant.id], {wall.id: giant.id})
	var spec := MakeBlockedEffect.unblocked_attacker_spec()
	var beauty := _in_hand(1, _beauty())
	assert_true(spec.is_legal(g, TargetRef.card(bear), beauty))
	assert_false(spec.is_legal(g, TargetRef.card(giant), beauty), "already blocked")
	assert_false(spec.is_legal(g, TargetRef.card(home), beauty), "not attacking")
	assert_true(MakeBlockedEffect.attacker_spec().is_legal(g, TargetRef.card(giant), beauty),
		"Choking Vines' spec takes a blocked attacker too")
	assert_false(g.make_blocked(giant), "already blocked: nothing changes")
	assert_false(g.make_blocked(home), "not an attacker: nothing changes")


func test_a_band_becomes_blocked_as_a_whole() -> void:
	var hero := put_battlefield(0, "Benalish Hero")
	var bear := put_battlefield(0, "Grizzly Bears")
	var became := _events(Mtg.EventType.BECOMES_BLOCKED)
	var paired := _events(Mtg.EventType.BLOCKED)
	_attack([hero.id, bear.id], {}, [[hero.id, bear.id]])
	assert_true(g.make_blocked(bear))
	assert_true(g.combat.blocked_attackers.has(hero.id), "CR 702.22i: the entire band")
	assert_eq(became.size(), 2, "each member becomes blocked")
	assert_eq(paired.size(), 0, "no creature blocked it: no BLOCKED pair (CR 509.3d)")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20)


func test_x_target_attacking_creatures_become_blocked_and_take_damage() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var elves := put_battlefield(0, "Llanowar Elves")
	var giant := put_battlefield(0, "Hill Giant")
	var card := _in_hand(1, _vines())
	_attack([bear.id, elves.id, giant.id])
	add_mana(1, Mtg.ManaColor.G, 3)
	assert_ok(_defender_casts(card, [TargetRef.card(bear), TargetRef.card(elves)], 2))
	resolve_stack()
	assert_true(g.combat.was_blocked([bear.id]))
	assert_eq(bear.damage, 1, "Choking Vines deals 1 damage to each of those creatures")
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)
	assert_false(g.combat.was_blocked([giant.id]))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 17, "only the untargeted giant connects")


func test_protection_refuses_the_target() -> void:
	var knight := put_synthetic(0, _creature("Test Pro-White", 2, 2) \
		.with_protection_from(Mtg.ManaColor.W))
	_attack([knight.id])
	var beauty := _in_hand(1, _beauty())
	assert_false(MakeBlockedEffect.unblocked_attacker_spec().is_legal(g,
		TargetRef.card(knight), beauty), "a white spell can't target it")


func test_a_search_rewinds_make_blocked() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	_attack([bear.id])
	var mark := g.make_mark()
	assert_true(g.make_blocked(bear))
	g.unmake_to(mark)
	g.end_search()
	assert_false(g.combat.was_blocked([bear.id]))


# ===================================================== N_block_life_tax ==

func test_a_taxed_block_costs_one_life_per_blocking_creature() -> void:
	put_synthetic(0, _heat_wave())
	var giant := put_battlefield(0, "Craw Wurm")
	var bear := put_battlefield(1, "Grizzly Bears")
	var elves := put_battlefield(1, "Llanowar Elves")
	_attack([giant.id], {bear.id: giant.id, elves.id: giant.id})
	assert_eq(g.players[1].life, 18, "two blocking creatures, 1 life each")
	assert_eq(g.combat.blockers_of(giant.id).size(), 2)


func test_a_blue_blocker_owes_nothing() -> void:
	put_synthetic(0, _heat_wave())
	var giant := put_battlefield(0, "Hill Giant")
	var merfolk := put_synthetic(1, _creature("Test Merfolk", 1, 1, [], "{U}"))
	_attack([giant.id], {merfolk.id: giant.id})
	assert_eq(g.players[1].life, 20)


func test_a_blocker_owes_each_source_once_however_many_it_blocks() -> void:
	put_synthetic(0, _heat_wave())
	put_synthetic(0, _heat_wave())
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var twin := put_synthetic(1, _creature("Test Two-Headed", 4, 4).with_extra_blocks(1))
	_attack([bear.id, giant.id], {twin.id: [bear.id, giant.id]})
	assert_eq(g.players[1].life, 18, "two Heat Waves, one blocking creature: 2 life")


func test_not_enough_life_refuses_the_whole_declaration() -> void:
	put_synthetic(0, _heat_wave())
	var giant := put_battlefield(0, "Craw Wurm")
	var bear := put_battlefield(1, "Grizzly Bears")
	var elves := put_battlefield(1, "Llanowar Elves")
	g.players[1].life = 1
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {bear.id: giant.id, elves.id: giant.id}),
		"not enough life")
	assert_eq(g.players[1].life, 1, "a refusal pays nothing")
	assert_true(g.awaiting_blockers)
	assert_true(g.combat.blocks.is_empty())
	assert_ok(g.declare_blockers(1, {bear.id: giant.id}))
	assert_eq(g.players[1].life, 0, "1 life may pay 1 (CR 119.4)")


func test_zero_life_cannot_pay_and_the_block_is_illegal() -> void:
	put_synthetic(0, _heat_wave())
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.players[1].life = 0   # no state-based check runs before the question
	assert_ne(CombatState.block_illegality(g, bear, giant, 1), "",
		"a block whose life cannot be paid is not legal")


func test_a_creature_that_must_block_is_not_made_to_pay() -> void:
	put_synthetic(0, _heat_wave())
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	bear.must_block_this_turn = true
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))   # "CR 509.1c: a requirement never forces a cost"


func test_the_ai_repair_keeps_a_declaration_it_can_pay_for() -> void:
	put_synthetic(0, _heat_wave())
	var giant := put_battlefield(0, "Craw Wurm")
	var bear := put_battlefield(1, "Grizzly Bears")
	var elves := put_battlefield(1, "Llanowar Elves")
	g.players[1].life = 2
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	var repaired: Dictionary = CombatDeclaration.repair_blocks(g, 1,
		{bear.id: giant.id, elves.id: giant.id})
	assert_lt(CombatDeclaration.block_life_fee(g, repaired), 2,
		"never pays its last life point to block")
	assert_ok(g.declare_blockers(1, repaired))


func test_a_search_rewinds_the_life_paid() -> void:
	put_synthetic(0, _heat_wave())
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	var mark := g.make_mark()
	assert_ok(g.declare_blockers(1, {bear.id: giant.id}))
	assert_eq(g.players[1].life, 19)
	g.unmake_to(mark)
	g.end_search()
	assert_eq(g.players[1].life, 20)
	assert_true(g.awaiting_blockers)


# ================================================ N_attacks_with_others ==

func test_the_cyclops_attacks_if_another_creature_does() -> void:
	var cyclops := put_synthetic(0, _cyclops())
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_true(cyclops.cur_attacks_if_others_attack)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [bear.id]), "Test Cyclops")
	assert_true(g.awaiting_attackers, "the refusal changed nothing")
	assert_eq(g.combat.attackers.size(), 0)
	assert_ok(g.declare_attackers(0, [bear.id, cyclops.id]))


func test_no_attack_and_the_cyclops_alone_are_both_legal() -> void:
	var cyclops := put_synthetic(0, _cyclops())
	put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	var mark := g.make_mark()
	assert_ok(g.declare_attackers(0, []))   # "nothing attacks: the condition never arises"
	g.unmake_to(mark)
	g.end_search()
	assert_ok(g.declare_attackers(0, [cyclops.id]))


func test_a_cyclops_that_can_t_attack_is_excused() -> void:
	var cyclops := put_synthetic(0, _cyclops())
	cyclops.summoning_sick = true
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))


func test_a_cyclops_with_an_attack_cost_is_not_made_to_pay() -> void:
	var cyclops := put_synthetic(0, _cyclops() \
		.static_ability(StaticAbility.new(func(_g: MtgGame, s: CardInstance) -> void:
			s.cur_attack_costs.append({"desc": "you pay {9}",
				"can_pay": func(_gg: MtgGame, _p: int) -> bool: return false,
				"pay": func(_gg: MtgGame, _p: int) -> void: pass}), "Test tax.")))
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))   # "CR 508.1d: costs are never required"
	assert_false(cyclops.attacked_this_turn)


func test_a_cap_on_attackers_lets_either_creature_attack() -> void:
	var cyclops := put_synthetic(0, _cyclops())
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	g.max_attackers = 1   # setup (Caverns of Despair's shape)
	assert_refused(g.declare_attackers(0, [bear.id]), "Test Cyclops")
	assert_ok(g.declare_attackers(0, [cyclops.id]))   # "the most requirements the cap allows"


func test_the_ai_repair_brings_the_cyclops_along() -> void:
	var cyclops := put_synthetic(0, _cyclops())
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	var repaired: Array = CombatDeclaration.repair_attacks(g, 0, [bear.id])
	assert_true(repaired.has(cyclops.id))
	assert_true(repaired.has(bear.id))
	assert_ok(g.declare_attackers(0, repaired))


func test_the_requirement_is_the_same_under_the_fifth_edition() -> void:
	g.rules.set_edition("fifth")
	var cyclops := put_synthetic(0, _cyclops())
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [bear.id]))
	assert_ok(g.declare_attackers(0, [bear.id, cyclops.id]))


func test_a_silenced_cyclops_has_no_requirement() -> void:
	var cyclops := put_synthetic(0, _cyclops())
	var bear := put_battlefield(0, "Grizzly Bears")
	put_synthetic(1, _song())
	assert_false(cyclops.cur_attacks_if_others_attack, "a live value, rebuilt each pass")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))


# ================================================ N_trigger_multi_target ==

func test_both_targets_are_chosen_as_the_trigger_goes_on() -> void:
	var grenadiers := put_synthetic(0, _grenadiers())
	put_battlefield(0, "Forest")
	var bear := put_battlefield(1, "Grizzly Bears")
	var island := put_battlefield(1, "Island")
	_attack_unresolved([grenadiers.id])
	var item: StackItem = g.stack.back()
	assert_eq(item.trigger.target_slot_count(), 2)
	assert_eq(item.targets.size(), 2, "one target per slot")
	assert_true(item.targets[0].same_object(TargetRef.card(bear)), "slot 0: target creature")
	assert_true(item.targets[1].same_object(TargetRef.card(island)), "slot 1: target land")
	assert_eq(item.target_groups.size(), 2, "grouped per slot")
	assert_true(item.description.contains("Grizzly Bears") and item.description.contains("Island"))


func test_the_trigger_destroys_both_after_the_sacrifice() -> void:
	var grenadiers := put_synthetic(0, _grenadiers())
	var bear := put_battlefield(1, "Grizzly Bears")
	var island := put_battlefield(1, "Island")
	_attack_unresolved([grenadiers.id])
	resolve_stack()
	assert_eq(grenadiers.zone, Mtg.Zone.GRAVEYARD, "sacrificed")
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(island.zone, Mtg.Zone.GRAVEYARD)


func test_no_legal_land_means_no_trigger() -> void:
	var grenadiers := put_synthetic(0, _grenadiers())
	put_battlefield(1, "Grizzly Bears")
	_attack_unresolved([grenadiers.id])
	assert_true(g.stack.is_empty(), "every target is required (CR 603.3d)")


func test_the_same_object_may_fill_both_slots() -> void:
	# CR 115.3: once per instance of the word "target".
	var grenadiers := put_synthetic(0, _grenadiers())
	var dryad := put_synthetic(1, CardData.new("Test Dryad Land",
		"", Mtg.CardType.LAND | Mtg.CardType.CREATURE).pt(1, 1))
	_attack_unresolved([grenadiers.id])
	var item: StackItem = g.stack.back()
	assert_true(item.targets[0].same_object(TargetRef.card(dryad)))
	assert_true(item.targets[1].same_object(TargetRef.card(dryad)))


func test_one_illegal_target_does_not_stop_the_other() -> void:
	var grenadiers := put_synthetic(0, _grenadiers())
	var bear := put_battlefield(1, "Grizzly Bears")
	var island := put_battlefield(1, "Island")
	_attack_unresolved([grenadiers.id])
	g.return_to_hand(bear)
	resolve_stack()
	assert_eq(grenadiers.zone, Mtg.Zone.GRAVEYARD, "it still resolves (CR 608.2b)")
	assert_eq(island.zone, Mtg.Zone.GRAVEYARD, "and the land is destroyed")
	assert_eq(bear.zone, Mtg.Zone.HAND)


func test_every_target_illegal_fizzles_without_the_sacrifice() -> void:
	var grenadiers := put_synthetic(0, _grenadiers())
	var bear := put_battlefield(1, "Grizzly Bears")
	var island := put_battlefield(1, "Island")
	_attack_unresolved([grenadiers.id])
	g.return_to_hand(bear)
	g.return_to_hand(island)
	resolve_stack()
	assert_eq(grenadiers.zone, Mtg.Zone.BATTLEFIELD, "a fizzled trigger does nothing")


func test_a_human_seat_answers_each_slot_in_turn() -> void:
	var human := HumanAgent.new()
	g.agents[0] = human
	g.interactive_choices = true
	var grenadiers := put_synthetic(0, _grenadiers())
	put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	put_battlefield(1, "Island")
	var swamp := put_battlefield(1, "Swamp")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [grenadiers.id]))
	_pass_until_blockers()
	assert_ok(g.declare_blockers(1, {}))
	assert_not_null(g.awaiting_choice, "held on the first slot at priority")
	assert_eq(g.awaiting_choice.prompt, "Select target creature.")
	assert_ok(g.answer_choice("Hill Giant"))
	assert_not_null(g.awaiting_choice, "then the second slot")
	assert_eq(g.awaiting_choice.prompt, "Select target land.")
	assert_ok(g.answer_choice("Swamp"))
	assert_null(g.awaiting_choice)
	var item: StackItem = g.stack.back()
	assert_false(item.target_held)
	assert_true(item.targets[0].same_object(TargetRef.card(giant)))
	assert_true(item.targets[1].same_object(TargetRef.card(swamp)))


func test_a_search_rewinds_the_multi_target_trigger() -> void:
	var grenadiers := put_synthetic(0, _grenadiers())
	var bear := put_battlefield(1, "Grizzly Bears")
	var island := put_battlefield(1, "Island")
	_attack_unresolved([grenadiers.id])
	var mark := g.make_mark()
	while not g.stack.is_empty():
		g._resolve_top()
	g.check_state_based_actions()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	g.unmake_to(mark)
	g.end_search()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(island.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(grenadiers.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.stack.size(), 1)


## Attack and declare no blocks, leaving the "isn't blocked" trigger on
## the stack.
func _attack_unresolved(ids: Array) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, ids))
	_pass_until_blockers()
	assert_ok(g.declare_blockers(1, {}))


func _pass_until_blockers() -> void:
	var guard := 0
	while not g.awaiting_blockers and guard < 20:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
