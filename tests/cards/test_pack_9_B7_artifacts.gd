extends GameTest
## Pack 9 (the Tempest block), batch B7: the Tempest artifacts in
## cards/sets/tmp/_artifacts.gd — Altar of Dementia, Booby Trap, Bottle
## Gnomes, Cold Storage, Cursed Scroll, Echo Chamber, Emmessi Tome,
## Energizer, Essence Bottle, Excavator, Flowstone Sculpture, Fool's Tome,
## Grindstone, Helm of Possession, Jinxed Idol, Mogg Cannon, Patchwork
## Gnomes, Puppet Strings, Scalding Tongs, Squee's Toy, Telethopter,
## Thumbscrews and Torture Chamber. Each card: it is not pending, its main
## effect, a refused case and the interactions its text implies (the 1997
## "tapped artifacts stop" rule where a static is involved).

const CLAIMED := ["Altar of Dementia", "Booby Trap", "Bottle Gnomes", "Cold Storage",
	"Cursed Scroll", "Echo Chamber", "Emmessi Tome", "Energizer", "Essence Bottle",
	"Excavator", "Flowstone Sculpture", "Fool's Tome", "Grindstone", "Helm of Possession",
	"Jinxed Idol", "Mogg Cannon", "Patchwork Gnomes", "Puppet Strings", "Scalding Tongs",
	"Squee's Toy", "Telethopter", "Thumbscrews", "Torture Chamber"]

## Picks the card named [member pick] when offered (else the hint); answers
## options with [member option] (-1 = the hint) or the label [member label].
class Seat extends DecisionAgent:
	var pick := ""
	var option := -1
	var label := ""
	var options_seen: Array = []
	func answer_card(_g: MtgGame, _pid: int, candidates: Array[CardInstance], _prompt: String) -> CardInstance:
		for c in candidates:
			if c.data.card_name == pick: return c
		return null if candidates.is_empty() else candidates[0]
	func answer_option(_g: MtgGame, _pid: int, _prompt: String, options: Array[String], hint: int) -> int:
		options_seen = options.duplicate()
		if label != "" and options.has(label): return options.find(label)
		return hint if option < 0 else option

func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)

func _seat(pid: int) -> Seat:
	var s := Seat.new()
	g.set_agent(pid, s)
	return s

func _on_library_top(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.LIBRARY
	g.players[pid].library.append(inst)
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


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)
		assert_eq(c.set_code, "tmp", card_name)


# --------------------------------------------------------- Altar of Dementia --

func test_altar_of_dementia_mills_the_sacrificed_creatures_power() -> void:
	var altar := put_battlefield(0, "Altar of Dementia")
	var giant := put_battlefield(0, "Hill Giant")   # 3/3
	g.continuous.add_until_eot_pump(giant.id, 2, 0)
	g.recalculate()
	assert_ok(g.activate_ability(0, altar, 0, [TargetRef.player(1)]))
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "sacrificed as the cost")
	resolve_stack()
	assert_eq(g.players[1].graveyard.size(), 5, "its power as it was sacrificed (CR 608.2h)")
	assert_eq(g.players[1].library.size(), 25)
	assert_false(altar.tapped, "no {T}")

func test_altar_of_dementia_needs_a_creature_of_your_own() -> void:
	var altar := put_battlefield(0, "Altar of Dementia")
	put_battlefield(1, "Grizzly Bears")
	assert_refused(g.activate_ability(0, altar, 0, [TargetRef.player(1)]))
	var wall := put_battlefield(0, "Wall of Stone")   # power 0
	assert_ok(g.activate_ability(0, altar, 0, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].library.size(), 30, "power 0 mills nothing")


# --------------------------------------------------------------- Booby Trap --

func test_booby_trap_names_from_the_opponents_decklist_and_springs_on_the_draw() -> void:
	g.players[1].deck_names.append_array(["Lightning Bolt", "Lightning Bolt", "Giant Growth"])
	var seat := _seat(0)
	var trap := put_battlefield(0, "Booby Trap")
	assert_eq(int(trap.memory.get("victim", -1)), 1)
	assert_eq(String(trap.memory.get("named", "")), "Lightning Bolt", "most copies unaccounted for first")
	assert_false(seat.options_seen.has("Forest"), "no basic land name is offered")
	assert_true(seat.options_seen.has("Giant Growth"))
	var shown := _reveals()
	_on_library_top(1, "Lightning Bolt")
	advance_to_next_turn()   # P1 draws it in their draw step
	assert_eq(g.active_player, 1)
	assert_eq(trap.zone, Mtg.Zone.GRAVEYARD, "sacrificed")
	assert_eq(g.players[1].life, 10, "10 damage to that player")
	assert_eq(shown.size(), 1, "the draw was revealed")
	assert_eq(shown[0][1], ["Lightning Bolt"])

