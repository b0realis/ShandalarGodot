extends GameTest
## Pack 9 (the Tempest block), batch B12: the Exodus artifacts in
## cards/sets/exo/_artifacts.gd — Coat of Arms, Erratic Portal, Medicine
## Bag, Mindless Automaton, Null Brooch, Skyshaper, Spellbook and Thopter
## Squadron. Each card: it is not pending, its main effect, a refused case
## and the interactions its text implies (the 1997 "tapped artifacts stop"
## rule for the two statics).

const CLAIMED := ["Coat of Arms", "Erratic Portal", "Medicine Bag", "Mindless Automaton",
	"Null Brooch", "Skyshaper", "Spellbook", "Thopter Squadron"]

func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)

func _creature(pid: int, card_name: String, types: Array, p := 1, t := 1) -> CardInstance:
	return put_synthetic(pid, CardData.new(card_name, "{1}", Mtg.CardType.CREATURE).pt(p, t).with_subtypes(types))

func _pt(i: CardInstance) -> Array: return [i.cur_power, i.cur_toughness]


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)
		assert_eq(c.set_code, "exo", card_name)


# ------------------------------------------------------------ Coat of Arms --

func test_coat_of_arms_counts_other_creatures_sharing_a_type_on_both_sides() -> void:
	put_battlefield(0, "Coat of Arms")
	var w1 := _creature(0, "Test Goblin Warrior", ["goblin", "warrior"])
	var w2 := _creature(0, "Test Goblin Warrior", ["goblin", "warrior"])
	var shaman := _creature(0, "Test Goblin Shaman", ["goblin", "shaman"])
	var bear := put_battlefield(0, "Grizzly Bears")
	g.recalculate()
	# The printed example: each of the three gets +2/+2.
	assert_eq(_pt(w1), [3, 3])
	assert_eq(_pt(w2), [3, 3])
	assert_eq(_pt(shaman), [3, 3])
	assert_eq(_pt(bear), [2, 2], "a Bear shares no type with them")
	# "On the battlefield": an opponent's Goblin counts too, and is pumped.
	var theirs := _creature(1, "Test Goblin", ["goblin"])
	g.recalculate()
	assert_eq(_pt(w1), [4, 4])
	assert_eq(_pt(theirs), [4, 4])
	# One shared type is enough, and a creature counts once however many it shares.
	assert_eq(_pt(w2), [4, 4], "the other Warrior shares two types and still counts once")

func test_coat_of_arms_ignores_land_types_and_untyped_bodies() -> void:
	put_battlefield(0, "Coat of Arms")
	var a := _creature(0, "Test Forest Beast", ["forest"])
	var b := _creature(0, "Test Forest Beast", ["forest"])
	var c := put_synthetic(0, CardData.new("Test Blob", "{1}", Mtg.CardType.CREATURE).pt(1, 1))
	var d := put_synthetic(0, CardData.new("Test Blob", "{1}", Mtg.CardType.CREATURE).pt(1, 1))
	g.recalculate()
	assert_eq(_pt(a), [1, 1], "Forest is a land type, not a creature type (CR 205.3)")
	assert_eq(_pt(b), [1, 1])
	assert_eq(_pt(c), [1, 1], "no creature types: nothing shared")
	assert_eq(_pt(d), [1, 1])

func test_a_tapped_coat_of_arms_stops_only_under_the_1997_rule() -> void:
	for old_rule in [false, true]:
		if old_rule: before_each()
		g.rules.tapped_artifacts_stop = old_rule
		var coat := put_battlefield(0, "Coat of Arms")
		var a := _creature(0, "Test Elf", ["elf"])
		_creature(0, "Test Elf", ["elf"])
		g.recalculate()
		assert_eq(_pt(a), [2, 2])
		g.tap_permanent(coat)
		g.recalculate()
		assert_eq(_pt(a), [1, 1] if old_rule else [2, 2])


# ---------------------------------------------------------- Erratic Portal --

func test_erratic_portal_bounces_unless_the_controller_pays_one() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var portal := put_battlefield(0, "Erratic Portal")
	var bear := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, portal, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.HAND, "no mana to pay: back to its owner's hand")
	assert_true(portal.tapped)
	assert_refused(g.activate_ability(0, portal, 0, [TargetRef.card(put_battlefield(1, "Hill Giant"))]))

func test_erratic_portal_is_bought_off_by_the_creatures_controller() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var portal := put_battlefield(0, "Erratic Portal")
	var bear := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, portal, 0, [TargetRef.card(bear)]))
	add_mana(1, Mtg.ManaColor.G)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "its controller paid {1}")
	assert_eq(g.players[1].mana_pool.total(), 0, "and the {1} was spent")


# ------------------------------------------------------------ Medicine Bag --

func test_medicine_bag_discards_a_card_to_regenerate_target_creature() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bag := put_battlefield(0, "Medicine Bag")
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_refused(g.activate_ability(0, bag, 0, [TargetRef.card(bear)]), "")
	give_hand(0, "Forest")
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, bag, 0, [TargetRef.card(bear)]))
	assert_eq(g.players[0].hand.size(), 0, "the discard is part of the cost")
	resolve_stack()
	assert_eq(bear.regeneration_shields, 1, "any target creature, even theirs")
	g.destroy(bear)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(bear.tapped, "regenerated: tapped")
	assert_true(bag.data.activated_abilities[0].effects[0].is_regeneration)


# ------------------------------------------------------ Mindless Automaton --

