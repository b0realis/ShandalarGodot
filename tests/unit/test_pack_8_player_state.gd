extends GameTest
## PACK 8, E10 — PLAYER STATE & COLOUR / MANA RULES.
##
## - N_trackers — per-turn facts the Mirage block asks about: creatures put
##   into YOUR graveyard from the battlefield this turn (OWNER-keyed: Asmira,
##   Urborg Justice), whether a player tapped a land for mana this turn
##   (Desolation), and the creature YOU CAST this turn as an OBJECT (Cycle of
##   Life, CR 400.7).
## - N_pending_ransom — "... at the beginning of their next upkeep unless
##   they pay {2} before that step" (Sabertooth Cobra): the engine's delayed
##   trigger with a settlement (MtgGame.settle_delayed_trigger), pinned here
##   in the upkeep shape.
## - N_cant_gain_life — "Players can't gain life" (Forsaken Wastes, CR 119.7).
## - N_additive_land_type — "Each land is a Swamp in addition to its other
##   land types" (Blanket of Night, the CR 305.7 exception).
## - N_offzone_color — Celestial Dawn's colour outside the battlefield, plus
##   the layer-5 static tag (`StaticAbility.changing_colors`) its "nonland
##   permanents you control are white" needs.
## - N_mana_colorless_only — Celestial Dawn's spending rule, in the pool and
##   in the planner.


# ------------------------------------------------- synthetic cards --

func _wastes_static(game: MtgGame, _source: CardInstance) -> void:
	for p in game.players:
		p.cant_gain_life = true


## "Players can't gain life."
func _wastes() -> CardData:
	return CardData.new("Test Wastes", "{2}{B}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_wastes_static, "Players can't gain life."))


func _blanket_static(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_land():
			inst.add_basic_land_type("swamp")


## "Each land is a Swamp in addition to its other land types."
func _blanket() -> CardData:
	return CardData.new("Test Blanket", "{1}{B}{B}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_blanket_static,
			"Each land is a Swamp in addition to its other land types.").changing_land_types())


func _dawn_colors(game: MtgGame, source: CardInstance) -> void:
	for inst in game.players[source.controller_id].battlefield:
		if not inst.is_land():
			inst.cur_colors = Mtg.ManaColor.W
	game.set_offzone_color(source.controller_id, Mtg.ManaColor.W)


func _dawn_mana(game: MtgGame, source: CardInstance) -> void:
	game.set_mana_spending_rule(source.controller_id, Mtg.ManaColor.W,
		Mtg.ManaColor.U | Mtg.ManaColor.B | Mtg.ManaColor.R | Mtg.ManaColor.G)


## Celestial Dawn's colour and mana halves (its land half is Blood Moon's
## shape and needs nothing new).
func _dawn() -> CardData:
	return CardData.new("Test Dawn", "{1}{W}{W}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_dawn_colors,
			"Nonland permanents you control are white. The same is true for spells you control and nonland cards you own that aren't on the battlefield.").changing_colors()) \
		.static_ability(StaticAbility.new(_dawn_mana,
			"You may spend white mana as though it were mana of any color. You may spend other mana only as though it were colorless mana."))


func _paint_creatures_white(game: MtgGame, source: CardInstance) -> void:
	for inst in game.players[source.controller_id].battlefield:
		if inst.is_creature():
			inst.cur_colors = Mtg.ManaColor.W


func _whitewash() -> CardData:
	return CardData.new("Test Whitewash", "{W}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_paint_creatures_white,
			"Creatures you control are white.").changing_colors())


# ================================================ N_trackers ==

