extends GameTest
## Pack 10 engine package E4, part two.
##
## SPELL_COUNTERED (CR 701.5a): one [constant Mtg.EventType.SPELL_COUNTERED]
## per spell [method MtgGame.counter_spell] really counters — whatever
## replaces its destination (the top of its library, exile, the
## battlefield) — naming the player who CAST it (its stack controller,
## read before the card goes home to its owner, CR 110.2) and whether it
## was a copy. Nothing for a spell that "can't be countered" (it stays on
## the stack) and nothing for a FIZZLE: under the modern rules a spell
## whose targets are all illegal "doesn't resolve" — it is not countered
## (CR 608.2b), and the engine's rules options carry no Fifth Edition fork
## for it. Multani's Presence: "Whenever a spell you've cast is countered,
## draw a card."
##
## STILL RESOLVES (Gilded Drake): "This ability still resolves if its
## target becomes illegal." — [method TriggeredAbility.still_resolves]: the
## trigger is not removed for an illegal target (the printed exception to
## CR 608.2b); [method MtgGame.current_trigger_target] answers null for
## it and the card does the rest ("If you don't or can't make an exchange,
## sacrifice this creature").
##
## Every card here is SYNTHETIC; the real ones are batch B13's.

const COUNTERED := Mtg.EventType.SPELL_COUNTERED

var countered: Array = []


func before_each() -> void:
	super.before_each()
	countered = []
	g.event_occurred.connect(func(e: GameEvent) -> void:
		if e.type == COUNTERED: countered.append(e))


# ------------------------------------------------------------- the cards --

## Multani's Presence's shape.
static func _presence() -> CardData:
	return CardData.new("Test Presence", "{G}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(COUNTERED, _presence_draw,
			"Whenever a spell you've cast is countered, draw a card.", _yours_cast))


