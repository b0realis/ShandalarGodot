extends GameTest
## Pack 10 (the Urza block), batch B6: the triggered enchantments of
## cards/sets/usg/_enchantments.gd and cards/sets/ulg/_enchantments.gd —
## Angelic Chorus, Remembrance, Bereavement, Oppression, Tainted Aether,
## Yawgmoth's Edict, Antagonism, Bulwark, Scald, Fecundity, Greener
## Pastures, Sporogenesis, Delusions of Mediocrity, No Mercy, Subversion
## and Rivalry.

const W := Mtg.ManaColor.W
const U := Mtg.ManaColor.U
const B := Mtg.ManaColor.B
const R := Mtg.ManaColor.R
const G := Mtg.ManaColor.G

## A seat whose answers a test scripts: yes/no (-1 follows the hint) and
## card names to prefer.
class Seat extends DecisionAgent:
	var yes := -1
	var prefer: Array = []
	var asked: Array = []
	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String, hint: bool) -> bool:
		asked.append(prompt)
		return hint if yes < 0 else yes == 1
	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		asked.append(prompt)
		for name in prefer:
			for c in candidates:
				if c.data.card_name == name: return c
		return null if candidates.is_empty() else candidates[0]

var me: Seat
var foe: Seat


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	me = Seat.new()
	foe = Seat.new()
	g.set_agent(0, me)
	g.set_agent(1, foe)
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _to_upkeep(pid: int) -> void:
	var start := g.turn_number
	var guard := 0
	while not g.game_over and guard < 800 and not (g.turn_number > start
			and g.active_player == pid and g.current_step() == Mtg.Step.UPKEEP):
		_advance_once()
		guard += 1
	assert_lt(guard, 800, "never reached the upkeep")

func _priority(pid: int) -> void:
	if g.priority_player != pid:
		assert_ok(g.pass_priority(g.priority_player))
	assert_eq(g.priority_player, pid)

func _cast(pid: int, card_name: String, targets: Array = []) -> CardInstance:
	var card := give_hand(pid, card_name)
	for color in [W, U, B, R, G]: add_mana(pid, color, 4)
	assert_ok(g.cast_spell(pid, card, targets))
	resolve_stack()
	return card

func _named(pid: int, card_name: String) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for i in g.players[pid].battlefield:
		if i.data.card_name == card_name: out.append(i)
	return out

func _bolt(pid: int, target: TargetRef) -> void:
	_priority(pid)
	var bolt := give_hand(pid, "Lightning Bolt")
	add_mana(pid, R)
	assert_ok(g.cast_spell(pid, bolt, [target]))
	resolve_stack()


# ----------------------------------------------------------- Angelic Chorus --

func test_angelic_chorus_gains_the_entering_creatures_toughness() -> void:
	put_battlefield(0, "Angelic Chorus")
	_cast(0, "Craw Wurm")
	assert_eq(g.players[0].life, 24)
	put_battlefield(1, "Grizzly Bears")
	resolve_stack()
	assert_eq(g.players[0].life, 24, "only creatures you control")
	assert_eq(g.players[1].life, 20)


func test_angelic_chorus_counts_a_creature_that_left_by_its_last_toughness() -> void:
	put_battlefield(0, "Angelic Chorus")
	put_battlefield(0, "Glorious Anthem")
	var wurm := give_hand(0, "Craw Wurm")
	add_mana(0, G, 6)
	assert_ok(g.cast_spell(0, wurm))
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))   # the Wurm resolves; the Chorus triggers
	assert_eq(g.stack.size(), 1)
	g.destroy(wurm)
	resolve_stack()
	assert_eq(g.players[0].life, 25, "5: as it last existed, with the Anthem (CR 608.2h)")


# -------------------------------------------------------------- Remembrance --

func test_remembrance_finds_a_copy_of_the_dead_creature() -> void:
	put_battlefield(0, "Remembrance")
	var bears := put_battlefield(0, "Grizzly Bears")
	var copy := _make_instance(0, "Grizzly Bears")
	copy.zone = Mtg.Zone.LIBRARY
	g.players[0].library.insert(0, copy)
	me.yes = 1
	g.destroy(bears)
	resolve_stack()
	assert_eq(copy.zone, Mtg.Zone.HAND)


func test_remembrance_is_optional_and_ignores_tokens_and_the_opponent() -> void:
	put_battlefield(0, "Remembrance")
	var bears := put_battlefield(0, "Grizzly Bears")
	var copy := _make_instance(0, "Grizzly Bears")
	copy.zone = Mtg.Zone.LIBRARY
	g.players[0].library.insert(0, copy)
	me.yes = 0
	g.destroy(bears)
	resolve_stack()
	assert_eq(copy.zone, Mtg.Zone.LIBRARY)
	var asked := me.asked.size()
	g.destroy(put_battlefield(1, "Grizzly Bears"))
	var token := g.create_token(0, CardData.new("Saproling", "", Mtg.CardType.CREATURE).pt(1, 1))
	g.destroy(token[0])
	resolve_stack()
	assert_eq(me.asked.size(), asked, "no trigger for theirs or a token")


