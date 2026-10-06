extends GameTest
## Pack 9 engine follow-up F — CR 704.3: "Whenever a player would get
## priority, the game checks for any of the listed conditions for
## state-based actions." That includes the player who KEEPS priority after
## their own action (CR 117.3c: after casting a spell or activating an
## ability; CR 116.3: after a special action such as playing a land).
##
## The engine's [method MtgGame._open_priority] always checked; the
## keep-priority path ([method MtgGame._resume_priority]) relied on the
## action's own helpers, and the cost helpers deliberately run no check
## halfway through a payment. So a creature that paid its last +1/+1
## counter as a cost sat at 0/0 — able to block, to be sacrificed again, to
## be counted — until the next check, and an Aura whose creature was
## sacrificed as a cost stayed on the battlefield attached to nothing. A
## land drop that broke the legend rule waited the same way. Every case is
## pinned under both rules presets.

const PRESETS := ["modern", "fifth"]


## "Remove a +1/+1 counter from this creature: You gain 2 life." on a 0/0
## that enters with counters (Spike Feeder's shape).
static func _spike() -> CardData:
	return CardData.new("Test Spike", "{1}{G}", Mtg.CardType.CREATURE).pt(0, 0) \
		.activated(ActivatedAbility.new("", false, [GainLifeEffect.new(2)],
			"Remove a +1/+1 counter from this creature: You gain 2 life.") \
			.with_counter_cost("+1/+1", 1))


## "Sacrifice a creature: You gain 1 life." on a noncreature artifact.
static func _altar() -> CardData:
	return CardData.new("Test Altar", "{3}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("", false, [GainLifeEffect.new(1)],
			"Sacrifice a creature: You gain 1 life.") \
			.with_sacrifice_of("creature", _is_creature))


static func _is_creature(inst: CardInstance) -> bool:
	return inst.is_creature()


func _fresh(preset: String) -> void:
	before_each()
	g.rules.set_edition(preset)
	advance_to_step(Mtg.Step.MAIN1)


func test_a_creature_that_pays_its_last_counter_dies_before_priority() -> void:
	for preset in PRESETS:
		_fresh(preset)
		var spike := put_synthetic(0, _spike())
		g.add_counters(spike, "+1/+1", 1)
		assert_eq(spike.cur_toughness, 1, "%s: precondition" % preset)
		assert_ok(g.activate_ability(0, spike, 0))
		assert_eq(g.priority_player, 0, "%s: the activator keeps priority (CR 117.3c)" % preset)
		assert_eq(spike.zone, Mtg.Zone.GRAVEYARD,
			"%s: a 0/0 is put into the graveyard before anyone gets priority (CR 704.3)" % preset)
		assert_eq(g.stack.size(), 1, "%s: its ability is on the stack" % preset)
		resolve_stack()
		assert_eq(g.players[0].life, 22,
			"%s: and resolves without its source (CR 113.7a)" % preset)


func test_the_sweep_round_trips_through_the_journal() -> void:
	# The AI's search activates under the journal and unmakes: the death the
	# sweep caused must come back with everything else.
	_fresh("modern")
	var spike := put_synthetic(0, _spike())
	g.add_counters(spike, "+1/+1", 1)
	var mark := g.make_mark()
	assert_ok(g.activate_ability(0, spike, 0))
	assert_eq(spike.zone, Mtg.Zone.GRAVEYARD)
	g.unmake_to(mark)
	g.end_search()
	assert_eq(spike.zone, Mtg.Zone.BATTLEFIELD, "back")
	assert_eq(int(spike.counters.get("+1/+1", 0)), 1, "with its counter")
	assert_true(g.stack.is_empty())
	assert_ok(g.activate_ability(0, spike, 0))
	assert_eq(spike.zone, Mtg.Zone.GRAVEYARD, "and the real activation sweeps again")


func test_a_creature_with_counters_left_stays() -> void:
	for preset in PRESETS:
		_fresh(preset)
		var spike := put_synthetic(0, _spike())
		g.add_counters(spike, "+1/+1", 2)
		assert_ok(g.activate_ability(0, spike, 0))
		assert_eq(spike.zone, Mtg.Zone.BATTLEFIELD, preset)
		assert_eq(spike.cur_toughness, 1, preset)


