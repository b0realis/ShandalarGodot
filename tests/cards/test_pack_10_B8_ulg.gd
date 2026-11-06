extends GameTest
## Pack 10 (the Urza block), batch B8: the Urza's Legacy artifacts of
## cards/sets/ulg/_artifacts.gd — Angel's Trumpet, Beast of Burden,
## Crawlspace, Defense Grid, Iron Maiden, Jhoira's Toolbox, Memory Jar,
## Quicksilver Amulet, Scrapheap, Thran Lens and Wheel of Torture. Memory
## Jar's interactions with older cards are pinned in
## test_pack_10_B8_interactions.gd.

## Answers yes/no with [member yes] (-1 = the hint), cards by [member pick]
## ("" = the first offered, "-" = decline).
class Seat extends DecisionAgent:
	var yes := -1
	var pick := ""
	func answer_yes_no(_g: MtgGame, _pid: int, _prompt: String, hint: bool) -> bool:
		return hint if yes < 0 else yes == 1
	func answer_card(_g: MtgGame, _pid: int, candidates: Array[CardInstance], _prompt: String) -> CardInstance:
		if pick == "-": return null
		for c in candidates:
			if c.data.card_name == pick: return c
		return null if candidates.is_empty() else candidates[0]

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

func _names(cards: Array) -> Array:
	var out: Array = []
	for c in cards: out.append(c.data.card_name)
	out.sort()
	return out


# ------------------------------------------------------------ Angel's Trumpet --

func test_angels_trumpet_gives_vigilance_and_taxes_creatures_that_stayed_home() -> void:
	put_battlefield(0, "Angel's Trumpet")
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var elves := put_battlefield(0, "Llanowar Elves")
	var theirs := put_battlefield(1, "Grizzly Bears")
	assert_true(theirs.has_keyword(Mtg.Keyword.VIGILANCE), "all creatures")
	g.tap_permanent(elves)   # already tapped: not counted
	run_combat([bears.id])
	assert_false(bears.tapped, "vigilance")
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_true(giant.tapped, "it didn't attack")
	assert_false(bears.tapped, "it attacked")
	assert_false(theirs.tapped, "only that player's creatures")
	assert_eq(g.players[0].life, 19, "one creature tapped this way")
	assert_eq(g.players[1].life, 18)


# ------------------------------------------------------------ Beast of Burden --

func test_beast_of_burden_counts_every_creature_itself_included() -> void:
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Llanowar Elves")
	var in_hand := give_hand(0, "Beast of Burden")
	g.recalculate()
	assert_eq([in_hand.cur_power, in_hand.cur_toughness], [2, 2], "in hand: the battlefield's creatures")
	var beast := put_battlefield(0, "Beast of Burden")
	assert_eq([beast.cur_power, beast.cur_toughness], [3, 3], "on the battlefield it counts itself")
	put_battlefield(1, "Hill Giant")
	assert_eq(beast.cur_power, 4)


# ---------------------------------------------------------------- Crawlspace --

func test_crawlspace_lets_no_more_than_two_creatures_attack_you() -> void:
	put_battlefield(0, "Crawlspace")
	advance_to_next_turn()
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	var c := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(1, [a.id, b.id, c.id]))
	assert_ok(g.declare_attackers(1, [a.id, b.id]))

func test_crawlspace_does_not_limit_its_controllers_attack() -> void:
	put_battlefield(0, "Crawlspace")
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(0, "Grizzly Bears")
	var c := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [a.id, b.id, c.id]))


# --------------------------------------------------------------- Defense Grid --

func test_defense_grid_taxes_spells_cast_outside_their_controllers_turn() -> void:
	put_battlefield(0, "Defense Grid")
	assert_ok(g.pass_priority(0))
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	add_mana(1, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].life, 17)

func test_defense_grid_does_not_tax_a_spell_in_its_controllers_own_turn() -> void:
	put_battlefield(1, "Defense Grid")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 17, "every caster, both Grids' controllers alike")

func test_a_tapped_defense_grid_stops_under_the_1997_rule() -> void:
	g.rules.tapped_artifacts_stop = true
	var grid := put_battlefield(0, "Defense Grid")
	g.tap_permanent(grid)
	g.recalculate()
	assert_ok(g.pass_priority(0))
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))