# -------------------------------------------------------------- Bereavement --

func test_bereavement_makes_a_green_creatures_controller_discard() -> void:
	put_battlefield(0, "Bereavement")
	var elves := put_battlefield(1, "Llanowar Elves")
	var giant := put_battlefield(1, "Hill Giant")
	give_hand(1, "Forest")
	give_hand(1, "Island")
	g.destroy(giant)
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 2, "not green")
	g.destroy(elves)
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 1)


# --------------------------------------------------------------- Oppression --

func test_oppression_makes_each_caster_discard() -> void:
	put_battlefield(0, "Oppression")
	give_hand(1, "Forest")
	give_hand(1, "Island")
	var bolt := give_hand(1, "Lightning Bolt")
	_priority(1)
	add_mana(1, R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 1, "the caster discarded one")
	give_hand(0, "Forest")
	_cast(0, "Grizzly Bears")
	assert_eq(g.players[0].hand.size(), 0, "its controller too")


# ----------------------------------------------------------- Tainted Aether --

func test_tainted_aether_makes_the_entering_creatures_controller_sacrifice() -> void:
	put_battlefield(1, "Tainted Aether")
	var land := put_battlefield(0, "Forest")
	foe.prefer = []
	var bears := _cast(0, "Grizzly Bears")
	var gone := 0
	for i in [land, bears]:
		if i.zone == Mtg.Zone.GRAVEYARD: gone += 1
	assert_eq(gone, 1, "a creature or land of their choice")


func test_tainted_aether_lets_the_player_choose_the_creature_itself() -> void:
	put_battlefield(1, "Tainted Aether")
	var land := put_battlefield(0, "Forest")
	me.prefer = ["Grizzly Bears"]
	var bears := _cast(0, "Grizzly Bears")
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(land.zone, Mtg.Zone.BATTLEFIELD)


# --------------------------------------------------------- Yawgmoth's Edict --

func test_yawgmoths_edict_drains_on_an_opponents_white_spell() -> void:
	put_battlefield(0, "Yawgmoth's Edict")
	var ring := put_battlefield(0, "Sol Ring")
	_priority(1)
	var disenchant := give_hand(1, "Disenchant")
	add_mana(1, W, 2)
	assert_ok(g.cast_spell(1, disenchant, [TargetRef.card(ring)]))
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 19)
	assert_eq(g.players[0].life, 21)
	_cast(0, "Savannah Lions")
	assert_eq(g.players[0].life, 21, "not its controller's white spells")
	assert_eq(g.players[1].life, 19)


# --------------------------------------------------------------- Antagonism --

func test_antagonism_burns_a_player_whose_opponent_took_no_damage() -> void:
	put_battlefield(1, "Antagonism")
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(g.players[0].life, 18)
	advance_to_next_turn()
	_bolt(1, TargetRef.player(0))
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(g.players[1].life, 20, "its opponent was dealt damage this turn")


# ------------------------------------------------------------------ Bulwark --

func test_bulwark_deals_the_hand_size_difference() -> void:
	put_battlefield(0, "Bulwark")
	_to_upkeep(0)
	for n in 4: give_hand(0, "Forest")
	give_hand(1, "Forest")
	var x := g.players[0].hand.size() - g.players[1].hand.size()
	assert_gt(x, 0)
	resolve_stack()
	assert_eq(g.players[1].life, 20 - x, "counted on resolution")


func test_bulwark_never_deals_a_negative_amount() -> void:
	put_battlefield(0, "Bulwark")
	_to_upkeep(0)
	for n in 5: give_hand(1, "Forest")
	resolve_stack()
	assert_eq(g.players[1].life, 20)
	assert_eq(g.players[0].life, 20)


# -------------------------------------------------------------------- Scald --

func test_scald_burns_whoever_taps_an_island_for_mana() -> void:
	put_battlefield(0, "Scald")
	var island := put_battlefield(1, "Island")
	var forest := put_battlefield(1, "Forest")
	assert_ok(g.tap_for_mana(1, forest))
	resolve_stack()
	assert_eq(g.players[1].life, 20)
	assert_ok(g.tap_for_mana(1, island))
	resolve_stack()
	assert_eq(g.players[1].life, 19)


# ---------------------------------------------------------------- Fecundity --

func test_fecundity_asks_the_dead_creatures_controller() -> void:
	put_battlefield(0, "Fecundity")
	var theirs := put_battlefield(1, "Grizzly Bears")
	var hand := g.players[1].hand.size()
	foe.yes = 1
	g.destroy(theirs)
	resolve_stack()
	assert_eq(g.players[1].hand.size(), hand + 1)
	assert_eq(foe.asked.size(), 1)
	assert_eq(me.asked.size(), 0)
	var mine := put_battlefield(0, "Grizzly Bears")
	me.yes = 0
	g.destroy(mine)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 0, "declined")


