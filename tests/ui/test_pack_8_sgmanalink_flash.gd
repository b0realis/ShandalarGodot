extends GameTest
## FLASH AT AN SGMANALINK TABLE (Pack 8). A networked human seat decides
## whether to hold a priority window from the filtered presentation the
## referee sends it (`SgDuelPresentation.build`: `respond` — a fast effect
## the untapped sources could pay and aim — and `floating` — one the
## floating pool pays now; `SgDuelView._could_respond` /
## `_has_affordable_fast_effect` read them). Until Pack 8 that test asked
## `is_type(INSTANT)`, so a King Cheetah, a flash-rider Aura or a creature
## under Winding Canyons never held the window the local screen holds for
## it. It now asks the engine's own `MtgGame.casts_at_instant_speed`, the
## predicate the local duel screen uses (`DuelScreen._fast_spells`).

var referee: SgPracticeMatch


func before_each() -> void:
	super.before_each()
	referee = SgPracticeMatch.new(42)
	referee.game = g


static func _cheetah() -> CardData:
	return CardData.new("Test Cheetah", "{G}", Mtg.CardType.CREATURE).pt(3, 2) \
		.with_keywords([Mtg.Keyword.FLASH])


static func _bear() -> CardData:
	return CardData.new("Test Bear", "{G}", Mtg.CardType.CREATURE).pt(2, 2)


static func _armor() -> CardData:
	return CardData.new("Test Armor", "{G}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()).with_flash_rider()


static func _is_creature(_g: MtgGame, inst: CardInstance) -> bool:
	return inst.is_creature()


## Seat 1 holds priority in seat 0's upkeep with one untapped Forest.
func _their_upkeep() -> void:
	advance_to_step(Mtg.Step.UPKEEP)
	assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1)
	put_battlefield(1, "Forest")


func _row(card: CardInstance) -> Dictionary:
	var handle := referee._handle(1, card)
	for row in referee.view(1).presentation.cards:
		if row.id == handle:
			return row
	return {}


func test_a_flash_creature_is_a_response_at_the_networked_table() -> void:
	_their_upkeep()
	var cheetah := give_synthetic(1, _cheetah())
	assert_true(g.casts_at_instant_speed(1, cheetah))
	var shown: Dictionary = referee.view(1).presentation
	assert_true(shown.respond, "the window is held for the flash creature")
	assert_true(_row(cheetah).get("castable", false), "and its row is castable")
	assert_false(shown.floating, "nothing floating yet")
	add_mana(1, Mtg.ManaColor.G)
	assert_true(referee.view(1).presentation.floating, "Done stops for it once {G} floats")


func test_a_plain_creature_is_not() -> void:
	_their_upkeep()
	var bear := give_synthetic(1, _bear())
	add_mana(1, Mtg.ManaColor.G)
	var shown: Dictionary = referee.view(1).presentation
	assert_false(shown.respond)
	assert_false(shown.floating)
	assert_false(_row(bear).get("castable", true), "the step forbids it")


func test_winding_canyons_grant_counts_at_the_table() -> void:
	_their_upkeep()
	give_synthetic(1, _bear())
	assert_false(referee.view(1).presentation.respond, "control")
	g.grant_flash(1, _is_creature, "creature spells this turn")
	assert_true(referee.view(1).presentation.respond)


func test_a_flash_rider_aura_needs_a_creature_to_enchant() -> void:
	_their_upkeep()
	give_synthetic(1, _armor())
	assert_false(referee.view(1).presentation.respond,
		"no creature on the table: nothing to cast it at")
	put_battlefield(0, "Grizzly Bears")
	assert_true(referee.view(1).presentation.respond)
