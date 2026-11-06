extends GameTest
## Pack 10 (the Urza block), batch B8: the Urza's Saga artifacts of
## cards/sets/usg/_artifacts.gd, first half — Barrin's Codex, Chimeric
## Staff, Citanul Flute, Claws of Gix, Copper Gnomes, Crystal Chimes,
## Dragon Blood, Endoskeleton, Grafted Skullcap, Hopping Automaton,
## Lifeline and Lotus Blossom — plus the claim of all 45 B8 names. Each
## card: its main effect, a refused or declined case and the interactions
## its text implies.

const CLAIMED := {
	"usg": ["Barrin's Codex", "Chimeric Staff", "Citanul Flute", "Claws of Gix", "Copper Gnomes",
		"Crystal Chimes", "Dragon Blood", "Endoskeleton", "Grafted Skullcap", "Hopping Automaton",
		"Lifeline", "Lotus Blossom", "Metrognome", "Mishra's Helix", "Mobile Fort", "Noetic Scales",
		"Phyrexian Processor", "Purging Scythe", "Smokestack", "Umbilicus", "Urza's Armor",
		"Whetstone", "Wirecat"],
	"ulg": ["Angel's Trumpet", "Beast of Burden", "Crawlspace", "Defense Grid", "Iron Maiden",
		"Jhoira's Toolbox", "Memory Jar", "Quicksilver Amulet", "Scrapheap", "Thran Lens",
		"Wheel of Torture"],
	"uds": ["Braidwood Cup", "Braidwood Sextant", "Brass Secretary", "Caltrops", "Fodder Cannon",
		"Mantis Engine", "Powder Keg", "Scrying Glass", "Thran Foundry", "Thran Golem",
		"Urza's Incubator"],
}

## Answers yes/no with [member yes] (-1 = the hint), cards by [member pick]
## ("" = the first offered, "-" = decline), options by [member option]
## (-1 = the hint); records every question.
class Seat extends DecisionAgent:
	var yes := -1
	var pick := ""
	var option := -1
	var asked: Array = []
	func answer_yes_no(_g: MtgGame, _pid: int, prompt: String, hint: bool) -> bool:
		asked.append(["yes_no", prompt, hint])
		return hint if yes < 0 else yes == 1
	func answer_card(_g: MtgGame, _pid: int, candidates: Array[CardInstance], prompt: String) -> CardInstance:
		var names: Array = []
		for c in candidates: names.append(c.data.card_name)
		asked.append(["card", prompt, names])
		if pick == "-": return null
		for c in candidates:
			if c.data.card_name == pick: return c
		return null if candidates.is_empty() else candidates[0]
	func answer_option(_g: MtgGame, _pid: int, prompt: String, options: Array[String], hint: int) -> int:
		asked.append(["option", prompt, options.duplicate(), hint])
		return hint if option < 0 else option

func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

func _seat(pid: int) -> Seat:
	var s := Seat.new()
	g.set_agent(pid, s)
	return s

func _on_library_top(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.LIBRARY
	g.players[pid].library.append(inst)
	return inst

func _in_graveyard(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.GRAVEYARD
	g.players[pid].graveyard.append(inst)
	return inst

func _to_next_turn_of(pid: int) -> void:
	advance_to_next_turn()
	if g.active_player != pid: advance_to_next_turn()
	assert_eq(g.active_player, pid)

func _reveals() -> Array:
	var seen: Array = []
	g.information_revealed.connect(func(_viewer: int, title: String, names: Array) -> void:
		seen.append([title, names.duplicate()]))
	return seen


func test_every_b8_card_is_claimed_by_its_artifacts_module() -> void:
	for code in CLAIMED:
		for card_name in CLAIMED[code]:
			var c := CardRegistry.get_card(card_name)
			assert_not_null(c, card_name)
			if c == null: continue
			var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
			assert_false(pending, "%s is still pending" % card_name)
			assert_eq(c.set_code, code, card_name)
			var module: GDScript = load("res://cards/sets/%s/_artifacts.gd" % code)
			var probe := CardData.new(card_name, "", Mtg.CardType.ARTIFACT)
			assert_true(module.configure(probe), "%s is claimed by %s/_artifacts.gd" % [card_name, code])

func test_thran_golem_prints_no_keyword() -> void:
	assert_true(CardRegistry.get_card("Thran Golem").keywords.is_empty(),
		"flying, first strike and trample are the enchanted bonus only")


# ------------------------------------------------------------ Barrin's Codex --

func test_barrins_codex_may_add_a_page_each_upkeep_and_draws_that_many() -> void:
	var book := put_battlefield(0, "Barrin's Codex")
	_to_next_turn_of(0)
	assert_eq(int(book.counters.get("page", 0)), 1, "the hint is yes")
	var seat := _seat(0)
	seat.yes = 0
	_to_next_turn_of(0)
	assert_eq(int(book.counters.get("page", 0)), 1, "declined: no page this time")
	g.add_counters(book, "page", 2)
	var hand := g.players[0].hand.size()
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, book, 0))
	assert_eq(book.zone, Mtg.Zone.GRAVEYARD, "sacrificed as the cost")
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 3, "X = the pages it had as it was sacrificed")