func test_booby_trap_reveals_other_draws_and_ignores_its_controllers() -> void:
	g.players[1].deck_names.append_array(["Lightning Bolt", "Giant Growth"])
	var seat := _seat(0)
	seat.label = "Giant Growth"
	var trap := put_battlefield(0, "Booby Trap")
	assert_eq(String(trap.memory.get("named", "")), "Giant Growth")
	var shown := _reveals()
	_on_library_top(0, "Giant Growth")
	g.draw_cards(0, 1)
	assert_true(shown.is_empty(), "only the chosen player reveals")
	_on_library_top(1, "Lightning Bolt")
	advance_to_next_turn()
	assert_eq(shown.size(), 1)
	assert_eq(trap.zone, Mtg.Zone.BATTLEFIELD, "not the chosen name")
	assert_eq(g.players[1].life, 20)
	assert_eq(g.players[0].life, 20)

## Fair play (CONTRIBUTING.md rule 8): the name list and its default are
## read off the decklist and the PUBLIC zones only — where the copies sit
## among the opponent's hidden hand and library changes nothing, a copy
## put where everyone can see it does.
func _trap_named(bolt_in_hand: bool, bolt_in_graveyard := false) -> String:
	g = null
	before_each()
	g.players[1].deck_names.append_array(["Lightning Bolt", "Lightning Bolt", "Giant Growth"])
	var bolt := _make_instance(1, "Lightning Bolt")
	var growth := _make_instance(1, "Giant Growth")
	var hidden: CardInstance = bolt if bolt_in_hand else growth
	var other: CardInstance = growth if bolt_in_hand else bolt
	hidden.zone = Mtg.Zone.HAND
	g.players[1].hand.append(hidden)
	other.zone = Mtg.Zone.LIBRARY
	g.players[1].library.append(other)
	if bolt_in_graveyard:
		var gone := _make_instance(1, "Lightning Bolt")
		gone.zone = Mtg.Zone.GRAVEYARD
		g.players[1].graveyard.append(gone)
	var trap := put_battlefield(0, "Booby Trap")
	return String(trap.memory.get("named", ""))

func test_booby_trap_default_name_reads_no_hidden_zone() -> void:
	var first := _trap_named(true)
	assert_eq(first, _trap_named(false), "hand and library swapped: same answer")
	assert_eq(first, "Lightning Bolt")
	assert_eq(_trap_named(true, true), "Giant Growth", "a public copy moves the count")

func test_cursed_scroll_names_read_only_its_own_side() -> void:
	var lists: Array = []
	for theirs in ["Lightning Bolt", "Giant Growth"]:
		g = null
		before_each()
		g.players[0].deck_names.append_array(["Lightning Bolt", "Giant Growth"])
		give_hand(0, "Giant Growth")
		give_hand(1, theirs)
		var scroll := put_battlefield(0, "Cursed Scroll")
		var seat := _seat(0)
		add_mana(0, Mtg.ManaColor.C, 3)
		assert_ok(g.activate_ability(0, scroll, 0, [TargetRef.player(1)]))
		resolve_stack()
		lists.append(seat.options_seen.duplicate())
	assert_eq(lists[0], lists[1], "the opponent's hand changes nothing")
	assert_eq(lists[0][0], "Giant Growth", "its own hand first")

func test_booby_trap_with_nothing_nameable_never_springs() -> void:
	var trap := put_battlefield(0, "Booby Trap")   # the filler decks are all Forests
	assert_eq(String(trap.memory.get("named", "x")), "")
	advance_to_next_turn()
	assert_eq(trap.zone, Mtg.Zone.BATTLEFIELD)