## OWNER-keyed: your creature dies under the opponent's control and it is
## still YOUR graveyard it went to. A token counts; a creature exiled
## instead does not; a noncreature does not.
func test_creatures_put_into_your_graveyard_are_counted_by_owner() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var stolen := put_battlefield(0, "Hill Giant")
	g.change_control(stolen, 1)
	g.destroy(bear)
	g.destroy(stolen)
	assert_eq(g.players[0].creatures_to_graveyard_this_turn, 2, "both were mine")
	assert_eq(g.players[1].creatures_to_graveyard_this_turn, 0)
	var token: CardInstance = g.create_token(1, CardRegistry.get_card("Grizzly Bears"))[0]
	g.destroy(token)
	assert_eq(g.players[1].creatures_to_graveyard_this_turn, 1, "a token reaches its graveyard")
	var exiled := put_battlefield(1, "Grizzly Bears")
	exiled.exile_instead_of_dying = true
	g.destroy(exiled)
	assert_eq(g.players[1].creatures_to_graveyard_this_turn, 1, "exiled instead: not counted")
	g.destroy(put_battlefield(0, "Sol Ring"))
	assert_eq(g.players[0].creatures_to_graveyard_this_turn, 2, "an artifact is not a creature")
	advance_to_next_turn()
	assert_eq(g.players[0].creatures_to_graveyard_this_turn, 0, "this turn only")


## "Each player who tapped a LAND for mana this turn": the acting player,
## a land's mana ability with {T} — not a Sol Ring.
func test_tapping_a_land_for_mana_is_remembered_for_the_turn() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var ring := put_battlefield(0, "Sol Ring")
	assert_ok(g.tap_for_mana(0, ring))
	assert_false(g.players[0].tapped_land_for_mana_this_turn, "an artifact is no land")
	var forest := put_battlefield(0, "Forest")
	assert_ok(g.tap_for_mana(0, forest))
	assert_true(g.players[0].tapped_land_for_mana_this_turn)
	assert_false(g.players[1].tapped_land_for_mana_this_turn)
	advance_to_next_turn()
	assert_false(g.players[0].tapped_land_for_mana_this_turn, "this turn only")


## "Target creature you cast this turn": the object the spell became — not
## one put onto the battlefield without casting, not one that has left and
## come back, not another player's, and not after the turn ends.
func test_the_creature_you_cast_this_turn_is_an_object() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := give_hand(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, bear, []))
	assert_false(g.cast_this_turn_by(bear, 0), "still a spell on the stack")
	resolve_stack()
	assert_true(g.cast_this_turn_by(bear, 0), "the permanent it became")
	assert_false(g.cast_this_turn_by(bear, 1), "not the opponent's")
	var dropped := put_battlefield(0, "Hill Giant")
	assert_false(g.cast_this_turn_by(dropped, 0), "never cast")
	g.return_to_hand(bear)
	g.put_from_hand_into_play(bear, 0)
	assert_false(g.cast_this_turn_by(bear, 0), "a new object (CR 400.7)")
	var other := give_hand(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, other, []))
	resolve_stack()
	advance_to_next_turn()
	assert_false(g.cast_this_turn_by(other, 0), "last turn's cast")


## Undo: the trackers come back through the search journal.
func test_the_trackers_round_trip_through_the_journal() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var forest := put_battlefield(0, "Forest")
	var bear := put_battlefield(0, "Grizzly Bears")
	var mark := g.make_mark()
	assert_ok(g.tap_for_mana(0, forest))
	g.destroy(bear)
	assert_eq(g.players[0].creatures_to_graveyard_this_turn, 1)
	g.unmake_to(mark)
	g.end_search()
	assert_false(g.players[0].tapped_land_for_mana_this_turn)
	assert_eq(g.players[0].creatures_to_graveyard_this_turn, 0)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


# =========================================== N_pending_ransom ==

func _bitten_upkeep(_game: MtgGame, _source: CardInstance, event: GameEvent,
		bitten: int) -> bool:
	return int(event.data["player"]) == bitten


func _poison(game: MtgGame, _source: CardInstance, _event: GameEvent, bitten: int) -> void:
	game.add_poison(bitten, 1)


func _bite(source: CardInstance, bitten: int) -> Dictionary:
	var entry := g.schedule_delayed_trigger(TriggeredAbility.new(
		Mtg.EventType.UPKEEP_START, _poison.bind(bitten),
		"The bitten player gets a poison counter at the beginning of their next upkeep.",
		_bitten_upkeep.bind(bitten)), source.controller_id, source, false, {},
		"Test Cobra: pay {2} before your next upkeep or get a poison counter")
	entry["settle_cost"] = ManaCost.parse("{2}")
	entry["settle_by"] = bitten
	return entry