func test_barrins_codex_with_no_page_draws_nothing() -> void:
	var book := put_battlefield(0, "Barrin's Codex")
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, book, 0))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 0)
	assert_eq(g.players[0].library.size(), 30)


# ------------------------------------------------------------ Chimeric Staff --

func test_chimeric_staff_becomes_an_x_by_x_construct_until_end_of_turn() -> void:
	var staff := put_battlefield(0, "Chimeric Staff")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, staff, 0, [], 3))
	resolve_stack()
	assert_true(staff.is_creature())
	assert_true(staff.is_type(Mtg.CardType.ARTIFACT), "still an artifact")
	assert_true(staff.has_subtype("construct"))
	assert_eq([staff.cur_power, staff.cur_toughness], [3, 3])
	advance_to_next_turn()
	assert_false(staff.is_creature(), "the animation ended with the turn")

func test_chimeric_staff_for_zero_is_a_zero_zero_that_dies() -> void:
	var staff := put_battlefield(0, "Chimeric Staff")
	assert_ok(g.activate_ability(0, staff, 0, [], 0))
	resolve_stack()
	assert_eq(staff.zone, Mtg.Zone.GRAVEYARD, "a 0/0 creature (CR 704.5f)")


# ------------------------------------------------------------- Citanul Flute --

func test_citanul_flute_finds_a_creature_of_mana_value_x_or_less_and_reveals_it() -> void:
	var flute := put_battlefield(0, "Citanul Flute")
	_on_library_top(0, "Shivan Dragon")
	_on_library_top(0, "Grizzly Bears")
	_on_library_top(0, "Llanowar Elves")
	var seat := _seat(0)
	seat.pick = "Grizzly Bears"
	var shown := _reveals()
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, flute, 0, [], 2))
	assert_true(flute.tapped)
	resolve_stack()
	var offered: Array = seat.asked[-1][2]
	assert_true(offered.has("Grizzly Bears") and offered.has("Llanowar Elves"))
	assert_false(offered.has("Shivan Dragon"), "mana value 6 is more than X")
	assert_false(offered.has("Forest"), "creature cards only")
	assert_eq(g.players[0].hand.size(), 1)
	assert_eq(g.players[0].hand[0].data.card_name, "Grizzly Bears")
	assert_eq(shown.size(), 1, "the card is revealed")
	assert_eq(shown[0][1], ["Grizzly Bears"])

func test_citanul_flute_for_zero_finds_no_ordinary_creature() -> void:
	var flute := put_battlefield(0, "Citanul Flute")
	_on_library_top(0, "Llanowar Elves")
	assert_ok(g.activate_ability(0, flute, 0, [], 0))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 0)


# --------------------------------------------------------------- Claws of Gix --

func test_claws_of_gix_sacrifices_any_permanent_for_a_life() -> void:
	var claws := put_battlefield(0, "Claws of Gix")
	put_battlefield(0, "Grizzly Bears")
	var seat := _seat(0)
	seat.pick = "Grizzly Bears"
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_ok(g.activate_ability(0, claws, 0))
	resolve_stack()
	assert_eq(g.players[0].life, 21)
	assert_eq(claws.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].graveyard.size(), 1)

func test_claws_of_gix_may_sacrifice_itself() -> void:
	var claws := put_battlefield(0, "Claws of Gix")
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_ok(g.activate_ability(0, claws, 0))
	assert_eq(claws.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[0].life, 21)


# ------------------------------------------------------------- Copper Gnomes --

