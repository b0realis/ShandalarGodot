extends GameTest
## Pack 10 (the Urza block), batch B7: the Urza's Saga Auras in
## cards/sets/usg/_auras.gd. Each card: not pending, its main effect, a
## refused or non-triggering case, and the interactions its text implies;
## the self-returning Auras' shared trigger (graveyard only, the same
## object only) is pinned on Brilliant Halo and in
## test_pack_10_B7_legacy_auras.gd.

const CLAIMED := ["Brilliant Halo", "Pariah", "Serra's Embrace", "Cloak of Mists", "Confiscate",
	"Hermetic Study", "Launch", "Pendrell Flux", "Zephid's Embrace", "Despondency",
	"Parasitic Bond", "Vampiric Embrace", "Bravado", "Destructive Urge", "Fiery Mantle",
	"Reflexes", "Shiv's Embrace", "Blanchwood Armor", "Fertile Ground", "Fortitude",
	"Gaea's Embrace", "Spreading Algae", "Venomous Fangs"]

## Scripted answers: every yes/no with [member yes], every colour with
## [member color] (0 = the hint), and the questions it was asked.
class Seat extends DecisionAgent:
	var yes := true
	var color := 0
	var asked: Array[String] = []
	func answer_yes_no(_g: MtgGame, _pid: int, prompt: String, _hint: bool) -> bool:
		asked.append(prompt)
		return yes
	func answer_color(_g: MtgGame, _pid: int, prompt: String, hint: int) -> int:
		asked.append(prompt)
		return color if color != 0 else hint

func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

func _seat(pid: int) -> Seat:
	var s := Seat.new()
	g.set_agent(pid, s)
	return s

func _pt(i: CardInstance) -> Array: return [i.cur_power, i.cur_toughness]

## Give [param pid] priority (the other seat passes to them if needed).
func _priority_to(pid: int) -> void:
	if g.priority_player != pid: assert_ok(g.pass_priority(g.priority_player))
	assert_eq(g.priority_player, pid)

func _enchant(pid: int, aura_name: String, host: CardInstance, mana: Array) -> CardInstance:
	_priority_to(pid)
	var aura := give_hand(pid, aura_name)
	for m in mana: add_mana(pid, int(m))
	assert_ok(g.cast_spell(pid, aura, [TargetRef.card(host)]))
	resolve_stack()
	assert_eq(aura.attached_to, host.id, aura_name + " is attached")
	return aura

func _cast_at(pid: int, spell: String, target: TargetRef, mana: Array) -> CardInstance:
	_priority_to(pid)
	var card := give_hand(pid, spell)
	for m in mana: add_mana(pid, int(m))
	assert_ok(g.cast_spell(pid, card, [target]))
	resolve_stack()
	return card

func _bolt(pid: int, target: TargetRef) -> void:
	_cast_at(pid, "Lightning Bolt", target, [Mtg.ManaColor.R])

func _terror(pid: int, victim: CardInstance) -> void:
	_cast_at(pid, "Terror", TargetRef.card(victim), [Mtg.ManaColor.B, Mtg.ManaColor.C])

## [param pid]'s next upkeep, with its triggers on the stack.
func _to_upkeep_of(pid: int) -> void:
	var turn := g.turn_number
	var guard := 0
	while g.turn_number == turn and guard < 400:
		_advance_once()
		guard += 1
	while not (g.active_player == pid and g.current_step() == Mtg.Step.UPKEEP) and guard < 400:
		_advance_once()
		guard += 1
	assert_eq(g.active_player, pid)
	assert_eq(g.current_step(), Mtg.Step.UPKEEP)

func _ability_index(i: CardInstance, text_start: String) -> int:
	for n in i.cur_activated_abilities.size():
		if i.cur_activated_abilities[n].text.begins_with(text_start): return n
	return -1


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)
		assert_true(c.is_aura(), "%s enchants something" % card_name)


# ------------------------------------------------------------- Brilliant Halo --

func test_brilliant_halo_pumps_and_comes_home_when_its_creature_dies() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var halo := _enchant(0, "Brilliant Halo", bear, [Mtg.ManaColor.W, Mtg.ManaColor.C])
	assert_eq(_pt(bear), [3, 4])
	_bolt(1, TargetRef.card(bear))
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "a 3/4 survives the Bolt")
	_terror(1, bear)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(halo.zone, Mtg.Zone.HAND, "shed by state-based actions, it comes back")
	assert_true(g.players[0].hand.has(halo))

