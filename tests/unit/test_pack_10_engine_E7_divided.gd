extends GameTest
## A DIVIDED TOTAL THE SOURCE DECIDES (Pack 10 engine package E7), pinned
## on synthetic cards: "Sacrifice this enchantment: Prevent the next X
## damage that would be dealt this turn to any number of targets, divided
## as you choose, where X is the number of verse counters on this
## enchantment" (Serra's Hymn).
##
## [method EffectBase.divided_by] takes `func(game, source) -> int`; X is
## read as the ability is announced — before its sacrifice is paid — and
## the division is announced with the targets (CR 601.2c-d): every target
## at least one, the shares adding up to X, at most X targets, none at all
## when X is 0. The shares ride the targets ([member TargetRef.amount]), so
## a counter added in response changes nothing and a target that is gone
## takes its share with it (the owner's ruling of 2026-10-21).
## [method EffectBase.source_counters] reads the source's counters live,
## and as it last existed once a cost has moved it (CR 608.2h).
##
## And the SGManalink half: an "up to X targets" slot whose X is the
## source's own counters (the verse cards — a FIRST-slot count) crosses
## with its exact range, as the referee's TargetPlan will judge it.


func before_each() -> void:
	super()
	advance_to_step(Mtg.Step.MAIN1)


# ------------------------------------------------------------ the cards --

const HYMN_TEXT := "Sacrifice this enchantment: Prevent the next X damage that would be dealt this turn to any number of targets, divided as you choose, where X is the number of verse counters on this enchantment."


static func _hymn() -> CardData:
	var prevent := PreventDamageEffect.new(0).any_target()
	prevent.divided_by(EffectBase.source_counters("verse"))
	return CardData.new("Test Hymn", "{W}", Mtg.CardType.ENCHANTMENT) \
		.activated(ActivatedAbility.new("", false, [prevent], HYMN_TEXT).with_sacrifice_cost())


## The same division with no sacrifice, so counters can change under the
## ability on the stack.
static func _chant() -> CardData:
	var prevent := PreventDamageEffect.new(0).any_target()
	prevent.divided_by(EffectBase.source_counters("verse"))
	return CardData.new("Test Chant", "{W}", Mtg.CardType.ENCHANTMENT) \
		.activated(ActivatedAbility.new("", false, [prevent],
			"Prevent the next X damage that would be dealt this turn to any number of targets, divided as you choose, where X is the number of verse counters on this enchantment."))


## Divided DAMAGE from charge counters (a DamageEffect reader).
static func _volley() -> CardData:
	var burn := DamageEffect.new(0).any_target()
	burn.divided_by(EffectBase.source_counters("charge"))
	return CardData.new("Test Volley", "{2}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("", false, [burn],
			"Sacrifice this artifact: It deals X damage divided as you choose among any number of targets, where X is the number of charge counters on it.").with_sacrifice_cost())


## "Destroy up to X target permanents, where X is the number of verse
## counters on this enchantment" (Serra's Liturgy's shape) — a count, not
## a division, read from the source as the first slot.
static func _liturgy() -> CardData:
	var destroy := DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target permanents"))
	destroy.targets_counted_by(_verse_up_to)
	return CardData.new("Test Liturgy", "{W}", Mtg.CardType.ENCHANTMENT) \
		.activated(ActivatedAbility.new("", false, [destroy],
			"Sacrifice this enchantment: Destroy up to X target permanents, where X is the number of verse counters on this enchantment.").with_sacrifice_cost())


static func _verse_up_to(game: MtgGame, source: CardInstance, _earlier: Array) -> Vector2i:
	return Vector2i(0, int(EffectBase.source_counters("verse").call(game, source)))


func _with_verses(data: CardData, n: int, kind := "verse") -> CardInstance:
	var inst := put_synthetic(0, data)
	if n > 0:
		g.add_counters(inst, kind, n)
	return inst


func _effect(inst: CardInstance) -> EffectBase:
	return inst.cur_activated_abilities[0].effects[0]


# ================================================================ reads ==

func test_the_total_and_the_range_are_read_from_the_source() -> void:
	var hymn := _with_verses(_hymn(), 3)
	var e := _effect(hymn)
	assert_true(e.is_divided())
	assert_eq(e.divided_amount(0), 0, "the source-less reader knows no X")
	assert_eq(e.divided_amount_at(g, hymn, 0), 3)
	assert_eq(e.target_range_at(g, hymn, 0, []), Vector2i(1, 3), "at most one target per point")
	assert_eq(e.target_range(0), Vector2i(1, -1), "the static range: any number")
	assert_string_contains(e.describe(), "prevents the next X damage")


func test_no_counters_no_targets() -> void:
	var hymn := _with_verses(_hymn(), 0)
	assert_eq(_effect(hymn).divided_amount_at(g, hymn, 0), 0)
	assert_eq(_effect(hymn).target_range_at(g, hymn, 0, []), Vector2i(0, 0))