func test_a_tapped_booby_trap_stops_revealing_only_under_the_1997_rule() -> void:
	for old_rule in [false, true]:
		if old_rule:
			g = null
			before_each()
		g.rules.tapped_artifacts_stop = old_rule
		g.players[1].deck_names.append_array(["Lightning Bolt"])
		var trap := put_battlefield(0, "Booby Trap")
		g.tap_permanent(trap)
		g.recalculate()
		var shown := _reveals()
		_on_library_top(1, "Giant Growth")
		_on_library_top(1, "Lightning Bolt")
		advance_to_next_turn()
		assert_eq(shown.size(), 0 if old_rule else 1, "tapped_artifacts_stop=%s" % old_rule)
		assert_eq(trap.zone, Mtg.Zone.GRAVEYARD, "the trigger is not a static: it still springs")
		assert_eq(g.players[1].life, 10)


# ------------------------------------------------------------- Bottle Gnomes --

func test_bottle_gnomes_sacrifices_for_three_life_even_when_new() -> void:
	var gnomes := put_battlefield(0, "Bottle Gnomes", true)
	g.players[0].life = 12
	assert_ok(g.activate_ability(0, gnomes, 0))
	assert_eq(gnomes.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[0].life, 15)
	assert_refused(g.activate_ability(0, gnomes, 0))
	assert_eq([gnomes.data.power, gnomes.data.toughness], [1, 3])


# -------------------------------------------------------------- Cold Storage --

func test_cold_storage_banks_your_creatures_and_returns_them_under_your_control() -> void:
	var storage := put_battlefield(0, "Cold Storage")
	var bears := put_battlefield(0, "Grizzly Bears")
	var borrowed := put_battlefield(1, "Hill Giant")
	g.change_control(borrowed, 0)
	var theirs := put_battlefield(1, "Craw Wurm")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_refused(g.activate_ability(0, storage, 0, [TargetRef.card(theirs)]))
	assert_ok(g.activate_ability(0, storage, 0, [TargetRef.card(bears)]))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.EXILE)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, storage, 0, [TargetRef.card(borrowed)]))
	resolve_stack()
	assert_eq(borrowed.zone, Mtg.Zone.EXILE)
	assert_false(storage.tapped, "no {T}: as often as you can pay")
	assert_ok(g.activate_ability(0, storage, 1))
	assert_eq(storage.zone, Mtg.Zone.GRAVEYARD, "sacrificed as the cost")
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(borrowed.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(borrowed.controller_id, 0, "under YOUR control")
	assert_eq(borrowed.owner_id, 1)
	assert_false(borrowed.memory.has("cold_storage"))

func test_cold_storage_returns_only_creature_cards_it_exiled_itself() -> void:
	var storage := put_battlefield(0, "Cold Storage")
	var token: CardInstance = g.create_token(0, CardData.new("Test Token", "", Mtg.CardType.CREATURE).pt(1, 1))[0]
	var other := put_battlefield(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, storage, 0, [TargetRef.card(token)]))
	resolve_stack()
	g.exile_permanent(other)   # exiled by something else
	var second := put_battlefield(0, "Cold Storage")
	var mine := put_battlefield(0, "Hill Giant")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, second, 0, [TargetRef.card(mine)]))
	resolve_stack()
	assert_ok(g.activate_ability(0, storage, 1))
	resolve_stack()
	assert_eq(other.zone, Mtg.Zone.EXILE, "not exiled with this artifact")
	assert_eq(mine.zone, Mtg.Zone.EXILE, "exiled with the OTHER Storage")
	assert_eq(g.players[0].battlefield.size(), 1, "the token ceased to exist")
	assert_ok(g.activate_ability(0, second, 1))
	resolve_stack()
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------------------------- Cursed Scroll --

func test_cursed_scroll_hits_when_the_revealed_card_has_the_name() -> void:
	g.players[0].deck_names.append_array(["Lightning Bolt", "Giant Growth"])
	var scroll := put_battlefield(0, "Cursed Scroll")
	var bears := put_battlefield(1, "Grizzly Bears")
	give_hand(0, "Lightning Bolt")
	var seat := _seat(0)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, scroll, 0, [TargetRef.card(bears)]))
	var shown := _reveals()
	resolve_stack()
	assert_eq(seat.options_seen[0], "Lightning Bolt", "the names in your own hand first")
	assert_true(seat.options_seen.has("Giant Growth"))
	assert_eq(shown.size(), 1)
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "2 damage")
	assert_eq(g.players[0].hand.size(), 1, "revealing is not discarding")