func test_brilliant_halo_destroyed_itself_comes_home_but_a_bounced_halo_just_goes() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var halo := _enchant(0, "Brilliant Halo", bear, [Mtg.ManaColor.W, Mtg.ManaColor.C])
	_cast_at(1, "Disenchant", TargetRef.card(halo), [Mtg.ManaColor.W, Mtg.ManaColor.C])
	assert_eq(halo.zone, Mtg.Zone.HAND)
	assert_eq(_pt(bear), [2, 2])
	halo = _enchant(0, "Brilliant Halo", bear, [Mtg.ManaColor.W, Mtg.ManaColor.C])
	var hand := g.players[0].hand.size()
	_cast_at(1, "Unsummon", TargetRef.card(bear), [Mtg.ManaColor.U])
	assert_eq(halo.zone, Mtg.Zone.HAND, "the Bear left: the Halo went to the graveyard and came back")
	assert_eq(g.players[0].hand.size(), hand + 2, "the Bear and the Halo")

func test_brilliant_halo_that_left_the_graveyard_in_response_is_not_returned() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var halo := _enchant(0, "Brilliant Halo", bear, [Mtg.ManaColor.W, Mtg.ManaColor.C])
	_priority_to(1)
	var disenchant := give_hand(1, "Disenchant")
	add_mana(1, Mtg.ManaColor.W)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, disenchant, [TargetRef.card(halo)]))
	assert_ok(g.pass_priority(1))
	assert_ok(g.pass_priority(0))   # the Disenchant resolves; the Halo's trigger waits
	assert_eq(halo.zone, Mtg.Zone.GRAVEYARD)
	assert_false(g.stack.is_empty(), "the return trigger is on the stack")
	# Setup: the card leaves the graveyard and comes back — a new object.
	g.return_from_graveyard_to_hand(halo)
	g.discard_cards(0, [halo])
	assert_eq(halo.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(halo.zone, Mtg.Zone.GRAVEYARD, "a new object: not returned (CR 400.7)")

func test_brilliant_halo_that_never_reached_the_battlefield_stays_in_the_graveyard() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var halo := give_hand(0, "Brilliant Halo")
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, halo, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(0))
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(halo.zone, Mtg.Zone.GRAVEYARD, "countered on resolution from the stack: no trigger")


# --------------------------------------------------------------------- Pariah --

func test_pariah_sends_damage_aimed_at_you_to_the_enchanted_creature() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var giant := put_battlefield(1, "Hill Giant")
	_enchant(0, "Pariah", giant, [Mtg.ManaColor.W, Mtg.ManaColor.C, Mtg.ManaColor.C])
	_bolt(1, TargetRef.player(0))
	assert_eq(g.players[0].life, 20, "the Aura's controller is spared")
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "the opponent's own creature took it")
	_bolt(1, TargetRef.player(0))
	assert_eq(g.players[0].life, 17, "no creature left to take it")

func test_pariah_does_not_touch_damage_to_the_opponent() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	_enchant(0, "Pariah", bear, [Mtg.ManaColor.W, Mtg.ManaColor.C, Mtg.ManaColor.C])
	_bolt(0, TargetRef.player(1))
	assert_eq(g.players[1].life, 17)
	assert_eq(bear.damage, 0)


# ------------------------------------------------------- Serra's / Zephid's / Shiv's Embrace --

func test_serras_embrace_gives_flying_and_vigilance() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	_enchant(0, "Serra's Embrace", bear, [Mtg.ManaColor.W, Mtg.ManaColor.W, Mtg.ManaColor.C, Mtg.ManaColor.C])
	assert_eq(_pt(bear), [4, 4])
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING))
	assert_true(bear.has_keyword(Mtg.Keyword.VIGILANCE))
	run_combat([bear.id])
	assert_eq(g.players[1].life, 16)
	assert_false(bear.tapped, "vigilance")

func test_zephids_embrace_gives_shroud_without_shedding_itself() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := _enchant(0, "Zephid's Embrace", bear, [Mtg.ManaColor.U, Mtg.ManaColor.U, Mtg.ManaColor.C, Mtg.ManaColor.C])
	assert_eq(_pt(bear), [4, 4])
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING))
	assert_true(bear.cur_shroud)
	assert_eq(aura.zone, Mtg.Zone.BATTLEFIELD, "shroud does not make the Aura illegal")
	_priority_to(1)
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(1, bolt, [TargetRef.card(bear)]))

