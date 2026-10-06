extends GameTest
## Pack 9 engine package E7 — the COST AND TARGET VOCABULARY the Tempest
## block prints that the engine did not have.
##
## Every capability is pinned on SYNTHETIC cards built in this file, so the
## mechanism is tested apart from any one card script (the card batches'
## own tests quote the oracle text):
##   * random_discard — "As an additional cost to cast this spell, discard
##     a card at random" (Sonic Burst; Flowstone Flood's buyback row);
##   * library_top    — "Put a card from your hand on top of your library:"
##     (Penance, Hidden Retreat);
##   * remove_counter — "Remove a +1/+1 counter from a creature you
##     control:" (Spike Rogue);
##   * the ability-cost FLOOR — "Activated abilities of creatures cost {1}
##     less to activate. This effect can't reduce the mana in that cost to
##     less than one mana." (Heartstone, CR 601.2f, 602.2b);
##   * a DYNAMIC target count — "up to X target cards …, where X is the
##     number of black permanents target opponent controls" (Reap, 601.2c);
##   * a trigger whose target ANOTHER player chooses — "that creature's
##     controller may have it deal damage … to any target of their choice"
##     (Pandemonium, CR 603.3d);
##   * retargeting an ABILITY — "Change the target of target spell or
##     ability that targets only this creature" (Silver Wyvern, CR 115.7).
## CR 601.2h/602.2b: a refused cost asks nothing and changes nothing.

const OC := preload("res://engine/additional_object_costs.gd")


func before_each() -> void:
	super()
	advance_to_step(Mtg.Step.MAIN1)


# ----------------------------------------------------------------- helpers --

func _card_in(pid: int, data: CardData, zone: int) -> CardInstance:
	var inst := CardInstance.new(data, g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	inst.zone = zone
	match zone:
		Mtg.Zone.HAND: g.players[pid].hand.append(inst)
		Mtg.Zone.GRAVEYARD: g.players[pid].graveyard.append(inst)
		Mtg.Zone.LIBRARY: g.players[pid].library.append(inst)
	return inst


func _named_in(pid: int, card_name: String, zone: int) -> CardInstance:
	return _card_in(pid, CardRegistry.get_card(card_name), zone)


func _human_seat(pid := 0) -> HumanAgent:
	var human := HumanAgent.new()
	g.agents[pid] = human
	g.interactive_choices = true
	return human


static func _creature(c: CardInstance) -> bool:
	return c.is_creature()


## Sonic Burst's shape.
func _burst() -> CardData:
	return CardData.new("Synthetic Burst", "{1}{R}", Mtg.CardType.INSTANT) \
		.spell(DamageEffect.new(4).any_target()) \
		.with_object_cost(OC.discarding_at_random()) \
		.oracle("As an additional cost to cast this spell, discard a card at random. Synthetic Burst deals 4 damage to any target.")


## A spell paying a CHOSEN discard and a RANDOM one — the two must take
## different cards (the disjoint assignment, CR 601.2h).
func _double_discard() -> CardData:
	return CardData.new("Synthetic Purge", "{R}", Mtg.CardType.SORCERY) \
		.spell(DamageEffect.new(1).any_target()) \
		.with_object_cost(OC.discarding()) \
		.with_object_cost(OC.discarding_at_random()) \
		.oracle("As an additional cost to cast this spell, discard a card and discard a card at random.")


## Flowstone Flood's buyback shape, as a payment row: pay 3 life, discard
## a card at random (E2 builds the real buyback row on the same group).
func _flood() -> CardData:
	return CardData.new("Synthetic Flood", "{3}{R}", Mtg.CardType.SORCERY) \
		.spell(DamageEffect.new(1).any_target()) \
		.with_alternative_cost("Pay 3 life, discard a card at random",
			{"mana": "{3}{R}", "life": 3, "object_costs": [OC.discarding_at_random()]}) \
		.oracle("...")


## Penance's shape: "Put a card from your hand on top of your library:
## <effect>."
func _penance() -> CardData:
	var ability := ActivatedAbility.new("", false, [GainLifeEffect.new(1)],
		"Put a card from your hand on top of your library: You gain 1 life.") \
		.with_object_cost(OC.putting_on_top())
	return CardData.new("Synthetic Penance", "{2}{W}", Mtg.CardType.ENCHANTMENT) \
		.activated(ability).oracle("Put a card from your hand on top of your library: You gain 1 life.")


## A spell paying "put a card from your hand on top of your library" as an
## additional cost — the spell itself can never pay it.
func _top_spell() -> CardData:
	return CardData.new("Synthetic Restack", "{W}", Mtg.CardType.INSTANT) \
		.spell(GainLifeEffect.new(1)) \
		.with_object_cost(OC.putting_on_top()) \
		.oracle("As an additional cost, put a card from your hand on top of your library. You gain 1 life.")


## Spike Rogue's second ability: "{2}, Remove a +1/+1 counter from a
## creature you control: <effect>." (The effect is a plain life gain here;
## the cost is what is pinned.)
func _rogue(toughness := 1, counters := 0) -> CardData:
	var ability := ActivatedAbility.new("{2}", false, [GainLifeEffect.new(1)],
		"{2}, Remove a +1/+1 counter from a creature you control: You gain 1 life.") \
		.with_object_cost(OC.removing_counter("+1/+1", "creature you control", _creature))
	var data := CardData.new("Synthetic Rogue", "{1}{G}{G}", Mtg.CardType.CREATURE).pt(0, toughness) \
		.activated(ability).oracle("{2}, Remove a +1/+1 counter from a creature you control: You gain 1 life.")
	if counters > 0:
		data.with_enters_counters("+1/+1", counters)
	return data


## A spy seat: counts every question it is asked and answers with fixed
## picks by name (cards) or label (options).
class SpySeat extends DecisionAgent:
	var asked: Array[String] = []
	var picks: Array = []
	var option_label := ""

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		asked.append(prompt)
		if not picks.is_empty():
			var wanted := String(picks.pop_front())
			for inst in candidates:
				if inst.data.card_name == wanted:
					return inst
		return candidates[0] if not candidates.is_empty() else null

	func answer_option(_game: MtgGame, _pid: int, prompt: String,
			options: Array[String], hint: int) -> int:
		asked.append(prompt)
		if option_label != "":
			for i in options.size():
				if options[i] == option_label:
					return i
		return hint

	func answer_discard(game: MtgGame, pid: int, count: int) -> Array[CardInstance]:
		asked.append("discard")
		return super.answer_discard(game, pid, count)


# ----------------------------------------------------------- random_discard --

func test_random_discard_is_refused_with_no_other_card_and_changes_nothing() -> void:
	var burst := give_synthetic(0, _burst())
	add_mana(0, Mtg.ManaColor.R, 2)
	var spy := SpySeat.new()
	g.agents[0] = spy
	assert_refused(g.cast_spell(0, burst, [TargetRef.player(1)]))
	assert_eq(burst.zone, Mtg.Zone.HAND, "the spell cannot pay for itself")
	assert_eq(g.players[0].mana_pool.total(), 2, "no mana spent")
	assert_true(g.stack.is_empty())
	assert_eq(spy.asked, [] as Array[String], "a refused cost asks nothing")
	assert_eq(OC.refusal(g, 0, burst.data.object_costs, burst) != "", true)


func test_random_discard_pays_on_the_seeded_rng_and_asks_nobody() -> void:
	var burst := give_synthetic(0, _burst())
	var a := give_hand(0, "Grizzly Bears")
	var b := give_hand(0, "Hill Giant")
	var c := give_hand(0, "Llanowar Elves")
	var spy := SpySeat.new()
	g.agents[0] = spy
	add_mana(0, Mtg.ManaColor.R, 2)
	var mark := g.make_mark()
	assert_ok(g.cast_spell(0, burst, [TargetRef.player(1)]))
	var first: Array[String] = []
	for card in [a, b, c]:
		if card.zone == Mtg.Zone.GRAVEYARD: first.append(card.data.card_name)
	assert_eq(first.size(), 1, "exactly one card discarded")
	assert_eq(burst.zone, Mtg.Zone.STACK, "never the spell itself")
	var receipt: Array = g.stack[-1].cost_paid["_object_costs"]
	assert_eq(receipt.size(), 1)
	assert_eq(String(receipt[0]["operation"]), "discard")
	assert_eq(String(receipt[0]["name"]), first[0])
	assert_eq(spy.asked, [] as Array[String], "at random: nobody chooses")
	# The roll is the game's seeded RNG: rewound, the same card goes again.
	g.unmake_to(mark)
	g.end_search()
	if g.players[0].mana_pool.total() == 0:
		add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, burst, [TargetRef.player(1)]))
	var second: Array[String] = []
	for card in [a, b, c]:
		if card.zone == Mtg.Zone.GRAVEYARD: second.append(card.data.card_name)
	assert_eq(second, first, "same seed, same discard")