static func _yours_cast(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return int(e.data["controller"]) == s.controller_id and not bool(e.data["is_copy"])


static func _presence_draw(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	g.draw_cards(s.controller_id, 1)


static func _bear() -> CardData:
	return CardData.new("Test Bear", "{1}{G}", Mtg.CardType.CREATURE).pt(2, 2)


static func _uncounterable() -> CardData:
	return CardData.new("Test Scragnoth", "{4}{G}", Mtg.CardType.CREATURE).pt(4, 4) \
		.with_cant_be_countered()


static func _counter_with(effect: CounterEffect) -> CardData:
	return CardData.new("Test Counter", "{U}", Mtg.CardType.INSTANT).spell(effect)


## Gilded Drake's shape: "When this creature enters, exchange control of
## this creature and up to one target creature an opponent controls. If
## you don't or can't make an exchange, sacrifice this creature. This
## ability still resolves if its target becomes illegal."
static func _drake(still := true) -> CardData:
	var trig := TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _exchange,
		"When this creature enters, exchange control of this creature and up to one target creature an opponent controls. If you don't or can't make an exchange, sacrifice this creature.",
		_self_enters) \
		.targeting_up_to(TargetSpec.creature("target creature an opponent controls") \
			.with_source_filter(_an_opponents), 1)
	if still:
		trig.still_resolves()
	return CardData.new("Test Drake", "{1}{U}", Mtg.CardType.CREATURE).pt(3, 3) \
		.with_keywords([Mtg.Keyword.FLYING]).triggered(trig)


static func _self_enters(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("instance") == s


static func _an_opponents(_g: MtgGame, source: CardInstance, inst: CardInstance) -> bool:
	return source == null or inst.controller_id != source.controller_id


static func _exchange(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ref := g.current_trigger_target(0)
	var victim: CardInstance = g.find_instance(ref.instance_id) if ref != null else null
	if victim != null and g.exchange_control(s, victim):
		return
	if g.is_present(s):
		g.sacrifice_permanent(s)


## "Other players can't gain control of it" for every creature of its
## controller (Guardian Beast's flag, on creatures here).
static func _guard() -> CardData:
	return CardData.new("Test Guard", "{3}{B}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_guard_all, "Creatures you control can't change controllers."))


static func _guard_all(g: MtgGame, s: CardInstance) -> void:
	for inst in g.players[s.controller_id].battlefield:
		if inst.is_creature():
			inst.cur_cant_change_control = true


## P0 casts [param card] in their main phase (the mana floated) and passes,
## so P1 holds priority with the spell on the stack.
func _p0_casts(card: CardInstance, targets: Array = []) -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var cost := card.data.cost
	for color in cost.colored:
		add_mana(0, int(color), int(cost.colored[color]))
	if cost.generic > 0:
		add_mana(0, Mtg.ManaColor.C, cost.generic)
	assert_ok(g.cast_spell(0, card, targets))
	assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1)


func _p1_counters(spell: CardInstance) -> CardInstance:
	var counter := give_hand(1, "Counterspell")
	add_mana(1, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(1, counter, [TargetRef.card(spell)]))
	resolve_stack()
	return counter


# ------------------------------------------------------- spell countered --

func test_a_countered_spell_is_announced_with_its_caster() -> void:
	var bear := give_synthetic(0, _bear())
	_p0_casts(bear)
	_p1_counters(bear)
	assert_eq(countered.size(), 1)
	var event: GameEvent = countered[0]
	assert_eq(event.data["instance"], bear)
	assert_eq(int(event.data["controller"]), 0)
	assert_eq(int(event.data["owner"]), 0)
	assert_false(bool(event.data["is_copy"]))
	assert_eq(int(event.data["destination"]), Mtg.Zone.GRAVEYARD)


func test_presence_draws_for_its_controllers_countered_spell() -> void:
	put_synthetic(0, _presence())
	var bear := give_synthetic(0, _bear())
	_p0_casts(bear)
	var hand := g.players[0].hand.size()
	_p1_counters(bear)
	assert_eq(g.players[0].hand.size(), hand + 1)


func test_presence_ignores_the_opponents_countered_spell() -> void:
	put_synthetic(1, _presence())
	var bear := give_synthetic(0, _bear())
	_p0_casts(bear)
	var hand := g.players[1].hand.size()
	_p1_counters(bear)
	assert_eq(countered.size(), 1)
	assert_eq(g.players[1].hand.size(), hand, "not a spell P1 cast")


func test_an_unpaid_force_spike_counters() -> void:
	put_synthetic(0, _presence())
	var bear := give_synthetic(0, _bear())
	_p0_casts(bear)
	var spike := give_hand(1, "Force Spike")
	add_mana(1, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(1, spike, [TargetRef.card(bear)]))
	var hand := g.players[0].hand.size()
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(countered.size(), 1, "\"unless its controller pays\" — not paid")
	assert_eq(g.players[0].hand.size(), hand + 1)


func test_a_spell_that_cant_be_countered_announces_nothing() -> void:
	put_synthetic(0, _presence())
	var scragnoth := give_synthetic(0, _uncounterable())
	_p0_casts(scragnoth)
	_p1_counters(scragnoth)
	assert_eq(scragnoth.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(countered.size(), 0)


func test_a_fizzle_is_not_a_counter() -> void:
	put_synthetic(0, _presence())
	var bear := put_synthetic(1, _bear())
	var bolt := give_hand(0, "Lightning Bolt")
	_p0_casts(bolt, [TargetRef.card(bear)])
	g.exile_permanent(bear)   # the only target is gone (setup)
	var hand := g.players[0].hand.size()
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(countered.size(), 0, "CR 608.2b: it does not resolve; nothing counters it")
	assert_eq(g.players[0].hand.size(), hand)


func test_a_fizzle_is_not_a_counter_under_the_fifth_edition_preset_either() -> void:
	g.rules.set_edition("fifth")
	var bear := put_synthetic(1, _bear())
	var bolt := give_hand(0, "Lightning Bolt")
	_p0_casts(bolt, [TargetRef.card(bear)])
	g.exile_permanent(bear)
	resolve_stack()
	assert_eq(countered.size(), 0, "no rules fork treats a fizzle as a counter")


func test_every_destination_is_still_a_counter() -> void:
	for destination in [Mtg.Zone.LIBRARY, Mtg.Zone.EXILE, Mtg.Zone.BATTLEFIELD]:
		before_each()
		var bear := give_synthetic(0, _bear())
		_p0_casts(bear)
		var effect := CounterEffect.new()
		match destination:
			Mtg.Zone.LIBRARY: effect.to_library_top()
			Mtg.Zone.EXILE: effect.to_exile()
			Mtg.Zone.BATTLEFIELD: effect.to_battlefield_for_caster()
		var counter := give_synthetic(1, _counter_with(effect))
		add_mana(1, Mtg.ManaColor.U)
		assert_ok(g.cast_spell(1, counter, [TargetRef.card(bear)]))
		resolve_stack()
		assert_eq(bear.zone, destination)
		assert_eq(countered.size(), 1, "destination %d" % destination)
		assert_eq(int(countered[0].data["destination"]), destination)
		assert_eq(int(countered[0].data["controller"]), 0, "the caster, whoever has it now")


func test_a_countered_copy_says_so() -> void:
	put_synthetic(0, _presence())
	var bolt := give_hand(0, "Lightning Bolt")
	_p0_casts(bolt, [TargetRef.player(1)])
	var copy := g.copy_spell_on_stack(bolt, 0)
	var hand := g.players[0].hand.size()
	g.counter_spell(copy)
	assert_eq(countered.size(), 1)
	assert_eq(countered[0].data["instance"], copy)
	assert_true(bool(countered[0].data["is_copy"]))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand, "a copy is not a spell you cast")


func test_the_caster_not_the_owner_is_the_controller() -> void:
	# P0 casts a card P1 owns, out of exile (a play permission); countered,
	# the card goes to P1's graveyard but the event names P0.
	advance_to_step(Mtg.Step.MAIN1)
	var bear := give_synthetic(1, _bear())
	g.exile_from_hand(bear)
	g.grant_exile_play(bear, 0)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, bear))
	assert_ok(g.pass_priority(0))
	_p1_counters(bear)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.players[1].graveyard.has(bear))
	assert_eq(countered.size(), 1)
	assert_eq(int(countered[0].data["controller"]), 0)
	assert_eq(int(countered[0].data["owner"]), 1)


