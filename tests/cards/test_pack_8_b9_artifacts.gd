extends GameTest
## Pack 8 (the Mirage block), batch B9: the Weatherlight artifacts in
## cards/sets/wth/_artifacts.gd — Bubble Matrix, Chimeric Sphere, Dingus
## Staff, Mana Web, Phyrexian Furnace, Thran Forge, Thran Tome, Touchstone,
## Well of Knowledge and Xanthic Statue.

const CLAIMED := ["Bubble Matrix", "Chimeric Sphere", "Dingus Staff", "Mana Web",
	"Phyrexian Furnace", "Thran Forge", "Thran Tome", "Touchstone",
	"Well of Knowledge", "Xanthic Statue", "Bösium Strip", "Jabari's Banner", "Null Rod"]

## Picks the candidate with the given name and remembers who was asked.
class PickNamed extends DecisionAgent:
	var wanted: String
	var asked: Array[int] = []
	var offered: Array[String] = []
	func _init(card_name: String) -> void:
		wanted = card_name
	func answer_card(_g: MtgGame, pid: int, candidates: Array[CardInstance], _prompt: String) -> CardInstance:
		asked.append(pid)
		for c in candidates:
			offered.append(c.data.card_name)
		for c in candidates:
			if c.data.card_name == wanted: return c
		return null if candidates.is_empty() else candidates[0]

func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)

func _on_library_top(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.LIBRARY
	g.players[pid].library.append(inst)
	return inst

func _to_graveyard(pid: int, card_name: String) -> CardInstance:
	var inst := give_hand(pid, card_name)
	g.card_to_graveyard_from_anywhere(inst)
	return inst

func _bolt(pid: int, target: TargetRef) -> void:
	var bolt := give_hand(pid, "Lightning Bolt")
	add_mana(pid, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(pid, bolt, [target]))
	resolve_stack()


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


# ------------------------------------------------------------ Bubble Matrix --

func test_bubble_matrix_prevents_damage_to_every_creature_but_not_to_players() -> void:
	put_battlefield(1, "Bubble Matrix")
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Grizzly Bears")
	_bolt(0, TargetRef.card(theirs))
	_bolt(0, TargetRef.card(mine))
	assert_eq(theirs.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(theirs.damage, 0)
	assert_eq(mine.damage, 0)
	_bolt(0, TargetRef.player(1))
	assert_eq(g.players[1].life, 17, "damage to a player is not prevented")

func test_bubble_matrix_covers_combat_and_stops_when_it_leaves() -> void:
	var matrix := put_battlefield(0, "Bubble Matrix")
	var attacker := put_battlefield(0, "Hill Giant")
	var blocker := put_battlefield(1, "Grizzly Bears")
	run_combat([attacker.id], {blocker.id: attacker.id})
	assert_eq(blocker.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(attacker.damage, 0)
	g.destroy(matrix)
	_bolt(0, TargetRef.card(blocker))
	assert_eq(blocker.zone, Mtg.Zone.GRAVEYARD)

func test_bubble_matrix_shields_an_animated_artifact() -> void:
	put_battlefield(1, "Bubble Matrix")
	var sphere := put_battlefield(0, "Chimeric Sphere")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, sphere, 0))
	resolve_stack()
	_bolt(0, TargetRef.card(sphere))
	assert_eq(sphere.zone, Mtg.Zone.BATTLEFIELD)


# ---------------------------------------------------------- Chimeric Sphere --

func test_chimeric_sphere_first_form_is_a_2_1_flying_construct() -> void:
	var sphere := put_battlefield(0, "Chimeric Sphere")
	assert_false(sphere.is_creature())
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, sphere, 0))
	resolve_stack()
	assert_true(sphere.is_creature())
	assert_true(sphere.is_type(Mtg.CardType.ARTIFACT))
	assert_true(sphere.has_subtype("construct"))
	assert_eq([sphere.cur_power, sphere.cur_toughness], [2, 1])
	assert_true(sphere.has_keyword(Mtg.Keyword.FLYING))
	advance_to_next_turn()
	assert_false(sphere.is_creature(), "the animation ends at cleanup")
	assert_false(sphere.has_keyword(Mtg.Keyword.FLYING))