# ------------------------------------------------ Iron Maiden / Wheel of Torture --

func test_iron_maiden_punishes_a_hand_of_more_than_four() -> void:
	put_battlefield(0, "Iron Maiden")
	for _n in 6: give_hand(1, "Forest")
	advance_to_next_turn()
	assert_eq(g.players[1].life, 18, "6 - 4")
	assert_eq(g.players[0].life, 20)

func test_iron_maiden_ignores_four_cards_and_its_controller() -> void:
	put_battlefield(0, "Iron Maiden")
	for _n in 4: give_hand(1, "Forest")
	for _n in 7: give_hand(0, "Forest")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(g.players[1].life, 20)
	assert_eq(g.players[0].life, 20, "only each opponent's upkeep")

func test_wheel_of_torture_punishes_a_hand_of_fewer_than_three() -> void:
	put_battlefield(0, "Wheel of Torture")
	give_hand(1, "Forest")
	advance_to_next_turn()
	assert_eq(g.players[1].life, 18, "3 - 1")

func test_wheel_of_torture_ignores_three_cards() -> void:
	put_battlefield(0, "Wheel of Torture")
	for _n in 3: give_hand(1, "Forest")
	advance_to_next_turn()
	assert_eq(g.players[1].life, 20)


# ------------------------------------------------------------ Jhoira's Toolbox --

func test_jhoiras_toolbox_regenerates_an_artifact_creature_only() -> void:
	var box := put_battlefield(0, "Jhoira's Toolbox")
	var jugg := put_battlefield(0, "Juggernaut")
	var bears := put_battlefield(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_refused(g.activate_ability(0, box, 0, [TargetRef.card(bears)]))
	assert_ok(g.activate_ability(0, box, 0, [TargetRef.card(jugg)]))
	resolve_stack()
	g.destroy(jugg)
	assert_eq(jugg.zone, Mtg.Zone.BATTLEFIELD, "regenerated")
	assert_true(jugg.tapped)


# ----------------------------------------------------------------- Memory Jar --

func test_memory_jar_swaps_every_hand_for_seven_until_the_end_step() -> void:
	var jar := put_battlefield(0, "Memory Jar")
	var bolt := give_hand(0, "Lightning Bolt")
	var growth := give_hand(0, "Giant Growth")
	var counter := give_hand(1, "Counterspell")
	var giant := give_hand(1, "Hill Giant")
	assert_ok(g.activate_ability(0, jar, 0))
	assert_eq(jar.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	for card in [bolt, growth, counter, giant]:
		assert_eq(card.zone, Mtg.Zone.EXILE)
		assert_true(card.face_down, "face down")
		assert_eq(card.exile_visible_to, -1, "nobody may look (CR 406.3)")
	assert_eq(g.players[0].hand.size(), 7)
	assert_eq(g.players[1].hand.size(), 7)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(_names(g.players[0].hand), ["Giant Growth", "Lightning Bolt"])
	assert_eq(_names(g.players[1].hand), ["Counterspell", "Hill Giant"])
	assert_eq(g.players[0].graveyard.size(), 8, "seven discarded, and the Jar")
	assert_eq(g.players[1].graveyard.size(), 7)
	for card in [bolt, growth, counter, giant]:
		assert_false(card.face_down)

## The exiled hands are hidden information: no reveal reaches either seat,
## and the log never names them (CONTRIBUTING.md rule 8).
func test_memory_jar_never_names_the_exiled_cards() -> void:
	var jar := put_battlefield(0, "Memory Jar")
	give_hand(1, "Counterspell")
	var reveals: Array = []
	g.information_revealed.connect(func(_viewer: int, title: String, names: Array) -> void:
		reveals.append([title, names.duplicate()]))
	var before := g.log_lines.size()
	assert_ok(g.activate_ability(0, jar, 0))
	resolve_stack()
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(reveals, [])
	for n in range(before, g.log_lines.size()):
		assert_false(String(g.log_lines[n]).contains("Counterspell"), String(g.log_lines[n]))

func test_memory_jar_activated_in_an_end_step_waits_for_the_next_one() -> void:
	var jar := put_battlefield(0, "Memory Jar")
	var bolt := give_hand(0, "Lightning Bolt")
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_ok(g.activate_ability(0, jar, 0))
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.EXILE)
	advance_to_next_turn()
	assert_eq(bolt.zone, Mtg.Zone.EXILE, "this end step had already begun")
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.HAND, "the next end step is the opponent's")

