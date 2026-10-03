extends GameTest
## FLANKING (CR 702.25, Pack 8 engine package E2) — the Mirage block's
## knights. "Whenever a creature without flanking blocks this creature, the
## blocking creature gets -1/-1 until end of turn."
##
## A TRIGGERED ability, one per instance (702.25b): [Flanking] keeps the
## live instance count in `cur_keywords` (one FLANKING entry per instance)
## and the continuous pipeline gives a creature one shared flanking trigger
## per entry, so silencing, a loss ("loses flanking", Barbed Foliage) and a
## grant (Agility, Jabari's Banner) all reach the trigger the way they reach
## a printed one. Every trigger goes on the stack, so the blocker can be
## pumped in response. "Blocks this creature" is a per-blocker "becomes
## blocked by a creature" trigger (CR 509.3d) — a band member is blocked by
## the band's blocker (702.22h) and an effect-made block counts, a block
## made by an effect with no creature (Dazzling Beauty) does not.
##
## Synthetic knights only: the cards are the card agents' to write.


static func _knight(name := "Test Knight", power := 2, toughness := 2,
		extra: Array = []) -> CardData:
	var keywords: Array = [Mtg.Keyword.FLANKING]
	keywords.append_array(extra)
	return CardData.new(name, "{2}{W}", Mtg.CardType.CREATURE) \
		.pt(power, toughness).with_keywords(keywords)


## Attack with [param attackers] and declare [param blocks]; stops in the
## declare-blockers step with the flanking triggers on the stack.
func _attack_and_block(attackers: Array, blocks: Dictionary, bands: Array = []) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, attackers, bands))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, blocks))


func _flanking_items() -> Array:
	var out: Array = []
	for item in g.stack:
		if item.kind == Mtg.StackKind.TRIGGER and item.trigger != null \
				and item.trigger.text.begins_with("Flanking"):
			out.append(item)
	return out


# ------------------------------------------------------------ the trigger --

func test_a_non_flanking_blocker_gets_minus_one_from_a_stack_trigger() -> void:
	var knight := put_synthetic(0, _knight())
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_eq(Flanking.instances(knight), 1)
	_attack_and_block([knight.id], {bear.id: knight.id})
	var items := _flanking_items()
	assert_eq(items.size(), 1, "one instance, one blocker: one trigger")
	assert_eq(items[0].card, knight, "the attacker's ability")
	assert_eq(items[0].controller, 0, "controlled by the attacking player")
	assert_eq(bear.cur_power, 2, "nothing happens until it resolves (it uses the stack)")
	resolve_stack()
	assert_eq([bear.cur_power, bear.cur_toughness], [1, 1])
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "the 1/1 bear dies to the 2/2 knight")
	assert_eq(knight.zone, Mtg.Zone.BATTLEFIELD, "and the knight takes only 1")
	assert_eq(knight.damage, 1)


func test_a_flanking_blocker_is_not_shrunk() -> void:
	var knight := put_synthetic(0, _knight())
	var other := put_synthetic(1, _knight("Other Knight"))
	_attack_and_block([knight.id], {other.id: knight.id})
	assert_eq(_flanking_items().size(), 0, "a creature WITH flanking blocks freely")
	resolve_stack()
	assert_eq(other.cur_toughness, 2)


func test_each_blocker_triggers_separately() -> void:
	var knight := put_synthetic(0, _knight("Big Knight", 5, 5))
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	_attack_and_block([knight.id], {bear.id: knight.id, giant.id: knight.id})
	assert_eq(_flanking_items().size(), 2, "one per blocking creature (CR 509.3d)")
	resolve_stack()
	assert_eq([bear.cur_power, bear.cur_toughness], [1, 1])
	assert_eq([giant.cur_power, giant.cur_toughness], [2, 2])


func test_each_instance_triggers_separately() -> void:
	# Printed flanking plus a granted one (Jabari's Banner's shape) is two
	# instances, and CR 702.25b: each triggers.
	var knight := put_synthetic(0, _knight())
	g.continuous.add_until_eot_keywords(knight.id, [Mtg.Keyword.FLANKING])
	g.recalculate()
	assert_eq(Flanking.instances(knight), 2, "a grant is a second instance")
	var giant := put_battlefield(1, "Hill Giant")
	_attack_and_block([knight.id], {giant.id: knight.id})
	assert_eq(_flanking_items().size(), 2)
	resolve_stack()
	assert_eq([giant.cur_power, giant.cur_toughness], [1, 1])


func test_a_pump_grant_and_a_static_grant_are_instances_too() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_eq(Flanking.instances(bear), 0)
	g.continuous.add_until_eot_pump(bear.id, 0, 0, [Mtg.Keyword.FLANKING])
	g.recalculate()
	assert_eq(Flanking.instances(bear), 1, "PumpEffect's keyword list (Jabari's Banner)")
	var aura := CardData.new("Test Agility", "{1}{R}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(func(_g: MtgGame, _s: CardInstance) -> void:
			Flanking.grant(bear), "Test creature has flanking.").changing_abilities())
	put_synthetic(0, aura)
	assert_eq(Flanking.instances(bear), 2, "a layer-6 static grant adds one more")
	assert_eq(bear.cur_triggered_abilities.size(), 2, "one trigger per instance")