func test_cursed_scroll_misses_on_another_name_and_does_nothing_on_an_empty_hand() -> void:
	g.players[0].deck_names.append_array(["Lightning Bolt", "Giant Growth"])
	var scroll := put_battlefield(0, "Cursed Scroll")
	give_hand(0, "Lightning Bolt")
	var seat := _seat(0)
	seat.label = "Giant Growth"
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, scroll, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 20, "a miss")
	g.untap_permanent(scroll)
	g.discard_cards(0, g.players[0].hand.duplicate())
	seat.options_seen = []
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, scroll, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 20)
	assert_true(seat.options_seen.is_empty(), "nothing to reveal: nothing asked")

func test_cursed_scroll_needs_three_and_its_tap() -> void:
	var scroll := put_battlefield(0, "Cursed Scroll")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, scroll, 0, [TargetRef.player(1)]))
	assert_true(scroll.cur_activated_abilities[0].effects[0] is DamageEffect, "typed damage for the AI")


# -------------------------------------------------------------- Echo Chamber --

func test_echo_chamber_copies_the_creature_the_opponent_picks_for_one_hasty_turn() -> void:
	var chamber := put_battlefield(0, "Echo Chamber")
	put_battlefield(1, "Hill Giant")
	put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, chamber, 0, []))
	resolve_stack()
	var tokens: Array = []
	for i in g.players[0].battlefield:
		if i.is_token: tokens.append(i)
	assert_eq(tokens.size(), 1)
	var token: CardInstance = tokens[0]
	assert_eq(token.data.card_name, "Grizzly Bears", "the chooser hands over their weakest body")
	assert_true(token.has_keyword(Mtg.Keyword.HASTE))
	run_combat([token.id])
	assert_eq(g.players[1].life, 18, "it attacks the turn it is made")
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_false(g.players[0].battlefield.has(token), "exiled at the next end step")

func test_echo_chamber_only_as_a_sorcery_and_only_with_a_creature_opposite() -> void:
	var chamber := put_battlefield(0, "Echo Chamber")
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_refused(g.activate_ability(0, chamber, 0, []))
	put_battlefield(0, "Grizzly Bears")
	assert_refused(g.activate_ability(0, chamber, 0, []))
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_refused(g.activate_ability(0, chamber, 0, []), "sorcery")
	assert_eq(chamber.cur_activated_abilities[0].effects[0].ai_role, &"hasty_token")


# -------------------------------------------------------------- Emmessi Tome --

func test_emmessi_tome_draws_two_then_discards_one() -> void:
	var tome := put_battlefield(0, "Emmessi Tome")
	give_hand(0, "Craw Wurm")
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_refused(g.activate_ability(0, tome, 0))
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_ok(g.activate_ability(0, tome, 0))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 2, "one plus two minus one")
	assert_eq(g.players[0].graveyard.size(), 1)
	assert_eq(g.players[0].library.size(), 28)
	assert_true(tome.has_subtype("book"))


# ----------------------------------------------------------------- Energizer --

func test_energizer_grows_a_counter_at_a_time() -> void:
	var sick := put_battlefield(0, "Energizer", true)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, sick, 0), "summoning sickness")
	var energizer := put_battlefield(0, "Energizer")
	assert_ok(g.activate_ability(0, energizer, 0))
	resolve_stack()
	assert_eq([energizer.cur_power, energizer.cur_toughness], [3, 3])
	assert_eq(int(energizer.counters.get("+1/+1", 0)), 1)


# ------------------------------------------------------------ Essence Bottle --

func test_essence_bottle_stores_elixir_and_drinks_it_all() -> void:
	var bottle := put_battlefield(0, "Essence Bottle")
	for n in 3:
		add_mana(0, Mtg.ManaColor.C, 3)
		assert_ok(g.activate_ability(0, bottle, 0))
		resolve_stack()
		g.untap_permanent(bottle)
	assert_eq(int(bottle.counters.get("elixir", 0)), 3)
	g.players[0].life = 10
	assert_ok(g.activate_ability(0, bottle, 1))
	assert_eq(int(bottle.counters.get("elixir", 0)), 0, "removed as the cost, before anyone responds")
	resolve_stack()
	assert_eq(g.players[0].life, 16, "2 life for each of the three")
	g.untap_permanent(bottle)
	assert_ok(g.activate_ability(0, bottle, 1))
	resolve_stack()
	assert_eq(g.players[0].life, 16, "none left: nothing gained")

