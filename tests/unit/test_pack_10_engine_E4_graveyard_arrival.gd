extends GameTest
## Pack 10 engine package E4 — "PUT INTO A GRAVEYARD FROM ANYWHERE"
## (CR 603.2, 603.6a, 603.6c, 603.10a; tokens are not cards, CR 111.7 /
## 111.8). One [constant Mtg.EventType.CARD_PUT_INTO_GRAVEYARD] per CARD
## that really lands in a graveyard, whichever door it came through:
## a resolved, countered or fizzled spell, a refused permanent spell, a
## discard, a mill, a death, the legend rule, exile, the ante and an
## owner change. A card a graveyard replacement exiles instead (Forbidden
## Crypt, Yawgmoth's Will, Bösium Strip) never arrives and fires nothing.
## The moved card's OWN graveyard triggers hear it (Serra Avatar's "When
## Serra Avatar is put into a graveyard from anywhere, shuffle it into its
## owner's library"), and so does the battlefield (Planar Void, Energy
## Field, Compost) — a "from anywhere" trigger is never a leaves-the-
## battlefield one (CR 603.6c), so a listener that has left hears nothing.
##
## Every card here is SYNTHETIC; the real ones are batch B13's.

const GRAVE := Mtg.EventType.CARD_PUT_INTO_GRAVEYARD

## Every CARD_PUT_INTO_GRAVEYARD the game dispatched, in order.
var seen: Array = []


func before_each() -> void:
	super.before_each()
	seen = []
	g.event_occurred.connect(_on_event)


func _on_event(event: GameEvent) -> void:
	if event.type == GRAVE:
		seen.append(event)


## How many arrival events named [param inst].
func _arrivals(inst: CardInstance) -> int:
	var n := 0
	for event in seen:
		if event.data.get("instance") == inst:
			n += 1
	return n


func _last_arrival(inst: CardInstance) -> GameEvent:
	for i in range(seen.size() - 1, -1, -1):
		if seen[i].data.get("instance") == inst:
			return seen[i]
	return null


# ------------------------------------------------------------- the cards --

static func _nothing(_g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	pass


static func _never(_g: MtgGame, _s: CardInstance, _e: GameEvent) -> bool:
	return false


## A listener that never fires — its presence alone makes the engine
## announce the event (the dispatch is gated on a listener).
static func _watcher() -> CardData:
	return CardData.new("Test Graveyard Watcher", "{0}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(GRAVE, _nothing,
			"Whenever a card is put into a graveyard from anywhere, nothing happens.", _never))


## Planar Void's shape: "Whenever another card is put into a graveyard from
## anywhere, exile that card." — only the SAME graveyard object (CR 400.7).
static func _void() -> CardData:
	return CardData.new("Test Void", "{B}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(GRAVE, _void_exile,
			"Whenever another card is put into a graveyard from anywhere, exile that card.",
			_another_card))