func test_shivs_embrace_flies_and_firebreathes() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := _enchant(0, "Shiv's Embrace", bear, [Mtg.ManaColor.R, Mtg.ManaColor.R, Mtg.ManaColor.C, Mtg.ManaColor.C])
	assert_eq(_pt(bear), [4, 4])
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING))
	assert_refused(g.activate_ability(0, aura, 0, []))
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.activate_ability(0, aura, 0, []))
	assert_ok(g.activate_ability(0, aura, 0, []))
	resolve_stack()
	assert_eq(_pt(bear), [6, 4])
	advance_to_next_turn()
	assert_eq(_pt(bear), [4, 4], "until end of turn")


# -------------------------------------------------------- Cloak of Mists / Launch / Reflexes --

func test_cloak_of_mists_makes_its_creature_unblockable() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	_enchant(0, "Cloak of Mists", bear, [Mtg.ManaColor.U, Mtg.ManaColor.C])
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {giant.id: bear.id}))
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 18)

func test_launch_gives_flying_and_comes_home() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var launch := _enchant(0, "Launch", bear, [Mtg.ManaColor.U, Mtg.ManaColor.C])
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING))
	_bolt(1, TargetRef.card(bear))
	assert_eq(launch.zone, Mtg.Zone.HAND)

func test_reflexes_gives_first_strike() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var other := put_battlefield(1, "Grizzly Bears")
	_enchant(0, "Reflexes", bear, [Mtg.ManaColor.R])
	assert_true(bear.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	run_combat([bear.id], {other.id: bear.id})
	assert_eq(other.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "struck first")


# ----------------------------------------------------------------- Confiscate --

func test_confiscate_steals_any_permanent_until_it_leaves() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var ring := put_battlefield(1, "Sol Ring")
	var aura := _enchant(0, "Confiscate", ring,
		[Mtg.ManaColor.U, Mtg.ManaColor.U, Mtg.ManaColor.C, Mtg.ManaColor.C, Mtg.ManaColor.C, Mtg.ManaColor.C])
	assert_eq(ring.controller_id, 0)
	_cast_at(1, "Disenchant", TargetRef.card(aura), [Mtg.ManaColor.W, Mtg.ManaColor.C])
	assert_eq(aura.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(ring.controller_id, 1, "back to its owner")

func test_confiscate_takes_a_land() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var forest := put_battlefield(1, "Forest")
	_enchant(0, "Confiscate", forest,
		[Mtg.ManaColor.U, Mtg.ManaColor.U, Mtg.ManaColor.C, Mtg.ManaColor.C, Mtg.ManaColor.C, Mtg.ManaColor.C])
	assert_eq(forest.controller_id, 0)
	assert_true(g.players[0].battlefield.has(forest))


# ------------------------------------------------------------- Hermetic Study --

func test_hermetic_study_gives_the_creature_a_tap_ping() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	_enchant(0, "Hermetic Study", bear, [Mtg.ManaColor.U, Mtg.ManaColor.C])
	var n := _ability_index(bear, "{T}: This creature deals 1 damage")
	assert_ne(n, -1, "the creature has the ability")
	assert_ok(g.activate_ability(0, bear, n, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 19)
	assert_true(bear.tapped)

func test_hermetic_study_respects_summoning_sickness() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears", true)
	_enchant(0, "Hermetic Study", bear, [Mtg.ManaColor.U, Mtg.ManaColor.C])
	var n := _ability_index(bear, "{T}: This creature deals 1 damage")
	assert_refused(g.activate_ability(0, bear, n, [TargetRef.player(1)]))


# -------------------------------------------------------------- Pendrell Flux --

func test_pendrell_flux_sacrifices_an_unpaid_creature_in_its_controllers_upkeep() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	_enchant(0, "Pendrell Flux", bear, [Mtg.ManaColor.U, Mtg.ManaColor.C])
	_to_upkeep_of(1)
	assert_true(g.stack.is_empty(), "not the creature's controller's upkeep")
	_to_upkeep_of(0)
	assert_false(g.stack.is_empty(), "the creature's own trigger")
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "nothing to pay {1}{G} with")

func test_pendrell_flux_paid_keeps_the_creature() -> void:
	var seat := _seat(1)
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Forest")
	put_battlefield(1, "Forest")
	_enchant(0, "Pendrell Flux", bear, [Mtg.ManaColor.U, Mtg.ManaColor.C])
	_to_upkeep_of(1)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(seat.asked.size(), 1, "its controller was asked to pay")
	seat.yes = false
	_to_upkeep_of(1)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "declined")

func test_pendrell_flux_on_a_token_cannot_be_paid() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var token: CardInstance = g.create_token(1, CardData.new("Soldier", "", Mtg.CardType.CREATURE).pt(1, 1))[0]
	put_battlefield(1, "Forest")
	_enchant(0, "Pendrell Flux", token, [Mtg.ManaColor.U, Mtg.ManaColor.C])
	_to_upkeep_of(1)
	resolve_stack()
	assert_ne(token.zone, Mtg.Zone.BATTLEFIELD, "no mana cost is an unpayable cost (CR 118.6)")


# ----------------------------------------------------------------- Despondency --

func test_despondency_shrinks_and_comes_home() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var giant := put_battlefield(1, "Hill Giant")
	var aura := _enchant(0, "Despondency", giant, [Mtg.ManaColor.B, Mtg.ManaColor.C])
	assert_eq(_pt(giant), [1, 3])
	_terror(0, giant)
	assert_eq(aura.zone, Mtg.Zone.HAND)


# -------------------------------------------------------------- Parasitic Bond --

func test_parasitic_bond_burns_the_creatures_controller_each_of_their_upkeeps() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	_enchant(0, "Parasitic Bond", bear, [Mtg.ManaColor.B, Mtg.ManaColor.C, Mtg.ManaColor.C, Mtg.ManaColor.C])
	_to_upkeep_of(1)
	resolve_stack()
	assert_eq(g.players[1].life, 18)
	_to_upkeep_of(0)
	assert_true(g.stack.is_empty(), "not on its own controller's upkeep")
	assert_eq(g.players[0].life, 20)


func test_parasitic_bond_still_burns_after_the_aura_has_left() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	var bond := _enchant(0, "Parasitic Bond", bear, [Mtg.ManaColor.B, Mtg.ManaColor.C, Mtg.ManaColor.C, Mtg.ManaColor.C])
	_to_upkeep_of(1)
	assert_false(g.stack.is_empty())
	assert_eq(g.priority_player, 1)
	var disenchant := give_hand(1, "Disenchant")
	add_mana(1, Mtg.ManaColor.W)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, disenchant, [TargetRef.card(bond)]))
	resolve_stack()
	assert_eq(bond.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 18, "dealt by the Aura as it last existed (CR 608.2h)")