func test_essence_bottle_needs_three_to_charge() -> void:
	var bottle := put_battlefield(0, "Essence Bottle")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, bottle, 0))


# ----------------------------------------------------------------- Excavator --

func test_excavator_gives_the_sacrificed_basics_landwalk() -> void:
	var excavator := put_battlefield(0, "Excavator")
	var forest := put_battlefield(0, "Forest")
	var bears := put_battlefield(0, "Grizzly Bears")
	assert_ok(g.activate_ability(0, excavator, 0, [TargetRef.card(bears)]))
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_true(bears.cur_landwalk.has("forest"))
	put_battlefield(1, "Forest")
	var wall := put_battlefield(1, "Wall of Stone")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bears.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {wall.id: bears.id}))
	_to_next_turn_of(0)
	assert_false(bears.cur_landwalk.has("forest"), "until end of turn")

func test_excavator_refuses_a_nonbasic_land() -> void:
	var excavator := put_battlefield(0, "Excavator")
	put_battlefield(0, "Ancient Tomb")
	var bears := put_battlefield(0, "Grizzly Bears")
	assert_refused(g.activate_ability(0, excavator, 0, [TargetRef.card(bears)]))


# ------------------------------------------------------- Flowstone Sculpture --

func test_flowstone_sculpture_chooses_a_counter_or_a_lasting_keyword() -> void:
	var seat := _seat(0)
	var sculpture := put_battlefield(0, "Flowstone Sculpture")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, sculpture, 0))
	give_hand(0, "Craw Wurm")
	give_hand(0, "Hill Giant")
	give_hand(0, "Grizzly Bears")
	assert_ok(g.activate_ability(0, sculpture, 0))
	resolve_stack()
	assert_true(sculpture.has_keyword(Mtg.Keyword.FLYING), "the default answer: the evasion it lacks")
	seat.option = 0
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, sculpture, 0))
	resolve_stack()
	assert_eq([sculpture.cur_power, sculpture.cur_toughness], [5, 5])
	seat.option = 3
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, sculpture, 0))
	resolve_stack()
	assert_true(sculpture.has_keyword(Mtg.Keyword.TRAMPLE))
	assert_eq(g.players[0].graveyard.size(), 3, "a card discarded for each")
	_to_next_turn_of(0)
	assert_true(sculpture.has_keyword(Mtg.Keyword.FLYING), "indefinitely")
	assert_true(sculpture.has_keyword(Mtg.Keyword.TRAMPLE))


# --------------------------------------------------------------- Fool's Tome --

func test_fools_tome_draws_only_from_an_empty_hand() -> void:
	var tome := put_battlefield(0, "Fool's Tome")
	var held := give_hand(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, tome, 0), "no cards in hand")
	g.discard_cards(0, [held])
	assert_ok(g.activate_ability(0, tome, 0))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 1)


# ---------------------------------------------------------------- Grindstone --

func test_grindstone_repeats_while_the_pair_shares_a_colour() -> void:
	var stone := put_battlefield(0, "Grindstone")
	_on_library_top(1, "Grizzly Bears")     # green
	_on_library_top(1, "Lightning Bolt")    # red: the third pair breaks
	_on_library_top(1, "Llanowar Elves")    # green
	_on_library_top(1, "Giant Growth")      # green: the first pair shares
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, stone, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].graveyard.size(), 4, "two pairs")
	assert_eq(g.players[1].library.size(), 30)

func test_grindstone_stops_on_colourless_and_at_the_bottom_of_the_library() -> void:
	var stone := put_battlefield(0, "Grindstone")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, stone, 0, [TargetRef.player(1)]))
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_ok(g.activate_ability(0, stone, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].graveyard.size(), 2, "two Forests share no colour")
	g.players[0].library.clear()
	for n in 5: _on_library_top(0, "Giant Growth")
	g.untap_permanent(stone)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, stone, 0, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].library.size(), 0, "two, two, then the last one")
	assert_eq(g.players[0].graveyard.size(), 5)
	assert_false(g.game_over, "milling is not drawing")


# -------------------------------------------------------- Helm of Possession --

