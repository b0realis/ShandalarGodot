extends GameTest
## SEEDS OF INNOCENCE AND PURGATORY (bug hunt 2026-10-21, cardsB).
##
## Seeds of Innocence — "Destroy all artifacts. … The controller of each of
## those artifacts gains life equal to its mana value." It paid only for an
## artifact whose card REACHED a graveyard, so an artifact destroyed under
## Forbidden Crypt (exiled instead, CR 614.6) gave its controller nothing,
## though it was destroyed all the same. It now pays for every artifact the
## destruction moved off the battlefield, wherever it went.
##
## Purgatory — "return a card exiled with this enchantment to the
## battlefield": with no "under its owner's control" the card enters under
## the control of the ability's controller (CR 110.2a). It came back under
## its OWNER's, which differs once Purgatory has changed hands (Avarice
## Totem, Pack 9): the new controller paid {4} and 2 life for the old
## controller's creature.


func before_each() -> void:
	CardPacks.set_enabled(MirageBlockPack.ID, true)
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled(MirageBlockPack.ID, false)


class Yes extends DecisionAgent:
	func answer_yes_no(_g: MtgGame, _pid: int, _prompt: String, _hint: bool) -> bool:
		return true


func _cast_seeds() -> void:
	var spell := give_hand(0, "Seeds of Innocence")
	add_mana(0, Mtg.ManaColor.G, 3)
	assert_ok(g.cast_spell(0, spell))
	resolve_stack()


func test_seeds_of_innocence_pays_for_an_artifact_forbidden_crypt_exiles() -> void:
	put_battlefield(1, "Forbidden Crypt")
	var rock := put_battlefield(1, "Sol Ring")
	_cast_seeds()
	assert_eq(rock.zone, Mtg.Zone.EXILE, "Forbidden Crypt exiled the destroyed artifact")
	assert_eq(g.players[1].life, 21, "its controller still gains its mana value")


func test_seeds_of_innocence_still_pays_for_an_artifact_in_the_graveyard() -> void:
	var rock := put_battlefield(1, "Sol Ring")
	var mine := put_battlefield(0, "Sol Ring")
	_cast_seeds()
	assert_eq(rock.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 21)
	assert_eq(g.players[1].life, 21)


func test_stolen_purgatory_returns_the_card_under_its_new_controller() -> void:
	var purgatory := put_battlefield(0, "Purgatory")
	var bear := put_battlefield(0, "Grizzly Bears")
	g.destroy(bear)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.EXILE, "Purgatory exiled the dying creature")
	g.change_control(purgatory, 1)
	for _n in 4:
		put_battlefield(1, "Forest")
	g.agents[1] = Yes.new()
	advance_to_next_turn()   # player 1's upkeep: pay {4} and 2 life
	assert_eq(g.players[1].life, 18)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.controller_id, 1, "under the control of Purgatory's controller")
	assert_eq(bear.owner_id, 0)


func test_purgatory_returns_its_own_controllers_card_to_them() -> void:
	put_battlefield(0, "Purgatory")
	var bear := put_battlefield(0, "Grizzly Bears")
	g.destroy(bear)
	resolve_stack()
	for _n in 4:
		put_battlefield(0, "Forest")
	g.agents[0] = Yes.new()
	advance_to_next_turn()
	advance_to_next_turn()   # player 0's next upkeep
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.controller_id, 0)
