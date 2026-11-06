extends GameTest
## 0.60.19 bug pass, h2-1 and h2-2 — two old cards meeting Pack 10's type
## changes.
##
## h2-1, Ashnod's Transmogrant: "That creature becomes an artifact in
## addition to its other types" is a layer-4 effect with the timestamp of
## the ability's resolution (CR 613.7). It was written into the instance's
## printed-type grant, which the reset applies BEFORE layer 4 — so an OLDER
## type change (an awakened Opal Caryatid's "becomes a 2/2 Soldier
## creature") overwrote the newer artifact.
##
## h2-2, Kismet: "creatures your opponents control enter tapped" — which
## replacement effects apply to an arriving permanent is judged on it AS IT
## WOULD EXIST on the battlefield (CR 614.12). An enchantment entering
## under an Opalescence already there is a creature there, so it enters
## tapped; Kismet read its off-battlefield (printed) types.

const W := Mtg.ManaColor.W
const G := Mtg.ManaColor.G


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-10", false)


func _pt(inst: CardInstance) -> Array:
	return [inst.cur_power, inst.cur_toughness]


func _cast_bears(pid: int) -> CardInstance:
	var bears := give_hand(pid, "Grizzly Bears")
	add_mana(pid, G, 2)
	assert_ok(g.cast_spell(pid, bears, []))
	return bears


func _in_graveyard(pid: int, card_name: String) -> CardInstance:
	var card := give_hand(pid, card_name)
	g.discard_cards(pid, [card])
	return card


# ================================================ h2-1 Ashnod's Transmogrant --

func test_transmogrant_on_an_awakened_opal_makes_an_artifact() -> void:
	var opal := put_battlefield(1, "Opal Caryatid")
	_cast_bears(0)
	resolve_stack()
	assert_true(opal.is_creature(), "awake")
	var mogrant := put_battlefield(0, "Ashnod's Transmogrant")
	assert_ok(g.activate_ability(0, mogrant, 0, [TargetRef.card(opal)]))
	resolve_stack()
	assert_eq(_pt(opal), [3, 3], "the +1/+1 counter landed")
	assert_true(opal.is_creature(), "still the Soldier creature")
	assert_true(opal.is_type(Mtg.CardType.ARTIFACT),
		"CR 613.7: the newer 'artifact in addition' survives the older type change")


func test_a_newer_type_change_overwrites_the_transmogrant_until_it_ends() -> void:
	var bears := put_battlefield(1, "Grizzly Bears")
	var mogrant := put_battlefield(0, "Ashnod's Transmogrant")
	assert_ok(g.activate_ability(0, mogrant, 0, [TargetRef.card(bears)]))
	resolve_stack()
	assert_true(bears.is_type(Mtg.CardType.ARTIFACT))
	var sculptor := put_battlefield(0, "Soul Sculptor")
	add_mana(0, W, 2)
	assert_ok(g.activate_ability(0, sculptor, 0, [TargetRef.card(bears)]))
	resolve_stack()
	assert_false(bears.is_type(Mtg.CardType.ARTIFACT), "the Sculptor's newer change sets the types")
	assert_true(bears.is_type(Mtg.CardType.ENCHANTMENT))
	_cast_bears(0)
	assert_true(bears.is_type(Mtg.CardType.ARTIFACT),
		"the Sculptor's change ended; the Transmogrant's is still there")
	assert_true(bears.is_creature())


# ============================================================ h2-2 Kismet --

func test_kismet_taps_an_enchantment_entering_under_opalescence() -> void:
	put_battlefield(1, "Kismet")
	put_battlefield(0, "Opalescence")
	var crusade := give_hand(0, "Crusade")
	add_mana(0, W, 2)
	assert_ok(g.cast_spell(0, crusade, []))
	resolve_stack()
	assert_true(crusade.is_creature())
	assert_true(crusade.tapped, "CR 614.12: it would be a creature, so it enters tapped")


func test_kismet_still_spares_its_own_side_and_an_aura() -> void:
	put_battlefield(1, "Kismet")
	put_battlefield(1, "Opalescence")
	var own := give_hand(1, "Crusade")
	var bears := put_battlefield(0, "Grizzly Bears")
	var strength := give_hand(0, "Holy Strength")
	add_mana(0, W, 1)
	assert_ok(g.cast_spell(0, strength, [TargetRef.card(bears)]))
	resolve_stack()
	assert_eq(strength.zone, Mtg.Zone.BATTLEFIELD)
	assert_false(strength.tapped, "Opalescence makes no Aura a creature")
	advance_to_next_turn()
	add_mana(1, W, 2)
	assert_ok(g.cast_spell(1, own, []))
	resolve_stack()
	assert_true(own.is_creature())
	assert_false(own.tapped, "Kismet taps only its opponents' arrivals")


func test_kismet_taps_an_enchantment_replenished_under_opalescence() -> void:
	put_battlefield(1, "Kismet")
	put_battlefield(0, "Opalescence")
	var crusade := _in_graveyard(0, "Crusade")
	var replenish := give_hand(0, "Replenish")
	add_mana(0, W, 4)
	assert_ok(g.cast_spell(0, replenish))
	resolve_stack()
	assert_eq(crusade.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(crusade.tapped, "arriving together is judged the same way")


func test_kismet_reads_printed_types_where_nothing_changes_them() -> void:
	put_battlefield(1, "Kismet")
	var crusade := give_hand(0, "Crusade")
	add_mana(0, W, 2)
	assert_ok(g.cast_spell(0, crusade, []))
	resolve_stack()
	assert_false(crusade.tapped, "an enchantment is no artifact, creature or land")
	var bears := _cast_bears(0)
	resolve_stack()
	assert_true(bears.tapped)