func test_copper_gnomes_puts_an_artifact_from_hand_onto_the_battlefield() -> void:
	var gnomes := put_battlefield(0, "Copper Gnomes", true)
	var jugg := give_hand(0, "Juggernaut")
	var bears := give_hand(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, gnomes, 0))   # no {T}: summoning sickness does not matter
	assert_eq(gnomes.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(jugg.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(jugg.controller_id, 0)
	assert_eq(bears.zone, Mtg.Zone.HAND, "artifact cards only")

func test_copper_gnomes_may_put_nothing() -> void:
	var gnomes := put_battlefield(0, "Copper Gnomes")
	var jugg := give_hand(0, "Juggernaut")
	_seat(0).pick = "-"
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, gnomes, 0))
	resolve_stack()
	assert_eq(jugg.zone, Mtg.Zone.HAND)

## Not cast, but it still ENTERS: Phyrexian Processor's as-enters payment
## (a replacement, CR 614.12) is asked as it arrives by Copper Gnomes.
func test_copper_gnomes_puts_a_processor_that_still_pays_life() -> void:
	var gnomes := put_battlefield(0, "Copper Gnomes")
	var processor := give_hand(0, "Phyrexian Processor")
	var seat := _seat(0)
	seat.option = 4
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, gnomes, 0))
	resolve_stack()
	assert_eq(processor.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(int(processor.memory.get("paid", -1)), 4)
	assert_eq(g.players[0].life, 16)


# ------------------------------------------------------------ Crystal Chimes --

func test_crystal_chimes_returns_every_enchantment_card_from_your_graveyard() -> void:
	var chimes := put_battlefield(0, "Crystal Chimes")
	var crusade := _in_graveyard(0, "Crusade")
	var strength := _in_graveyard(0, "Holy Strength")
	var bears := _in_graveyard(0, "Grizzly Bears")
	var theirs := _in_graveyard(1, "Crusade")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, chimes, 0))
	resolve_stack()
	assert_eq(crusade.zone, Mtg.Zone.HAND)
	assert_eq(strength.zone, Mtg.Zone.HAND, "an Aura card is an enchantment card")
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD, "your graveyard only")
	assert_eq(chimes.zone, Mtg.Zone.GRAVEYARD)


# --------------------------------------------------------------- Dragon Blood --

func test_dragon_blood_puts_a_counter_on_any_creature() -> void:
	var blood := put_battlefield(0, "Dragon Blood")
	var bears := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, blood, 0, [TargetRef.card(bears)]))
	resolve_stack()
	assert_eq([bears.cur_power, bears.cur_toughness], [3, 3])
	assert_true(blood.tapped)
	assert_refused(g.activate_ability(0, blood, 0, [TargetRef.card(bears)]))


# -------------------------------------------------------------- Endoskeleton --

func test_endoskeleton_holds_while_it_stays_tapped() -> void:
	var skeleton := put_battlefield(0, "Endoskeleton")
	var bears := put_battlefield(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, skeleton, 0, [TargetRef.card(bears)]))
	resolve_stack()
	assert_eq([bears.cur_power, bears.cur_toughness], [2, 5])
	_to_next_turn_of(0)
	assert_true(skeleton.tapped, "the hint keeps it tapped while it holds something")
	assert_eq(bears.cur_toughness, 5)
	g.untap_permanent(skeleton)
	g.recalculate()
	assert_eq(bears.cur_toughness, 2, "untapped: the effect is over")
	g.tap_permanent(skeleton)
	g.recalculate()
	assert_eq(bears.cur_toughness, 2, "and tapping it again does not bring it back (CR 611.2b)")

func test_endoskeleton_works_while_tapped_under_the_1997_rule() -> void:
	g.rules.tapped_artifacts_stop = true
	var skeleton := put_battlefield(0, "Endoskeleton")
	var bears := put_battlefield(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, skeleton, 0, [TargetRef.card(bears)]))
	resolve_stack()
	assert_eq(bears.cur_toughness, 5)

func test_endoskeleton_does_nothing_when_untapped_in_response() -> void:
	var skeleton := put_battlefield(0, "Endoskeleton")
	var bears := put_battlefield(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, skeleton, 0, [TargetRef.card(bears)]))
	g.untap_permanent(skeleton)
	resolve_stack()
	assert_eq(bears.cur_toughness, 2, "the duration had already ended")


