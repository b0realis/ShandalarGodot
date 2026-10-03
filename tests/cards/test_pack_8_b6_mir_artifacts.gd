extends GameTest
## Pack 8 (the Mirage block), batch B6: the Mirage artifacts in
## cards/sets/mir/_artifacts.gd — Acidic Dagger, Amber Prison, Amulet of
## Unmaking, Bone Mask, Chariot of the Sun, Cursed Totem, Elixir of
## Vitality, Grinning Totem, Mangara's Tome, Misers' Cage, Paupers' Cage,
## Phyrexian Vault, Razor Pendulum, Telim'Tor's Darts, Unerring Sling and
## Ventifact Bottle.

const CLAIMED := ["Acidic Dagger", "Amber Prison", "Amulet of Unmaking", "Bone Mask",
	"Chariot of the Sun", "Cursed Totem", "Elixir of Vitality", "Grinning Totem",
	"Mangara's Tome", "Misers' Cage", "Paupers' Cage", "Phyrexian Vault",
	"Razor Pendulum", "Telim'Tor's Darts", "Unerring Sling", "Ventifact Bottle"]

## Picks the card named [member pick] when offered; answers options with
## [member option] (-1 = the hint).
class Seat extends DecisionAgent:
	var pick := ""
	var option := -1
	func answer_card(_g: MtgGame, _pid: int, candidates: Array[CardInstance], _prompt: String) -> CardInstance:
		for c in candidates:
			if c.data.card_name == pick: return c
		return null if candidates.is_empty() else candidates[0]
	func answer_option(_g: MtgGame, _pid: int, _prompt: String, _options: Array[String], hint: int) -> int:
		return hint if option < 0 else option

func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	super()

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)

func _seat(pid: int) -> Seat:
	var s := Seat.new()
	g.set_agent(pid, s)
	return s

func _on_library_top(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.LIBRARY
	g.players[pid].library.append(inst)
	return inst

func _to_next_step_of(pid: int, step: int) -> void:
	var turn := g.turn_number
	var guard := 0
	while g.turn_number == turn and guard < 400:
		_advance_once()
		guard += 1
	while not (g.active_player == pid and g.current_step() == step) and guard < 800:
		_advance_once()
		guard += 1
	assert_eq(g.active_player, pid)
	assert_eq(g.current_step(), step)


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


# --------------------------------------------------------------- Acidic Dagger --

func test_acidic_dagger_destroys_what_the_creature_hits_then_follows_it_out() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var dagger := put_battlefield(0, "Acidic Dagger")
	var giant := put_battlefield(0, "Hill Giant")
	var wurm := put_battlefield(1, "Craw Wurm")
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, dagger, 0, [TargetRef.card(giant)]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wurm.id: giant.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD, "3 combat damage to a 6/4: destroyed by the Dagger")
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(dagger.zone, Mtg.Zone.GRAVEYARD, "the targeted creature left: sacrifice the Dagger")

func test_acidic_dagger_spares_walls_and_ends_with_the_turn() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var dagger := put_battlefield(0, "Acidic Dagger")
	var giant := put_battlefield(0, "Hill Giant")
	var wall := put_battlefield(1, "Wall of Stone")
	var wurm := put_battlefield(1, "Craw Wurm")
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, dagger, 0, [TargetRef.card(giant)]))
	resolve_stack()
	run_combat([giant.id], {wall.id: giant.id})
	assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD, "a Wall is not destroyed")
	assert_eq(dagger.zone, Mtg.Zone.BATTLEFIELD)
	advance_to_next_turn()
	advance_to_next_turn()   # P0's next turn: the Giant attacks into the Wurm
	run_combat([giant.id], {wurm.id: giant.id})
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD, "last turn's Dagger is over")
	assert_eq(dagger.zone, Mtg.Zone.BATTLEFIELD, "and so is its sacrifice clause")

