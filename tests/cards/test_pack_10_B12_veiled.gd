extends GameTest
## Pack 10 (the Urza block), batch B12: the blue Veiled enchantments of
## cards/sets/usg/_opal.gd — Veil of Birds, Veiled Apparition, Veiled
## Crocodile, Veiled Sentry, Veiled Serpent (and its cycling).
##
## Veiled Apparition's upkeep trigger and Veiled Serpent's Island clause are
## GRANTED as they become creatures: a Humility already on the battlefield
## leaves them, one that arrives later removes them (CR 613.7); a dormant
## Serpent that Opalescence animates has no such clause at all.

const U := Mtg.ManaColor.U
const B := Mtg.ManaColor.B
const G := Mtg.ManaColor.G


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _pt(inst: CardInstance) -> Array:
	return [inst.cur_power, inst.cur_toughness]


## P0 casts a spell that is not a creature (Dark Ritual) and lets it resolve.
func _cast_ritual() -> void:
	var ritual := give_hand(0, "Dark Ritual")
	add_mana(0, B)
	assert_ok(g.cast_spell(0, ritual, []))
	resolve_stack()


func _cast(card_name: String, color: int, amount: int) -> CardInstance:
	var spell := give_hand(0, card_name)
	add_mana(0, color, amount)
	assert_ok(g.cast_spell(0, spell, []))
	return spell


# ------------------------------------------------------------- Veil of Birds --

func test_veil_of_birds_becomes_a_flying_bird_on_any_spell() -> void:
	var veil := put_battlefield(1, "Veil of Birds")
	_cast_ritual()
	assert_true(veil.is_creature())
	assert_false(veil.is_type(Mtg.CardType.ENCHANTMENT))
	assert_true(veil.has_subtype("bird"))
	assert_eq(_pt(veil), [1, 1])
	assert_true(veil.has_keyword(Mtg.Keyword.FLYING))


func test_veil_of_birds_ignores_its_controllers_spells() -> void:
	var veil := put_battlefield(0, "Veil of Birds")
	_cast_ritual()
	assert_false(veil.is_creature())


# ---------------------------------------------------------- Veiled Apparition --

func test_apparition_becomes_a_three_three_flyer_that_asks_for_upkeep() -> void:
	var ghost := put_battlefield(1, "Veiled Apparition")
	_cast_ritual()
	assert_true(ghost.is_creature() and ghost.has_subtype("illusion"))
	assert_eq(_pt(ghost), [3, 3])
	assert_true(ghost.has_keyword(Mtg.Keyword.FLYING))
	advance_to_next_turn()   # P1's upkeep: nothing to pay with
	assert_eq(ghost.zone, Mtg.Zone.GRAVEYARD, "sacrificed unless {1}{U} is paid")


func test_apparition_stays_when_its_controller_pays() -> void:
	var ghost := put_battlefield(1, "Veiled Apparition")
	put_battlefield(1, "Island")
	put_battlefield(1, "Island")
	_cast_ritual()
	advance_to_next_turn()
	assert_eq(ghost.zone, Mtg.Zone.BATTLEFIELD, "paid {1}{U}")


func test_a_dormant_apparition_owes_nothing() -> void:
	var ghost := put_battlefield(1, "Veiled Apparition")
	advance_to_next_turn()
	assert_eq(ghost.zone, Mtg.Zone.BATTLEFIELD, "the upkeep line comes with the creature")


func test_humility_arriving_later_removes_the_granted_upkeep() -> void:
	CardPacks.set_enabled("pack-9", true)
	var ghost := put_battlefield(1, "Veiled Apparition")
	_cast_ritual()
	put_battlefield(0, "Humility")
	advance_to_next_turn()
	assert_eq(ghost.zone, Mtg.Zone.BATTLEFIELD, "the newer Humility took the grant (CR 613.7)")
	assert_eq(_pt(ghost), [1, 1])


func test_humility_already_there_leaves_the_granted_upkeep() -> void:
	CardPacks.set_enabled("pack-9", true)
	put_battlefield(0, "Humility")
	var ghost := put_battlefield(1, "Veiled Apparition")
	_cast_ritual()
	assert_eq(_pt(ghost), [3, 3], "animated after Humility: printed size")
	advance_to_next_turn()
	assert_eq(ghost.zone, Mtg.Zone.GRAVEYARD, "a grant made after Humility works")