# ---------------------------------------------------------- still resolves --

func _p0_drake(still := true) -> CardInstance:
	var drake := give_synthetic(0, _drake(still))
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, drake))
	resolve_stack()   # the Drake resolves; its trigger goes on with its target
	return drake


func test_the_flag_is_declared_on_the_trigger() -> void:
	var trig: TriggeredAbility = _drake().triggered_abilities[0]
	assert_true(trig.resolves_untargeted)
	assert_false((_drake(false).triggered_abilities[0] as TriggeredAbility).resolves_untargeted)


func test_a_legal_target_is_exchanged() -> void:
	var bear := put_synthetic(1, _bear())
	var drake := _p0_drake()
	assert_eq(drake.controller_id, 1)
	assert_eq(bear.controller_id, 0)


func test_an_illegal_target_still_resolves_and_the_drake_is_sacrificed() -> void:
	var bear := put_synthetic(1, _bear())
	var drake := give_synthetic(0, _drake())
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, drake))
	# Resolve the Drake only: its trigger is put on with the Bear targeted.
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	assert_eq(drake.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.stack.size(), 1, "the trigger, aimed at the Bear")
	g.return_to_hand(bear)   # in response, the target leaves (setup)
	resolve_stack()
	assert_eq(drake.zone, Mtg.Zone.GRAVEYARD, "\"can't make an exchange\": sacrificed")
	assert_eq(bear.zone, Mtg.Zone.HAND)


func test_without_the_flag_an_illegal_target_fizzles() -> void:
	var bear := put_synthetic(1, _bear())
	var drake := give_synthetic(0, _drake(false))
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, drake))
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	g.return_to_hand(bear)
	resolve_stack()
	assert_eq(drake.zone, Mtg.Zone.BATTLEFIELD, "the control: CR 608.2b fizzle")
	assert_eq(drake.controller_id, 0)


func test_no_target_chosen_sacrifices_the_drake() -> void:
	var drake := _p0_drake()
	assert_eq(drake.zone, Mtg.Zone.GRAVEYARD, "\"if you don't ... make an exchange\"")


func test_an_exchange_the_rules_forbid_sacrifices_the_drake() -> void:
	put_synthetic(1, _guard())
	var bear := put_synthetic(1, _bear())
	g.recalculate()
	var drake := _p0_drake()
	assert_eq(drake.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.controller_id, 1)