func test_acidic_dagger_only_before_blockers() -> void:
	var dagger := put_battlefield(0, "Acidic Dagger")
	var giant := put_battlefield(0, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_refused(g.activate_ability(0, dagger, 0, [TargetRef.card(giant)]))


# ---------------------------------------------------------------- Amber Prison --

func test_amber_prison_holds_while_it_stays_tapped() -> void:
	var seat := _seat(0)
	advance_to_step(Mtg.Step.MAIN1)
	var prison := put_battlefield(0, "Amber Prison")
	var giant := put_battlefield(1, "Hill Giant")
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, prison, 0, [TargetRef.card(giant)]))
	resolve_stack()
	assert_true(giant.tapped)
	advance_to_next_turn()   # P1's untap step
	assert_true(giant.tapped, "doesn't untap while the Prison remains tapped")
	advance_to_next_turn()   # P0's untap step: the heuristic keeps the Prison tapped
	assert_true(prison.tapped, "you may choose not to untap it — and it holds something")
	seat.option = 0          # next time: untap it
	advance_to_next_turn()   # P1's turn: still held
	assert_true(giant.tapped)
	advance_to_next_turn()   # P0 untaps the Prison
	assert_false(prison.tapped)
	advance_to_next_turn()   # P1's untap step: free
	assert_false(giant.tapped)


# ---------------------------------------------------------- Amulet of Unmaking --

func test_amulet_of_unmaking_exiles_itself_and_a_permanent_at_sorcery_speed() -> void:
	var amulet := put_battlefield(0, "Amulet of Unmaking")
	var land := put_battlefield(1, "Forest")
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_refused(g.activate_ability(0, amulet, 0, [TargetRef.card(land)]), "sorcery")
	advance_to_step(Mtg.Step.MAIN2)
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.activate_ability(0, amulet, 0, [TargetRef.card(land)]))
	assert_eq(amulet.zone, Mtg.Zone.EXILE, "exiled as the cost")
	resolve_stack()
	assert_eq(land.zone, Mtg.Zone.EXILE)


# ------------------------------------------------------------------- Bone Mask --

func test_bone_mask_prevents_the_bolt_and_exiles_that_many_cards() -> void:
	var mask := put_battlefield(0, "Bone Mask")
	advance_to_next_turn()   # P1's turn
	var library := g.players[0].library.size()
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, mask, 0))
	resolve_stack()
	assert_eq(g.players[0].life, 20, "the named source's damage to you was prevented")
	assert_eq(g.players[0].library.size(), library - 3, "3 prevented: 3 cards exiled")
	assert_eq(g.players[0].exile.size(), 3)


# ---------------------------------------------------------- Chariot of the Sun --

func test_chariot_of_the_sun_gives_flying_and_base_toughness_one() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var chariot := put_battlefield(0, "Chariot of the Sun")
	var wurm := put_battlefield(0, "Craw Wurm")
	var theirs := put_battlefield(1, "Craw Wurm")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, chariot, 0, [TargetRef.card(theirs)]), "")
	assert_ok(g.activate_ability(0, chariot, 0, [TargetRef.card(wurm)]))
	resolve_stack()
	assert_true(wurm.has_keyword(Mtg.Keyword.FLYING))
	assert_eq([wurm.cur_power, wurm.cur_toughness], [6, 1])
	var growth := give_hand(0, "Giant Growth")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(wurm)]))
	resolve_stack()
	assert_eq(wurm.cur_toughness, 4, "a pump applies on top of the base toughness")
	advance_to_next_turn()
	assert_eq([wurm.cur_power, wurm.cur_toughness], [6, 4])
	assert_false(wurm.has_keyword(Mtg.Keyword.FLYING))


# ---------------------------------------------------------------- Cursed Totem --

func test_cursed_totem_stops_creature_abilities_mana_included() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var totem := put_battlefield(1, "Cursed Totem")
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	var elves := put_battlefield(0, "Llanowar Elves")
	var darts := put_battlefield(0, "Telim'Tor's Darts")
	assert_refused(g.activate_ability(0, sorcerer, 0, [TargetRef.player(1)]))
	assert_refused(g.tap_for_mana(0, elves))
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, darts, 0, [TargetRef.player(1)]))   # an artifact's ability is fine
	resolve_stack()
	g.destroy(totem)
	assert_ok(g.tap_for_mana(0, elves))
	assert_ok(g.activate_ability(0, sorcerer, 0, [TargetRef.player(1)]))