# ------------------------------------------------------------ Vampiric Embrace --

func test_vampiric_embrace_grows_when_a_creature_it_damaged_dies() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var sprites := put_battlefield(1, "Scryb Sprites")
	var other := put_battlefield(1, "Grizzly Bears")
	_enchant(0, "Vampiric Embrace", bear, [Mtg.ManaColor.B, Mtg.ManaColor.B, Mtg.ManaColor.C, Mtg.ManaColor.C])
	assert_eq(_pt(bear), [4, 4])
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING))
	run_combat([bear.id], {sprites.id: bear.id})
	resolve_stack()
	assert_eq(sprites.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(int(bear.counters.get("+1/+1", 0)), 1)
	assert_eq(_pt(bear), [5, 5])
	advance_to_step(Mtg.Step.MAIN2)
	_terror(0, other)
	assert_eq(int(bear.counters.get("+1/+1", 0)), 1, "it never damaged that one")


# --------------------------------------------------------------------- Bravado --

func test_bravado_counts_the_other_creatures_you_control() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Llanowar Elves")
	put_battlefield(0, "Hill Giant")
	put_battlefield(1, "Grizzly Bears")
	_enchant(0, "Bravado", bear, [Mtg.ManaColor.R, Mtg.ManaColor.C])
	assert_eq(_pt(bear), [4, 4], "two others; the opponent's do not count")


# ------------------------------------------------------------ Destructive Urge --

func test_destructive_urge_makes_the_damaged_player_sacrifice_a_land() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Forest")
	put_battlefield(1, "Island")
	_enchant(0, "Destructive Urge", bear, [Mtg.ManaColor.R, Mtg.ManaColor.R, Mtg.ManaColor.C])
	run_combat([bear.id])
	resolve_stack()
	assert_eq(g.players[1].life, 18)
	var lands := 0
	for i in g.players[1].battlefield:
		if i.is_land(): lands += 1
	assert_eq(lands, 1, "one land sacrificed, of their choice")

func test_destructive_urge_needs_combat_damage_to_a_player() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	put_battlefield(1, "Forest")
	_enchant(0, "Destructive Urge", bear, [Mtg.ManaColor.R, Mtg.ManaColor.R, Mtg.ManaColor.C])
	run_combat([bear.id], {giant.id: bear.id})
	resolve_stack()
	assert_eq(g.players[1].battlefield.size(), 2, "it hit a creature, not a player")


# ---------------------------------------------------------------- Fiery Mantle --

func test_fiery_mantle_pumps_and_comes_home() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var mantle := _enchant(0, "Fiery Mantle", bear, [Mtg.ManaColor.R, Mtg.ManaColor.C])
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, mantle, 0, []))
	resolve_stack()
	assert_eq(_pt(bear), [3, 2])
	_bolt(1, TargetRef.card(bear))
	assert_eq(mantle.zone, Mtg.Zone.HAND)