func test_last_known_counters_after_the_sacrifice() -> void:
	var hymn := _with_verses(_hymn(), 2)
	g.sacrifice_permanent(hymn)
	assert_eq(hymn.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(int(EffectBase.source_counters("verse").call(g, hymn)), 2, "CR 608.2h")


# =========================================================== activation ==

func test_three_verses_divide_three() -> void:
	var hymn := _with_verses(_hymn(), 3)
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_ok(g.activate_ability(0, hymn, 0, [TargetRef.player(0, 1), TargetRef.card(bear, 2)]))
	assert_eq(hymn.zone, Mtg.Zone.GRAVEYARD, "sacrificed as the cost")
	resolve_stack()
	assert_eq(g.players[0].damage_prevention, 1)
	assert_eq(bear.prevention, 2)


func test_one_target_takes_it_all() -> void:
	var hymn := _with_verses(_hymn(), 3)
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_ok(g.activate_ability(0, hymn, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.prevention, 3)


func test_the_shares_must_add_up_to_x() -> void:
	var hymn := _with_verses(_hymn(), 3)
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_refused(g.activate_ability(0, hymn, 0, [TargetRef.player(0, 1), TargetRef.card(bear, 1)]),
		"add up to 3")
	assert_eq(hymn.zone, Mtg.Zone.BATTLEFIELD, "the refusal paid nothing")
	assert_refused(g.activate_ability(0, hymn, 0, [TargetRef.player(0, 2), TargetRef.card(bear, 2)]),
		"add up to 3")


func test_no_more_targets_than_points() -> void:
	var hymn := _with_verses(_hymn(), 2)
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(0, "Llanowar Elves")
	assert_refused(g.activate_ability(0, hymn, 0,
		[TargetRef.card(a, 1), TargetRef.card(b, 1), TargetRef.player(0, 1)]))
	assert_eq(hymn.zone, Mtg.Zone.BATTLEFIELD)


func test_zero_verses_activates_with_no_target() -> void:
	var hymn := _with_verses(_hymn(), 0)
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_refused(g.activate_ability(0, hymn, 0, [TargetRef.card(bear)]))
	assert_ok(g.activate_ability(0, hymn, 0, []))
	resolve_stack()
	assert_eq(bear.prevention, 0)
	assert_eq(g.players[0].damage_prevention, 0)


## X is fixed at announcement (CR 601.2c-d): the shares on the stack are
## the ones resolved, whatever the counters do meanwhile.
func test_a_counter_added_in_response_changes_nothing() -> void:
	var chant := _with_verses(_chant(), 2)
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_ok(g.activate_ability(0, chant, 0, [TargetRef.card(bear)]))
	g.add_counters(chant, "verse")
	assert_eq(_effect(chant).divided_amount_at(g, chant, 0), 3, "the source now reads 3")
	resolve_stack()
	assert_eq(bear.prevention, 2, "the announced X")


## The owner's ruling of 2026-10-21: a target that is gone loses its
## share; nothing is redistributed.
func test_a_gone_target_takes_its_share_with_it() -> void:
	var hymn := _with_verses(_hymn(), 3)
	var bear := put_battlefield(0, "Grizzly Bears")
	var elf := put_battlefield(0, "Llanowar Elves")
	assert_ok(g.activate_ability(0, hymn, 0, [TargetRef.card(bear, 1), TargetRef.card(elf, 2)]))
	g.return_to_hand(elf)
	resolve_stack()
	assert_eq(bear.prevention, 1)
	assert_eq(g.players[0].damage_prevention, 0)


func test_divided_damage_from_counters() -> void:
	var volley := _with_verses(_volley(), 3, "charge")
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_ok(g.activate_ability(0, volley, 0, [TargetRef.card(bear, 2), TargetRef.player(1, 1)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 19)
	assert_string_contains(_effect_of(_volley()).describe(), "deals X damage divided")


static func _effect_of(data: CardData) -> EffectBase:
	return data.activated_abilities[0].effects[0]


func test_a_search_rewinds_the_activation() -> void:
	var hymn := _with_verses(_hymn(), 3)
	var bear := put_battlefield(0, "Grizzly Bears")
	var mark := g.make_mark()
	assert_ok(g.activate_ability(0, hymn, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.prevention, 3)
	g.unmake_to(mark)
	g.end_search()
	assert_eq(bear.prevention, 0)
	assert_eq(hymn.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(int(hymn.counters.get("verse", 0)), 3)


# ============================================================ SGManalink ==

func _referee() -> SgPracticeMatch:
	var duel := SgPracticeMatch.new(42)
	duel.game = g
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())
	g.interactive_choices = true
	duel.view(0)
	return duel


func _prepare(duel: SgPracticeMatch, inst: CardInstance) -> Dictionary:
	assert_ok(duel.act(0, {"op": "prepare", "card": duel._handle(0, inst), "kind": "ability",
		"index": 0, "x": 0, "mode": 0}))
	var view := duel.view(0)
	assert_true(SgViewProtocol.game(view), "the announcement validates")
	return view


func test_the_referee_offers_exactly_x_points() -> void:
	var hymn := _with_verses(_hymn(), 3)
	put_battlefield(1, "Grizzly Bears")
	var duel := _referee()
	var slots: Array = _prepare(duel, hymn).announcement.slots
	assert_eq(slots.size(), 1)
	assert_eq(int(slots[0].divided), 3, "the source's three verses")
	assert_eq(int(slots[0].min), 1)
	assert_eq(int(slots[0].max), 3)
	assert_eq(slots[0].counts, [], "a first-slot count needs no rows")
	assert_ok(duel.act(0, {"op": "submit", "targets": [[slots[0].targets[0].id, 3]]}))
	assert_eq(hymn.zone, Mtg.Zone.GRAVEYARD, "activated")


func test_the_referee_offers_up_to_x_targets_for_a_verse_count() -> void:
	var liturgy := _with_verses(_liturgy(), 2)
	for i in 4:
		put_battlefield(1, "Grizzly Bears")
	var duel := _referee()
	var slots: Array = _prepare(duel, liturgy).announcement.slots
	assert_eq(slots.size(), 1)
	assert_eq(int(slots[0].min), 0)
	assert_eq(int(slots[0].max), 2, "two verses: up to two, not every candidate")
	assert_eq(int(slots[0].divided), 0)


func test_the_count_is_bounded_by_the_candidates() -> void:
	var liturgy := _with_verses(_liturgy(), 9)
	var duel := _referee()
	var slots: Array = _prepare(duel, liturgy).announcement.slots
	assert_eq(int(slots[0].max), slots[0].targets.size())