func test_chimeric_sphere_second_form_loses_flying_and_the_later_form_wins() -> void:
	var sphere := put_battlefield(0, "Chimeric Sphere")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, sphere, 0))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, sphere, 1))
	resolve_stack()
	assert_eq([sphere.cur_power, sphere.cur_toughness], [3, 2])
	assert_false(sphere.has_keyword(Mtg.Keyword.FLYING), "the 3/2 form loses flying")
	assert_true(sphere.has_subtype("construct"))
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, sphere, 0))
	resolve_stack()
	assert_eq([sphere.cur_power, sphere.cur_toughness], [2, 1])
	assert_true(sphere.has_keyword(Mtg.Keyword.FLYING), "a later flying form flies again (CR 613.7)")

func test_chimeric_sphere_does_nothing_if_it_left_before_resolution() -> void:
	var sphere := put_battlefield(0, "Chimeric Sphere")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, sphere, 1))
	g.return_to_hand(sphere)
	g.put_from_hand_into_play(sphere, 0)
	resolve_stack()
	assert_false(sphere.is_creature(), "a new object is not animated (CR 400.7)")


# ----------------------------------------------------------- Xanthic Statue --

func test_xanthic_statue_becomes_an_8_8_trampling_golem_until_end_of_turn() -> void:
	var statue := put_battlefield(0, "Xanthic Statue")
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_refused(g.activate_ability(0, statue, 0))
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_ok(g.activate_ability(0, statue, 0))
	resolve_stack()
	assert_true(statue.is_creature())
	assert_true(statue.is_type(Mtg.CardType.ARTIFACT))
	assert_true(statue.has_subtype("golem"))
	assert_eq([statue.cur_power, statue.cur_toughness], [8, 8])
	assert_true(statue.has_keyword(Mtg.Keyword.TRAMPLE))
	advance_to_next_turn()
	assert_false(statue.is_creature())
	assert_false(statue.has_keyword(Mtg.Keyword.TRAMPLE))


# ------------------------------------------------------------- Dingus Staff --

func test_dingus_staff_hits_the_dead_creatures_controller_either_side() -> void:
	put_battlefield(0, "Dingus Staff")
	var theirs := put_battlefield(1, "Grizzly Bears")
	_bolt(0, TargetRef.card(theirs))
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 18)
	assert_eq(g.players[0].life, 20)
	var mine := put_battlefield(0, "Grizzly Bears")
	_bolt(0, TargetRef.card(mine))
	assert_eq(g.players[0].life, 18, "the Staff punishes its own controller too")

func test_dingus_staff_ignores_noncreature_deaths() -> void:
	put_battlefield(0, "Dingus Staff")
	var rock := put_battlefield(1, "Sol Ring")
	g.destroy(rock)
	resolve_stack()
	assert_eq(g.players[1].life, 20)

func test_dingus_staff_trigger_resolves_after_the_staff_is_gone() -> void:
	var staff := put_battlefield(0, "Dingus Staff")
	var bear := put_battlefield(1, "Grizzly Bears")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.stack.size(), 1, "the Staff's trigger waits on the stack")
	var shatter := give_hand(0, "Shatter")
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, shatter, [TargetRef.card(staff)]))
	resolve_stack()
	assert_eq(staff.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 18, "CR 608.2h: the trigger still deals its damage")


# ----------------------------------------------------------------- Mana Web --

func test_mana_web_taps_every_land_sharing_a_mana_type_with_the_tapped_land() -> void:
	put_battlefield(0, "Mana Web")
	var forest := put_battlefield(1, "Forest")
	var other_forest := put_battlefield(1, "Forest")
	var taiga := put_battlefield(1, "Taiga")
	var island := put_battlefield(1, "Island")
	var mountain := put_battlefield(1, "Mountain")
	assert_ok(g.tap_for_mana(1, forest))
	resolve_stack()
	assert_true(other_forest.tapped)
	assert_true(taiga.tapped, "Taiga could produce {G}")
	assert_false(island.tapped)
	assert_false(mountain.tapped)