func test_losing_flanking_loses_every_instance_and_a_later_grant_is_one() -> void:
	var knight := put_synthetic(0, _knight())
	g.continuous.add_until_eot_keywords(knight.id, [Mtg.Keyword.FLANKING])
	g.continuous.add_until_eot_loss(knight.id, [Mtg.Keyword.FLANKING])   # Barbed Foliage
	g.recalculate()
	assert_eq(Flanking.instances(knight), 0, "\"loses flanking\" takes them all (CR 613.7)")
	assert_false(knight.has_keyword(Mtg.Keyword.FLANKING))
	assert_true(knight.cur_triggered_abilities.is_empty(), "and the trigger with it")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.continuous.add_until_eot_keywords(knight.id, [Mtg.Keyword.FLANKING])
	g.recalculate()
	assert_eq(Flanking.instances(knight), 1, "a grant timestamped after the loss is back")
	_attack_and_block([knight.id], {bear.id: knight.id})
	assert_eq(_flanking_items().size(), 1)


func test_the_flanking_trigger_object_is_stable_across_recalculations() -> void:
	# A rewind compares the live lists by identity (UndoLog/GameSnapshot):
	# the pipeline must hand back the same trigger, not a fresh one.
	var knight := put_synthetic(0, _knight())
	var first: TriggeredAbility = knight.cur_triggered_abilities[0]
	g.recalculate()
	assert_same(knight.cur_triggered_abilities[0], first)


# ------------------------------------------------------- the stack window --

func test_the_blocker_can_be_pumped_in_response() -> void:
	var knight := put_synthetic(0, _knight())
	var bear := put_battlefield(1, "Grizzly Bears")
	var growth := give_hand(1, "Giant Growth")
	_attack_and_block([knight.id], {bear.id: knight.id})
	assert_eq(g.priority_player, 0)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(1, growth, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq([bear.cur_power, bear.cur_toughness], [4, 4], "2/2 +3/+3 -1/-1")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(knight.zone, Mtg.Zone.GRAVEYARD, "the pumped bear wins the fight")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


func test_gaining_flanking_after_the_block_does_not_stop_the_trigger() -> void:
	# CR 509.3f: "without flanking" is read as the creature becomes a
	# blocker; changing it later changes nothing.
	var knight := put_synthetic(0, _knight())
	var bear := put_battlefield(1, "Grizzly Bears")
	_attack_and_block([knight.id], {bear.id: knight.id})
	g.continuous.add_until_eot_keywords(bear.id, [Mtg.Keyword.FLANKING])
	g.recalculate()
	resolve_stack()
	assert_eq(bear.cur_toughness, 1)


func test_a_blocker_that_dies_to_flanking_leaves_the_attacker_blocked() -> void:
	var knight := put_synthetic(0, _knight())
	var elves := put_battlefield(1, "Llanowar Elves")
	_attack_and_block([knight.id], {elves.id: knight.id})
	resolve_stack()
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD, "0 toughness: put into the graveyard (CR 704.5f)")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20, "a blocked creature stays blocked (CR 509.1h)")


func test_a_trampler_whose_blocker_died_to_flanking_tramples_over() -> void:
	var knight := put_synthetic(0, _knight("Trampling Knight", 3, 3, [Mtg.Keyword.TRAMPLE]))
	var elves := put_battlefield(1, "Llanowar Elves")
	_attack_and_block([knight.id], {elves.id: knight.id})
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 17, "all of it to the player (CR 702.19e)")