# --------------------------------------------------------- Greener Pastures --

func test_greener_pastures_feeds_the_player_with_the_most_lands() -> void:
	put_battlefield(0, "Greener Pastures")
	for n in 3: put_battlefield(1, "Forest")
	for n in 2: put_battlefield(0, "Forest")
	_to_upkeep(1)
	resolve_stack()
	assert_eq(_named(1, "Saproling").size(), 1, "the upkeep player's token")
	_to_upkeep(0)
	resolve_stack()
	assert_eq(_named(0, "Saproling").size(), 0, "fewer lands")


func test_greener_pastures_rechecks_on_resolution() -> void:
	put_battlefield(0, "Greener Pastures")
	put_battlefield(0, "Forest")
	_to_upkeep(0)
	assert_eq(g.stack.size(), 1)
	put_battlefield(1, "Forest")
	resolve_stack()
	assert_eq(_named(0, "Saproling").size(), 0, "a tie is not more (CR 603.4)")


# ------------------------------------------------------------- Sporogenesis --

func test_sporogenesis_turns_fungus_counters_into_saprolings() -> void:
	put_battlefield(0, "Sporogenesis")
	var giant := put_battlefield(1, "Hill Giant")
	_to_upkeep(0)
	resolve_stack()
	assert_eq(int(giant.counters.get("fungus", 0)), 1, "the opponent's creature first")
	_to_upkeep(0)
	resolve_stack()
	assert_eq(int(giant.counters.get("fungus", 0)), 2)
	g.destroy(giant)
	resolve_stack()
	assert_eq(_named(0, "Saproling").size(), 2, "one per counter, for Sporogenesis's controller")


func test_sporogenesis_counter_is_optional() -> void:
	put_battlefield(0, "Sporogenesis")
	var giant := put_battlefield(1, "Hill Giant")
	me.yes = 0
	_to_upkeep(0)
	resolve_stack()
	assert_eq(int(giant.counters.get("fungus", 0)), 0)


func test_sporogenesis_leaving_removes_every_fungus_counter() -> void:
	var spore := put_battlefield(0, "Sporogenesis")
	var giant := put_battlefield(1, "Hill Giant")
	g.add_counters(giant, "fungus", 2)
	g.destroy(spore)
	resolve_stack()
	assert_eq(int(giant.counters.get("fungus", 0)), 0)


# -------------------------------------------------- Delusions of Mediocrity --

func test_delusions_gains_ten_and_loses_ten() -> void:
	var delusions := _cast(0, "Delusions of Mediocrity")
	assert_eq(g.players[0].life, 30)
	g.destroy(delusions)
	resolve_stack()
	assert_eq(g.players[0].life, 20)


func test_delusions_costs_the_player_who_controlled_it_as_it_left() -> void:
	var delusions := _cast(0, "Delusions of Mediocrity")
	g.change_control(delusions, 1)
	resolve_stack()
	g.destroy(delusions)
	resolve_stack()
	assert_eq(g.players[0].life, 30)
	assert_eq(g.players[1].life, 10)


# ----------------------------------------------------------------- No Mercy --

func test_no_mercy_destroys_a_creature_that_damages_you() -> void:
	put_battlefield(1, "No Mercy")
	var giant := put_battlefield(0, "Hill Giant")
	run_combat([giant.id])
	resolve_stack()
	assert_eq(g.players[1].life, 17)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)


func test_no_mercy_ignores_damage_to_other_players_and_noncreature_sources() -> void:
	put_battlefield(0, "No Mercy")
	var giant := put_battlefield(0, "Hill Giant")
	run_combat([giant.id])
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "it damaged the opponent")
	_bolt(1, TargetRef.player(0))
	assert_eq(g.players[0].life, 17)


# --------------------------------------------------------------- Subversion --

func test_subversion_drains_one_each_upkeep() -> void:
	put_battlefield(0, "Subversion")
	_to_upkeep(0)
	resolve_stack()
	assert_eq(g.players[1].life, 19)
	assert_eq(g.players[0].life, 21)
	_to_upkeep(1)
	resolve_stack()
	assert_eq(g.players[1].life, 19, "only its controller's upkeep")


# ------------------------------------------------------------------ Rivalry --

func test_rivalry_burns_the_upkeep_player_with_the_most_lands() -> void:
	put_battlefield(0, "Rivalry")
	for n in 3: put_battlefield(1, "Forest")
	put_battlefield(0, "Forest")
	_to_upkeep(1)
	resolve_stack()
	assert_eq(g.players[1].life, 18)
	_to_upkeep(0)
	resolve_stack()
	assert_eq(g.players[0].life, 20, "fewer lands: nothing")