func test_mana_web_reads_what_the_land_could_produce_not_what_it_made() -> void:
	put_battlefield(0, "Mana Web")
	var forest := put_battlefield(1, "Forest")
	var taiga := put_battlefield(1, "Taiga")
	var island := put_battlefield(1, "Island")
	var mountain := put_battlefield(1, "Mountain")
	assert_ok(g.tap_for_mana(1, taiga, 0))
	resolve_stack()
	assert_true(forest.tapped, "Taiga could also make {G}")
	assert_true(mountain.tapped)
	assert_false(island.tapped)

func test_mana_web_ignores_its_controllers_own_lands() -> void:
	put_battlefield(0, "Mana Web")
	var forest := put_battlefield(0, "Forest")
	var other := put_battlefield(0, "Forest")
	var size := g.stack.size()
	assert_ok(g.tap_for_mana(0, forest))
	resolve_stack()
	assert_eq(g.stack.size(), size)
	assert_false(other.tapped)

func test_mana_web_uses_the_stack_so_the_opponent_may_tap_in_response() -> void:
	put_battlefield(0, "Mana Web")
	var forest := put_battlefield(1, "Forest")
	var other := put_battlefield(1, "Forest")
	assert_ok(g.tap_for_mana(1, forest))
	assert_eq(g.stack.size(), 1, "Mana Web's trigger is not a mana ability")
	assert_ok(g.tap_for_mana(1, other))
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.G), 2)
	resolve_stack()
	assert_true(other.tapped)


# -------------------------------------------------------- Phyrexian Furnace --

func test_furnace_tap_exiles_the_bottom_card_of_target_players_graveyard() -> void:
	var furnace := put_battlefield(0, "Phyrexian Furnace")
	var bottom := _to_graveyard(1, "Grizzly Bears")
	var top := _to_graveyard(1, "Lightning Bolt")
	assert_ok(g.activate_ability(0, furnace, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(bottom.zone, Mtg.Zone.EXILE)
	assert_eq(top.zone, Mtg.Zone.GRAVEYARD)
	assert_true(furnace.tapped)

func test_furnace_tap_on_an_empty_graveyard_does_nothing() -> void:
	var furnace := put_battlefield(0, "Phyrexian Furnace")
	var mine := _to_graveyard(0, "Grizzly Bears")
	assert_ok(g.activate_ability(0, furnace, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD)

func test_furnace_sacrifice_exiles_any_graveyard_card_and_draws() -> void:
	var furnace := put_battlefield(0, "Phyrexian Furnace")
	_to_graveyard(1, "Grizzly Bears")
	var middle := _to_graveyard(1, "Lightning Bolt")
	_to_graveyard(1, "Forest")
	var hand := g.players[0].hand.size()
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, furnace, 1, [TargetRef.card(middle)]))
	assert_eq(furnace.zone, Mtg.Zone.GRAVEYARD, "sacrificed as a cost")
	resolve_stack()
	assert_eq(middle.zone, Mtg.Zone.EXILE)
	assert_eq(g.players[0].hand.size(), hand + 1)

func test_furnace_sacrifice_fizzles_when_its_target_leaves_the_graveyard() -> void:
	var furnace := put_battlefield(0, "Phyrexian Furnace")
	var card := _to_graveyard(1, "Grizzly Bears")
	var hand := g.players[0].hand.size()
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, furnace, 1, [TargetRef.card(card)]))
	g.exile_from_graveyard(card)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand, "no draw — the ability was countered (CR 608.2b)")


# -------------------------------------------------------------- Thran Forge --

func test_thran_forge_pumps_and_makes_a_nonartifact_creature_an_artifact() -> void:
	var forge := put_battlefield(0, "Thran Forge")
	var bear := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, forge, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq([bear.cur_power, bear.cur_toughness], [3, 2])
	assert_true(bear.is_type(Mtg.CardType.ARTIFACT))
	assert_true(bear.is_creature())
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, forge, 0, [TargetRef.card(bear)]), "")
	var shatter := give_hand(0, "Shatter")
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, shatter, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "an artifact now, so Shatter kills it")