# ------------------------------------------------------------ Veiled Crocodile --

func test_crocodile_waits_for_an_empty_hand() -> void:
	var gift := give_hand(0, "Grizzly Bears")
	give_hand(1, "Grizzly Bears")
	var croc := put_battlefield(1, "Veiled Crocodile")
	g.check_state_based_actions()
	assert_false(croc.is_creature(), "both players hold a card")
	add_mana(0, G, 2)
	assert_ok(g.cast_spell(0, gift, []))
	resolve_stack()
	assert_true(croc.is_creature() and croc.has_subtype("crocodile"))
	assert_eq(_pt(croc), [4, 4])


# --------------------------------------------------------------- Veiled Sentry --

func test_sentry_takes_the_spells_mana_value() -> void:
	var sentry := put_battlefield(1, "Veiled Sentry")
	_cast("Grizzly Bears", G, 2)
	resolve_stack()
	assert_true(sentry.is_creature() and sentry.has_subtype("illusion"))
	assert_false(sentry.is_type(Mtg.CardType.ENCHANTMENT))
	assert_eq(_pt(sentry), [2, 2])


func test_sentry_answering_a_zero_drop_dies() -> void:
	var sentry := put_battlefield(1, "Veiled Sentry")
	var thopter := give_hand(0, "Ornithopter")
	assert_ok(g.cast_spell(0, thopter, []))
	resolve_stack()
	assert_eq(sentry.zone, Mtg.Zone.GRAVEYARD, "a 0/0 Illusion (CR 704.5f)")


func test_sentry_reads_the_spell_as_it_was_cast_even_if_it_is_gone() -> void:
	var sentry := put_battlefield(1, "Veiled Sentry")
	var dragon := _cast("Shivan Dragon", Mtg.ManaColor.R, 6)
	g.counter_spell(dragon)   # gone before the trigger resolves
	resolve_stack()
	assert_eq(_pt(sentry), [6, 6], "the mana value as it was cast (CR 608.2h)")


# --------------------------------------------------------------- Veiled Serpent --

func test_serpent_becomes_a_four_four_that_needs_an_island() -> void:
	var serpent := put_battlefield(1, "Veiled Serpent")
	_cast_ritual()
	assert_true(serpent.is_creature() and serpent.has_subtype("serpent"))
	assert_eq(_pt(serpent), [4, 4])
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(1, [serpent.id]))
	assert_ok(g.declare_attackers(1, []))


func test_serpent_attacks_when_the_defender_has_an_island() -> void:
	var serpent := put_battlefield(1, "Veiled Serpent")
	put_battlefield(0, "Island")
	_cast_ritual()
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [serpent.id]))


func test_a_dormant_serpent_under_opalescence_attacks_freely() -> void:
	var serpent := put_battlefield(1, "Veiled Serpent")
	put_battlefield(1, "Opalescence")
	assert_true(serpent.is_creature() and serpent.is_type(Mtg.CardType.ENCHANTMENT))
	assert_eq(_pt(serpent), [3, 3], "its mana value")
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [serpent.id]))   # the Island clause is granted, not printed


func test_humility_arriving_later_removes_the_island_clause() -> void:
	CardPacks.set_enabled("pack-9", true)
	var serpent := put_battlefield(1, "Veiled Serpent")
	_cast_ritual()
	assert_true(serpent.cur_cant_attack, "precondition")
	put_battlefield(0, "Humility")
	assert_false(serpent.cur_cant_attack, "the newer Humility removed it")


func test_humility_already_there_leaves_the_island_clause() -> void:
	CardPacks.set_enabled("pack-9", true)
	put_battlefield(0, "Humility")
	var serpent := put_battlefield(1, "Veiled Serpent")
	_cast_ritual()
	assert_true(serpent.cur_cant_attack, "granted after Humility (CR 613.7)")


func test_serpent_cycles_from_the_hand() -> void:
	var serpent := give_hand(0, "Veiled Serpent")
	var before := g.players[0].hand.size()
	add_mana(0, U, 2)
	assert_ok(g.activate_ability(0, serpent, 0, []))
	resolve_stack()
	assert_eq(serpent.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].hand.size(), before, "discarded one, drew one")