func test_random_discard_never_holds_a_human_seat() -> void:
	var burst := give_synthetic(0, _burst())
	give_hand(0, "Grizzly Bears")
	_human_seat(0)
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, burst, [TargetRef.player(1)]))
	assert_null(g.awaiting_choice, "no question to hold on")
	assert_eq(burst.zone, Mtg.Zone.STACK)
	assert_eq(g.players[0].hand.size(), 0)


func test_chosen_and_random_discards_take_distinct_cards() -> void:
	var purge := give_synthetic(0, _double_discard())
	var a := give_hand(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(0, purge, [TargetRef.player(1)]))
	assert_eq(a.zone, Mtg.Zone.HAND, "one card cannot pay both")
	assert_eq(g.players[0].mana_pool.total(), 1)
	var b := give_hand(0, "Hill Giant")
	var spy := SpySeat.new()
	spy.picks = ["Hill Giant"]
	g.agents[0] = spy
	assert_ok(g.cast_spell(0, purge, [TargetRef.player(1)]))
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD, "the chosen discard")
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD, "the random one took the other card")
	assert_eq(spy.asked.size(), 1, "only the chosen discard was asked")


func test_random_discard_rides_an_alternative_payment_row() -> void:
	var flood := give_synthetic(0, _flood())
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 3)
	# Row 1 (the life + random discard row) needs a card besides the spell.
	assert_refused(g.cast_spell(0, flood, [TargetRef.player(1)], 0, 1))
	assert_eq(g.players[0].life, 20, "refused: no life paid")
	var a := give_hand(0, "Grizzly Bears")
	assert_ok(g.cast_spell(0, flood, [TargetRef.player(1)], 0, 1))
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 17)


func test_random_discard_as_an_ability_cost() -> void:
	var ability := ActivatedAbility.new("", false, [GainLifeEffect.new(2)], "Discard a card at random: You gain 2 life.") \
		.with_object_cost(OC.discarding_at_random())
	var source := put_synthetic(0, CardData.new("Synthetic Totem", "{1}", Mtg.CardType.ARTIFACT)
		.activated(ability).oracle("Discard a card at random: You gain 2 life."))
	assert_refused(g.activate_ability(0, source, 0))
	var a := give_hand(0, "Grizzly Bears")
	assert_ok(g.activate_ability(0, source, 0))
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[0].life, 22)