# ---------------------------------------------------------- Elixir of Vitality --

func test_elixir_of_vitality_enters_tapped_and_offers_four_or_eight() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var elixir := give_hand(0, "Elixir of Vitality")
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, elixir))
	resolve_stack()
	assert_true(elixir.tapped, "enters tapped")
	assert_refused(g.activate_ability(0, elixir, 0))
	advance_to_next_turn()
	advance_to_next_turn()
	assert_ok(g.activate_ability(0, elixir, 0))
	resolve_stack()
	assert_eq(g.players[0].life, 24)
	assert_eq(elixir.zone, Mtg.Zone.GRAVEYARD)
	var big := put_battlefield(0, "Elixir of Vitality")
	g.untap_permanent(big)
	add_mana(0, Mtg.ManaColor.C, 8)
	assert_ok(g.activate_ability(0, big, 1))
	resolve_stack()
	assert_eq(g.players[0].life, 32)


# --------------------------------------------------------------- Grinning Totem --

func test_grinning_totem_steals_a_card_to_play_until_your_next_upkeep() -> void:
	var seat := _seat(0)
	seat.pick = "Lightning Bolt"
	advance_to_step(Mtg.Step.MAIN1)
	var totem := put_battlefield(0, "Grinning Totem")
	var bolt := _on_library_top(1, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, totem, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.EXILE)
	assert_true(g.can_play_from_exile(0, bolt), "you may play that card")
	assert_false(g.can_play_from_exile(1, bolt))
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 17)
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.players[1].graveyard.has(bolt), "its owner's graveyard")

func test_grinning_totem_card_goes_to_the_graveyard_at_your_next_upkeep() -> void:
	var seat := _seat(0)
	seat.pick = "Shivan Dragon"
	advance_to_step(Mtg.Step.MAIN1)
	var totem := put_battlefield(0, "Grinning Totem")
	var dragon := _on_library_top(1, "Shivan Dragon")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, totem, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(dragon.zone, Mtg.Zone.EXILE)
	_to_next_step_of(0, Mtg.Step.UPKEEP)
	assert_false(g.can_play_from_exile(0, dragon), "the permission ended as the upkeep began")
	resolve_stack()
	assert_eq(dragon.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.players[1].graveyard.has(dragon))


# --------------------------------------------------------------- Mangara's Tome --

func test_mangaras_tome_exiles_a_pile_and_feeds_a_draw_from_it() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var dragon := _on_library_top(0, "Shivan Dragon")
	var library := g.players[0].library.size()
	var tome := give_hand(0, "Mangara's Tome")
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.cast_spell(0, tome))
	resolve_stack()
	assert_eq(g.players[0].library.size(), library - 5, "five cards searched out")
	assert_eq(g.players[0].exile.size(), 5)
	for card in g.players[0].exile:
		assert_true(card.face_down, "a face-down pile")
	assert_eq(dragon.zone, Mtg.Zone.EXILE, "the default seat searches for its best card")
	_to_next_step_of(0, Mtg.Step.UPKEEP)
	resolve_stack()
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, tome, 0))
	resolve_stack()
	var hand := g.players[0].hand.size()
	var lib := g.players[0].library.size()
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(g.players[0].hand.size(), hand + 1, "the draw step's draw was replaced...")
	assert_eq(g.players[0].library.size(), lib, "...nothing came off the library")
	assert_eq(g.players[0].exile.size(), 4, "the pile's top card went to the hand")


# ---------------------------------------------------------------- the cages --

func test_misers_cage_punishes_a_full_hand_at_the_opponents_upkeep() -> void:
	put_battlefield(0, "Misers' Cage")
	for n in 5: give_hand(1, "Forest")
	_to_next_step_of(1, Mtg.Step.UPKEEP)
	resolve_stack()
	assert_eq(g.players[1].life, 18, "five cards: 2 damage")
	g.discard_random(1, 2)   # three left, plus the turn's draw: four next upkeep
	_to_next_step_of(1, Mtg.Step.UPKEEP)
	assert_eq(g.players[1].hand.size(), 4)
	resolve_stack()
	assert_eq(g.players[1].life, 18, "four cards: nothing")
	assert_eq(g.players[0].life, 20, "never at its controller's upkeep")

