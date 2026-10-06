extends GameTest
## Pack 9 engine package E5 — Volrath's Shapeshifter's "full text of the top
## creature card of your graveyard" (CR 613.2 layer 1, CR 707.2):
##
##   "As long as the top card of your graveyard is a creature card, this
##   creature has the full text of that card and has the text '{2}: Discard
##   a card.' (This creature has that card's name, mana cost, color, types,
##   abilities, power, and toughness.) {2}: Discard a card."
##
## [method CardData.with_graveyard_top_copy] declares it; every
## recalculation reads the top card of the CONTROLLER's graveyard and swaps
## the permanent's definition in place — never a zone change: counters,
## damage, tapped state, summoning sickness and timestamp stay, nothing
## enters, and the trigger/static indexes follow the new text.
##
## The Shapeshifter here is SYNTHETIC (the card is a Pack 9 script written
## against this API).


## "{2}: Discard a card." — the controller discards the first card of their
## hand (the choice is not under test here).
class DiscardOne extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		var hand: Array = game.players[controller].hand
		if not hand.is_empty():
			game.discard_cards(controller, [hand[0]])

	func describe() -> String:
		return "discard a card"


static func _discard_ability() -> ActivatedAbility:
	return ActivatedAbility.new("{2}", false, [DiscardOne.new()], "{2}: Discard a card.")


static func _shapeshifter() -> CardData:
	return CardData.new("Test Shapeshifter", "{1}{U}{U}", Mtg.CardType.CREATURE) \
		.pt(0, 1).with_subtypes(["phyrexian", "shapeshifter"]) \
		.with_graveyard_top_copy(_discard_ability())


## A creature card whose ETB and upkeep triggers both gain life — to tell an
## entering apart from merely having the text.
static func _lifegiver() -> CardData:
	return CardData.new("Test Lifegiver", "{2}{W}", Mtg.CardType.CREATURE).pt(2, 3) \
		.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _gain.bind(5),
			"When this creature enters, you gain 5 life.", _self_enters)) \
		.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _gain.bind(1),
			"At the beginning of your upkeep, you gain 1 life.", _own_upkeep))