func test_helm_of_possession_holds_while_it_stays_tapped() -> void:
	var helm := put_battlefield(0, "Helm of Possession")
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, helm, 0, [TargetRef.card(giant)]))
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "a creature sacrificed as the cost")
	resolve_stack()
	assert_eq(giant.controller_id, 0)
	_to_next_turn_of(0)
	assert_true(helm.tapped, "you may choose not to untap it — and it holds something")
	assert_eq(giant.controller_id, 0)
	g.untap_permanent(helm)
	g.check_state_based_actions()
	assert_eq(giant.controller_id, 1, "untapped: the hold ends")

func test_helm_of_possession_needs_a_creature_to_sacrifice() -> void:
	var helm := put_battlefield(0, "Helm of Possession")
	var giant := put_battlefield(1, "Hill Giant")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, helm, 0, [TargetRef.card(giant)]))
	assert_false(helm.tapped)

func test_helm_of_possession_untapped_before_resolution_takes_nothing() -> void:
	var helm := put_battlefield(0, "Helm of Possession")
	put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, helm, 0, [TargetRef.card(giant)]))
	g.untap_permanent(helm)   # a Twiddle in response
	resolve_stack()
	assert_eq(giant.controller_id, 1, "the duration had already ended (CR 611.2b)")


# --------------------------------------------------------------- Jinxed Idol --

func test_jinxed_idol_hurts_its_controller_and_can_be_passed_on() -> void:
	var idol := put_battlefield(0, "Jinxed Idol")
	_to_next_turn_of(0)
	assert_eq(g.players[0].life, 18, "2 damage in your upkeep")
	var bears := put_battlefield(0, "Grizzly Bears")
	assert_ok(g.activate_ability(0, idol, 0, [TargetRef.player(1)]))
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(idol.controller_id, 1, "target opponent gains control")
	_to_next_turn_of(1)
	assert_eq(g.players[1].life, 18)
	assert_eq(g.players[0].life, 18)

func test_jinxed_idol_refuses_without_a_creature_or_at_yourself() -> void:
	var idol := put_battlefield(0, "Jinxed Idol")
	assert_refused(g.activate_ability(0, idol, 0, [TargetRef.player(1)]))
	put_battlefield(0, "Grizzly Bears")
	assert_refused(g.activate_ability(0, idol, 0, [TargetRef.player(0)]))


# --------------------------------------------------------------- Mogg Cannon --

func test_mogg_cannon_fires_a_creature_that_dies_at_the_end_step() -> void:
	var cannon := put_battlefield(0, "Mogg Cannon")
	var bears := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Hill Giant")
	assert_refused(g.activate_ability(0, cannon, 0, [TargetRef.card(theirs)]))
	assert_ok(g.activate_ability(0, cannon, 0, [TargetRef.card(bears)]))
	resolve_stack()
	assert_eq([bears.cur_power, bears.cur_toughness], [3, 2])
	assert_true(bears.has_keyword(Mtg.Keyword.FLYING))
	run_combat([bears.id])
	assert_eq(g.players[1].life, 17)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "destroyed at the next end step")


# ---------------------------------------------------------- Patchwork Gnomes --

func test_patchwork_gnomes_regenerate_for_a_discard() -> void:
	var gnomes := put_battlefield(0, "Patchwork Gnomes")
	assert_refused(g.activate_ability(0, gnomes, 0))
	give_hand(0, "Craw Wurm")
	assert_ok(g.activate_ability(0, gnomes, 0))
	assert_eq(g.players[0].hand.size(), 0, "discarded as the cost")
	resolve_stack()
	assert_eq(gnomes.regeneration_shields, 1)
	g.destroy(gnomes)
	assert_eq(gnomes.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(gnomes.tapped)
	assert_true(gnomes.cur_activated_abilities[0].effects[0].is_regeneration, "the 1997 regeneration window")


# ------------------------------------------------------------ Puppet Strings --

func test_puppet_strings_taps_or_untaps_or_leaves_it() -> void:
	var seat := _seat(0)
	var strings := put_battlefield(0, "Puppet Strings")
	var giant := put_battlefield(1, "Hill Giant")
	var bears := put_battlefield(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, strings, 0, [TargetRef.card(giant)]))
	resolve_stack()
	assert_true(giant.tapped, "their untapped creature: tap it")
	g.untap_permanent(strings)
	g.tap_permanent(bears)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, strings, 0, [TargetRef.card(bears)]))
	resolve_stack()
	assert_false(bears.tapped, "our tapped creature: untap it")
	g.untap_permanent(strings)
	seat.option = 2
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, strings, 0, [TargetRef.card(bears)]))
	resolve_stack()
	assert_false(bears.tapped, "\"you may\": left as it is")
	assert_eq(seat.options_seen.size(), 3)
	assert_refused(g.activate_ability(0, strings, 0, [TargetRef.card(giant)]), "tapped")