func test_thran_forge_refuses_artifact_creatures_and_wears_off() -> void:
	var forge := put_battlefield(0, "Thran Forge")
	var juggernaut := put_battlefield(0, "Obsianus Golem")
	var bear := put_battlefield(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, forge, 0, [TargetRef.card(juggernaut)]))
	assert_ok(g.activate_ability(0, forge, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.is_type(Mtg.CardType.ARTIFACT))
	advance_to_next_turn()
	assert_false(bear.is_type(Mtg.CardType.ARTIFACT))
	assert_eq(bear.cur_power, 2)

func test_thran_forge_type_grant_does_not_follow_a_new_object() -> void:
	var forge := put_battlefield(0, "Thran Forge")
	var bear := put_battlefield(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, forge, 0, [TargetRef.card(bear)]))
	resolve_stack()
	g.return_to_hand(bear)
	g.put_from_hand_into_play(bear, 0)
	assert_false(bear.is_type(Mtg.CardType.ARTIFACT), "CR 400.7")


# --------------------------------------------------------------- Thran Tome --

func test_thran_tome_opponent_chooses_the_card_that_is_buried_then_you_draw_two() -> void:
	var tome := put_battlefield(0, "Thran Tome")
	var c := _on_library_top(0, "Grizzly Bears")
	var b := _on_library_top(0, "Shatter")
	var a := _on_library_top(0, "Lightning Bolt")
	var picker := PickNamed.new("Shatter")
	g.agents[1] = picker
	var hand := g.players[0].hand.size()
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.activate_ability(0, tome, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(picker.asked, [1], "the targeted opponent makes the choice")
	assert_eq(picker.offered.size(), 3)
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(a.zone, Mtg.Zone.HAND)
	assert_eq(c.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].hand.size(), hand + 2)
	assert_true(tome.tapped)

func test_thran_tome_must_target_an_opponent_and_costs_five() -> void:
	var tome := put_battlefield(0, "Thran Tome")
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_refused(g.activate_ability(0, tome, 0, [TargetRef.player(1)]))
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_refused(g.activate_ability(0, tome, 0, [TargetRef.player(0)]))

func test_thran_tome_with_exactly_three_cards_left() -> void:
	var tome := put_battlefield(0, "Thran Tome")
	g.players[0].library.clear()
	var c := _on_library_top(0, "Grizzly Bears")
	var b := _on_library_top(0, "Shatter")
	var a := _on_library_top(0, "Lightning Bolt")
	g.agents[1] = PickNamed.new("Lightning Bolt")
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.activate_ability(0, tome, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(b.zone, Mtg.Zone.HAND)
	assert_eq(c.zone, Mtg.Zone.HAND)
	assert_true(g.players[0].library.is_empty())
	assert_false(g.game_over)


# --------------------------------------------------------------- Touchstone --

func test_touchstone_taps_only_an_artifact_you_dont_control() -> void:
	var stone := put_battlefield(0, "Touchstone")
	var own := put_battlefield(0, "Sol Ring")
	var bear := put_battlefield(1, "Grizzly Bears")
	var ring := put_battlefield(1, "Sol Ring")
	assert_refused(g.activate_ability(0, stone, 0, [TargetRef.card(own)]))
	assert_refused(g.activate_ability(0, stone, 0, [TargetRef.card(bear)]))
	assert_ok(g.activate_ability(0, stone, 0, [TargetRef.card(ring)]))
	resolve_stack()
	assert_true(ring.tapped)
	assert_true(stone.tapped)
	assert_false(own.tapped)


# -------------------------------------------------------- Well of Knowledge --

func test_well_of_knowledge_only_in_the_activators_own_draw_step() -> void:
	var well := put_battlefield(0, "Well of Knowledge")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, well, 0), "draw")
	# On to the opponent's draw step: they may use the Well they don't control.
	advance_to_step(Mtg.Step.DRAW)
	assert_eq(g.active_player, 1)
	var theirs := g.players[1].hand.size()
	var mine := g.players[0].hand.size()
	add_mana(1, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(1, well, 0))
	resolve_stack()
	assert_eq(g.players[1].hand.size(), theirs + 1, "the activator draws")
	assert_eq(g.players[0].hand.size(), mine)
	# Its controller may not use it in the opponent's draw step.
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, well, 0), "your turn")