static func _self_enters(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("instance") == s


static func _own_upkeep(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return int(e.data.get("player", -1)) == s.controller_id


static func _gain(g: MtgGame, s: CardInstance, _e: GameEvent, amount: int) -> void:
	g.adjust_life(s.controller_id, amount)


static func _legend() -> CardData:
	return CardData.new("Test Legend", "{2}{B}", Mtg.CardType.CREATURE).pt(3, 3) \
		.with_supertypes(Mtg.Supertype.LEGENDARY)


func _to_graveyard(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.GRAVEYARD
	g.players[pid].graveyard.append(inst)
	g.recalculate()
	return inst


func _synthetic_to_graveyard(pid: int, data: CardData) -> CardInstance:
	var inst := CardInstance.new(data, g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	inst.zone = Mtg.Zone.GRAVEYARD
	g.players[pid].graveyard.append(inst)
	g.recalculate()
	return inst


# ----------------------------------------------------------- the reading --

func test_with_no_creature_on_top_it_is_itself() -> void:
	var shifter := put_synthetic(0, _shapeshifter())
	assert_eq(shifter.data.card_name, "Test Shapeshifter")
	assert_eq([shifter.cur_power, shifter.cur_toughness], [0, 1])
	assert_eq(shifter.cur_activated_abilities.size(), 1, "its own {2}: Discard a card")
	_to_graveyard(0, "Forest")
	assert_eq(shifter.data.card_name, "Test Shapeshifter", "a land on top: still itself")


func test_a_creature_card_on_top_gives_its_full_text() -> void:
	var shifter := put_synthetic(0, _shapeshifter())
	_to_graveyard(0, "Shivan Dragon")
	assert_eq(shifter.data.card_name, "Shivan Dragon")
	assert_eq([shifter.cur_power, shifter.cur_toughness], [5, 5])
	assert_true(shifter.has_keyword(Mtg.Keyword.FLYING))
	assert_eq(shifter.cur_colors, Mtg.ManaColor.R)
	assert_true(shifter.has_subtype("dragon"))
	assert_false(shifter.has_subtype("shapeshifter"))
	assert_eq(shifter.cur_activated_abilities.size(), 2,
		"the Dragon's firebreathing plus '{2}: Discard a card'")
	assert_eq(shifter.printed_data.card_name, "Test Shapeshifter", "the card is unchanged")


func test_the_top_card_decides() -> void:
	var shifter := put_synthetic(0, _shapeshifter())
	_to_graveyard(0, "Shivan Dragon")
	_to_graveyard(0, "Forest")
	assert_eq(shifter.data.card_name, "Test Shapeshifter", "a Forest buried the Dragon")
	_to_graveyard(0, "Grizzly Bears")
	assert_eq(shifter.data.card_name, "Grizzly Bears")
	assert_eq([shifter.cur_power, shifter.cur_toughness], [2, 2])


func test_it_reads_its_controllers_graveyard() -> void:
	var shifter := put_synthetic(0, _shapeshifter())
	_to_graveyard(1, "Shivan Dragon")
	assert_eq(shifter.data.card_name, "Test Shapeshifter", "the opponent's graveyard is not 'your'")
	g.change_control(shifter, 1)
	g.recalculate()
	assert_eq(shifter.data.card_name, "Shivan Dragon", "now it is")


# ------------------------------------------------- never a zone change --

func test_counters_damage_tapped_and_sickness_stay() -> void:
	var shifter := put_synthetic(0, _shapeshifter())
	shifter.summoning_sick = true
	var stamp := shifter.layer_timestamp
	g.add_counters(shifter, "+1/+1")
	g.tap_permanent(shifter)
	_to_graveyard(0, "Shivan Dragon")
	shifter.damage = 2
	assert_eq([shifter.cur_power, shifter.cur_toughness], [6, 6])
	assert_true(shifter.tapped)
	assert_true(shifter.summoning_sick)
	assert_eq(shifter.layer_timestamp, stamp, "no new object (CR 400.7 does not apply)")
	assert_eq(shifter.damage, 2)
	_to_graveyard(0, "Forest")
	assert_eq([shifter.cur_power, shifter.cur_toughness], [1, 2], "0/1 plus the counter")
	g.check_state_based_actions()
	assert_eq(shifter.zone, Mtg.Zone.GRAVEYARD, "two damage on a 1/2 is lethal")


func test_no_enters_trigger_but_the_copied_triggers_work() -> void:
	var shifter := put_synthetic(0, _shapeshifter())
	var life := g.players[0].life
	_synthetic_to_graveyard(0, _lifegiver())
	assert_eq(shifter.data.card_name, "Test Lifegiver")
	resolve_stack()
	assert_eq(g.players[0].life, life, "it did not ENTER: no ETB")
	advance_to_next_turn()   # P1's turn
	advance_to_step(Mtg.Step.UPKEEP)   # P0's next upkeep
	assert_eq(g.active_player, 0)
	resolve_stack()
	assert_eq(g.players[0].life, life + 1, "the copied upkeep trigger fires")


func test_the_copied_cards_statics_work() -> void:
	var shifter := put_synthetic(0, _shapeshifter())
	var merfolk := put_battlefield(0, "Merfolk of the Pearl Trident")
	_to_graveyard(0, "Lord of Atlantis")
	assert_eq(shifter.data.card_name, "Lord of Atlantis")
	assert_eq([merfolk.cur_power, merfolk.cur_toughness], [2, 2], "the lord's +1/+1")
	assert_true(merfolk.cur_landwalk.has("island"))


func test_its_own_discard_changes_what_it_is() -> void:
	var shifter := put_synthetic(0, _shapeshifter())
	_to_graveyard(0, "Shivan Dragon")
	give_hand(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	var discard_index := shifter.cur_activated_abilities.size() - 1
	assert_ok(g.activate_ability(0, shifter, discard_index, []))
	resolve_stack()
	assert_eq(shifter.data.card_name, "Grizzly Bears")
	assert_eq([shifter.cur_power, shifter.cur_toughness], [2, 2])
	assert_eq(shifter.cur_activated_abilities.size(), 1, "only '{2}: Discard a card'")


func test_leaving_the_battlefield_restores_the_printed_card() -> void:
	var shifter := put_synthetic(0, _shapeshifter())
	_to_graveyard(0, "Shivan Dragon")
	g.destroy(shifter)
	assert_eq(shifter.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(shifter.data.card_name, "Test Shapeshifter")


func test_the_legend_rule_sees_the_new_name() -> void:
	var shifter := put_synthetic(0, _shapeshifter())
	var legend := put_synthetic(0, _legend())
	_synthetic_to_graveyard(0, _legend())
	assert_eq(shifter.data.card_name, "Test Legend")
	g.check_state_based_actions()
	assert_true(shifter.zone == Mtg.Zone.BATTLEFIELD \
		and legend.zone == Mtg.Zone.GRAVEYARD,
		"two legends share a name: the newer one is buried (the Shapeshifter is older)")


# ----------------------------------------------------------------- copies --

func test_a_copy_of_the_shifted_body_does_not_follow_its_own_graveyard() -> void:
	var shifter := put_synthetic(0, _shapeshifter())
	_to_graveyard(0, "Shivan Dragon")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.become_copy(bear, g.copiable_data(shifter))
	assert_eq(bear.data.card_name, "Shivan Dragon")
	_to_graveyard(1, "Forest")
	_to_graveyard(0, "Forest")
	assert_eq(bear.data.card_name, "Shivan Dragon",
		"the copy took the copiable values; it has no 'as long as' of its own")
	assert_eq(shifter.data.card_name, "Test Shapeshifter")


func test_a_copy_of_the_unshifted_card_follows_its_own_graveyard() -> void:
	var shifter := put_synthetic(0, _shapeshifter())
	var bear := put_battlefield(1, "Grizzly Bears")
	g.become_copy(bear, g.copiable_data(shifter))
	assert_eq(bear.data.card_name, "Test Shapeshifter")
	_to_graveyard(1, "Shivan Dragon")
	assert_eq(bear.data.card_name, "Shivan Dragon", "it reads ITS controller's graveyard")
	assert_eq(shifter.data.card_name, "Test Shapeshifter")


# ------------------------------------------------------------------ undo --

func test_a_snapshot_rewinds_it_too() -> void:
	var shifter := put_synthetic(0, _shapeshifter())
	var dragon := give_hand(0, "Shivan Dragon")
	var snap := GameSnapshot.take(g)
	g.discard_cards(0, [dragon])
	g.recalculate()
	assert_eq(shifter.data.card_name, "Shivan Dragon")
	snap.restore()
	g.recalculate()
	assert_eq(shifter.data.card_name, "Test Shapeshifter")
	assert_eq(dragon.zone, Mtg.Zone.HAND)


func test_undo_puts_the_old_text_back() -> void:
	var shifter := put_synthetic(0, _shapeshifter())
	var dragon := give_hand(0, "Shivan Dragon")
	var mark := g.make_mark()
	g.discard_cards(0, [dragon])
	g.recalculate()
	assert_eq(shifter.data.card_name, "Shivan Dragon")
	g.unmake_to(mark)
	g.end_search()
	assert_eq(dragon.zone, Mtg.Zone.HAND)
	assert_eq(shifter.data.card_name, "Test Shapeshifter")
	assert_eq([shifter.cur_power, shifter.cur_toughness], [0, 1])