# -------------------------------------------------------------- library_top --

func test_library_top_cost_is_refused_with_an_empty_hand() -> void:
	var penance := put_synthetic(0, _penance())
	var top_before: CardInstance = g.players[0].library[-1]
	assert_refused(g.activate_ability(0, penance, 0))
	assert_true(g.stack.is_empty())
	assert_eq(g.players[0].library[-1], top_before, "the library is untouched")


func test_library_top_cost_puts_the_chosen_card_on_top() -> void:
	var penance := put_synthetic(0, _penance())
	var a := give_hand(0, "Grizzly Bears")
	var b := give_hand(0, "Hill Giant")
	var spy := SpySeat.new()
	spy.picks = ["Hill Giant"]
	g.agents[0] = spy
	var size_before: int = g.players[0].library.size()
	assert_ok(g.activate_ability(0, penance, 0))
	assert_eq(b.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[0].library[-1], b, "on TOP of the library")
	assert_eq(g.players[0].library.size(), size_before + 1)
	assert_eq(a.zone, Mtg.Zone.HAND)
	assert_eq(spy.asked.size(), 1)
	assert_string_contains(spy.asked[0], "top of your library")
	var receipt: Array = g.stack[-1].cost_paid["_object_costs"]
	assert_eq(String(receipt[0]["operation"]), "library_top")
	resolve_stack()
	assert_eq(g.players[0].life, 21)


func test_library_top_cost_holds_a_human_seat_before_anything_moves() -> void:
	var penance := put_synthetic(0, _penance())
	var a := give_hand(0, "Grizzly Bears")
	var b := give_hand(0, "Hill Giant")
	_human_seat(0)
	assert_ok(g.activate_ability(0, penance, 0))
	assert_not_null(g.awaiting_choice, "held on the cost question")
	assert_true(g.awaiting_choice.is_cost)
	assert_eq(g.awaiting_choice.pid, 0)
	assert_eq(g.awaiting_choice.candidates.size(), 2)
	assert_string_contains(g.awaiting_choice.prompt, "top of your library")
	assert_eq(a.zone, Mtg.Zone.HAND)
	assert_eq(b.zone, Mtg.Zone.HAND)
	assert_true(g.stack.is_empty(), "nothing on the stack while held")
	assert_ok(g.answer_choice("Hill Giant"))
	assert_null(g.awaiting_choice)
	assert_eq(g.players[0].library[-1], b)
	assert_eq(g.stack.size(), 1)


func test_a_spell_never_puts_itself_on_top_for_its_own_cost() -> void:
	var spell := give_synthetic(0, _top_spell())
	add_mana(0, Mtg.ManaColor.W)
	assert_refused(g.cast_spell(0, spell))
	assert_eq(spell.zone, Mtg.Zone.HAND)
	var a := give_hand(0, "Grizzly Bears")
	assert_ok(g.cast_spell(0, spell))
	assert_eq(g.players[0].library[-1], a)
	assert_eq(spell.zone, Mtg.Zone.STACK)


# ----------------------------------------------------------- remove_counter --

func test_remove_counter_cost_needs_a_counter_on_a_creature_you_control() -> void:
	var rogue := put_synthetic(0, _rogue(1))
	var theirs := put_battlefield(1, "Grizzly Bears")
	g.add_counters(theirs, "+1/+1", 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, rogue, 0))
	assert_eq(int(theirs.counters.get("+1/+1", 0)), 2, "an opponent's counters are not yours")
	assert_eq(g.players[0].mana_pool.total(), 2, "refused before the mana")
	assert_true(g.stack.is_empty())
	assert_ne(g.ability_announce_refusal(0, rogue, 0), "", "the announcement refuses too")


func test_remove_counter_cost_takes_one_counter_from_the_chosen_creature() -> void:
	var rogue := put_synthetic(0, _rogue(1))
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	g.add_counters(bear, "+1/+1", 2)
	g.add_counters(giant, "+1/+1", 1)
	var spy := SpySeat.new()
	spy.picks = ["Hill Giant"]
	g.agents[0] = spy
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_eq(g.ability_announce_refusal(0, rogue, 0), "")
	assert_ok(g.activate_ability(0, rogue, 0))
	assert_eq(int(giant.counters.get("+1/+1", 0)), 0, "the chosen creature paid")
	assert_eq(int(bear.counters.get("+1/+1", 0)), 2)
	assert_eq(giant.cur_power, 3, "back to a 3/3 at once")
	assert_eq(spy.asked.size(), 1)
	assert_string_contains(spy.asked[0], "+1/+1")
	var receipt: Array = g.stack[-1].cost_paid["_object_costs"]
	assert_eq(String(receipt[0]["operation"]), "remove_counter")


func test_the_source_may_pay_its_own_remove_counter_cost_and_a_response_cannot_reuse_it() -> void:
	var rogue := put_synthetic(0, _rogue(3))
	g.add_counters(rogue, "+1/+1", 1)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, rogue, 0))
	assert_eq(int(rogue.counters.get("+1/+1", 0)), 0, "removed at activation")
	assert_refused(g.activate_ability(0, rogue, 0))
	assert_eq(g.stack.size(), 1)
	assert_eq(g.players[0].mana_pool.total(), 2, "the second activation spent nothing")