## Sabertooth Cobra's ransom: "another poison counter at the beginning of
## their next upkeep unless they pay {2} BEFORE THAT STEP". Paid any time
## the bitten player has priority, the trigger is gone; unpaid, it fires.
func test_a_ransom_paid_before_the_upkeep_is_dropped() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var cobra := put_battlefield(0, "Grizzly Bears")
	var entry := _bite(cobra, 1)
	assert_eq(g.settleable_delayed_triggers(1).size(), 1, "offered to the bitten player")
	assert_eq(g.settleable_delayed_triggers(0).size(), 0, "and not to the biter")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.C, 2)
	assert_ok(g.settle_delayed_trigger(1, int(entry["id"])))
	advance_to_next_turn()
	assert_eq(g.players[1].poison, 0, "paid off")


func test_an_unpaid_ransom_poisons_at_the_upkeep() -> void:
	var cobra := put_battlefield(0, "Grizzly Bears")
	_bite(cobra, 1)
	advance_to_next_turn()
	assert_eq(g.players[1].poison, 1, "the upkeep came and nobody paid")


# =========================================== N_cant_gain_life ==

## CR 119.7: nothing gains life — and a replacement of the gain (Lich's
## "draw that many instead") is not applied either. Loss is untouched.
func test_players_cant_gain_life() -> void:
	var wastes := put_synthetic(0, _wastes())
	g.adjust_life(0, 3)
	g.adjust_life(1, 3)
	assert_eq(g.players[0].life, 20)
	assert_eq(g.players[1].life, 20)
	g.players[0].life_gain_becomes_draw = true
	var hand := g.players[0].hand.size()
	g.adjust_life(0, 2)
	assert_eq(g.players[0].hand.size(), hand, "the Lich's draw replaces nothing")
	g.adjust_life(1, -2)
	assert_eq(g.players[1].life, 18, "losing life still works")
	g.destroy(wastes)
	g.adjust_life(1, 2)
	assert_eq(g.players[1].life, 20, "it leaves, they gain again")


# ====================================== N_additive_land_type ==

## A Forest becomes a Forest Swamp: it keeps {G} and gains {B}; a basic
## Swamp is not given a second Swamp; a nonbasic keeps its own abilities.
func test_a_land_gains_a_basic_type_in_addition() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_synthetic(1, _blanket())
	var forest := put_battlefield(0, "Forest")
	var swamp := put_battlefield(0, "Swamp")
	var mine := put_battlefield(0, "Strip Mine")
	assert_true(forest.has_subtype("forest") and forest.has_subtype("swamp"))
	assert_eq(forest.cur_mana_abilities.size(), 2)
	assert_eq(swamp.cur_mana_abilities.size(), 1, "no second Swamp")
	assert_true(mine.has_subtype("swamp"))
	assert_false(mine.cur_activated_abilities.is_empty(), "Strip Mine keeps its own ability")
	assert_false(mine.cur_abilities_silenced, "the CR 305.7 strip does not apply")
	assert_ok(g.tap_for_mana(0, forest, 1))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 1, "taps for black")


## Timestamp order with a REPLACING retyper: Blood Moon after the Blanket
## leaves a nonbasic a Mountain only; the Blanket after Blood Moon makes it
## a Mountain Swamp.
func test_additive_and_replacing_retypers_apply_in_timestamp_order() -> void:
	var blanket := put_synthetic(1, _blanket())
	put_battlefield(1, "Blood Moon")
	var mine := put_battlefield(0, "Strip Mine")
	assert_eq(mine.cur_subtypes, ["mountain"], "Blood Moon is the later effect")
	g.destroy(blanket)
	put_synthetic(1, _blanket())
	assert_true(mine.has_subtype("mountain") and mine.has_subtype("swamp"),
		"now the Blanket is: %s" % [mine.cur_subtypes])


# ============================================= N_offzone_color ==