func test_paupers_cage_punishes_an_empty_hand() -> void:
	put_battlefield(0, "Paupers' Cage")
	for n in 3: give_hand(1, "Forest")
	_to_next_step_of(1, Mtg.Step.UPKEEP)
	resolve_stack()
	assert_eq(g.players[1].life, 20, "three cards: nothing")
	g.discard_random(1, 2)
	_to_next_step_of(1, Mtg.Step.UPKEEP)
	resolve_stack()
	assert_eq(g.players[1].life, 18, "two or fewer: 2 damage")
	_to_next_step_of(0, Mtg.Step.UPKEEP)
	resolve_stack()
	assert_eq(g.players[0].life, 20, "its controller's own empty hand is safe")


# ------------------------------------------------------------- Phyrexian Vault --

func test_phyrexian_vault_draws_for_a_creature() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var vault := put_battlefield(0, "Phyrexian Vault")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, vault, 0), "")
	var bear := put_battlefield(0, "Grizzly Bears")
	var hand := g.players[0].hand.size()
	assert_ok(g.activate_ability(0, vault, 0))
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 1)


# -------------------------------------------------------------- Razor Pendulum --

func test_razor_pendulum_hits_a_player_at_five_or_less_at_their_end_step() -> void:
	put_battlefield(0, "Razor Pendulum")
	g.players[1].life = 5
	g.players[0].life = 6
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(g.players[0].life, 6, "six is safe")
	_to_next_step_of(1, Mtg.Step.END)
	resolve_stack()
	assert_eq(g.players[1].life, 3, "each player's end step, its controller's opponent included")


# ------------------------------------------------------------ Telim'Tor's Darts --

func test_telimtors_darts_pings_a_player_only() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var darts := put_battlefield(0, "Telim'Tor's Darts")
	var bear := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, darts, 0, [TargetRef.card(bear)]))
	assert_ok(g.activate_ability(0, darts, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 19)


# -------------------------------------------------------------- Unerring Sling --

func test_unerring_sling_throws_the_tapped_creatures_power_at_an_attacking_flier() -> void:
	var sling := put_battlefield(0, "Unerring Sling")
	var wurm := put_battlefield(0, "Craw Wurm")
	advance_to_next_turn()   # P1's turn
	var angel := put_battlefield(1, "Serra Angel")
	var idle := put_battlefield(1, "Air Elemental")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [angel.id]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_refused(g.activate_ability(0, sling, 0, [TargetRef.card(idle)]), "")
	assert_ok(g.activate_ability(0, sling, 0, [TargetRef.card(angel)]))
	assert_true(wurm.tapped, "the creature was tapped as the cost")
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD, "6 damage")

func test_unerring_sling_needs_an_untapped_creature() -> void:
	var sling := put_battlefield(0, "Unerring Sling")
	advance_to_next_turn()
	var angel := put_battlefield(1, "Serra Angel")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [angel.id]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_refused(g.activate_ability(0, sling, 0, [TargetRef.card(angel)]), "")


# ------------------------------------------------------------ Ventifact Bottle --

func test_ventifact_bottle_banks_charge_for_your_next_first_main_phase() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bottle := put_battlefield(0, "Ventifact Bottle")
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, bottle, 0, [], 3))
	resolve_stack()
	assert_eq(int(bottle.counters.get("charge", 0)), 3)
	advance_to_next_turn()   # P1's main phase: not "your" main phase
	resolve_stack()
	assert_eq(int(bottle.counters.get("charge", 0)), 3)
	advance_to_next_turn()   # P0's first main phase
	resolve_stack()
	assert_eq(int(bottle.counters.get("charge", 0)), 0)
	assert_true(bottle.tapped)
	assert_eq(g.players[0].mana_pool.total(), 3, "three colorless mana")

func test_ventifact_bottle_is_sorcery_speed() -> void:
	var bottle := put_battlefield(0, "Ventifact Bottle")
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_refused(g.activate_ability(0, bottle, 0, [], 3), "sorcery")