func test_a_zero_toughness_payer_dies_after_the_activation_not_during_it() -> void:
	var rogue := put_synthetic(0, _rogue(0, 1))
	assert_eq(rogue.zone, Mtg.Zone.BATTLEFIELD, "a 1/1 with its counter")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, rogue, 0))
	assert_eq(g.stack.size(), 1, "the ability is on the stack, its cost paid whole")
	assert_eq(rogue.cur_toughness, 0, "the payment recomputed the 0/0")
	resolve_stack()
	assert_eq(rogue.zone, Mtg.Zone.GRAVEYARD, "the 0/0 died to a state-based action")
	assert_eq(g.players[0].life, 21, "and the ability resolved without its source")


func test_remove_counter_cost_holds_a_human_seat() -> void:
	var rogue := put_synthetic(0, _rogue(1))
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	g.add_counters(bear, "+1/+1", 1)
	g.add_counters(giant, "+1/+1", 1)
	_human_seat(0)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, rogue, 0))
	assert_not_null(g.awaiting_choice)
	assert_true(g.awaiting_choice.is_cost)
	assert_eq(g.awaiting_choice.candidates.size(), 2, "only creatures with the counter")
	assert_eq(int(bear.counters.get("+1/+1", 0)), 1, "nothing removed while held")
	assert_eq(g.players[0].mana_pool.total(), 2)
	assert_ok(g.answer_choice(giant.id))
	assert_eq(int(giant.counters.get("+1/+1", 0)), 0)
	assert_eq(int(bear.counters.get("+1/+1", 0)), 1)


# ------------------------------------------------------- ability cost floor --

## Heartstone's shape.
func _heartstone() -> CardData:
	return CardData.new("Synthetic Heartstone", "{3}", Mtg.CardType.ARTIFACT) \
		.with_ability_cost_reduction(1, _creature_ability, 1) \
		.oracle("Activated abilities of creatures cost {1} less to activate. This effect can't reduce the mana in that cost to less than one mana.")


static func _creature_ability(_g: MtgGame, _pid: int, source: CardInstance,
		_ability: ActivatedAbility, _modifier: CardInstance) -> bool:
	return source.is_creature()


func _pumper(cost: String) -> CardData:
	return CardData.new("Synthetic Pumper", "{G}", Mtg.CardType.CREATURE).pt(1, 1) \
		.activated(ActivatedAbility.new(cost, false, [GainLifeEffect.new(1)], cost + ": You gain 1 life.")) \
		.oracle(cost + ": You gain 1 life.")


func _total(payment: Dictionary) -> int:
	return (payment["cost"] as ManaCost).mana_value() + int(payment["extra"])


func test_heartstone_reduces_a_two_mana_ability_to_its_coloured_pip() -> void:
	var pumper := put_synthetic(0, _pumper("{1}{G}"))
	assert_eq(_total(g.ability_payment(0, pumper, 0)), 2)
	put_synthetic(0, _heartstone())
	assert_eq(_total(g.ability_payment(0, pumper, 0)), 1, "{1}{G} costs {G}")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, pumper, 0))
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_heartstone_cannot_reduce_below_one_mana() -> void:
	var pumper := put_synthetic(0, _pumper("{1}"))
	put_synthetic(0, _heartstone())
	assert_eq(_total(g.ability_payment(0, pumper, 0)), 1, "{1} stays {1}")
	assert_refused(g.activate_ability(0, pumper, 0), "mana")
	var two := put_synthetic(0, _pumper("{2}"))
	assert_eq(_total(g.ability_payment(0, two, 0)), 1, "{2} costs {1}")


func test_two_heartstones_each_keep_the_floor() -> void:
	var three := put_synthetic(0, _pumper("{3}"))
	var greenish := put_synthetic(0, _pumper("{2}{G}"))
	put_synthetic(0, _heartstone())
	put_synthetic(0, _heartstone())
	assert_eq(_total(g.ability_payment(0, three, 0)), 1, "{3} -> {1}")
	assert_eq(_total(g.ability_payment(0, greenish, 0)), 1, "{2}{G} -> {G}")


func test_heartstone_counts_x_in_the_mana_of_the_cost() -> void:
	var x_pumper := put_synthetic(0, CardData.new("Synthetic X", "{G}", Mtg.CardType.CREATURE).pt(1, 1)
		.activated(ActivatedAbility.new("{X}", false, [GainLifeEffect.new(1)], "{X}: You gain 1 life."))
		.oracle("{X}: You gain 1 life."))
	put_synthetic(0, _heartstone())
	assert_eq(_total(g.ability_payment(0, x_pumper, 0, 1)), 1, "X=1 is already one mana")
	assert_eq(_total(g.ability_payment(0, x_pumper, 0, 3)), 2, "X=3 costs two")


func test_heartstone_leaves_noncreature_abilities_alone() -> void:
	var totem := put_synthetic(0, CardData.new("Synthetic Totem", "{1}", Mtg.CardType.ARTIFACT)
		.activated(ActivatedAbility.new("{2}", false, [GainLifeEffect.new(1)], "{2}: You gain 1 life."))
		.oracle("{2}: You gain 1 life."))
	put_synthetic(0, _heartstone())
	assert_eq(_total(g.ability_payment(0, totem, 0)), 2)


func test_heartstone_reduces_every_players_creature_abilities() -> void:
	var theirs := put_synthetic(1, _pumper("{2}{G}"))
	put_synthetic(0, _heartstone())
	assert_eq(_total(g.ability_payment(1, theirs, 0)), 2, "symmetric")