func test_an_aura_whose_creature_was_sacrificed_as_a_cost_goes_before_priority() -> void:
	for preset in PRESETS:
		_fresh(preset)
		var altar := put_synthetic(0, _altar())
		var bear := put_battlefield(0, "Grizzly Bears")
		var aura := _make_instance(0, "Holy Strength")
		g._put_on_battlefield(aura, 0, bear)
		assert_eq(aura.attached_to, bear.id, "%s: precondition" % preset)
		assert_ok(g.activate_ability(0, altar, 0))
		assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "%s: sacrificed as the cost" % preset)
		assert_eq(aura.zone, Mtg.Zone.GRAVEYARD,
			"%s: the Aura attached to nothing is put into the graveyard (CR 704.5m) before priority" % preset)
		assert_eq(g.priority_player, 0, preset)


func test_a_land_drop_that_breaks_the_legend_rule_is_swept_before_priority() -> void:
	for preset in PRESETS:
		_fresh(preset)
		var first := put_battlefield(0, "Hammerheim")
		var second := give_hand(0, "Hammerheim")
		assert_ok(g.play_land(0, second))
		assert_eq(g.priority_player, 0, "%s: a special action: the player keeps priority (CR 116.3)" % preset)
		assert_eq(first.zone, Mtg.Zone.BATTLEFIELD, preset)
		assert_eq(second.zone, Mtg.Zone.GRAVEYARD,
			"%s: the newer legend goes before anyone gets priority (CR 704.3)" % preset)


## "Remove a +1/+1 counter from this creature: Add {C}." — a mana ability
## with no {T} on a 0/0 that holds counters (Workhorse's shape).
static func _mana_horse() -> CardData:
	return CardData.new("Test Workhorse", "{6}", Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) \
		.pt(0, 0) \
		.mana(ManaAbility.new(Mtg.ManaColor.C).without_tap().with_counter_cost("+1/+1", 1))


func test_a_counter_paid_for_mana_resizes_the_creature_at_once() -> void:
	# The counter is part of its size: the P/T are recalculated as the cost
	# is paid (as the E7 object counter cost does, additional_object_costs.gd),
	# not left stale until something else recalculates.
	for preset in PRESETS:
		_fresh(preset)
		var horse := put_synthetic(0, _mana_horse())
		g.add_counters(horse, "+1/+1", 2)
		assert_ok(g.tap_for_mana(0, horse))
		assert_eq([horse.cur_power, horse.cur_toughness], [1, 1], preset)
		assert_eq(horse.zone, Mtg.Zone.BATTLEFIELD, preset)


func test_the_last_counter_paid_for_mana_kills_before_priority() -> void:
	# A mana ability is an activated ability: its activator receives
	# priority afterwards (CR 117.3c), and the 0/0 is put into the graveyard
	# first (CR 704.3). The mana stays (CR 605.3a).
	for preset in PRESETS:
		_fresh(preset)
		var horse := put_synthetic(0, _mana_horse())
		g.add_counters(horse, "+1/+1", 1)
		assert_ok(g.tap_for_mana(0, horse))
		assert_eq(horse.zone, Mtg.Zone.GRAVEYARD, preset)
		assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 1, preset)
		assert_eq(g.priority_player, 0, preset)


func test_the_real_workhorse_dies_with_its_last_counter() -> void:
	var was := Settings.enabled_card_packs().has("pack-9")
	CardPacks.set_enabled("pack-9", true)
	_fresh("modern")
	var horse := put_battlefield(0, "Workhorse")
	assert_eq(int(horse.counters.get("+1/+1", 0)), 4)
	for n in 3:
		assert_ok(g.tap_for_mana(0, horse))
	assert_eq([horse.cur_power, horse.cur_toughness], [1, 1])
	assert_ok(g.tap_for_mana(0, horse))
	assert_eq(horse.zone, Mtg.Zone.GRAVEYARD, "a 0/0 before anyone gets priority")
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 4)
	if not was:
		CardPacks.set_enabled("pack-9", false)


func test_a_spell_cast_keeps_the_casters_priority_and_sweeps() -> void:
	# The cast path (CR 117.3c): a spell whose casting changes nothing on
	# the board leaves the board as it was, and the caster still holds
	# priority with the spell on the stack.
	for preset in PRESETS:
		_fresh(preset)
		var bear := put_battlefield(1, "Grizzly Bears")
		var bolt := give_hand(0, "Lightning Bolt")
		add_mana(0, Mtg.ManaColor.R)
		assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
		assert_eq(g.priority_player, 0, preset)
		assert_eq(g.stack.size(), 1, preset)
		assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, preset)
		resolve_stack()
		assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, preset)