# ---------------------------------------------------------- Grafted Skullcap --

func test_grafted_skullcap_draws_an_extra_card_and_discards_the_hand_at_end_step() -> void:
	put_battlefield(0, "Grafted Skullcap")
	advance_to_next_turn()
	assert_eq(g.players[1].hand.size(), 1, "the opponent's draw step is untouched")
	advance_to_next_turn()
	assert_eq(g.active_player, 0)
	assert_eq(g.players[0].hand.size(), 2, "the draw and one more")
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 0, "the hand is discarded at your end step")
	assert_eq(g.players[0].graveyard.size(), 2)
	assert_eq(g.players[1].hand.size(), 1)


# --------------------------------------------------------- Hopping Automaton --

func test_hopping_automaton_trades_size_for_flying() -> void:
	var hopper := put_battlefield(0, "Hopping Automaton", true)
	assert_ok(g.activate_ability(0, hopper, 0))
	resolve_stack()
	assert_eq([hopper.cur_power, hopper.cur_toughness], [1, 1])
	assert_true(hopper.has_keyword(Mtg.Keyword.FLYING))
	assert_ok(g.activate_ability(0, hopper, 0))
	resolve_stack()
	assert_eq(hopper.zone, Mtg.Zone.GRAVEYARD, "a 0/0")


# ------------------------------------------------------------------ Lifeline --

func test_lifeline_returns_a_dead_creature_at_the_next_end_step_to_its_owner() -> void:
	put_battlefield(0, "Lifeline")
	put_battlefield(0, "Hill Giant")
	var bears := put_battlefield(1, "Grizzly Bears")
	g.destroy(bears)
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "not yet: at the next end step")
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bears.controller_id, 1, "under its owner's control")

func test_lifeline_returns_nothing_when_every_creature_died_at_once() -> void:
	put_battlefield(0, "Lifeline")
	var giant := put_battlefield(0, "Hill Giant")
	var bears := put_battlefield(1, "Grizzly Bears")
	var wrath := give_hand(0, "Wrath of God")
	add_mana(0, Mtg.ManaColor.W, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, wrath))
	resolve_stack()
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "no other creature as the trigger resolved (CR 603.4)")

func test_lifeline_does_not_trigger_for_a_lone_creature() -> void:
	put_battlefield(0, "Lifeline")
	var bears := put_battlefield(1, "Grizzly Bears")
	g.destroy(bears)
	assert_true(g.stack.is_empty(), "no other creature: the intervening if fails")
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)

func test_lifeline_leaves_a_card_that_moved_on_and_returns_nothing_for_a_token() -> void:
	put_battlefield(0, "Lifeline")
	put_battlefield(0, "Hill Giant")
	var bears := put_battlefield(1, "Grizzly Bears")
	g.destroy(bears)
	resolve_stack()
	g.return_from_graveyard_to_hand(bears)   # a new object afterwards (CR 400.7)
	var made := g.create_token(1, CardData.new("Saproling", "", Mtg.CardType.CREATURE).pt(1, 1))
	g.destroy(made[0])
	resolve_stack()
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.HAND)
	var saprolings := 0
	for i in g.players[1].battlefield:
		if i.data.card_name == "Saproling": saprolings += 1
	assert_eq(saprolings, 0)


# ------------------------------------------------------------- Lotus Blossom --

func test_lotus_blossom_adds_one_mana_of_a_color_per_petal() -> void:
	var blossom := put_battlefield(0, "Lotus Blossom")
	_to_next_turn_of(0)
	_to_next_turn_of(0)
	assert_eq(int(blossom.counters.get("petal", 0)), 2)
	assert_ok(g.tap_for_mana(0, blossom, 3))   # the red ability
	assert_eq(blossom.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.R), 2, "counted before the sacrifice")

## A Blossom with no petal makes nothing, and the planner never counts it.
func test_an_empty_lotus_blossom_is_no_mana_source() -> void:
	put_battlefield(0, "Lotus Blossom")
	assert_true(ManaPlanner.plan(g, 0, ManaCost.parse("{R}"), 0).is_empty())
	var blossom := put_battlefield(0, "Lotus Blossom")
	g.add_counters(blossom, "petal", 1)
	assert_false(ManaPlanner.plan(g, 0, ManaCost.parse("{R}"), 0).is_empty())