func test_a_tapped_heartstone_stops_only_under_the_1997_artifact_rule() -> void:
	var pumper := put_synthetic(0, _pumper("{1}{G}"))
	var stone := put_synthetic(0, _heartstone())
	g.tap_permanent(stone)
	assert_eq(_total(g.ability_payment(0, pumper, 0)), 1, "modern: a tapped artifact still works")
	g.rules.tapped_artifacts_stop = true
	g.recalculate()
	assert_eq(_total(g.ability_payment(0, pumper, 0)), 2, "fifth: a tapped artifact's effect has ceased")


# --------------------------------------------------------- dynamic count --

## "Target opponent" — the slot the count is read against.
class OpponentSlot extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.opponent()

	func resolve(_game: MtgGame, _source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		pass


static func _black_permanents_of_that_opponent(game: MtgGame, _source: CardInstance,
		earlier: Array) -> Vector2i:
	if earlier.is_empty() or not (earlier[0] as TargetRef).is_player:
		return Vector2i(0, 0)
	var n := 0
	for perm in game.players[(earlier[0] as TargetRef).player_id].battlefield:
		if (perm.cur_colors & Mtg.ManaColor.B) != 0:
			n += 1
	return Vector2i(0, n)


## Reap's shape.
func _reap() -> CardData:
	var cards := ReturnFromGraveyardEffect.new().any_card()
	cards.targets_counted_by(_black_permanents_of_that_opponent)
	return CardData.new("Synthetic Reap", "{1}{G}", Mtg.CardType.INSTANT) \
		.spell(OpponentSlot.new()) \
		.spell(cards) \
		.oracle("Return up to X target cards from your graveyard to your hand, where X is the number of black permanents target opponent controls as you cast this spell.")


func test_reap_with_no_black_permanents_takes_no_cards() -> void:
	var reap := give_synthetic(0, _reap())
	var dead := _named_in(0, "Grizzly Bears", Mtg.Zone.GRAVEYARD)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_refused(g.cast_spell(0, reap, [TargetRef.player(1), TargetRef.card(dead)]))
	assert_eq(g.players[0].mana_pool.total(), 2)
	assert_ok(g.cast_spell(0, reap, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(dead.zone, Mtg.Zone.GRAVEYARD)


func test_reap_takes_up_to_the_count_of_the_target_opponents_black_permanents() -> void:
	var reap := give_synthetic(0, _reap())
	put_battlefield(1, "Black Knight")
	put_battlefield(1, "Black Knight")
	put_battlefield(1, "Swamp")   # a land is colourless
	var a := _named_in(0, "Grizzly Bears", Mtg.Zone.GRAVEYARD)
	var b := _named_in(0, "Hill Giant", Mtg.Zone.GRAVEYARD)
	var c := _named_in(0, "Llanowar Elves", Mtg.Zone.GRAVEYARD)
	var effect: EffectBase = reap.data.spell_effects[1]
	assert_eq(effect.target_range_at(g, reap, 0, [TargetRef.player(1)]), Vector2i(0, 2))
	assert_eq(effect.target_range_at(g, reap, 0, [TargetRef.player(0)]), Vector2i(0, 0))
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_refused(g.cast_spell(0, reap, [TargetRef.player(1), TargetRef.card(a),
		TargetRef.card(b), TargetRef.card(c)]))
	# "Target opponent" — never the caster, whatever their own board.
	assert_refused(g.cast_spell(0, reap, [TargetRef.player(0)]))
	assert_ok(g.cast_spell(0, reap, [TargetRef.player(1), TargetRef.card(a), TargetRef.card(b)]))
	resolve_stack()
	assert_eq(a.zone, Mtg.Zone.HAND)
	assert_eq(b.zone, Mtg.Zone.HAND)
	assert_eq(c.zone, Mtg.Zone.GRAVEYARD)


func test_reap_counts_as_it_is_cast_not_as_it_resolves() -> void:
	var reap := give_synthetic(0, _reap())
	var knight := put_battlefield(1, "Black Knight")
	put_battlefield(1, "Black Knight")
	var a := _named_in(0, "Grizzly Bears", Mtg.Zone.GRAVEYARD)
	var b := _named_in(0, "Hill Giant", Mtg.Zone.GRAVEYARD)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, reap, [TargetRef.player(1), TargetRef.card(a), TargetRef.card(b)]))
	g.destroy(knight)   # one fewer black permanent in response
	resolve_stack()
	assert_eq(a.zone, Mtg.Zone.HAND, "X was fixed as the spell was cast (CR 601.2c)")
	assert_eq(b.zone, Mtg.Zone.HAND)


func test_an_effect_without_a_count_function_keeps_its_static_range() -> void:
	var plain := ReturnFromGraveyardEffect.new()
	assert_eq(plain.target_range_at(g, null, 0, []), plain.target_range(0))


# --------------------------------------------------------- trigger chooser --

static func _creature_entered(_game: MtgGame, _source: CardInstance, event: GameEvent) -> bool:
	var inst: CardInstance = event.data.get("instance")
	return inst != null and inst.is_creature()


static func _entering_controller(_game: MtgGame, _source: CardInstance, event: GameEvent) -> int:
	return int(event.data.get("controller", -1))


static func _pandemonium_resolve(game: MtgGame, _source: CardInstance, event: GameEvent) -> void:
	var creature: CardInstance = event.data.get("instance")
	var targets := game.current_targets()
	if creature == null or targets.is_empty():
		return
	game.deal_damage(creature, targets[0], maxi(0, creature.cur_power))


## Pandemonium's shape (the "may" is the card's own business).
func _pandemonium() -> CardData:
	var trig := TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _pandemonium_resolve,
		"Whenever a creature enters, that creature's controller may have it deal damage equal to its power to any target of their choice.",
		_creature_entered).targeting(TargetSpec.any_target()).chosen_by(_entering_controller)
	return CardData.new("Synthetic Pandemonium", "{3}{R}", Mtg.CardType.ENCHANTMENT) \
		.triggered(trig).oracle("Whenever a creature enters, that creature's controller may have it deal damage equal to its power to any target of their choice.")