static func _another_card(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("instance") != s


static func _void_exile(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var card: CardInstance = e.data["instance"]
	if card.zone == Mtg.Zone.GRAVEYARD and card.graveyard_entry == int(e.data["graveyard_entry"]):
		g.exile_from_graveyard(card)


## Energy Field's sacrifice clause: "When a card is put into your graveyard
## from anywhere, sacrifice this enchantment."
static func _field() -> CardData:
	return CardData.new("Test Field", "{1}{U}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(GRAVE, _field_sacrifice,
			"When a card is put into your graveyard from anywhere, sacrifice this enchantment.",
			_into_your_graveyard))


static func _into_your_graveyard(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return int(e.data["owner"]) == s.controller_id


static func _field_sacrifice(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if g.is_present(s):
		g.sacrifice_permanent(s)


## Compost's shape: "Whenever a black card is put into an opponent's
## graveyard from anywhere, you may draw a card." (the "may" is not under test).
static func _compost() -> CardData:
	return CardData.new("Test Compost", "{1}{G}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(GRAVE, _compost_draw,
			"Whenever a black card is put into an opponent's graveyard from anywhere, draw a card.",
			_black_into_opponents))


static func _black_into_opponents(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var card: CardInstance = e.data["instance"]
	return int(e.data["owner"]) != s.controller_id and card.has_color(Mtg.ManaColor.B)


static func _compost_draw(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	g.draw_cards(s.controller_id, 1)


## Serra Avatar's shape: "When this is put into a graveyard from anywhere,
## shuffle it into its owner's library." — a GRAVEYARD trigger of the card
## itself, resolving only for the graveyard object it fired for.
static func _avatar() -> CardData:
	return CardData.new("Test Avatar", "{4}{W}", Mtg.CardType.CREATURE).pt(3, 3) \
		.with_graveyard_trigger(TriggeredAbility.new(GRAVE, _avatar_home,
			"When this creature is put into a graveyard from anywhere, shuffle it into its owner's library.",
			_self_moved))


static func _self_moved(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("instance") == s


static func _avatar_home(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	if s.zone != Mtg.Zone.GRAVEYARD or s.graveyard_entry != int(e.data["graveyard_entry"]):
		return
	g.return_from_graveyard_to_library_top(s)
	g.shuffle_library(s.owner_id)


static func _bear() -> CardData:
	return CardData.new("Test Bear", "{1}{G}", Mtg.CardType.CREATURE).pt(2, 2)


static func _black_bear() -> CardData:
	return CardData.new("Test Black Bear", "{1}{B}", Mtg.CardType.CREATURE).pt(2, 2)


static func _legend() -> CardData:
	return CardData.new("Test Legend", "{2}{W}", Mtg.CardType.CREATURE).pt(2, 2) \
		.with_supertypes(Mtg.Supertype.LEGENDARY)


static func _refused() -> CardData:
	return CardData.new("Test Refused", "{1}{G}", Mtg.CardType.CREATURE).pt(2, 2) \
		.enters_only_if(func(_g: MtgGame, _i: CardInstance, _c: int) -> String:
			return "it never can")


## Forbidden Crypt's replacement, as a static: "If a card would be put into
## your graveyard from anywhere, exile that card instead."
static func _crypt() -> CardData:
	return CardData.new("Test Crypt", "{3}{B}{B}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_crypt_exile,
			"If a card would be put into your graveyard from anywhere, exile that card instead."))


static func _crypt_exile(g: MtgGame, s: CardInstance) -> void:
	g.players[s.controller_id].graveyard_becomes_exile = true


func _cast_and_resolve(pid: int, card: CardInstance, targets: Array = []) -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var cost := card.data.cost
	for color in cost.colored:
		add_mana(pid, int(color), int(cost.colored[color]))
	if cost.generic > 0:
		add_mana(pid, Mtg.ManaColor.C, cost.generic)
	assert_ok(g.cast_spell(pid, card, targets))
	resolve_stack()


# --------------------------------------------- one event per card, per door --

func test_a_resolved_instant_arrives_once() -> void:
	put_synthetic(1, _watcher())
	var bolt := give_hand(0, "Lightning Bolt")
	_cast_and_resolve(0, bolt, [TargetRef.player(1)])
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(_arrivals(bolt), 1)
	var event := _last_arrival(bolt)
	assert_eq(int(event.data["owner"]), 0)
	assert_eq(int(event.data["from_zone"]), Mtg.Zone.STACK)
	assert_eq(int(event.data["graveyard_entry"]), bolt.graveyard_entry)


func test_a_countered_spell_arrives_once() -> void:
	put_synthetic(0, _watcher())
	advance_to_step(Mtg.Step.MAIN1)
	var bear := give_synthetic(0, _bear())
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, bear))
	assert_ok(g.pass_priority(0))
	var counter := give_hand(1, "Counterspell")
	add_mana(1, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(1, counter, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(_arrivals(bear), 1)
	assert_eq(int(_last_arrival(bear).data["from_zone"]), Mtg.Zone.STACK)
	assert_eq(_arrivals(counter), 1, "the counterspell itself resolved into the graveyard")


func test_a_fizzled_spell_arrives_once() -> void:
	put_synthetic(1, _watcher())
	var bear := put_synthetic(1, _bear())
	advance_to_step(Mtg.Step.MAIN1)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	g.exile_permanent(bear)   # the target is gone (setup)
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(_arrivals(bolt), 1)
	assert_eq(_arrivals(bear), 0, "exiled, never in a graveyard")


func test_a_refused_permanent_spell_arrives_once() -> void:
	put_synthetic(1, _watcher())
	var refused := give_synthetic(0, _refused())
	_cast_and_resolve(0, refused)
	assert_eq(refused.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(_arrivals(refused), 1)
	assert_eq(int(_last_arrival(refused).data["from_zone"]), Mtg.Zone.STACK)


func test_a_discard_arrives_once_from_the_hand() -> void:
	put_synthetic(1, _watcher())
	var card := give_hand(0, "Grizzly Bears")
	g.discard_cards(0, [card])
	assert_eq(_arrivals(card), 1)
	assert_eq(int(_last_arrival(card).data["from_zone"]), Mtg.Zone.HAND)
	var other := give_hand(0, "Lightning Bolt")
	g.discard_hand(0)
	assert_eq(_arrivals(other), 1, "a whole-hand discard too")
	var third := give_hand(0, "Shatter")
	g.discard_random(0, 1)
	assert_eq(_arrivals(third), 1, "a random discard too")


func test_a_mill_arrives_once_per_card_beside_the_library_event() -> void:
	put_synthetic(1, _watcher())
	var top := g.players[0].library.back() as CardInstance
	var second := g.players[0].library[g.players[0].library.size() - 2] as CardInstance
	g.mill(0, 2)
	assert_eq(_arrivals(top), 1)
	assert_eq(_arrivals(second), 1)
	assert_eq(int(_last_arrival(top).data["from_zone"]), Mtg.Zone.LIBRARY)


func test_a_death_arrives_once_after_the_dies_event() -> void:
	put_synthetic(1, _watcher())
	var bear := put_synthetic(0, _bear())
	var order: Array = []
	g.event_occurred.connect(func(e: GameEvent) -> void:
		if e.data.get("instance") == bear: order.append(e.type))
	g.destroy(bear)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(_arrivals(bear), 1)
	var event := _last_arrival(bear)
	assert_eq(int(event.data["from_zone"]), Mtg.Zone.BATTLEFIELD)
	assert_eq(int(event.data["from_controller"]), 0)
	assert_eq(order, [Mtg.EventType.LEAVES_BATTLEFIELD, Mtg.EventType.DIES, GRAVE],
		"the existing events keep their order; the arrival is last")


func test_a_sacrificed_stolen_permanent_arrives_in_its_owners_graveyard() -> void:
	put_synthetic(1, _watcher())
	var bear := put_synthetic(1, _bear())
	g.change_control(bear, 0)
	g.sacrifice_permanent(bear)
	var event := _last_arrival(bear)
	assert_not_null(event)
	assert_eq(int(event.data["owner"]), 1)
	assert_eq(int(event.data["from_controller"]), 0)


func test_the_legend_rule_arrives_once() -> void:
	put_synthetic(1, _watcher())
	var first := put_synthetic(0, _legend())
	var second := put_synthetic(0, _legend())
	g.check_state_based_actions()
	var buried := first if first.zone == Mtg.Zone.GRAVEYARD else second
	assert_eq(buried.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(_arrivals(buried), 1)


func test_exile_to_graveyard_arrives_once() -> void:
	put_synthetic(1, _watcher())
	var bear := put_synthetic(0, _bear())
	g.exile_permanent(bear)
	g.return_from_exile_to_graveyard(bear)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(_arrivals(bear), 1)
	assert_eq(int(_last_arrival(bear).data["from_zone"]), Mtg.Zone.EXILE)


func test_the_ante_to_graveyard_is_a_new_graveyard_object() -> void:
	put_synthetic(1, _watcher())
	g.ante_enabled = true
	var staked := g.ante_top_of_library(0)
	assert_not_null(staked)
	var entry := staked.graveyard_entry
	g.remove_from_ante(staked, Mtg.Zone.GRAVEYARD)
	assert_eq(staked.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.players[0].graveyard.has(staked))
	assert_false(g.players[0].ante.has(staked))
	assert_eq(staked.graveyard_entry, entry + 1, "CR 400.7: a new object")
	assert_eq(_arrivals(staked), 1)
	assert_eq(int(_last_arrival(staked).data["from_zone"]), Mtg.Zone.ANTE)


func test_the_ante_to_graveyard_obeys_forbidden_crypt() -> void:
	put_synthetic(1, _watcher())
	put_synthetic(0, _crypt())
	g.recalculate()
	g.ante_enabled = true
	var staked := g.ante_top_of_library(0)
	g.remove_from_ante(staked, Mtg.Zone.GRAVEYARD)
	assert_eq(staked.zone, Mtg.Zone.EXILE)
	assert_true(g.players[0].exile.has(staked))
	assert_eq(_arrivals(staked), 0)


func test_the_ante_to_other_zones_is_unchanged() -> void:
	put_synthetic(1, _watcher())
	g.ante_enabled = true
	var staked := g.ante_top_of_library(0)
	g.remove_from_ante(staked, Mtg.Zone.LIBRARY)
	assert_eq(staked.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[0].library.back(), staked)
	assert_eq(_arrivals(staked), 0)


func test_an_owner_change_in_a_graveyard_arrives_in_the_new_owners() -> void:
	put_synthetic(1, _watcher())
	var bear := put_synthetic(0, _bear())
	g.destroy(bear)
	var entry := bear.graveyard_entry
	seen.clear()
	g.change_owner(bear, 1)
	assert_true(g.players[1].graveyard.has(bear))
	assert_false(g.players[0].graveyard.has(bear))
	assert_eq(bear.graveyard_entry, entry + 1, "another graveyard is another zone (CR 400.7)")
	assert_eq(_arrivals(bear), 1)
	var event := _last_arrival(bear)
	assert_eq(int(event.data["owner"]), 1)
	assert_eq(int(event.data["from_zone"]), Mtg.Zone.GRAVEYARD)


func test_an_owner_change_elsewhere_fires_nothing() -> void:
	put_synthetic(1, _watcher())
	var card := give_hand(0, "Grizzly Bears")
	g.change_owner(card, 1)
	assert_eq(card.zone, Mtg.Zone.HAND)
	assert_eq(_arrivals(card), 0)


# ------------------------------------------------- what never arrives --

func test_a_token_is_not_a_card() -> void:
	put_synthetic(1, _watcher())
	var tokens := g.create_token(0, _bear())
	g.destroy(tokens[0])
	assert_eq(_arrivals(tokens[0]), 0, "CR 111.7/111.8")


func test_a_copy_of_a_spell_is_not_a_card() -> void:
	put_synthetic(1, _watcher())
	advance_to_step(Mtg.Step.MAIN1)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	var copy := g.copy_spell_on_stack(bolt, 0)
	assert_not_null(copy)
	resolve_stack()
	assert_eq(_arrivals(copy), 0, "CR 707.10a")
	assert_eq(_arrivals(bolt), 1)
	assert_eq(seen.size(), 1)


func test_a_graveyard_replacement_means_no_arrival() -> void:
	put_synthetic(1, _watcher())
	put_synthetic(0, _crypt())
	g.recalculate()
	var card := give_hand(0, "Grizzly Bears")
	g.discard_cards(0, [card])
	assert_eq(card.zone, Mtg.Zone.EXILE)
	var bear := put_synthetic(0, _bear())
	g.destroy(bear)
	assert_eq(bear.zone, Mtg.Zone.EXILE)
	var bolt := give_hand(0, "Lightning Bolt")
	_cast_and_resolve(0, bolt, [TargetRef.player(1)])
	assert_eq(bolt.zone, Mtg.Zone.EXILE)
	g.mill(0, 1)
	assert_eq(seen.size(), 0, "replaced events never happen (CR 614.1)")


func test_nothing_is_announced_without_a_listener() -> void:
	var card := give_hand(0, "Grizzly Bears")
	g.discard_cards(0, [card])
	assert_eq(card.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(seen.size(), 0, "gated: the hot path pays nothing")


func test_the_moved_cards_own_graveyard_trigger_is_a_listener() -> void:
	var avatar := give_synthetic(0, _avatar())
	g.discard_cards(0, [avatar])
	assert_eq(_arrivals(avatar), 1, "its own trigger ungates the event")


# ---------------------------------------- the moved card's own trigger --

func test_avatar_from_the_hand_shuffles_itself_back() -> void:
	var avatar := give_synthetic(0, _avatar())
	var library := g.players[0].library.size()
	g.discard_cards(0, [avatar])
	assert_eq(g.stack.size(), 1, "its own trigger, from the graveyard")
	assert_eq(g.stack[0].controller, 0, "its owner's")
	resolve_stack()
	assert_eq(avatar.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[0].library.size(), library + 1)


func test_avatar_from_the_library_triggers_once() -> void:
	var avatar := give_synthetic(0, _avatar())
	g.players[0].hand.erase(avatar)
	avatar.zone = Mtg.Zone.LIBRARY
	g.players[0].library.append(avatar)
	g.mill(0, 1)
	assert_eq(avatar.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.stack.size(), 1, "the library event is not this trigger's")
	resolve_stack()
	assert_eq(avatar.zone, Mtg.Zone.LIBRARY)


func test_avatar_from_the_battlefield_triggers_once() -> void:
	var avatar := put_synthetic(0, _avatar())
	g.destroy(avatar)
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq(avatar.zone, Mtg.Zone.LIBRARY)


func test_avatar_from_the_stack_when_countered() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var avatar := give_synthetic(0, _avatar())
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, avatar))
	assert_ok(g.pass_priority(0))
	var counter := give_hand(1, "Counterspell")
	add_mana(1, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(1, counter, [TargetRef.card(avatar)]))
	resolve_stack()
	assert_eq(avatar.zone, Mtg.Zone.LIBRARY)


func test_avatar_under_forbidden_crypt_is_simply_exiled() -> void:
	put_synthetic(0, _crypt())
	g.recalculate()
	var avatar := give_synthetic(0, _avatar())
	g.discard_cards(0, [avatar])
	assert_eq(avatar.zone, Mtg.Zone.EXILE)
	assert_eq(g.stack.size(), 0)


func test_avatar_that_left_and_came_back_is_not_shuffled_by_the_old_trigger() -> void:
	var avatar := give_synthetic(0, _avatar())
	g.discard_cards(0, [avatar])
	assert_eq(g.stack.size(), 1)
	# Setup: park the first trigger, send the card back to the hand and
	# into the graveyard again — a NEW graveyard object (CR 400.7) with a
	# trigger of its own, which is dropped so only the stale one is left.
	var stale: StackItem = g.stack.pop_back()
	g.return_from_graveyard_to_hand(avatar)
	g.discard_cards(0, [avatar])
	assert_eq(g.stack.size(), 1, "the new object's own trigger")
	g.stack.pop_back()
	g.stack.append(stale)
	resolve_stack()
	assert_eq(avatar.zone, Mtg.Zone.GRAVEYARD, "the old trigger names the old object")


# ------------------------------------------------- battlefield listeners --

func test_void_exiles_every_other_card_that_arrives() -> void:
	var void_ := put_synthetic(0, _void())
	var card := give_hand(1, "Grizzly Bears")
	g.discard_cards(1, [card])
	resolve_stack()
	assert_eq(card.zone, Mtg.Zone.EXILE)
	var bear := put_synthetic(0, _bear())
	g.destroy(bear)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.EXILE)
	g.destroy(void_)
	resolve_stack()
	assert_eq(void_.zone, Mtg.Zone.GRAVEYARD, "it does not hear its own arrival (CR 603.6c)")


func test_void_puts_one_trigger_per_card_of_a_sweep() -> void:
	put_synthetic(0, _void())
	var bodies: Array = [put_synthetic(0, _bear()), put_synthetic(1, _bear()),
		put_synthetic(1, _bear())]
	g.depart_together(bodies, func(i: CardInstance) -> void: g.destroy(i))
	assert_eq(g.stack.size(), 3)
	resolve_stack()
	for body in bodies:
		assert_eq((body as CardInstance).zone, Mtg.Zone.EXILE)


func test_void_exiles_only_the_same_graveyard_object() -> void:
	var void_ := put_synthetic(0, _void())
	var card := give_hand(1, "Grizzly Bears")
	g.discard_cards(1, [card])
	assert_eq(g.stack.size(), 1)
	g.exile_permanent(void_)   # nothing listens any more
	g.return_from_graveyard_to_hand(card)
	g.discard_cards(1, [card])   # back in the graveyard: a new object
	resolve_stack()
	assert_eq(card.zone, Mtg.Zone.GRAVEYARD, "CR 400.7")


func test_field_is_sacrificed_by_a_card_into_its_controllers_graveyard() -> void:
	var field := put_synthetic(0, _field())
	var theirs := give_hand(1, "Grizzly Bears")
	g.discard_cards(1, [theirs])
	assert_eq(g.stack.size(), 0, "not your graveyard")
	var mine := give_hand(0, "Grizzly Bears")
	g.discard_cards(0, [mine])
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq(field.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.stack.size(), 0, "its own arrival is heard by nobody")


func test_field_hears_a_stolen_card_go_home_to_its_owner() -> void:
	var field := put_synthetic(1, _field())
	var bear := put_synthetic(1, _bear())
	g.change_control(bear, 0)
	g.destroy(bear)
	assert_eq(g.stack.size(), 1, "the card went to ITS OWNER's graveyard")
	resolve_stack()
	assert_eq(field.zone, Mtg.Zone.GRAVEYARD)


func test_compost_reads_the_owner_and_the_color() -> void:
	put_synthetic(0, _compost())
	var hand := g.players[0].hand.size()
	var green := give_hand(1, "Grizzly Bears")
	g.discard_cards(1, [green])
	assert_eq(g.stack.size(), 0, "not black")
	var black := give_synthetic(1, _black_bear())
	g.discard_cards(1, [black])
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 1)
	var mine := give_synthetic(0, _black_bear())
	g.discard_cards(0, [mine])
	assert_eq(g.stack.size(), 0, "not an opponent's graveyard")


func test_triggers_go_on_in_apnap_order() -> void:
	# P0 (active) has a Void; the discarded card is P1's Avatar: the
	# active player's trigger goes on first, the Avatar's (P1's) above it.
	put_synthetic(0, _void())
	var avatar := give_synthetic(1, _avatar())
	g.discard_cards(1, [avatar])
	assert_eq(g.stack.size(), 2)
	assert_eq(g.stack[0].controller, 0)
	assert_eq(g.stack[1].controller, 1)
	resolve_stack()
	assert_eq(avatar.zone, Mtg.Zone.LIBRARY, "the Avatar resolves first (CR 603.3b)")


# ------------------------------------------------------------- the journal --

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


func test_arrivals_and_their_triggers_round_trip() -> void:
	var void_ := put_synthetic(0, _void())
	var avatar := give_synthetic(1, _avatar())
	_round_trips(func() -> void:
		g.discard_cards(1, [avatar])
		assert_eq(g.stack.size(), 2), "a discard heard by two triggers")
	assert_eq(avatar.zone, Mtg.Zone.HAND)
	assert_true(g.stack.is_empty())
	g.ante_enabled = true
	var staked := g.ante_top_of_library(0)
	_round_trips(func() -> void:
		g.remove_from_ante(staked, Mtg.Zone.GRAVEYARD)
		assert_eq(g.stack.size(), 1), "the ante into a graveyard")
	assert_eq(staked.zone, Mtg.Zone.ANTE)
	var bear := put_synthetic(0, _bear())
	g.exile_permanent(void_)   # nothing listens from here on
	g.destroy(bear)
	_round_trips(func() -> void:
		g.change_owner(bear, 1), "an owner change between graveyards")
	assert_true(g.players[0].graveyard.has(bear))