func test_well_of_knowledge_works_for_its_controller_in_their_draw_step() -> void:
	var well := put_battlefield(0, "Well of Knowledge")
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DRAW)
	assert_eq(g.active_player, 0)
	var hand := g.players[0].hand.size()
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, well, 0))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, well, 0))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 2, "no per-turn limit")

func test_touchstone_tapped_bubble_matrix_stops_only_under_the_1997_rule() -> void:
	for old_rule in [false, true]:
		if old_rule: before_each()   # a fresh duel for the second profile
		g.rules.tapped_artifacts_stop = old_rule
		var matrix := put_battlefield(1, "Bubble Matrix")
		var stone := put_battlefield(0, "Touchstone")
		var bear := put_battlefield(1, "Grizzly Bears")
		assert_ok(g.activate_ability(0, stone, 0, [TargetRef.card(matrix)]))
		resolve_stack()
		assert_true(matrix.tapped)
		_bolt(0, TargetRef.card(bear))
		if old_rule:
			assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "1997: a tapped artifact's effects cease")
		else:
			assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "modern: tapping changes nothing")


# ------------------------------------------------------------- Bösium Strip --

func test_bosium_strip_casts_the_top_instant_of_your_graveyard_then_exiles_it() -> void:
	var strip := put_battlefield(0, "Bösium Strip")
	var low := _to_graveyard(0, "Lightning Bolt")
	var bear := _to_graveyard(0, "Grizzly Bears")
	assert_false(g.can_cast_from_graveyard(0, low))
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, strip, 0))
	resolve_stack()
	assert_false(g.can_cast_from_graveyard(0, low), "only the TOP card")
	assert_false(g.can_cast_from_graveyard(0, bear), "instants and sorceries only")
	var top := _to_graveyard(0, "Lightning Bolt")
	assert_true(g.can_cast_from_graveyard(0, top))
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, top, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 17)
	assert_eq(top.zone, Mtg.Zone.EXILE, "a spell cast this way is exiled instead")
	assert_false(g.can_cast_from_graveyard(0, bear))


func test_bosium_strip_a_countered_spell_is_exiled_too() -> void:
	var strip := put_battlefield(0, "Bösium Strip")
	var top := _to_graveyard(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, strip, 0))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, top, [TargetRef.player(1)]))
	var counter := give_hand(1, "Counterspell")
	add_mana(1, Mtg.ManaColor.U, 2)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, counter, [TargetRef.card(top)]))
	resolve_stack()
	assert_eq(g.players[1].life, 20)
	assert_eq(top.zone, Mtg.Zone.EXILE)
	assert_eq(counter.zone, Mtg.Zone.GRAVEYARD)


func test_bosium_strip_permission_ends_with_the_turn_and_is_the_activators() -> void:
	var strip := put_battlefield(0, "Bösium Strip")
	var top := _to_graveyard(0, "Lightning Bolt")
	var theirs := _to_graveyard(1, "Lightning Bolt")
	assert_false(g.can_cast_from_graveyard(0, top))
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(0, top, [TargetRef.player(1)]))
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, strip, 0))
	resolve_stack()
	assert_true(g.can_cast_from_graveyard(0, top))
	assert_false(g.can_cast_from_graveyard(1, theirs), "the opponent gained nothing")
	assert_false(g.can_cast_from_graveyard(0, theirs), "your own graveyard only")
	advance_to_next_turn()
	assert_false(g.can_cast_from_graveyard(0, top))


# ---------------------------------------------------------- Jabari's Banner --

func _block_with(attacker: CardInstance, blocker: CardInstance) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {blocker.id: attacker.id}))
	resolve_stack()