# ------------------------------------------------ Scalding Tongs / Thumbscrews --

func test_scalding_tongs_bites_while_your_hand_is_small() -> void:
	put_battlefield(0, "Scalding Tongs")
	for n in 3: give_hand(0, "Grizzly Bears")
	_to_next_turn_of(0)   # the draw comes after the upkeep: three in hand
	assert_eq(g.players[1].life, 19)
	give_hand(0, "Grizzly Bears")
	_to_next_turn_of(0)
	assert_eq(g.players[1].life, 19, "five in hand: no trigger")

func test_thumbscrews_bites_while_your_hand_is_full() -> void:
	put_battlefield(0, "Thumbscrews")
	for n in 4: give_hand(0, "Grizzly Bears")
	_to_next_turn_of(0)
	assert_eq(g.players[1].life, 20, "four in hand at the upkeep")
	_to_next_turn_of(0)   # five (the draw), then the upkeep
	assert_eq(g.players[1].life, 19)
	assert_eq(g.players[0].life, 20, "target opponent only")


# -------------------------------------------------------------- Squee's Toy --

func test_squees_toy_prevents_one_to_a_creature() -> void:
	var toy := put_battlefield(0, "Squee's Toy")
	var bears := put_battlefield(0, "Grizzly Bears")
	assert_refused(g.activate_ability(0, toy, 0, [TargetRef.player(0)]))
	assert_ok(g.activate_ability(0, toy, 0, [TargetRef.card(bears)]))
	resolve_stack()
	g.deal_damage(toy, TargetRef.card(bears), 2)
	g.check_state_based_actions()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bears.damage, 1)
	assert_true(toy.cur_activated_abilities[0].effects[0].is_damage_prevention, "the 1997 prevention window")


# --------------------------------------------------------------- Telethopter --

func test_telethopter_taps_any_untapped_creature_for_flying() -> void:
	var thopter := put_battlefield(0, "Telethopter")
	var bears := put_battlefield(0, "Grizzly Bears", true)
	var seat := _seat(0)
	seat.pick = "Grizzly Bears"
	assert_ok(g.activate_ability(0, thopter, 0))
	assert_true(bears.tapped, "a summoning-sick creature pays: no {T} symbol (CR 302.6)")
	resolve_stack()
	assert_true(thopter.has_keyword(Mtg.Keyword.FLYING))
	assert_false(thopter.tapped)
	seat.pick = "Telethopter"
	assert_ok(g.activate_ability(0, thopter, 0))
	assert_true(thopter.tapped, "it may tap itself")
	resolve_stack()
	assert_refused(g.activate_ability(0, thopter, 0))
	_to_next_turn_of(0)
	assert_false(thopter.has_keyword(Mtg.Keyword.FLYING), "until end of turn")


# ------------------------------------------------------------ Torture Chamber --

func test_torture_chamber_gathers_pain_and_hurts_its_controller() -> void:
	var chamber := put_battlefield(0, "Torture Chamber")
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(g.players[0].life, 20, "no counters yet")
	_to_next_turn_of(0)
	assert_eq(int(chamber.counters.get("pain", 0)), 1)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(g.players[0].life, 19)
	_to_next_turn_of(0)
	assert_eq(int(chamber.counters.get("pain", 0)), 2)
	var giant := put_battlefield(1, "Hill Giant")
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_ok(g.activate_ability(0, chamber, 0, [TargetRef.card(giant)]))
	assert_eq(int(chamber.counters.get("pain", 0)), 0, "removed as the cost")
	resolve_stack()
	assert_eq(giant.damage, 2)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(g.players[0].life, 19, "nothing left to hurt with")

func test_torture_chamber_targets_creatures_only() -> void:
	var chamber := put_battlefield(0, "Torture Chamber")
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_refused(g.activate_ability(0, chamber, 0, [TargetRef.player(1)]))