func test_the_entering_creatures_controller_chooses_the_target() -> void:
	put_synthetic(0, _pandemonium())
	var mine := SpySeat.new()
	var theirs := SpySeat.new()
	theirs.option_label = "P0"
	g.agents[0] = mine
	g.agents[1] = theirs
	put_battlefield(1, "Hill Giant")
	assert_eq(g.stack.size(), 1, "Pandemonium's trigger is on the stack")
	var item: StackItem = g.stack[-1]
	assert_eq(item.controller, 0, "the trigger is still Pandemonium's controller's")
	assert_eq(g.trigger_chooser(item), 1, "but the target is the entering creature's controller's")
	assert_eq(mine.asked, [] as Array[String], "Pandemonium's controller is not asked")
	assert_eq(theirs.asked.size(), 1)
	assert_true(item.targets[0].is_player and item.targets[0].player_id == 0)
	resolve_stack()
	assert_eq(g.players[0].life, 17, "the Giant's 3 power hit the chosen player")


func test_a_trigger_without_a_chooser_is_its_controllers() -> void:
	var trig := TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _pandemonium_resolve, "", _creature_entered) \
		.targeting(TargetSpec.any_target())
	put_synthetic(0, CardData.new("Synthetic Plain", "{R}", Mtg.CardType.ENCHANTMENT).triggered(trig).oracle("..."))
	put_battlefield(1, "Hill Giant")
	assert_eq(g.trigger_chooser(g.stack[-1]), 0)


func test_the_chooser_is_held_when_it_is_a_human_seat() -> void:
	put_synthetic(1, _pandemonium())
	_human_seat(0)
	var bears := give_hand(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, bears))
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))   # the Bears resolve and enter
	assert_not_null(g.awaiting_choice, "the chooser's question holds the duel")
	assert_eq(g.awaiting_choice.pid, 0, "asked of the creature's controller, not Pandemonium's")
	assert_eq(g.awaiting_choice.source, "Synthetic Pandemonium")
	var item: StackItem = g.stack[-1]
	assert_eq(item.controller, 1)
	var p1_index := -1
	for i in g.awaiting_choice.options.size():
		if g.awaiting_choice.options[i] == "P1": p1_index = i
	assert_gt(p1_index, -1)
	assert_ok(g.answer_choice(p1_index))
	assert_null(g.awaiting_choice)
	assert_true(item.targets[0].is_player and item.targets[0].player_id == 1)


var _ranked_for := -2

func _rank_spy(game: MtgGame, _source: CardInstance, _a: TargetRef, _b: TargetRef) -> bool:
	_ranked_for = game.ranking_chooser()
	return false


func test_the_order_callable_can_ask_whose_choice_it_ranks_for() -> void:
	var trig := TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _pandemonium_resolve, "", _creature_entered) \
		.targeting(TargetSpec.any_target(), _rank_spy).chosen_by(_entering_controller)
	put_synthetic(0, CardData.new("Synthetic Ranker", "{R}", Mtg.CardType.ENCHANTMENT).triggered(trig).oracle("..."))
	put_battlefield(1, "Hill Giant")
	assert_eq(_ranked_for, 1, "ranked for the chooser")
	assert_eq(g.ranking_chooser(), -1, "and only while ranking")


func test_the_ai_answers_as_the_chooser_with_the_ranked_first() -> void:
	put_synthetic(0, _pandemonium())
	var ai := AiPlayer.new(1)
	g.agents[1] = ai
	put_battlefield(1, "Hill Giant")
	assert_eq(g.stack.size(), 1)
	assert_not_null(g.stack[-1].targets[0], "the AI named a target")


# ------------------------------------------------------- retarget an ability --

## Silver Wyvern's ability effect: "Change the target of target spell or
## ability that targets only this creature. The new target must be a
## creature." — first legal creature other than the source here.
class WyvernEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.spell_or_ability(
			"target spell or ability that targets only this creature", _targets_only)

	static func _targets_only(game: MtgGame, source: CardInstance, item: StackItem) -> bool:
		return MtgGame.stack_item_targets_only(item, source)

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var item := game.stack_item_for_ref(target)
		if item == null:
			return
		for ref in game.single_target_retargets(item):
			if ref.is_player:
				continue
			var inst := game.find_instance(ref.instance_id)
			if inst != null and inst != source and inst.zone == Mtg.Zone.BATTLEFIELD and inst.is_creature():
				game.retarget_stack_item(item.id, 0, ref)
				return


func _wyvern() -> CardData:
	return CardData.new("Synthetic Wyvern", "{3}{U}{U}", Mtg.CardType.CREATURE).pt(4, 4) \
		.activated(ActivatedAbility.new("{U}", false, [WyvernEffect.new()],
			"{U}: Change the target of target spell or ability that targets only this creature. The new target must be a creature.")) \
		.oracle("{U}: Change the target of target spell or ability that targets only this creature. The new target must be a creature.")


func test_spell_or_ability_kind_is_appended_after_every_older_kind() -> void:
	assert_gt(TargetSpec.Kind.SPELL_OR_ABILITY, TargetSpec.Kind.ABILITY)