# ------------------------------------------------------------ Blanchwood Armor --

func test_blanchwood_armor_counts_your_forests() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Island")
	put_battlefield(1, "Forest")
	_enchant(0, "Blanchwood Armor", bear, [Mtg.ManaColor.G, Mtg.ManaColor.C, Mtg.ManaColor.C])
	assert_eq(_pt(bear), [4, 4], "two Forests you control")
	put_battlefield(0, "Forest")
	g.recalculate()
	assert_eq(_pt(bear), [5, 5])


# --------------------------------------------------------------- Fertile Ground --

func test_fertile_ground_adds_one_mana_of_the_chosen_color() -> void:
	var seat := _seat(0)
	seat.color = Mtg.ManaColor.U
	advance_to_step(Mtg.Step.MAIN1)
	var forest := put_battlefield(0, "Forest")
	var other := put_battlefield(0, "Forest")
	_enchant(0, "Fertile Ground", forest, [Mtg.ManaColor.G, Mtg.ManaColor.C])
	assert_ok(g.tap_for_mana(0, forest))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.G), 1)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 1, "the color its controller chose")
	assert_eq(seat.asked.size(), 1)
	assert_ok(g.tap_for_mana(0, other))
	assert_eq(g.players[0].mana_pool.total(), 3, "only the enchanted land")

func test_fertile_ground_default_answer_is_the_lands_own_color() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var island := put_battlefield(0, "Island")
	_enchant(0, "Fertile Ground", island, [Mtg.ManaColor.G, Mtg.ManaColor.C])
	assert_ok(g.tap_for_mana(0, island))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 2,
		"the hint (and so the AI's answer) is the color the planner counted")

## A colorless land: "any color" can't be colorless — the hint is the color
## the chooser's OWN hand asks for most.
func test_fertile_ground_on_a_colorless_land_hints_the_hands_color() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var factory := put_battlefield(0, "Mishra's Factory")
	_enchant(0, "Fertile Ground", factory, [Mtg.ManaColor.G, Mtg.ManaColor.C])
	give_hand(0, "Counterspell")
	give_hand(1, "Lightning Bolt")
	give_hand(1, "Lightning Bolt")
	assert_ok(g.tap_for_mana(0, factory))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 1)
	assert_eq(g.players[0].mana_pool.total(), 2)

func test_fertile_ground_on_an_opponents_land_feeds_and_asks_its_controller() -> void:
	var mine := _seat(0)
	var theirs := _seat(1)
	theirs.color = Mtg.ManaColor.R
	advance_to_step(Mtg.Step.MAIN1)
	var forest := put_battlefield(1, "Forest")
	_enchant(0, "Fertile Ground", forest, [Mtg.ManaColor.G, Mtg.ManaColor.C])
	_priority_to(1)
	assert_ok(g.tap_for_mana(1, forest))
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.R), 1)
	assert_eq(g.players[0].mana_pool.total(), 0)
	assert_eq(theirs.asked.size(), 1, "the land's controller chooses")
	assert_eq(mine.asked.size(), 0)

## The engine (Pack 10 E8) asks the colour before the tap is paid and hands
## it over on the event: the card serves that answer and asks nothing.
## Setup dispatches such an event directly.
func test_fertile_ground_serves_a_color_the_engine_already_asked() -> void:
	var seat := _seat(0)
	seat.color = Mtg.ManaColor.U
	advance_to_step(Mtg.Step.MAIN1)
	var forest := put_battlefield(0, "Forest")
	var aura := _enchant(0, "Fertile Ground", forest, [Mtg.ManaColor.G, Mtg.ManaColor.C])
	seat.asked.clear()
	g.dispatch_event(Mtg.EventType.TAPPED_FOR_MANA, {"instance": forest, "controller": 0, "player": 0,
		"color": Mtg.ManaColor.G, "colors": [Mtg.ManaColor.G], "bonus_colors": {aura.id: Mtg.ManaColor.B}})
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 1)
	assert_eq(seat.asked.size(), 0, "already answered")