func test_the_trigger_resolves_after_its_source_has_left() -> void:
	# CR 113.7a: the ability on the stack is independent of its source.
	var knight := put_synthetic(0, _knight())
	var bear := put_battlefield(1, "Grizzly Bears")
	_attack_and_block([knight.id], {bear.id: knight.id})
	g.destroy(knight)
	assert_eq(knight.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(bear.cur_toughness, 1)


func test_a_blocker_that_left_and_came_back_is_a_new_object() -> void:
	# CR 400.7: the -1/-1 was for the creature that blocked.
	var knight := put_synthetic(0, _knight())
	var bear := put_battlefield(1, "Grizzly Bears")
	_attack_and_block([knight.id], {bear.id: knight.id})
	g.return_to_hand(bear)
	g._put_on_battlefield(bear, 1)
	resolve_stack()
	assert_eq(bear.cur_toughness, 2)


func test_a_blocker_phased_out_in_response_is_not_shrunk() -> void:
	# CR 702.26b: a phased-out permanent does not exist; the -1/-1 finds
	# nothing (MtgGame.is_present) and there is nothing to remember.
	var knight := put_synthetic(0, _knight())
	var bear := put_battlefield(1, "Grizzly Bears")
	_attack_and_block([knight.id], {bear.id: knight.id})
	assert_true(g.phase_out(bear))
	resolve_stack()
	assert_true(g.phase_in(bear))
	assert_eq(bear.cur_toughness, 2)


# ------------------------------------------------------ who is "blocked" --

func test_a_band_member_is_blocked_by_the_band_s_blocker() -> void:
	# CR 702.22h: blocking the Hero blocks the whole band, so the knight in
	# it "becomes blocked by" that creature and its flanking triggers.
	var hero := put_battlefield(0, "Benalish Hero")
	var knight := put_synthetic(0, _knight())
	var giant := put_battlefield(1, "Hill Giant")
	_attack_and_block([hero.id, knight.id], {giant.id: hero.id}, [[hero.id, knight.id]])
	assert_eq(_flanking_items().size(), 1)
	resolve_stack()
	assert_eq(giant.cur_toughness, 2)


func test_an_effect_that_makes_a_creature_block_triggers_it() -> void:
	# CR 509.3d: "if an effect causes a creature to block the attacking
	# creature" (False Orders / Sorrow's Path through MtgGame.set_block).
	var knight := put_synthetic(0, _knight())
	var bear := put_battlefield(1, "Grizzly Bears")
	_attack_and_block([knight.id], {})
	g.set_block(bear, knight)
	assert_eq(_flanking_items().size(), 1)
	resolve_stack()
	assert_eq(bear.cur_toughness, 1)


func test_becoming_blocked_by_an_effect_without_a_creature_does_not() -> void:
	# CR 509.3d: "It won't trigger if the creature becomes blocked by an
	# effect rather than a creature" (Dazzling Beauty, MtgGame.make_blocked).
	var knight := put_synthetic(0, _knight())
	put_battlefield(1, "Grizzly Bears")
	_attack_and_block([knight.id], {})
	g.make_blocked(knight)
	assert_eq(_flanking_items().size(), 0)


func test_a_silenced_knight_does_not_trigger() -> void:
	# "Loses all abilities" (Titania's Song's flag): the trigger is still
	# counted on the knight but a silenced permanent hears nothing.
	var knight := put_synthetic(0, _knight())
	put_synthetic(1, CardData.new("Test Song", "{3}{G}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(func(game: MtgGame, _s: CardInstance) -> void:
			for inst in game.all_battlefield():
				if inst.is_creature():
					inst.cur_abilities_silenced = true,
			"Creatures lose all abilities.").silencing_abilities()))
	var bear := put_battlefield(1, "Grizzly Bears")
	_attack_and_block([knight.id], {bear.id: knight.id})
	assert_eq(_flanking_items().size(), 0)


func test_a_stolen_knight_s_trigger_is_its_new_controller_s() -> void:
	var knight := put_synthetic(1, _knight())
	g.change_control(knight, 0)
	knight.summoning_sick = false   # setup: it has been ours all turn
	var bear := put_battlefield(1, "Grizzly Bears")
	_attack_and_block([knight.id], {bear.id: knight.id})
	var items := _flanking_items()
	assert_eq(items.size(), 1)
	assert_eq(items[0].controller, 0, "the attacker's controller controls it")


func test_the_shrink_ends_with_the_turn() -> void:
	var knight := put_synthetic(0, _knight())
	var wurm := put_battlefield(1, "Craw Wurm")
	_attack_and_block([knight.id], {wurm.id: knight.id})
	resolve_stack()
	assert_eq([wurm.cur_power, wurm.cur_toughness], [5, 3])
	advance_to_next_turn()
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq([wurm.cur_power, wurm.cur_toughness], [6, 4], "until end of turn")


# --------------------------------------------------------- undo / profiles --

func test_a_search_rewinds_the_triggers_and_the_shrink() -> void:
	var knight := put_synthetic(0, _knight())
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [knight.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	var mark := g.make_mark()
	assert_ok(g.declare_blockers(1, {bear.id: knight.id}))
	while not g.stack.is_empty():
		g._resolve_top()
	assert_eq(bear.cur_toughness, 1)
	g.unmake_to(mark)
	g.end_search()
	assert_true(g.stack.is_empty(), "the triggers are gone")
	assert_eq(bear.cur_toughness, 2, "and so is the -1/-1")
	assert_true(g.awaiting_blockers, "the declaration is open again")


func test_flanking_is_the_same_under_the_fifth_edition_rules() -> void:
	g.rules.set_edition("fifth")
	var knight := put_synthetic(0, _knight())
	var bear := put_battlefield(1, "Grizzly Bears")
	_attack_and_block([knight.id], {bear.id: knight.id})
	assert_eq(_flanking_items().size(), 1)
	resolve_stack()
	assert_eq(bear.cur_toughness, 1)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(knight.zone, Mtg.Zone.BATTLEFIELD)