func test_spell_or_ability_targets_spells_and_activations_on_the_stack() -> void:
	var wyvern := put_synthetic(0, _wyvern())
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(wyvern)]))
	assert_ok(g.activate_ability(0, sorcerer, 0, [TargetRef.card(wyvern)]))
	var spec := TargetSpec.spell_or_ability("target spell or ability")
	var refs := spec.legal_targets(g, wyvern)
	assert_eq(refs.size(), 2)
	var kinds := 0
	for ref in refs:
		if ref.is_ability: kinds |= 1
		elif g.find_instance(ref.instance_id) == bolt: kinds |= 2
	assert_eq(kinds, 3, "the activation (an ability ref) and the Bolt (a card ref)")
	assert_false(spec.is_legal(g, TargetRef.card(sorcerer), wyvern), "a permanent is not")


func test_targets_only_this_creature_is_a_stack_filter() -> void:
	var wyvern := put_synthetic(0, _wyvern())
	var bear := put_battlefield(0, "Grizzly Bears")
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	assert_ok(g.activate_ability(0, sorcerer, 0, [TargetRef.card(wyvern)]))
	var spec: TargetSpec = wyvern.data.activated_abilities[0].effects[0].target_spec
	var refs := spec.legal_targets(g, wyvern)
	assert_eq(refs.size(), 1, "only the activation aims at the Wyvern alone")
	assert_true(refs[0].is_ability)


func test_wyvern_redirects_a_lightning_bolt() -> void:
	var wyvern := put_synthetic(0, _wyvern())
	var bear := put_battlefield(1, "Grizzly Bears")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(wyvern)]))
	assert_ok(g.activate_ability(0, wyvern, 0, [TargetRef.card(bolt)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "the Bolt went to the Bears")
	assert_eq(wyvern.damage, 0)


func test_wyvern_redirects_a_prodigal_sorcerer_activation() -> void:
	var wyvern := put_synthetic(0, _wyvern())
	var bear := put_battlefield(1, "Grizzly Bears")
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.activate_ability(0, sorcerer, 0, [TargetRef.card(wyvern)]))
	var ping: StackItem = g.stack[-1]
	assert_ok(g.activate_ability(0, wyvern, 0, [TargetRef.ability(ping)]))
	resolve_stack()
	assert_eq(bear.damage, 1, "the ping hit the Bears")
	assert_eq(wyvern.damage, 0)


func test_retarget_stack_item_keeps_the_original_targeting_restrictions() -> void:
	var wyvern := put_synthetic(0, _wyvern())
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	var bear := put_battlefield(1, "Grizzly Bears")
	var terror := give_hand(0, "Terror")
	var knight := put_battlefield(1, "Black Knight")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, terror, [TargetRef.card(wyvern)]))
	var spell_item: StackItem = g.find_stack_item(terror)
	assert_false(g.retarget_stack_item(spell_item.id, 0, TargetRef.card(knight)), "Terror can't target a black creature")
	assert_true(g.retarget_stack_item(spell_item.id, 0, TargetRef.card(bear)))
	assert_true(spell_item.targets[0].instance_id == bear.id)
	assert_ok(g.activate_ability(0, sorcerer, 0, [TargetRef.card(wyvern)]))
	var ping: StackItem = g.stack[-1]
	var options := g.single_target_retargets(ping)
	var players := 0
	for ref in options:
		assert_false(ref.same_object(TargetRef.card(wyvern)), "never the current target")
		if ref.is_player: players += 1
	assert_eq(players, 2, "the ping's own 'any target' offers players too")
	assert_true(g.retarget_stack_item(ping.id, 0, TargetRef.player(1)))
	assert_true(ping.targets[0].is_player)
	assert_false(g.retarget_stack_item(9999, 0, TargetRef.player(1)), "no such item")


func test_retargeting_a_trigger() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	put_synthetic(0, _pandemonium())
	var theirs := SpySeat.new()
	theirs.option_label = "P0"
	g.agents[1] = theirs
	put_battlefield(1, "Hill Giant")
	var item: StackItem = g.stack[-1]
	assert_eq(item.kind, Mtg.StackKind.TRIGGER)
	var spec := TargetSpec.spell_or_ability("target spell or ability")
	assert_true(spec.is_legal(g, TargetRef.ability(item), bear), "a trigger is an ability on the stack")
	assert_true(g.retarget_stack_item(item.id, 0, TargetRef.card(bear)))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "the redirected trigger hit the Bears")
	assert_eq(g.players[0].life, 20)


func test_retarget_respects_the_new_targets_protection() -> void:
	var wyvern := put_synthetic(0, _wyvern())
	var white_knight := put_battlefield(1, "White Knight")   # protection from black
	var terror := give_hand(0, "Terror")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, terror, [TargetRef.card(wyvern)]))
	var item: StackItem = g.find_stack_item(terror)
	assert_false(g.retarget_stack_item(item.id, 0, TargetRef.card(white_knight)))
	for ref in g.single_target_retargets(item):
		assert_ne(ref.instance_id, white_knight.id, "never offered")
	assert_eq(item.targets[0].instance_id, wyvern.id, "unchanged")


func test_an_ability_that_left_the_stack_is_no_longer_a_target() -> void:
	var wyvern := put_synthetic(0, _wyvern())
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	assert_ok(g.activate_ability(0, sorcerer, 0, [TargetRef.card(wyvern)]))
	var ping: StackItem = g.stack[-1]
	var ref := TargetRef.ability(ping)
	var spec: TargetSpec = wyvern.data.activated_abilities[0].effects[0].target_spec
	assert_true(spec.is_legal(g, ref, wyvern))
	assert_eq(g.stack_item_for_ref(ref), ping)
	g.counter_ability(ping.id)
	assert_false(spec.is_legal(g, ref, wyvern), "countered: gone (CR 608.2b fizzle)")
	assert_null(g.stack_item_for_ref(ref))
	assert_false(g.retarget_stack_item(ping.id, 0, TargetRef.player(1)))


