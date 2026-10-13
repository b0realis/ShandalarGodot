extends GameTest
## EVERY "SACRIFICE THIS WHEN ..." CARD FOLLOWS THE RULES OPTION (the
## owner's ruling of 2026-10-13: "This sacrifice also probably touches other
## similar cards for other lands?" — every land type, subtype and condition,
## in all nine packs, cards that wrote the clause in their own script
## included).
##
## The family is every card whose modern Oracle text prints a STATE trigger
## that sacrifices the permanent itself — "When you control no Islands",
## "no Forests", "no lands", "a Dwarf", "a creature with toughness 2 or
## less", "there are no creatures / lands on the battlefield", Jihad's and
## Call to Arms' colour, "this creature has flying", "no +1/+1 counters",
## "power 7 or greater". Each is one of the three CardData clauses
## (MtgGame.sacrifice_clause_holds); five used to be STATE_CHECK triggers of
## their own (Marjhan, Floodgate, Afiya Grove, Phyrexian Devourer, Call to
## Arms) and always waited on the stack. By default every one is now
## sacrificed at once, under every preset; with
## RulesOptions.sacrifice_clauses_wait on, every one waits on the stack.

const PACKS := ["pack-1", "pack-2", "pack-3", "pack-4", "pack-5", "pack-6",
	"pack-7", "pack-8", "pack-9"]

## The sweep of 2026-10-13, by Oracle text over every pack.
const FAMILY := ["Afiya Grove", "Call to Arms", "Dandân", "Drop of Honey",
	"Endangered Armodon", "Floodgate", "Giant Shark", "Goblins of the Flarg",
	"Gorilla Pack", "Island Fish Jasconius", "Jihad", "Kukemssa Serpent",
	"Mana Vortex", "Manta Ray", "Marjhan", "Merchant Ship",
	"Phyrexian Devourer", "Pirate Ship", "Sea Serpent", "Seasinger",
	"Serendib Djinn", "Skeleton Ship", "Vodalian Knights"]


func before_all() -> void:
	for p in PACKS: CardPacks.set_enabled(p, true)
	CardRegistry.ensure_loaded()


func after_all() -> void:
	for p in PACKS: CardPacks.set_enabled(p, false)


func after_each() -> void:
	g = null


func _clause_items(card: CardInstance) -> int:
	var n := 0
	for item in g.stack + g._waiting_triggers:
		if item.kind == Mtg.StackKind.TRIGGER and item.card == card \
				and g._c2s_clause_triggers.has(item.trigger):
			n += 1
	return n


func _start(preset: String, wait: bool) -> void:
	before_each()
	g.rules.set_preset(preset)
	g.rules.sacrifice_clauses_wait = wait
	advance_to_step(Mtg.Step.MAIN1)


func _settle(card: CardInstance) -> void:
	g.check_state_based_actions()
	assert_eq(card.zone, Mtg.Zone.BATTLEFIELD, "%s is safe to begin with" % card.data.card_name)
	assert_eq(_clause_items(card), 0, "%s: nothing waits yet" % card.data.card_name)


## Put [param card_name] on seat 0's battlefield with its clause NOT holding,
## then make it hold. Returns the card.
func _place_and_doom(card_name: String) -> CardInstance:
	var card: CardInstance
	match card_name:
		"Serendib Djinn":   # "When you control no lands"
			var land := put_battlefield(0, "Forest")
			card = put_battlefield(0, card_name)
			_settle(card)
			g.destroy(land, false)
		"Mana Vortex":   # "When there are no lands on the battlefield"
			var land := put_battlefield(1, "Forest")
			card = put_battlefield(0, card_name)
			_settle(card)
			g.destroy(land, false)
		"Drop of Honey":   # "When there are no creatures on the battlefield"
			var bears := put_battlefield(1, "Grizzly Bears")
			card = put_battlefield(0, card_name)
			_settle(card)
			g.destroy(bears, false)
		"Goblins of the Flarg":   # "When you control a Dwarf"
			card = put_battlefield(0, card_name)
			_settle(card)
			put_battlefield(0, "Dwarven Warriors")
		"Jihad":   # the chosen player's chosen colour is gone
			var bears := put_battlefield(1, "Grizzly Bears")
			card = put_battlefield(0, card_name)
			_settle(card)
			g.destroy(bears, false)
		"Endangered Armodon":   # "a creature with toughness 2 or less"
			card = put_battlefield(0, card_name)
			_settle(card)
			put_battlefield(0, "Grizzly Bears")
		"Floodgate":   # "When this creature has flying"
			put_battlefield(0, "Island")
			card = put_battlefield(0, card_name)
			_settle(card)
			g.continuous.add_until_eot_keywords(card.id, [Mtg.Keyword.FLYING])
			g.recalculate()
		"Afiya Grove":   # "no +1/+1 counters on it"
			card = put_battlefield(0, card_name)
			_settle(card)
			g.remove_counters(card, "+1/+1", int(card.counters.get("+1/+1", 0)))
		"Phyrexian Devourer":   # "power is 7 or greater"
			card = put_battlefield(0, card_name)
			_settle(card)
			g.add_counters(card, "+1/+1", 7)
			g.recalculate()
		"Call to Arms":   # the chosen colour is no longer strictly most common
			put_battlefield(1, "Grizzly Bears")
			card = put_battlefield(0, card_name)
			_settle(card)
			put_battlefield(1, "Merfolk of the Pearl Trident")
		_:   # "When you control no Islands" (no Forests: Gorilla Pack)
			var land := put_battlefield(0, "Forest" if card_name == "Gorilla Pack" else "Island")
			card = put_battlefield(0, card_name)
			_settle(card)
			g.destroy(land, false)
	return card