func test_jabaris_banner_grants_flanking_until_end_of_turn() -> void:
	var banner := put_battlefield(0, "Jabari's Banner")
	var bear := put_battlefield(0, "Grizzly Bears")
	var blocker := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, banner, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(banner.tapped)
	assert_eq(Flanking.instances(bear), 1)
	_block_with(bear, blocker)
	assert_eq(blocker.cur_power, 1)
	assert_eq(blocker.cur_toughness, 1, "the flanking trigger shrank the blocker")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(blocker.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "a 1/1 blocker dealt 1")
	advance_to_next_turn()
	assert_eq(Flanking.instances(bear), 0, "until end of turn")


func test_two_banner_grants_are_two_instances_of_flanking() -> void:
	var first := put_battlefield(0, "Jabari's Banner")
	var second := put_battlefield(0, "Jabari's Banner")
	var bear := put_battlefield(0, "Grizzly Bears")
	var blocker := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, first, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_ok(g.activate_ability(0, second, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(Flanking.instances(bear), 2, "CR 702.25b: never deduplicated")
	_block_with(bear, blocker)
	assert_eq(blocker.zone, Mtg.Zone.GRAVEYARD, "-2/-2 before damage")


func test_jabaris_banner_needs_a_creature_target() -> void:
	var banner := put_battlefield(0, "Jabari's Banner")
	var forest := put_battlefield(0, "Forest")
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.activate_ability(0, banner, 0, [TargetRef.card(forest)]))
	assert_false(banner.tapped)


# ----------------------------------------------------------------- Null Rod --

func _ai_plan(text: String) -> Array:
	return ManaPlanner.plan(g, 0, ManaCost.parse(text), 0)

func _human_plan(text: String) -> Array:
	return ManaPlanner.plan_from(ManaPlanner.auto_tap_sources(g, 0), ManaCost.parse(text), 0)


func test_null_rod_stops_artifact_mana_and_the_planner_leaves_it_out() -> void:
	var mox := put_battlefield(0, "Mox Pearl")
	var vault := put_battlefield(0, "Mana Vault")
	assert_false(_ai_plan("{W}").is_empty())
	assert_false(_ai_plan("{3}").is_empty())
	var rod := put_battlefield(1, "Null Rod")   # an opponent's Rod stops yours too
	assert_refused(g.tap_for_mana(0, mox, 0))
	assert_refused(g.tap_for_mana(0, vault, 0))
	assert_false(mox.tapped)
	assert_false(vault.tapped)
	for text in ["{W}", "{1}", "{3}"]:
		assert_true(_ai_plan(text).is_empty(), text)
		assert_true(_human_plan(text).is_empty(), text)
	assert_false(g.can_afford_cost(0, ManaCost.parse("{1}")))
	assert_false(ManaPlanner.plan_and_pay(g, 0, ManaCost.parse("{1}")))
	assert_false(mox.tapped)
	var forest := put_battlefield(0, "Forest")
	assert_false(_ai_plan("{G}").is_empty(), "lands are not artifacts")
	assert_true(_ai_plan("{1}{W}").is_empty())
	g.return_to_hand(rod)
	assert_false(_ai_plan("{1}{W}").is_empty(), "the ban leaves with the Rod")
	assert_ok(g.tap_for_mana(0, mox, 0))
	assert_true(forest.zone == Mtg.Zone.BATTLEFIELD)


func test_null_rod_stops_other_artifact_abilities_but_not_creatures_or_the_stack() -> void:
	var icy := put_battlefield(0, "Icy Manipulator")
	var victim := put_battlefield(1, "Grizzly Bears")
	var other := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, icy, 0, [TargetRef.card(victim)]))
	put_battlefield(0, "Null Rod")
	resolve_stack()
	assert_true(victim.tapped, "an ability already on the stack still resolves")
	g.untap_permanent(icy)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.activate_ability(0, icy, 0, [TargetRef.card(other)]))
	assert_false(icy.tapped)
	var behemoth := put_battlefield(0, "Llanowar Behemoth")
	assert_ok(g.activate_ability(0, behemoth, 0))
	resolve_stack()
	assert_eq(behemoth.cur_power, 5, "a nonartifact creature's ability is untouched")