## Celestial Dawn outside the battlefield: its controller's nonland cards in
## hand, graveyard and library are white, and so are their spells on the
## stack; lands and the opponent's cards are not; gone, the printed colours
## come back.
func test_cards_off_the_battlefield_take_the_seat_colour() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bolt := give_hand(0, "Lightning Bolt")
	var forest := give_hand(0, "Forest")
	var their_bolt := give_hand(1, "Lightning Bolt")
	var dawn := put_synthetic(0, _dawn())
	assert_eq(bolt.cur_colors, Mtg.ManaColor.W, "in hand")
	assert_true(bolt.has_color(Mtg.ManaColor.W))
	assert_eq(forest.cur_colors, 0, "a land card is not painted")
	assert_eq(their_bolt.cur_colors, Mtg.ManaColor.R, "not the opponent's")
	assert_eq(g.players[0].library[-1].cur_colors, Mtg.ManaColor.W if not g.players[0].library[-1].data.is_land() else 0)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_eq(bolt.cur_colors, Mtg.ManaColor.W, "a spell you control on the stack")
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bolt.cur_colors, Mtg.ManaColor.W, "in the graveyard")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_eq(bear.cur_colors, Mtg.ManaColor.W, "a nonland permanent you control")
	g.destroy(dawn)
	assert_eq(bolt.cur_colors, Mtg.ManaColor.R, "printed again")
	assert_eq(bear.cur_colors, Mtg.ManaColor.G)


## A layer-5 STATIC runs in the colour layer: an anthem that reads colour
## (Crusade) sees the repaint whichever entered first.
func test_a_colour_static_is_seen_by_an_anthem_whatever_the_order() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	put_synthetic(0, _whitewash())
	put_battlefield(0, "Crusade")
	assert_eq(bear.cur_power, 3, "white, so +1/+1")
	var other := put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Crusade")
	put_synthetic(1, _whitewash())
	assert_eq(other.cur_power, 4, "the whitewash entered after the Crusade, and both Crusades count")


## CR 613.7 within layer 5: a floating colour change created AFTER the
## static wins; the static entering after it wins back.
func test_colour_statics_and_floating_changes_apply_in_timestamp_order() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var wash := put_synthetic(0, _whitewash())
	g.continuous.add_until_eot_color(bear.id, Mtg.ManaColor.B)
	g.recalculate()
	assert_eq(bear.cur_colors, Mtg.ManaColor.B, "the later effect")
	g.destroy(wash)
	put_synthetic(0, _whitewash())
	assert_eq(bear.cur_colors, Mtg.ManaColor.W, "now the static is the later one")


# ====================================== N_mana_colorless_only ==

## "You may spend white mana as though it were mana of any color. You may
## spend other mana only as though it were colorless mana."
func test_the_spending_rule_in_the_pool() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_synthetic(0, _dawn())
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(0, bolt, [TargetRef.player(1)]), "not enough mana")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.R), 1, "the white paid, the red waits")
	resolve_stack()
	assert_eq(g.players[1].life, 17)
	var ring := give_hand(0, "Sol Ring")
	assert_ok(g.cast_spell(0, ring, []))   # red pays generic


## The planner reads the same rule: Plains alone plan a red spell, and a
## Mountain alone plans only generic.
func test_the_spending_rule_reaches_the_planner() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_synthetic(0, _dawn())
	var plains := put_battlefield(0, "Plains")
	var bolt_cost := ManaCost.parse("{R}")
	assert_false(ManaPlanner.plan(g, 0, bolt_cost, 0).is_empty(), "white plans red")
	g.tap_for_mana(0, plains)
	g.players[0].mana_pool.clear()
	put_battlefield(0, "Mountain")
	assert_true(ManaPlanner.plan(g, 0, bolt_cost, 0).is_empty(), "red cannot pay {R}")
	assert_false(ManaPlanner.plan(g, 0, ManaCost.parse("{1}"), 0).is_empty(), "but pays {1}")
	g.destroy(g.players[0].battlefield[0])   # the Dawn
	assert_false(ManaPlanner.plan(g, 0, bolt_cost, 0).is_empty(), "the rule left with it")