func test_memory_jar_returns_only_cards_still_exiled_this_way() -> void:
	var jar := put_battlefield(0, "Memory Jar")
	var bolt := give_hand(0, "Lightning Bolt")
	assert_ok(g.activate_ability(0, jar, 0))
	resolve_stack()
	g.return_from_exile_to_hand(bolt, false)
	g.exile_from_hand(bolt, true, -1)   # a new exile visit (CR 400.7)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.EXILE)


# --------------------------------------------------------- Quicksilver Amulet --

func test_quicksilver_amulet_puts_a_creature_from_hand_onto_the_battlefield() -> void:
	var amulet := put_battlefield(0, "Quicksilver Amulet")
	var dragon := give_hand(0, "Shivan Dragon")
	give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, amulet, 0))
	resolve_stack()
	assert_eq(dragon.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(dragon.summoning_sick)
	assert_true(amulet.tapped)
	assert_eq(g.players[0].hand.size(), 1)

func test_quicksilver_amulet_may_put_nothing() -> void:
	var amulet := put_battlefield(0, "Quicksilver Amulet")
	var dragon := give_hand(0, "Shivan Dragon")
	_seat(0).pick = "-"
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, amulet, 0))
	resolve_stack()
	assert_eq(dragon.zone, Mtg.Zone.HAND)


# ------------------------------------------------------------------ Scrapheap --

func test_scrapheap_gains_life_for_your_artifacts_and_enchantments_dying() -> void:
	var heap := put_battlefield(0, "Scrapheap")
	var ring := put_battlefield(0, "Sol Ring")
	var crusade := put_battlefield(0, "Crusade")
	var theirs := put_battlefield(1, "Sol Ring")
	var exiled := put_battlefield(0, "Sol Ring")
	g.destroy(ring)
	resolve_stack()
	assert_eq(g.players[0].life, 21)
	g.destroy(crusade)
	resolve_stack()
	assert_eq(g.players[0].life, 22)
	g.destroy(theirs)
	resolve_stack()
	assert_eq(g.players[0].life, 22, "their graveyard, not yours")
	g.exile_permanent(exiled)
	resolve_stack()
	assert_eq(g.players[0].life, 22, "exiled, not put into a graveyard")
	g.destroy(heap)
	resolve_stack()
	assert_eq(g.players[0].life, 23, "the Scrapheap sees its own trip (CR 603.10a)")


# ----------------------------------------------------------------- Thran Lens --

func test_thran_lens_makes_every_permanent_colorless() -> void:
	var lens := put_battlefield(0, "Thran Lens")
	var knight := put_battlefield(1, "Black Knight")
	var bolt := give_hand(0, "Lightning Bolt")
	assert_eq(knight.cur_colors, 0)
	assert_eq(bolt.cur_colors, Mtg.ManaColor.R, "cards in other zones keep their colours")
	var terror := give_hand(0, "Terror")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, terror, [TargetRef.card(knight)]))   # a colorless creature is nonblack
	resolve_stack()
	assert_eq(knight.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(lens.cur_colors, 0)

func test_terror_cannot_target_a_black_creature_without_the_lens() -> void:
	var knight := put_battlefield(1, "Black Knight")
	var terror := give_hand(0, "Terror")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.cast_spell(0, terror, [TargetRef.card(knight)]))

func test_a_tapped_thran_lens_stops_under_the_1997_rule() -> void:
	g.rules.tapped_artifacts_stop = true
	var lens := put_battlefield(0, "Thran Lens")
	var knight := put_battlefield(1, "Black Knight")
	assert_eq(knight.cur_colors, 0)
	g.tap_permanent(lens)
	g.recalculate()
	assert_eq(knight.cur_colors, Mtg.ManaColor.B)