func test_fertile_ground_enchants_only_a_land() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := give_hand(0, "Fertile Ground")
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.cast_spell(0, aura, [TargetRef.card(bear)]))

func test_fertile_ground_is_described_to_the_mana_planner() -> void:
	var bonus: TriggeredAbility = CardRegistry.get_card("Fertile Ground").triggered_abilities[0]
	assert_true(bonus.is_mana_trigger)
	assert_eq(bonus.mana_bonus_subtype, ManaPlanner.BONUS_ENCHANTED_LAND)
	assert_eq(bonus.mana_bonus_amount, 1)
	assert_eq(bonus.mana_bonus_color, ManaPlanner.BONUS_ANY_COLOR, "one mana of any color, asked before paying")


# -------------------------------------------------------------------- Fortitude --

func test_fortitude_regenerates_for_a_forest_and_comes_home() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var forest := put_battlefield(0, "Forest")
	var fortitude := _enchant(0, "Fortitude", bear, [Mtg.ManaColor.G, Mtg.ManaColor.C])
	assert_ok(g.activate_ability(0, fortitude, 0, []))
	resolve_stack()
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD, "the Forest paid")
	_bolt(1, TargetRef.card(bear))
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "regenerated")
	assert_true(bear.tapped)
	assert_refused(g.activate_ability(0, fortitude, 0, []))
	_bolt(1, TargetRef.card(bear))
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(fortitude.zone, Mtg.Zone.HAND)


# --------------------------------------------------------------- Gaea's Embrace --

func test_gaeas_embrace_pumps_tramples_and_regenerates() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := _enchant(0, "Gaea's Embrace", bear, [Mtg.ManaColor.G, Mtg.ManaColor.G, Mtg.ManaColor.C, Mtg.ManaColor.C])
	assert_eq(_pt(bear), [5, 5])
	assert_true(bear.has_keyword(Mtg.Keyword.TRAMPLE))
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, aura, 0, []))
	resolve_stack()
	_cast_at(1, "Terror", TargetRef.card(bear), [Mtg.ManaColor.B, Mtg.ManaColor.C])
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "Terror: no regeneration")


func test_gaeas_embrace_shield_saves_from_damage() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := _enchant(0, "Gaea's Embrace", bear, [Mtg.ManaColor.G, Mtg.ManaColor.G, Mtg.ManaColor.C, Mtg.ManaColor.C])
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, aura, 0, []))
	resolve_stack()
	_cast_at(1, "Lightning Bolt", TargetRef.card(bear), [Mtg.ManaColor.R])
	_bolt(1, TargetRef.card(bear))
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "six damage on a 5/5: regenerated")


# ------------------------------------------------------------- Spreading Algae --

func test_spreading_algae_destroys_its_swamp_when_tapped_and_comes_home() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var swamp := put_battlefield(1, "Swamp")
	var algae := _enchant(0, "Spreading Algae", swamp, [Mtg.ManaColor.G])
	_priority_to(1)
	assert_ok(g.tap_for_mana(1, swamp))
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.B), 1, "the mana is made first")
	resolve_stack()
	assert_eq(swamp.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(algae.zone, Mtg.Zone.HAND, "it fell off and came home")

func test_spreading_algae_enchants_only_a_swamp() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var forest := put_battlefield(1, "Forest")
	var algae := give_hand(0, "Spreading Algae")
	add_mana(0, Mtg.ManaColor.G)
	assert_refused(g.cast_spell(0, algae, [TargetRef.card(forest)]))


# --------------------------------------------------------------- Venomous Fangs --

func test_venomous_fangs_destroys_a_creature_it_damages() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var elves := put_battlefield(0, "Llanowar Elves")
	var wurm := put_battlefield(1, "Craw Wurm")
	_enchant(0, "Venomous Fangs", elves, [Mtg.ManaColor.G, Mtg.ManaColor.C, Mtg.ManaColor.C])
	run_combat([elves.id], {wurm.id: elves.id})
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD, "one damage was enough")
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)

func test_venomous_fangs_ignores_damage_to_players() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var elves := put_battlefield(0, "Llanowar Elves")
	var wurm := put_battlefield(1, "Craw Wurm")
	_enchant(0, "Venomous Fangs", elves, [Mtg.ManaColor.G, Mtg.ManaColor.C, Mtg.ManaColor.C])
	run_combat([elves.id])
	resolve_stack()
	assert_eq(g.players[1].life, 19)
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)