func test_the_referee_and_the_ai_price_the_new_costs_through_the_shared_reads() -> void:
	var penance := put_synthetic(0, _penance())
	var rogue := put_synthetic(0, _rogue(1))
	# Nothing to pay with: every reader says so, from the one engine count.
	assert_ne(g.ability_announce_refusal(0, penance, 0), "", "an empty hand")
	assert_ne(g.ability_announce_refusal(0, rogue, 0), "", "no counter")
	var burst := give_synthetic(0, _burst())
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_false(SgPayment.affordable(g, 0, burst), "the referee: no OTHER card to discard")
	var ai := AiPlayer.new(0)
	var tactics: GDScript = load("res://engine/ai/alliances_tactics.gd")
	assert_eq(tactics.object_price(g, ai, burst, burst.data.object_costs), INF)
	give_hand(0, "Grizzly Bears")
	g.add_counters(rogue, "+1/+1", 1)
	assert_true(SgPayment.affordable(g, 0, burst))
	assert_eq(g.ability_announce_refusal(0, penance, 0), "")
	assert_lt(tactics.object_price(g, ai, burst, burst.data.object_costs), INF)


func test_targets_only_reads_every_target() -> void:
	var wyvern := put_synthetic(0, _wyvern())
	var bear := put_battlefield(0, "Grizzly Bears")
	var item := StackItem.new()
	assert_false(MtgGame.stack_item_targets_only(item, wyvern), "no target at all")
	item.targets = [TargetRef.card(wyvern)] as Array[TargetRef]
	assert_true(MtgGame.stack_item_targets_only(item, wyvern))
	item.targets = [TargetRef.card(wyvern), TargetRef.card(bear)] as Array[TargetRef]
	assert_false(MtgGame.stack_item_targets_only(item, wyvern))


# --------------------------------------------------------------------- undo --
# The same field-exact differ tests/unit/test_pack_8_cost_vocabulary.gd uses.

func _capture() -> Array:
	var snap := GameSnapshot.take(g)
	var out: Array = []
	for i in snap._objects.size():
		var obj: Object = snap._objects[i]
		var props: Array = snap._props[i]
		var values: Array = snap._values[i]
		var k := 0
		for group in [props[0], props[1]]:
			for name in group:
				if name != &"undo_log" and name != &"journal":
					out.append([obj, name, _deep(values[k])])
				k += 1
	out.append([g.rng, &"state", g.rng.state])
	snap.restore()
	return out


static func _deep(value: Variant) -> Variant:
	var t := typeof(value)
	if t == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	if t == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	if t >= TYPE_PACKED_BYTE_ARRAY:
		return value.duplicate()
	return value


func _drift(before: Array) -> Array:
	var bad: Array = []
	for row in before:
		var obj: Object = row[0]
		var name: StringName = row[1]
		if not _same(obj.get(name), row[2]):
			bad.append("%s.%s" % [obj.get_script().get_global_name(), name])
	return bad


static func _same(a: Variant, b: Variant) -> bool:
	var ta := typeof(a)
	if ta != typeof(b):
		return false
	if ta == TYPE_ARRAY:
		var aa := a as Array
		var bb := b as Array
		if aa.size() != bb.size():
			return false
		for i in aa.size():
			if not _same(aa[i], bb[i]):
				return false
		return true
	if ta == TYPE_DICTIONARY:
		var ad := a as Dictionary
		var bd := b as Dictionary
		if ad.size() != bd.size():
			return false
		for k in ad:
			if not bd.has(k) or not _same(ad[k], bd[k]):
				return false
		return true
	return a == b


func _round_trips(move: Callable, what: String) -> void:
	var before := _capture()
	var mark := g.make_mark()
	move.call()
	var mark_size := g.undo_log.size()
	g.unmake_to(mark)
	assert_eq(_drift(before), [], "%s left state behind" % what)
	assert_gt(mark_size, mark, "%s recorded nothing — is the move happening?" % what)
	g.end_search()


func test_every_new_cost_and_retarget_round_trips_field_exact() -> void:
	var burst := give_synthetic(0, _burst())
	give_hand(0, "Grizzly Bears")
	give_hand(0, "Hill Giant")
	var penance := put_synthetic(0, _penance())
	var rogue := put_synthetic(0, _rogue(1))
	g.add_counters(rogue, "+1/+1", 1)
	var wyvern := put_synthetic(0, _wyvern())
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.R, 2)
	_round_trips(func() -> void:
		assert_ok(g.cast_spell(0, burst, [TargetRef.player(1)])), "the random discard")
	_round_trips(func() -> void:
		assert_ok(g.activate_ability(0, penance, 0)), "the library-top cost")
	add_mana(0, Mtg.ManaColor.C, 2)
	_round_trips(func() -> void:
		assert_ok(g.activate_ability(0, rogue, 0)), "the counter removal")
	assert_ok(g.activate_ability(0, sorcerer, 0, [TargetRef.card(wyvern)]))
	var ping: StackItem = g.stack[-1]
	_round_trips(func() -> void:
		assert_true(g.retarget_stack_item(ping.id, 0, TargetRef.player(1))), "the retarget")
	assert_true(ping.targets[0].instance_id == wyvern.id, "the target came back")