func test_mindless_automaton_grows_by_discard_and_cashes_counters_for_cards() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bot := put_battlefield(0, "Mindless Automaton")
	assert_eq(int(bot.counters.get("+1/+1", 0)), 2, "enters with two +1/+1 counters")
	assert_eq(_pt(bot), [2, 2])
	give_hand(0, "Forest")
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, bot, 0))
	resolve_stack()
	assert_eq(int(bot.counters.get("+1/+1", 0)), 3)
	assert_eq(g.players[0].hand.size(), 0)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.activate_ability(0, bot, 0), "")   # no card to discard
	var library := g.players[0].library.size()
	assert_ok(g.activate_ability(0, bot, 1))
	assert_eq(int(bot.counters.get("+1/+1", 0)), 1, "two counters removed as the cost")
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 1, "draw a card")
	assert_eq(g.players[0].library.size(), library - 1)
	assert_refused(g.activate_ability(0, bot, 1), "counters")
	assert_eq(_pt(bot), [1, 1])


# ------------------------------------------------------------- Null Brooch --

func test_null_brooch_discards_the_hand_to_counter_a_noncreature_spell() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var brooch := put_battlefield(1, "Null Brooch")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_ok(g.pass_priority(0))
	give_hand(1, "Forest")
	give_hand(1, "Grizzly Bears")
	add_mana(1, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(1, brooch, 0, [TargetRef.card(bolt)]))
	assert_eq(g.players[1].hand.size(), 0, "the whole hand is discarded as the cost")
	assert_eq(g.players[1].graveyard.size(), 2)
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 20, "countered")

func test_null_brooch_cannot_target_a_creature_spell_and_an_empty_hand_pays() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var brooch := put_battlefield(1, "Null Brooch")
	var bear := give_hand(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, bear, []))
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(1, brooch, 0, [TargetRef.card(bear)]), "")
	resolve_stack()
	var giant := give_hand(0, "Giant Growth")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, giant, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(1, brooch, 0, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(_pt(bear), [2, 2], "countered with an empty hand")


# --------------------------------------------------------------- Skyshaper --

func test_skyshaper_gives_only_your_creatures_flying_until_end_of_turn() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var shaper := put_battlefield(0, "Skyshaper")
	var bear := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Hill Giant")
	assert_ok(g.activate_ability(0, shaper, 0))
	assert_eq(shaper.zone, Mtg.Zone.GRAVEYARD, "sacrificed as the cost")
	resolve_stack()
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING))
	assert_false(theirs.has_keyword(Mtg.Keyword.FLYING))
	var late := put_battlefield(0, "Grizzly Bears")
	g.recalculate()
	assert_false(late.has_keyword(Mtg.Keyword.FLYING), "a creature arriving later gets nothing")
	advance_to_next_turn()
	assert_false(bear.has_keyword(Mtg.Keyword.FLYING), "until end of turn")


# --------------------------------------------------------------- Spellbook --

func _fill_hand(pid: int, n: int) -> void:
	for _k in n: give_hand(pid, "Forest")

func test_spellbook_removes_the_maximum_hand_size() -> void:
	put_battlefield(0, "Spellbook")
	_fill_hand(0, 9)
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	assert_eq(g.players[0].hand.size(), 9, "no discard at cleanup")

func test_without_spellbook_or_with_it_tapped_in_1997_the_hand_is_seven() -> void:
	_fill_hand(0, 9)
	advance_to_next_turn()
	assert_eq(g.players[0].hand.size(), 7, "the control: discard to seven")
	before_each()
	g.rules.tapped_artifacts_stop = true
	var book := put_battlefield(0, "Spellbook")
	g.tap_permanent(book)
	_fill_hand(0, 9)
	advance_to_next_turn()
	assert_eq(g.players[0].hand.size(), 7, "a tapped Spellbook does nothing under the 1997 rule")


# -------------------------------------------------------- Thopter Squadron --

func test_thopter_squadron_turns_counters_into_flying_thopter_tokens() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var squad := put_battlefield(0, "Thopter Squadron")
	assert_eq(_pt(squad), [3, 3], "enters with three +1/+1 counters")
	assert_true(squad.has_keyword(Mtg.Keyword.FLYING))
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, squad, 0))
	resolve_stack()
	assert_eq(_pt(squad), [2, 2])
	var tokens: Array = g.players[0].battlefield.filter(func(i: CardInstance) -> bool: return i.is_token)
	assert_eq(tokens.size(), 1)
	var thopter: CardInstance = tokens[0]
	assert_eq(thopter.data.card_name, "Thopter")
	assert_eq(_pt(thopter), [1, 1])
	assert_true(thopter.has_keyword(Mtg.Keyword.FLYING))
	assert_true(thopter.is_type(Mtg.CardType.ARTIFACT) and thopter.is_creature())
	assert_eq(thopter.cur_colors, 0, "colorless")
	assert_true(thopter.has_subtype("thopter"))
	# "Sacrifice another Thopter": the token goes, the Squadron grows.
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, squad, 1))
	resolve_stack()
	assert_eq(_pt(squad), [3, 3])
	assert_false(g.players[0].battlefield.has(thopter))

func test_thopter_squadron_is_sorcery_speed_and_never_eats_itself() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var squad := put_battlefield(0, "Thopter Squadron")
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.activate_ability(0, squad, 1), "")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, []))
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.activate_ability(0, squad, 0), "sorcery")
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.activate_ability(0, squad, 0), "sorcery")