func test_every_card_of_the_family_is_sacrificed_at_once_under_every_preset() -> void:
	for preset in ["modern_mana_burn", "modern", "fifth"]:
		for card_name in FAMILY:
			_start(preset, false)
			var card := _place_and_doom(card_name)
			g.check_state_based_actions()
			assert_eq(card.zone, Mtg.Zone.GRAVEYARD, "%s (%s): at once" % [card_name, preset])
			assert_eq(_clause_items(card), 0, "%s (%s): nothing waits" % [card_name, preset])


func test_switched_on_every_card_of_the_family_waits_on_the_stack() -> void:
	for card_name in FAMILY:
		_start(RulesOptions.DEFAULT_PRESET, true)
		var card := _place_and_doom(card_name)
		g.check_state_based_actions()
		assert_eq(card.zone, Mtg.Zone.BATTLEFIELD, "%s waits" % card_name)
		assert_eq(_clause_items(card), 1, "%s: one trigger" % card_name)
		g.check_state_based_actions()
		assert_eq(_clause_items(card), 1, "%s: and only one" % card_name)
		resolve_stack()
		assert_eq(card.zone, Mtg.Zone.GRAVEYARD, "%s: then it goes" % card_name)


func test_the_family_is_every_card_with_a_clause_and_none_writes_its_own() -> void:
	# The list above is the sweep; this keeps it whole. A card added later
	# with one of the three clauses must join it, and no card may write the
	# clause as a STATE_CHECK trigger of its own again — that one would
	# ignore the rules option.
	var with_clause: Array = []
	var own_trigger: Array = []
	for card_name in CardRegistry.all_names():
		var data := CardRegistry.get_card(card_name)
		if data == null:
			continue
		if MtgGame._c2s_has_clause(data):
			with_clause.append(card_name)
		for trig in data.triggered_abilities:
			if trig.event_type == Mtg.EventType.STATE_CHECK \
					and trig.text.to_lower().contains("sacrifice"):
				own_trigger.append(card_name)
	with_clause.sort()
	var family := FAMILY.duplicate()
	family.sort()
	assert_eq(with_clause, family, "the family is exactly the cards with a clause")
	assert_eq(own_trigger, [], "no card sacrifices itself through a state trigger of its own")


func test_phyrexian_devourer_has_no_intervening_if() -> void:
	# "When this creature's power is 7 or greater, sacrifice it." Switched
	# on, its power falling back under 7 in response does not save it.
	_start(RulesOptions.DEFAULT_PRESET, true)
	var devourer := _place_and_doom("Phyrexian Devourer")
	g.check_state_based_actions()
	assert_eq(_clause_items(devourer), 1)
	g.remove_counters(devourer, "+1/+1", 7)
	g.recalculate()
	assert_lt(devourer.cur_power, 7)
	resolve_stack()
	assert_eq(devourer.zone, Mtg.Zone.GRAVEYARD)


func test_gorilla_pack_counts_forests_only_and_only_its_controllers() -> void:
	for wait in [false, true]:
		_start(RulesOptions.DEFAULT_PRESET, wait)
		put_battlefield(1, "Forest")
		put_battlefield(0, "Island")
		var pack := put_battlefield(0, "Gorilla Pack")
		g.check_state_based_actions()
		if wait:
			assert_eq(_clause_items(pack), 1, "their Forest and your Island do not help")
			resolve_stack()
		assert_eq(pack.zone, Mtg.Zone.GRAVEYARD, "wait=%s" % wait)


func test_marjhan_follows_the_option_both_ways() -> void:
	# It used to be a respondable state trigger of its own under every
	# preset; it is now the engine's clause, so the default is at once.
	for wait in [false, true]:
		_start(RulesOptions.DEFAULT_PRESET, wait)
		var island := put_battlefield(0, "Island")
		var marjhan := put_battlefield(0, "Marjhan")
		g.check_state_based_actions()
		g.destroy(island, false)
		g.check_state_based_actions()
		assert_eq(g.stack.is_empty(), not wait, "a stack item only when switched on")
		resolve_stack()
		assert_eq(marjhan.zone, Mtg.Zone.GRAVEYARD)
